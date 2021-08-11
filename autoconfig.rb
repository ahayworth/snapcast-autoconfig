require 'logger'
require 'yaml'
require_relative './lib/snapcast'

config_file = ARGV.last
if config_file.nil? || !File.readable?(config_file)
  raise Snapcast::Error.new("Unable to read config file '#{config_file}'! Usage: ruby autoconfig.rb /path/to/config.yml")
end
@config = {
  'loglevel' =>'info',
  'polling_interval' => 2,
}.merge(YAML::load(File.read(config_file)))

@logger = Logger.new(STDOUT, level: Logger::INFO)
if @config['loglevel'] != 'info'
  new_level = "#{@config['loglevel']}!".to_sym
  @logger.send(new_level) if @logger.respond_to?(new_level)
end
Async.logger = @logger

Async(annotation: "autoconfig.rb", logger: @logger) do |task|
  begin
    server = Snapcast::Server.new(@config['server'])
    server.logger = @logger
    server.poll!(@config['polling_interval'])

    loop do
      if server.groups.any?
        @logger.debug("\n" + [
          "-" * 10,
          server.groups.map { |g|
            "#{g.id} (name: '#{g.name}', stream: '#{g.stream&.id}', muted: '#{g.muted}' / #{g.stream&.status}) #{g.clients.map(&:id).inspect}"
          },
          "-" * 10,
        ].join("\n"))
      end

      # For each playing stream, determine if any changes need to be made.
      # Ignore streams we're not managing (not in the config file) or that aren't playing, for now.
      playing_streams = server.streams.select do |stream|
        stream.playing? && @config['streams'].has_key?(stream.id)
      end

      # Sort the streams so that they're ordered the same way as the config file.
      playing_streams.sort_by! { |stream| @config['streams'].keys.index(stream.id) }

      playing_streams.each do |stream|
        # Find the configuration for this stream.
        stream_config = @config['streams'][stream.id]

        # Filter out any clients from the config that should be in higher-priority streams.
        desired_client_ids = stream_config['clients'].reject do |client_id|
          idx = @config['streams'].keys.index(stream.id)
          more_important_streams = @config['streams'].first(idx).to_h.select do |k, _|
            server.streams.select { |s| s.playing? }.map(&:id).include?(k)
          end
          more_important_clients = more_important_streams.flat_map { |_, v| v['clients'] }

          more_important_clients.include?(client_id)
        end
        desired_clients = server.clients.select { |c| desired_client_ids.include?(c.id) }

        # Bail out if we shouldn't actually move any clients to this stream.
        next if desired_client_ids.none? || desired_clients.none?

        # Now, find a candidate group to manage
        candidate_group = server.groups
          .select { |g| (g.clients.map(&:id) & desired_client_ids).any? }
          .sort_by { |g| g.clients.size }
          .first

        # Bail if we can't find a group (I don't think this should happen)
        next unless candidate_group

        # Pull out any desired volume changes, with a default of '100'.
        volume_config = stream_config['volume'] || {}
        volume_config.default = 100

        # Next, determine if this group is misconfigured in some way.
        correct_stream = candidate_group.stream.id == stream.id
        correct_clients = candidate_group.clients.map(&:id).to_set == desired_client_ids.to_set
        correct_name = candidate_group.name == stream.id
        correct_volume = candidate_group.clients.all? { |c| c.config.volume.percent == volume_config[c.id] }
        correct_muted = !candidate_group.muted
        unless correct_stream && correct_clients && correct_name && correct_volume && correct_muted
          # We need to make changes, so let's log that proposal.
          @logger.info "MISCONFIGURED: #{stream.id}"
          @logger.info <<~EOF
            Going to reconfigure group '#{candidate_group.id}':
              Name: #{candidate_group.name} -> #{stream.id}
              Stream: #{candidate_group.stream.id} -> #{stream.id}
              Clients: #{candidate_group.clients.map(&:id).sort} -> #{desired_client_ids.sort}
              Muted: #{candidate_group.muted} -> false
          EOF
          candidate_group.clients.each do |client|
            @logger.info "    #{client.id} volume: #{client.config.volume.percent} -> #{volume_config[client.id]}"
          end

          # Actually make the changes now.
          candidate_group.stream = stream unless correct_stream
          candidate_group.clients = desired_clients unless correct_clients
          candidate_group.name = stream.id unless correct_name

          # We wouldn't have had correct client info for volume manipulation
          # before, so we should break now and get new info before trying volume manipulation.
          break unless correct_clients

          candidate_group.clients.each do |client|
            new_volume = volume_config[client.id]
            client.volume = new_volume unless client.config.volume.percent == new_volume
          end

          candidate_group.muted = false unless correct_muted

          # Break out of the loop if we've made changes (we have, by this point) so we
          # can start the next round of modifications with correct info.
          break
        end
      end

      # Mute any incorrectly configured groups.
      # An incorrectly-configured group is one which, at this point is pointing towards a managed stream, but that stream's
      # configuration does not specify the client in question.  We mute because frankly that's just a lot easier given
      # the weird, idiosyncratic way that snapcast manages groups and streams and clients.
      server.groups.each do |group|
        # Is this a playing, unmuted, managed group? If so, check it.
        if group.stream.playing? && !group.muted && @config['streams'].has_key?(group.stream.id)
          group_client_list = group.clients.map(&:id).sort
          config_client_list = @config['streams'][group.stream.id]['clients'].sort

          if group_client_list != config_client_list
            @logger.info "MISCONFIGURED: #{group.id}"
            @logger.info <<~EOF
              Going to mute group '#{group.id}' / '#{group.name}' / '#{group.stream.id}'!
            EOF

            group.muted = true
          end
        end
      end

      task.sleep @config['polling_interval']
    end
  rescue => e
    puts e.backtrace.inspect
    raise Snapcast::Error.new(e)
  end
end
