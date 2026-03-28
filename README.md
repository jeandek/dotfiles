# Dotfiles

A single source of truth for developer environment configuration across macOS and Linux machines. Managed by [chezmoi](https://www.chezmoi.io/).

## Bootstrapping a New Machine

To set up a completely new macOS or Linux machine from scratch, start by creating a new SSH keypair.

```bash
ssh-keygen -t ed25519 -C "jean@kernier.dev"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat .ssh/id_ed25519.pub
```

Add the key [to GitHub](https://github.com/settings/keys).

Run the bootstrap script:

```bash
curl -fsSL https://raw.githubusercontent.com/jeandek/dotfiles/main/bootstrap.sh | bash
```

Provide your email when prompted.

This will:
1. Install minimal system requirements (`build-essential`, `git`, Homebrew).
2. Install `chezmoi`.
3. Apply the dotfiles, which will trigger the setup of all packages, tools, and runtimes via `run_onchange_` scripts.

## Keeping Machines in Sync

When you pull changes from this repository on an existing machine, you can sync your local state natively with:

```bash
dotfiles-update
```

This command automatically handles pulling the latest git commits, applying templated dotfiles, installing any new Homebrew packages from the `Brewfile`, and setting up new language runtimes in `mise`.

## Adding a New Tool

1. Test the installation manually on your current setup.
2. Determine the correct layer for the tool:
    - **System/OS packages (Linux only):** Add to `pkglist.txt`
    - **Global CLI utilities (macOS + Linux):** Add to `Brewfile`  ([docs](https://docs.brew.sh/Brew-Bundle-and-Brewfile))
    - **Language runtimes/tools:** Add to `dot_config/mise/config.toml` ([docs](https://mise.jdx.dev/configuration.html))
3. Add any specific dotfile configurations: `chezmoi add ~/.config/newtool/config`
4. Change directory to the dotfiles repo (`chezmoi cd`), then commit and push your changes.
5. On your other machines, simply run `dotfiles-update`.

## Structure

- **`bootstrap.sh`:** Minimal entrypoint script intended to get `chezmoi` running.
- **`Brewfile` & `pkglist.txt`:** Declarative dependencies installed securely into the environment. 
- **`dot_config/`:** Maps perfectly inside your `~/.config/` directory. Contains `mise` config and other standardized tool settings.
- **`run_onchange_*.sh.tmpl`:** Embedded scripts executed by `chezmoi` when their dependencies hash (like `Brewfile`) change. Idempotent by design.
