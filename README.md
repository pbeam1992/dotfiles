# dotfiles

My macOS dotfiles, managed with [chezmoi](https://www.chezmoi.io).

## Fresh machine setup

Open Terminal and paste:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pbeam1992/dotfiles/main/init.bash)"
```

The script:

1. Installs [Homebrew](https://brew.sh), which also installs the Xcode Command Line Tools (git).
2. Clones this repo to `~/Repositories/github.com/pbeam1992/dotfiles` over HTTPS, so no SSH key is needed.
3. Installs chezmoi.
4. Asks for confirmation, then runs `chezmoi init --apply`, which writes the dotfiles and
   installs the apps in the `Brewfile`.

It is safe to re-run; finished steps are skipped.

Afterwards, open 1Password, sign in, and turn on the SSH agent under Settings → Developer.
Git pushes and commit signing both go through it.

If the repo is already cloned, run it directly instead:

```sh
~/Repositories/github.com/pbeam1992/dotfiles/init.bash
```

## Pushing changes

Fetching uses HTTPS, pushing uses SSH (`git@github.com:pbeam1992/dotfiles.git`). Add an SSH key
to GitHub before your first push from a new machine.

## Layout

| Path        | Purpose                                                        |
| ----------- | -------------------------------------------------------------- |
| `init.bash` | Bootstrap script for a fresh machine                           |
| `Brewfile`  | Apps and tools; installed by `brew bundle` when it changes     |
| `home/`     | chezmoi source state; everything here maps to `$HOME`          |

## Daily use

```sh
chezmoi add ~/.zshrc     # start managing a file
chezmoi edit ~/.zshrc    # edit the managed copy
chezmoi diff             # preview pending changes
chezmoi apply            # write changes to $HOME
chezmoi cd               # open a shell in this repo
```
