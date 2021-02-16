require 'async'
require 'async/io/host_endpoint'
require 'async/io/protocol/line'
require 'async/io/stream'
require 'json-rpc-objects/v20/request'
require 'json-rpc-objects/v20/response'
require 'logger'

require_relative './client'
require_relative './group'
require_relative './stream'
require_relative './types'

module Snapcast
  class Server
    attr_reader :groups
    attr_reader :streams
    attr_reader :clients
    attr_reader :host
    attr_reader :snapserver

    attr_accessor :logger

    def initialize(uri)
      @groups = []
      @streams = []
      @clients = []
      @host = nil
      @snapserver = nil

      @calls = {}
      @last_id = 0
      @last_update = Time.at(0)
      @mutex = Mutex.new
      @uri = uri
      @endpoint = Async::IO::Endpoint.parse(@uri)
      @reactor_task = Async::Task.current
      @logger = Logger.new(STDOUT, level: Logger::INFO)
    end

    def refresh!
      request("Server.GetStatus")
    end

    def poll!(interval = 1)
      @reactor_task.async(annotation: "poll!") do |task|
        begin
          loop do
            refresh!.wait
            task.sleep interval
          end
        rescue => e
          task.reactor.print_hierarchy(backtrace: false)
          raise Snapcast::Error.new(e)
        end
      end
    end

    # TODO: this is wrong?
    def rpc_version
      request("Server.GetRPCVersion")
    end

    def add_stream(stream_uri)
      request("Stream.AddStream", streamUri: stream_uri)
    end

    def remove_stream(id)
      request("Stream.RemoveStream", id: id)
    end

    def delete_client(id)
      request("Server.DeleteClient", id: id)
    end

    def connected?
      return false unless @line_proto
      return !@line_proto.closed? && @stream.connected?
    end

    def request(method, params = [])
      connect! unless connected?

      task = @reactor_task.async(annotation: "request") do |st|
        request = @mutex.synchronize do
          @last_id += 1
          @calls[@last_id] = method

          JsonRpcObjects::V20::Request.create(method, params, id: @last_id)
        end

        @logger.debug "-> #{method} (#{params})"

        begin
          @line_proto.write_lines(request.serialize)
        rescue Errno::EPIPE
          st.reactor.print_hierarchy(backtrace: false)
          raise Snapcast::Error.new("Disconnected from #{@uri}!")
        end
      end

      task
    end

    def handle_messages
      @handle_messages_task.stop if @handle_messages_task
      @handle_messages_task = @reactor_task.async(annotation: "handle_messages") do |task|
        begin
          while line = @line_proto.read_line
            resp = JsonRpcObjects::V20::Response::parse(line)
            raise Snapcast::Error.new(resp.output) if resp.error?
            case @calls.delete(resp.id)
            when "Server.GetStatus"
              @logger.debug "<- Server.GetStatus"
              update_server_from_response(resp)
            when nil # Probably an inbound notification...
              @logger.debug "<- #{resp.output["method"]}"
              if resp.output["method"].match?(/^(Client|Group|Stream|Server)\.On.+/)
                # Something changed, just refresh the world...
                refresh!
              end
            end
          end
        rescue EOFError
          task.reactor.print_hierarchy(backtrace: false)
          raise Snapcast::Error.new("Disconnected from #{@uri}!")
        end
      end
    end
    private :handle_messages

    def connect!
      task = @reactor_task.async(annotation: "connect!") do
        @socket = @endpoint.connect
        @stream = Async::IO::Stream.new(@socket)
        @line_proto = Async::IO::Protocol::Line.new(@stream)
      end
      task.wait
      handle_messages
    end
    private :connect!

    def update_server_from_response(resp)
      @last_update = Time.now
      @streams = resp.result.dig("server", "streams").map do |stream|
        Snapcast::Stream.new(stream, self)
      end

      @clients = resp.result.dig("server", "groups").flat_map do |group|
        group["clients"].map do |client|
          Snapcast::Client.new(client, self)
        end
      end

      @groups = resp.result.dig("server", "groups").map do |group|
        stream = @streams.find { |s| s.id == group["stream_id"] }
        client_ids = group["clients"].map { |c| c["id"] }
        clients = @clients.select { |c| client_ids.include?(c.id) }
        Snapcast::Group.new(group, stream, clients, self)
      end

      @host = Snapcast::Types::Host.new(resp.result.dig("server", "server", "host"))
      @snapserver = Snapcast::Types::Snapserver.new(resp.result.dig("server", "server", "snapserver"))
    end
    private :update_server_from_response
  end
end
