require 'dry-types'
require 'dry-struct'

module Snapcast
  module Types
    include Dry.Types()

    class Base < Dry::Struct
      transform_keys do |key|
        inflector = Dry::Inflector.new
        inflector.underscore(key).to_sym
      end
    end

    class Volume < Base
      attribute :muted, Types::Bool
      attribute :percent, Types::Integer
    end

    class Config < Base
      attribute :instance, Types::Integer
      attribute :latency, Types::Integer
      attribute :name, Types::String
      attribute :volume, Volume
    end

    class Host < Base
      attribute :arch, Types::String
      attribute :ip, Types::String
      attribute :mac, Types::String
      attribute :name, Types::String
      attribute :os, Types::String
    end

    class LastSeen < Base
      attribute :sec, Types::Integer
      attribute :usec, Types::Integer
    end

    class Meta < Base
      attribute :stream, Types::String
      attribute? :title, Types::String
      attribute? :album, Types::String
      attribute? :artist, Types::String
      attribute? :cover, Types::String
    end

    class Query < Base
      attribute? :autoplay, Types::String
      attribute? :bitrate, Types::Coercible::Integer
      attribute? :cache, Types::String
      attribute? :chunk_ms, Types::Coercible::Integer
      attribute? :codec, Types::String
      attribute? :device, Types::String
      attribute? :devicename, Types::String
      attribute? :disable_audio_cache, Types::String
      attribute? :dryout_ms, Types::Coercible::Integer
      attribute? :idle_threshold, Types::String
      attribute? :killall, Types::String
      attribute? :log_stderr, Types::String
      attribute? :mode, Types::String
      attribute? :name, Types::String
      attribute? :normalize, Types::String
      attribute? :onevent, Types::String
      attribute? :params, Types::String
      attribute? :password, Types::String
      attribute? :port, Types::Coercible::Integer
      attribute? :sampleformat, Types::String
      attribute? :send_silence, Types::String
      attribute? :username, Types::String
      attribute? :volume, Types::Coercible::Integer
      attribute? :wd_timeout, Types::String
    end

    class URI < Base
      attribute :fragment, Types::String
      attribute :host, Types::String
      attribute :path, Types::String
      attribute :raw, Types::String
      attribute :scheme, Types::String
      attribute :query, Query
    end

    class Snapclient < Base
      attribute :name, Types::String
      attribute :protocol_version, Types::Integer
      attribute :version, Types::String
    end

    class Snapserver < Base
      attribute :control_protocol_version, Types::Integer
      attribute :name, Types::String
      attribute :protocol_version, Types::Integer
      attribute :version, Types::String
    end

    class Client < Base
      attribute :config, Config
      attribute :connected, Types::Bool
      attribute :host, Host
      attribute :id, Types::String
      attribute :last_seen, LastSeen
      attribute :snapclient, Snapclient
    end

    class Group < Base
      attribute :clients, Types::Array.of(Client)
      attribute :id, Types::String
      attribute :muted, Types::Bool
      attribute :name, Types::String
      attribute :stream_id, Types::String
    end

    class Stream < Base
      attribute :id, Types::String
      attribute :meta, Meta
      attribute :status, Types::String
      attribute :uri, URI
    end

    class Server < Base
      attribute :host, Host
      attribute :snapserver, Snapserver
    end

    class ServerStatus < Base
      attribute :groups, Types::Array.of(Group)
      attribute :streams, Types::Array.of(Stream)
      attribute :server, Server
    end
  end
end
