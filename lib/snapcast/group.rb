module Snapcast
  class Group
    attr_reader :id, :muted, :name, :stream_id
    attr_reader :stream, :server, :clients

    def initialize(attrs, stream, clients, server)
      @server = server
      @stream = stream
      @clients = clients

      @id = attrs["id"]
      @muted = attrs["muted"]
      @name = attrs["name"]
      @stream_id = attrs["stream_id"]
    end

    def refresh!
      # We have only one place for handling logic like this.
      server.refresh!
    end

    def muted=(muted)
      server.request("Group.SetMute", id: id, mute: muted)
    end

    def stream_id=(stream_id)
      set_stream(stream_id)
    end

    def stream=(stream)
      stream_id = stream.instance_of?(Snapcast::Stream) ? stream.id : stream
      set_stream(stream_id)
    end

    def set_stream(stream_id)
      server.request("Group.SetStream", id: id, stream_id: stream_id)
    end
    private :set_stream

    def clients=(clients)
      new_clients = clients.map do |c|
        if c.instance_of?(Snapcast::Client)
          c.id
        else
          c
        end
      end

      server.request("Group.SetClients", id: id, clients: new_clients)
    end

    def name=(new_name)
      server.request("Group.SetName", id: id, name: new_name)
    end
  end
end
