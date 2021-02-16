require_relative './types'

module Snapcast
  class Client
    attr_reader :id, :connected, :config, :host, :last_seen, :snapclient
    attr_reader :server

    def initialize(attrs, server)
      @server = server

      @id = attrs["id"]
      @connected = attrs["connected"]
      @config = Snapcast::Types::Config.new(attrs["config"])
      @host = Snapcast::Types::Host.new(attrs["host"])
      @last_seen = Snapcast::Types::LastSeen.new(attrs["lastSeen"])
      @snapclient = Snapcast::Types::Snapclient.new(attrs["snapclient"])
    end

    def refresh!
      # We have only one place for handling logic like this.
      server.refresh!
    end

    def volume=(percent)
      server.request("Client.SetVolume", id: id, volume: { percent: percent, muted: percent == 0 })
    end

    def latency=(latency)
      server.request("Client.SetLatency", id: id, latency: latency)
    end

    def name=(new_name)
      server.request("Client.SetName", id: id, name: new_name)
    end
  end
end
