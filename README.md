# O2M, Orgie 2 Metal

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

O2M uses config file in .esx format, see `example.exs` file inside
the `config` directory for real life examples.

## Running the tests

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
