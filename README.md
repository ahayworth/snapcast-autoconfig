## snapcast-autoconfig

snapcast-autoconfig watches pre-defined streams on a [`snapcast`](https://github.com/badaix/snapcast) server. If any of them are playing, it will then ensure that a group with the configured clients is playing that stream (and can optionally manipulate the volume of each client within that group).

### Wait, why is this necessary / useful?

Well, maybe it's better to just explain how I use it. I have multiple room in my house that have speakers I'd like to listen to:

- Living Room
- Kitchen
- Office
- Bedroom
- Bathroom
- Deck

But, there are actually *additional* logical groupings of those speakers that are useful:
- "Great Room" (Kitchen + Living Room)
- "Master Suite" (Bedroom + Bathroom)
- "Great Room + Outside" (Kitchen + Living Room + Deck ... in the summer!)
- "Whole House"
- "Whole House + Outside"

And what's more, I want these speakers *and* these zones to be available as Airplay targets! Me and mine like to use Airplay to play our music, because it's convenient and most people we know have iPhones. And we don't want to tell people "Oh wait, let me re-configure the sound server"... we want it to just happen automatically.

To solve this problem, I run multiple instances of [`shairport-sync`](https://github.com/mikebrady/shairport-sync) on my server, each one for a different speaker or logical zone (eg: I have an "Office" stream, a "Kitchen" stream... and also a "Whole House" stream, etc). And, I have snapcast set up to source music from each one of these airplay streams (shairport-sync instances). This brings us to the *why* of `snapcast-autoconfig`: it watches snapcast to see if any of these airplay streams become active, and then does the re-grouping of the clients behind the scenes.

All so that we can just say "airplay to the Great Room, mom!" when we're playing music at home.

Believe it or not, it actually works pretty well.

### Requirements

- Ruby >= 2.7.2 (I have tested with 2.7.2 and 3.0.0).
- A valid configuration file describing the streams to monitor, and the clients that should follow them. See the example in the repo.
- Your snapcast server *must* have the TCP api exposed and available (it is, by default).

### Installation

`bundle install`

### Deployment / Operation

I manually install this on my server, and have set up a systemd service to run it. I've included an example systemd unit file.
My own personal config file is also provided, and can be used as a reference.

### FAQ

- **Does it do x/y/z?** Probably not, but PRs are welcome!
- **Couldn't you just use the 'meta' stream type?** Almost!! Snapcast doesn't allow you to define "home" (or "default", or "initial") groups for clients; and that's still useful and important.
- **Wait, couldn't you just use the pre/post-play scripts in shairport-sync?** Yes, actually, but I didn't know about them when I first started the project and now I kinda like this.
- **Hold on, wouldn't Airplay2 make this obsolete?** Yes, basically. That'd be really nice to be honest. Hopefully someone cracks it eventually.
- **You just put your personal config into git?!** I'm lazy, and the info is not sensitive. It's also an instructive example of how I use it!
- **There are bugs!!** I'm not surprised - help me fix them! I've really only tested this at my house!
- **Didn't this used to be written in nodejs?** Yes, but that was a bad move on my part; I know ruby a lot better. I just didn't know much about Ruby event-loop programming at the time and node was an easy quick fix.
- **I need help!**  Please open an issue, and I'll try to help if possible.
