# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal macOS dotfiles managed with [chezmoi](https://www.chezmoi.io), plus a bootstrap script for a
fresh machine. The repo is **public**: never commit secrets, private keys or tokens.

## Layout and how the pieces fit

- `init.bash` is the fresh-machine bootstrap. It is fetched with `curl` and run via
  `bash -c "$(curl ...)"` (see `README.md`), so it runs *before* the repo, git, Homebrew or chezmoi
  exist. It installs Homebrew, clones this repo, installs chezmoi, asks for confirmation, then runs
  `chezmoi init --source <repo> --apply`.
- `.chezmoiroot` contains `home`, so the chezmoi source state is `home/`, not the repo root.
  Anything that should land in `$HOME` goes under `home/` using chezmoi naming (`dot_zshrc`,
  `private_dot_ssh/`, `run_onchange_*.sh`, `*.tmpl`). Files at the repo root (`README.md`,
  `init.bash`, this file) are never applied to `$HOME`.
- `home/.chezmoi.toml.tmpl` is the chezmoi config template. It sets `sourceDir` to
  `.chezmoi.workingTree` (the repo root), which is what lets chezmoi work from
  `~/Repositories/github.com/pbeam1992/dotfiles` instead of its default `~/.local/share/chezmoi`.
  Changes to it only take effect after `chezmoi init` is run again.
- `Brewfile` lives at the repo root, not under `home/`, so it is not copied to `$HOME`.
  `home/run_onchange_after_install-packages.sh.tmpl` embeds the Brewfile's hash and runs
  `brew bundle` against it, so `chezmoi apply` installs packages whenever the Brewfile changes.
  To add an app, edit `Brewfile` only.
- `home/run_onchange_after_macos-defaults.sh` sets macOS preferences with `defaults write` and
  rebuilds the Dock's pinned apps. Its name must keep sorting after `install-packages`, because
  chezmoi runs scripts alphabetically and the Dock pins need the apps installed first. It can be
  run directly with `/bin/bash` to test, but it changes the current machine's settings.
- The remote fetches over HTTPS and pushes over SSH (`init.bash` sets the push URL and adds
  GitHub's pinned host key to `known_hosts`). Pushing uses the 1Password SSH agent.
- Commits are SSH-signed through 1Password (`home/private_dot_gitconfig`), so `git commit` waits
  for the user to approve a 1Password prompt.
- `chezmoi apply` and `init.bash` both run `brew bundle` and the macOS preferences script when
  those have changed. Do not run them just to test an unrelated edit; use `chezmoi diff` or
  `chezmoi execute-template` instead.

## Constraints on `init.bash`

- Must run on the stock macOS `/bin/bash` (3.2): no associative arrays, `mapfile`, `${var,,}`, etc.
- No dependencies beyond what a fresh macOS ships. Do not use `gum`, `jq`, or anything from
  Homebrew for the UI or logic.
- Must stay idempotent: every step detects "already done" and skips.
- Must work both when executed as a file and when passed as a string to `bash -c` (no reliance on
  `$0` or the script's own path). `main` is guarded so the file can be sourced to test helpers.
- Steps that may need input (Homebrew installer, `chezmoi init --apply`) go through `run_visible`;
  silent steps go through `run_quiet`, which logs to a temp file and shows a spinner. The prompt
  reads from `/dev/tty`, not stdin.
- Colours and the spinner are disabled when stdout is not a terminal or `NO_COLOR` is set.
- The README one-liner fetches `init.bash` from `main` on GitHub, so changes are only live for
  fresh machines once pushed.

## Commands

```sh
/bin/bash -n init.bash                 # syntax check with the macOS system bash
shellcheck init.bash                   # lint (not installed by default: brew install shellcheck)
DOTFILES_ASSUME_YES=1 ./init.bash      # run end to end without the confirmation prompt
./init.bash </dev/null                 # exercise the "declined" path (no tty answer)

chezmoi diff                           # preview what apply would change in $HOME
chezmoi apply                          # apply home/ to $HOME
chezmoi add ~/.somefile                # start managing a file (copies it into home/)
chezmoi execute-template < home/.chezmoi.toml.tmpl   # render a template to check it
chezmoi doctor                         # sanity-check the chezmoi setup
```

There is no test suite. To see the spinner and colours, run the script inside a pseudo-terminal;
the already-installed paths are the only ones exercised on a machine that is set up.
