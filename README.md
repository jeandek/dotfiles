# Dotfiles

A single source of truth for developer environment configuration across macOS and Linux machines. Managed by [chezmoi](https://www.chezmoi.io/).

## Environments

Three answers describe a machine. Everything else is derived from the OS itself.

| Prompt | Meaning |
|---|---|
| `work` | Work machine. Enables the optional private source and skips the GPG signing key. |
| `gui` | Desktop session. Installs fonts and GUI apps. Always true on macOS; asked only on Linux. |
| `minimal` | Shell experience only. Skips language runtimes and the tools that depend on them. |

Derived automatically: `.chezmoi.os`, `.chezmoi.arch`, and on Linux `.chezmoi.osRelease.id` / `.idLike` for picking a package manager.

| Machine | `work` | `gui` | `minimal` |
|---|---|---|---|
| WSL on Windows | | | |
| Personal MacBook | | yes | |
| Work MacBook | yes | yes | |
| Cloud Desktop | yes | | |
| Linux servers | | | yes |

## Bootstrapping a New Machine

Create an SSH keypair first. Every machine gets its own, so a lost laptop can be revoked without touching the other four.

```bash
# The comment is only a label, but with five machines it is what tells you which key to revoke.
# Choose a passphrase when prompted.
ssh-keygen -t ed25519 -C "work-mac"   # or mbp-m3, wsl, cloud-desktop, vps-fra1

# Persist the key: the keychain on macOS, a session agent elsewhere.
ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null \
  || { eval "$(ssh-agent -s)"; ssh-add ~/.ssh/id_ed25519; }

cat ~/.ssh/id_ed25519.pub
```

Add the key [to GitHub](https://github.com/settings/keys), then run:

```bash
curl -fsSL https://raw.githubusercontent.com/jeandek/dotfiles/main/bootstrap.sh | bash
```

You will be asked the three questions above. This installs the base system packages, authenticates the GitHub CLI, installs chezmoi, and then applies the dotfiles, which triggers tool installation via `run_onchange_` scripts.

### GitHub credentials

Bootstrap installs the GitHub CLI and runs `gh auth login`, because mise resolves tools from the GitHub API and unauthenticated requests are capped at 60/hour per source IP — permanently exhausted on a shared NAT gateway.

If `gh` cannot be installed, export `GITHUB_TOKEN` instead with a [token](https://github.com/settings/tokens); it needs no scopes.

On a work machine, clone the private source as well. Until you do, git has no email configured and will refuse to commit — see [Machine-Local Configuration](#machine-local-configuration).

## Keeping Machines in Sync

```bash
dotfiles-update
```

Pulls, applies, and reconciles packages. If a second source directory exists at `~/.local/share/chezmoi-work`, that is updated too.

## Where Tools Come From

Tools are resolved in one place only. The rule:

1. **Does the tool update itself?** If it ships an `upgrade`/`update` subcommand that replaces its own binary, use the vendor's installer, in the self-updating section of `run_onchange_install-packages.sh.tmpl`. A version manager is the wrong home for these: it pins a version the tool then overwrites, so `mise ls` ends up reporting something that is not installed. Currently Claude Code and opencode.
2. **mise** owns everything else it can install as a prebuilt binary. See `dot_config/mise/config.toml.tmpl`.
3. **Platform package manager** is the fallback for anything mise cannot serve on that platform — Homebrew on macOS (`dot_config/private_homebrew/Brewfile.tmpl`, also home to `gui` casks), apt/dnf on Linux.
4. **Base system packages** are inlined in the install script: a shell, git, curl, a compiler, and gpg. Nothing else belongs there.

Rule 2 resolves tools from the GitHub API, so mise needs [GitHub credentials](#github-credentials).

Rule 1 is deliberately narrow. Nearly every tool offers an install script now, and preferring them wholesale would be a downgrade: mise verifies checksums, GitHub attestations and SLSA provenance on each install, while `curl | bash` is unverified remote code run on every new machine. Self-update is the only case where that trade is worth it, because there the version manager is actively lying.

`nnn` is the current example of rule 3: upstream ships x86_64 Linux statics only, so it comes from `github:` on amd64 Linux, Homebrew on macOS, and the distro package list on arm64 Linux.

Prefer explicit `github:owner/repo` over a bare registry alias in the mise config. Aliases add a layer that drifts: the `opencode` alias still points at `sst/opencode`, whose metadata resolves `latest` to a tag that has no release, and the project has since moved to `anomalyco`.

**oh-my-zsh** and its plugins sit outside all four rules, pulled as chezmoi externals and refreshed weekly.

## Adding a New Tool

1. Check `--help` for an `upgrade` or `update` subcommand. If it self-updates, add its installer to the self-updating section of `run_onchange_install-packages.sh.tmpl` with a `command -v` guard, and stop.
2. Otherwise check `mise registry`. If mise has a prebuilt binary for every platform you need, add it to `dot_config/mise/config.toml.tmpl` as `github:owner/repo` and stop. Install it once by hand first — a registry listing is not proof that `latest` resolves to a real release.
3. If not, add it to the Brewfile (macOS) and/or the base package list in `run_onchange_install-packages.sh.tmpl` (Linux), guarded by os/arch.
4. Add any config with `chezmoi add ~/.config/newtool/config`.
5. Commit from `chezmoi cd`, then run `dotfiles-update` elsewhere.

## Machine-Local Configuration

Nothing machine-specific or non-public belongs in this repo. Drop-in files in `~/.config/zsh/` are sourced at two points in both `.zshrc` and `.zprofile`:

| Directory | Sourced |
|---|---|
| `zsh/rc.pre.d` | top of `.zshrc`, before oh-my-zsh |
| `zsh/rc.post.d` | end of `.zshrc`, after everything |
| `zsh/profile.pre.d` | top of `.zprofile` |
| `zsh/profile.post.d` | end of `.zprofile` |

Use `pre.d` to set variables the managed config later reads, and `post.d` to override anything this repo defines. Those two positions span the whole file, so there is no third hook — `~/.zshlocal` is no longer sourced.

To add to `PATH` from a drop-in, use zsh's own `$path` array rather than a helper:

```zsh
typeset -U path PATH
path=( $HOME/some/bin(N) $path )
```

`typeset -U` removes duplicates and the `(N)` glob qualifier drops directories that do not exist, which is why this repo has no `path_prepend` function.

Git has the same arrangement. `.gitconfig` sets the personal identity and ends with:

```ini
[include]
	path = ~/.config/git/local.inc
```

Git ignores a missing include path, so that is a no-op on personal machines. Work machines get the file from the private dotfiles source, which supplies `user.email` without the work address ever entering this repo.

On work machines the public config sets **no** email at all, and `user.useConfigOnly = true` is always on. Without that flag git invents an identity rather than failing — it uses `$EMAIL` if set, otherwise `user@fqdn` — so a work machine would commit under the wrong address with no warning. With it, git refuses until an address is configured:

```
Author identity unknown
*** Please tell me who you are.
```

That is expected on a fresh work machine until the private source is cloned. Fix it by cloning that repo, or set the address for one repo with `git config user.email`.

## Unsupported Distros

The install script dispatches on `ID`/`ID_LIKE` and recognises debian- and fedora-family systems. Anything else fails loudly with the packages it wanted. Dotfiles still apply; only tool installation stops. Add a branch to `run_onchange_install-packages.sh.tmpl` to teach it a new family.

## Structure

- **`bootstrap.sh`** — minimal entrypoint to get chezmoi running.
- **`.chezmoi.toml.tmpl`** — the three prompts.
- **`dot_config/mise/config.toml.tmpl`** — primary tool inventory.
- **`dot_config/private_homebrew/Brewfile.tmpl`** — macOS fallback and GUI casks.
- **`run_onchange_*.sh.tmpl`** — executed when their hashed inputs change. Idempotent by design.
