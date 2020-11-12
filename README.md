## snapcast-autoconfig

This script watches for pre-defined streams on a snapcast server; and if any of them are playing it will then ensure that a group with the configured clients is playing that stream.

### Requirements

Node (tested with v15)

### Installation

`npm install`

### Deploying

I'm planning on systemd - but you do you.

### FAQ

- **Does it do x/y/z?** Probably not, but PRs are welcome.
- **You just put your personal config into git?!** I'm lazy, and the info is not sensitive. It's also an instructive example of how I use it.
- **There are bugs!!** I'm not surprised - help me fix them!
- **I need help!** Feel free to open an issue, but I'm basically just putting this out as-is unless anyone else is interested in helping.
- **What does the priority field mean** If there are two streams playing that have overlapping configured clients (ie: the 'kitchen' and 'whole house' streams are both playing, and they both claim the 'kitchen' client) - then the stream with the lowest priority wins.

### Other notes

- This expects that your clients have the ID set to something memorable; not the name.
- This might blow up, who knows. It's not well tested outside of my own living room.
