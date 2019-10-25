# O2M, Orgie 2 Metal

[![Build Status](https://drone.github.papey.fr/api/badges/papey/o2m/status.svg)](https://drone.github.papey.fr/papey/o2m)

O2M is an [Elixir](https://elixir-lang.org) Discord bot capable of fetching
data about metal bands (baked up by [Metalorgie](https://metalorgie.com)) and
monitor podcasts shows publications on [Ausha](https://podcast.ausha.co).

## Getting Started

### Prerequisites

- [Elixir](https://www.rust-lang.org/)

### Installing

#### Get O2M

##### From source

Clone this repo and run

```sh
mix deps.get
```

To download all the deps, then

```
mix compile
```

To compile all elixir files

### Usage

```sh
MIX_ENV=prod mix release
```

Everything will be generated inside _\_build_ dir, to start all the things

```
./_build/prod/rel/o2m/bin/o2m start
```

Configuration is passed to o2m using environment variables

- DISCORD_TOKEN from Discord
- O2M_AUSHA_SLUGS (eg : owAEhJ0qOPkb) from Ausha RSS page. To enable multiple shows add , between each slug (eg : owAEhJ0qOPkb,oLAxhNMl7P8y)
- O2M_CHAN_ID from Discord to select channel used to post message from podcasts

You can also configure O2M using `releases.esx`, see `example.exs` file inside
the `config` directory for real life examples.

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

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors

- **Wilfried OLLIVIER** - _Main author_ - [Papey](https://github.com/papey)

## License

[LICENSE](LICENSE) file for details

## Acknowledgments

- [Metalorgie](https://www.metalorgie.com) for the awesome website
- [Ausha](https://podcast.ausha.co) for the awesome podcast plateform
- [YCKM](https://podcast.ausha.co/yckm) & [Le Bruit](https://podcast.ausha.co/le-bruit) for the inspiration around podcasts tools
- [Discord](https://discordapp.com) for the plateform they provide for free
- Kudos @href, my Elixir master !
