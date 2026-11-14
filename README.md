# dotfiles

My macOS dotfiles, managed with [chezmoi](https://www.chezmoi.io).

## Fresh machine setup

Open Terminal and paste:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pbeam1992/dotfiles/main/init.bash)"
```

The script:

1. Installs [Homebrew](https://brew.sh), which also installs the Xcode Command Line Tools (git).
2. Clones this repo to `~/Repositories/github.com/pbeam1992/dotfiles` over HTTPS, so no SSH key
   is needed, and adds GitHub's SSH host key to `~/.ssh/known_hosts`.
3. Installs chezmoi.
4. Asks for confirmation, then runs `chezmoi init --apply`, which:
   - writes the dotfiles (`~/.gitconfig`, `~/.ssh/config`, `~/.zprofile`),
   - installs the apps in the `Brewfile`,
   - applies the macOS preferences and sets up the Dock.

It is safe to re-run; finished steps are skipped. If a step fails, the script prints the path
of its log.

If the repo is already cloned, run it directly instead:

```sh
~/Repositories/github.com/pbeam1992/dotfiles/init.bash
```

### After the script

1. Open 1Password, sign in, and turn on the SSH agent under Settings → Developer. Git pushes
   and commit signing both go through it, so neither works until this is done.
2. Log out and back in so the keyboard and trackpad preferences take effect.

## What is managed

| Path                                               | Purpose                                                    |
| -------------------------------------------------- | ---------------------------------------------------------- |
| `init.bash`                                        | Bootstrap script for a fresh machine                       |
| `Brewfile`                                         | Apps and tools                                             |
| `home/`                                            | chezmoi source state; everything here maps to `$HOME`      |
| `home/private_dot_gitconfig`                       | Git identity and SSH commit signing through 1Password      |
| `home/private_dot_ssh/private_config`              | Points SSH at the 1Password agent                          |
| `home/dot_zprofile`                                | Puts Homebrew on `PATH`                                    |
| `home/run_onchange_after_install-packages.sh.tmpl` | Runs `brew bundle` whenever the `Brewfile` changes         |
| `home/run_onchange_after_macos-defaults.sh`        | macOS preferences and Dock apps; re-runs when it changes   |

## Git and SSH

- Fetching uses HTTPS and pushing uses SSH (`git@github.com:pbeam1992/dotfiles.git`).
- The SSH key lives in 1Password; no private key is stored on disk or in this repo.
- Every commit is signed with that key, so 1Password asks for approval on each commit.
- For commits to show as Verified, the public key must be added on GitHub as a **Signing Key**
  (separately from its use as an authentication key).

## Daily use

```sh
chezmoi add ~/.zshrc     # start managing a file
chezmoi edit ~/.zshrc    # edit the managed copy
chezmoi diff             # preview pending changes
chezmoi apply            # write changes to $HOME
chezmoi cd               # open a shell in this repo
```

To install a new app, add it to the `Brewfile` and run `chezmoi apply`. To change a macOS
preference, edit `home/run_onchange_after_macos-defaults.sh` and run `chezmoi apply`.
