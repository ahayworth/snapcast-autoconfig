'use strict';

const debug = require('debug')('snapcast');
const deepEqual = require('deep-equal');
const net = require('net');
const jsonrpc = require('jsonrpc-lite');
const { Connection } = require('socket-json-wrapper');

const config = require('./config');

class Snapcast {
  constructor(config) {
    this.config = config;

    this.last_request_id = 0;
    this.request_log = [];

    this.streams = {};
    this.groups = {};

    this.sock = net.createConnection(this.config.port, this.config.host);
    this.conn = new Connection(this.sock);

    this.conn.on('message', this.handle_response.bind(this));
    this.conn.on('error', function(err) {
      console.log('Got error: ');
      console.log(err);
      process.exit(1);
    });
  }

  next_request_id() {
    return this.last_request_id++;
  }

  handle_response(msg) {
    var responses = [msg].flat().map(m => jsonrpc.parseJsonRpcObject(m));
    var checkSync = false;
    debug(responses);

    for (var resp of responses) {
      if (resp.type === 'success') {
        var method = this.request_log[resp.payload.id];
        if (method === 'Server.GetStatus' || method === 'Group.SetClients') {
          this.handle_update(resp.payload.result);
          checkSync = true;
        }
      } else if (resp.type === 'error') {
        var req = this.request_log[resp.payload.id];
        if (req !== undefined) {
          console.log('Got error for request "' + req + '":');
        } else {
          console.log('Got error:');
        }
        console.log(resp.payload);

        const ignorable = [
          'Group.SetStream',
          'Group.SetClients',
          'Group.SetName',
        ];
        if (ignorable.includes(req) && resp.payload.error.data === 'Group not found') {
          console.log("...but I'm ignoring it for the moment.");
        } else {
          console.log("...and I'm not sure what to do. See ya!");
          process.exit(1);
        }
      } else if (resp.type === 'notification') {
        if (resp.payload.method === 'Stream.OnUpdate') {
          var st = this.streams.find(s => {
            return s.id === resp.payload.params.stream.id;
          });

          if (st !== undefined) {
            st.status = resp.payload.params.stream.status;
          }
          checkSync = true;
        }
      }
    }

    if (checkSync && this.out_of_sync_groups().length > 0) {
      console.log('Detected out-of-sync groups!');
      console.log('Current groups:');
      console.log(this.groups);
      console.log('Going to make these groups a reality:');
      console.log(this.out_of_sync_groups());
      console.log('Re-synchronizing groups!');
      this.update_groups();
    }
    debug(this.groups);
    debug(this.streams);
  }

  handle_update(update) {
    this.streams = update.server.streams.map(function(s) {
      return {
        id: s.id,
        status: s.status,
      };
    });

    this.groups = update.server.groups.map(function(g) {
      return {
        id: g.id,
        stream_id: g.stream_id,
        clients: g.clients.map(function(c) {
          return c.id
        }),
      };
    });
  }

  playing_streams() {
    return this.streams.filter(s => {
      return s.status === 'playing' &&
        this.config.streams.some(cs => cs.id === s.id)
    });
  }

  desired_groups() {
    var current_config = this.config;
    var new_groups = this.playing_streams().map(function(s) {
      var match = current_config.streams.find(function(cs) {
        return cs.id === s.id
      });

      return {
        stream_id: s.id,
        clients: match.clients,
      };
    });

    for (var new_group of new_groups) {
      // find our priority
      var ng_priority = current_config.streams.find(cs => {
        return cs.id === new_group.stream_id;
      }).priority;

      // filter out clients that should be served by
      // a more important (lower priority, 1 == most imp.) group
      new_group.clients = new_group.clients.filter(ngc => {
        // find any other desired group containing this client
        var other_priorities = new_groups.filter(og => {
          return og.clients.includes(ngc)
            && og.stream_id !== new_group.stream_id;
        }).map(og => {
          var match = current_config.streams.find(cs => {
            return cs.id === og.stream_id;
          });
          return match.priority;
        });

        return other_priorities.every(op => op >= ng_priority);
      });
    }

    // I really wish snapcast wouldn't default clients into a new
    // group with a playing stream (any playing stream!) if they're
    // removed from a previous group. In a way it almost makes sense,
    // but it trips us up here.
    //
    // Get the set of all clients in groups with playing streams:
    var playing_clients = new_groups.flatMap(g => g.clients);
    debug(playing_clients)
    // Get clients who are *not* in a playing group:
    var paused_clients = this.config.streams
      .flatMap(s => s.clients).filter(c => !playing_clients.includes(c));

    // Filter out duplicates
    paused_clients = paused_clients
      .filter((c, i) => paused_clients.indexOf(c) === i);

    // Find the most-important group for this paused client
    // and push its config into the new groups
    for (var pc of paused_clients) {
      var g = this.config.streams
        .find(s => s.clients.includes(pc) && s.priority === 1);

      if (g !== undefined) {
        new_groups.push({
          stream_id: g.id,
          clients: g.clients,
        });
      }
    }

    return new_groups;
  }

  out_of_sync_groups() {
    return this.desired_groups().filter(dg => {
      var match = this.groups.find(g => {
        return g.stream_id === dg.stream_id &&
          deepEqual(g.clients, dg.clients);
      });

      return match === undefined;
    });
  }

  update_groups() {
    for (var oosg of this.out_of_sync_groups().sort()) {
      // Find the first group with one of our clients
      var match = this.groups.find(g => {
        return g.clients.includes(oosg.clients[0]);
      });

      // Reconfigure this group to be what we want.
      var batch = []
      this.request_log.push('Group.SetStream');
      batch.push(
        jsonrpc.request(
          this.next_request_id(),
          'Group.SetStream',
          { id: match.id, stream_id: oosg.stream_id }
        )
      );

      this.request_log.push('Group.SetClients');
      batch.push(
        jsonrpc.request(
          this.next_request_id(),
          'Group.SetClients',
          { id: match.id, clients: oosg.clients }
        )
      );

      this.request_log.push('Group.SetName');
      batch.push(
        jsonrpc.request(
          this.next_request_id(),
          'Group.SetName',
          { id: match.id, name: oosg.stream_id }
        )
      )

      for (var b of batch) { debug(b); }

      this.conn.send(batch);
    }
  }

  refresh() {
    this.request_log.push('Server.GetStatus');

    var msg = jsonrpc.request(this.next_request_id(), 'Server.GetStatus');
    this.conn.send(msg);
  }
}

console.log('Connecting to snapcast server at tcp://' + config.host + ':' + config.port);

var sc = new Snapcast(config);
setInterval(function() {
  sc.refresh();
}, 1000);
