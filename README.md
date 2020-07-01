## Pizzel Analytics

Tools for obtaining and analyzing episode stats.

### Installation

To install the `pizzel-analytics` command globally:

1. Clone this repo
2. `cd` to the repo's folder
3. Run:

```
bundle exec rake install:local
```

You'll also need to add Podtract and Google SpreadSheets creds to your
`~/.pizzel/config`. See [the example config](config.yml.example).

### Usage

To get a list of available commands:

```bash
pizzel-analytics help
```

### Fish autocompletion

Add this to your `~/.config/fish/config.fish`:

```fish
# pizzel-analytics subcommand autocompletion
set -l pizzel_analytics_commands fetch git upsheet gsheets-test help
complete -f -c pizzel-analytics -n "not __fish_seen_subcommand_from $pizzel_analytics_commands" -a "$pizzel_analytics_commands"
```
