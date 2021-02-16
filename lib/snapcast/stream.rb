require_relative './types'

module Snapcast
  class Stream
    attr_reader :id, :status, :uri
    attr_reader :server

    def initialize(attrs, server)
      @server = server
      @id = attrs["id"]
      @status = attrs["status"]
      @uri = Snapcast::Types::URI.new(attrs["uri"])
    end

    def destroy!
      server.request("Stream.RemoveStream", id: id)
    end

    def playing?
      status == "playing"
    end

    # TODO: ...
    def self.SetMeta(id, meta)
    end
  end
end
