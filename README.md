# O2M, Orgie 2 Metal

[![Build Status](https://drone.github.papey.fr/api/badges/papey/o2m/status.svg)](https://drone.github.papey.fr/papey/o2m)

O2M is an [Elixir](https://elixir-lang.org) Discord bot capable of :

- organize and run blind tests
- fetching data about metal bands (baked up by [Metalorgie](https://metalorgie.com))
- monitor podcasts shows publications on [Ausha](https://ausha.co) or [Anchor](https://anchor.fm).

## Getting Started

### Prerequisites

- [Elixir](https://elixir-lang.org/)

### Installing

#### Get O2M

##### From source

Clone this repo and run

```sh
mix deps.get
```

To download all the deps, then

```sh
mix compile
```

To compile all elixir files

##### From Docker Hub

See [papey/o2m](https://hub.docker.com/r/papey/o2m) on Docker Hub

### Usage

```sh
MIX_ENV=prod mix release
```

Everything will be generated inside _\_build_ dir, to start all the things

```sh
./_build/prod/rel/o2m/bin/o2m start
```

Configuration is passed to o2m using environment variables

The ones that are mandatory in order to connect to Discord :

- DISCORD_TOKEN from Discord
- O2M_GUILD_ID from Discord to indentify target guild

#### Podcast monitoring

- O2M_FEED_URLS (eg : https://feed.ausha.co/owAEhJ0qOPkb) from Ausha RSS page or Anchor RSS page. To enable multiple shows add a " " between each feed url (eg : https://feed.ausha.co/owAEhJ0qOPkb https://feed.ausha.co/oLAxhNMl7P8y)
- O2M_CHAN_ID from Discord to select channel used to post message from watched feeds
- O2M_NICKNAME for Discord nickname (also known as Display Name)

#### Blind tests

See the [wiki](https://github.com/papey/o2m/wiki) for a user guide on how to run blind tests.

- DISCORD_GW_INTENTS set to `yes` to activate required gateway intents
- O2M_BT_CHAN_ID from Discord to select the textual channel used to run the blind tests
- O2M_BT_VOCAL_ID from Discord to select the vocal channel used to run the blind tests
- O2M_BT_ADMIN from Discord to select the role needed to organize and run blind tests (not needed to participate to the blind tests)

For running blind tests in details, see the wiki.

You can also configure O2M using `config.esx`, see this file inside
the `config` directory for real life examples.

#### Notes on Discord permissions

If you run this bot in blind test mode you need to activate all Discord [gateway intents](https://discord.com/developers/docs/topics/gateway#gateway-intents).

On the scopes side, the bot needs at least the `Send Messages` (text permissions) scope. But if you enabled the blind tests feature
you need to add `Add Reactions` (text permissions), `Connect` (voice permissions) and `Speak` (voice permissions).

## Running the tests

With proper environment variables

```sh
mix test
```

## User Help & Manual

Once the bot is connected,

```text
!help
```

or for more specific stuff,

```text
!help <command>
```

## Built With

- [nostrum](https://github.com/Kraigie/nostrum) - A Discord bot library
- [elixir-feed-parser](https://github.com/fdietz/elixir-feed-parser) - A RSS feed parsing library
- [timex](https://github.com/bitwalker/timex) - A date parsing library
- [gen_state_machine](https://hexdocs.pm/gen_state_machine/GenStateMachine.html) - To handle game state

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors

- **Wilfried OLLIVIER** - _Main author_ - [Papey](https://github.com/papey)

## License

[LICENSE](LICENSE) file for details

## Acknowledgments

- [Metalorgie](https://www.metalorgie.com) for the awesome website
- [Ausha](https://ausha.co) for the awesome podcast plateform
- [YCKM](https://podcast.ausha.co/yckm) & [Le Bruit](https://podcast.ausha.co/le-bruit) for the inspiration around podcasts tools
- [Discord](https://discordapp.com) for the plateform they provide for free
- Kudos @href, my Elixir master !
