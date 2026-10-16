#!/bin/bash
# Minimal entrypoint: install just enough to run chezmoi, then hand over.
# Everything else (tools, runtimes, dotfiles) is applied by chezmoi itself.
set -euo pipefail

REPO="git@github.com:jeandek/dotfiles.git"

if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    OS="Linux"
else
    echo "ERROR: unsupported OS '$OSTYPE'." >&2
    exit 1
fi

echo "Detected OS: $OS"

if [[ "$OS" == "Linux" ]]; then
    # Request a package only when the command it provides is actually missing.
    # Amazon Linux 2023 preinstalls stripped variants such as curl-minimal that
    # already provide the command and conflict with the full package, so naming
    # the full package outright makes dnf refuse the whole transaction.
    PKGS=""
    need() { command -v "$1" &> /dev/null || PKGS="$PKGS $2"; }

    if command -v apt-get &> /dev/null; then
        need zsh zsh
        need git git
        need curl curl
        need unzip unzip
        need gcc build-essential
        need chsh passwd
        if [[ -n "$PKGS" ]]; then
            sudo apt-get update
            sudo apt-get install -y ${PKGS}
        fi
    elif command -v dnf &> /dev/null; then
        need zsh zsh
        need git git
        need curl curl
        need unzip unzip
        need gcc gcc
        need make make
        # chsh lives in util-linux-user on the fedora family and is not part of
        # the default Amazon Linux 2023 set.
        need chsh util-linux-user
        if [[ -n "$PKGS" ]]; then
            sudo dnf install -y ${PKGS}
        fi
    else
        echo "ERROR: no supported package manager (need apt-get or dnf)." >&2
        exit 1
    fi

    ZSH_PATH="$(command -v zsh)"
    if [[ "$SHELL" == "$ZSH_PATH" ]]; then
        echo "Login shell is already zsh."
    elif ! command -v chsh &> /dev/null; then
        echo "WARN: chsh not available. Set the login shell by hand:"
        echo "      chsh -s $ZSH_PATH"
    elif ! chsh -s "$ZSH_PATH"; then
        echo "WARN: chsh failed. Set the login shell by hand:"
        echo "      chsh -s $ZSH_PATH"
    fi
elif [[ "$OS" == "macOS" ]]; then
    if ! xcode-select -p &> /dev/null; then
        xcode-select --install
    fi
    # Homebrew is macOS-only here: it supplies GUI casks and the few CLIs that
    # have no prebuilt binary for this platform. Linux gets everything from mise.
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

# GitHub credentials for mise, which resolves most tools from GitHub releases.
#
# Unauthenticated GitHub API requests are capped at 60/hour per source IP. A
# host behind a shared NAT gateway shares that budget with everyone else on th
# gateway and is effectively always exhausted, so # mise cannot resolve tool
# versions at all. Authenticated requests get 5000/hour.
#
# This has to happen before chezmoi init, because that applies the dotfiles and
# triggers the run_onchange script that calls mise install. gh deliberately
# comes from the system package manager rather than mise, which would need the
# very API access it is here to provide.
if ! command -v gh &> /dev/null; then
    echo "Installing the GitHub CLI..."
    # gh is not in the Debian or Fedora/Amazon Linux default repositories, so
    # GitHub's own package repository has to be added first. Procedures from
    # https://github.com/cli/cli/blob/trunk/docs/install_linux.md
    if command -v apt-get &> /dev/null; then
        sudo mkdir -p -m 755 /etc/apt/keyrings /etc/apt/sources.list.d
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y gh || echo "WARN: gh install failed."
    elif command -v dnf &> /dev/null; then
        # dnf5 and dnf4 take different config-manager syntax. Amazon Linux 2023
        # is dnf4; recent Fedora is dnf5.
        if dnf --version 2>/dev/null | grep -qiE 'dnf5|^5\.'; then
            sudo dnf install -y dnf5-plugins
            sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
        else
            sudo dnf install -y 'dnf-command(config-manager)'
            sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        fi
        sudo dnf install -y gh || echo "WARN: gh install failed."
    elif command -v brew &> /dev/null; then
        brew install gh || echo "WARN: gh install failed."
    fi
fi

if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        echo "GitHub CLI already authenticated."
    else
        echo "Authenticating the GitHub CLI so mise can resolve tool versions."
        gh auth login || echo "WARN: gh auth login did not complete."
    fi
elif [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "WARN: no GitHub credentials available. mise will likely fail to"
    echo "      resolve tool versions on a rate-limited host. Either install"
    echo "      the GitHub CLI and run 'gh auth login', or export GITHUB_TOKEN"
    echo "      with a no-scope token from https://github.com/settings/tokens"
fi

# chezmoi prompts for work/gui/minimal on first run.
if ! command -v chezmoi &> /dev/null; then
    echo "Installing chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply "$REPO"
else
    chezmoi init --apply "$REPO"
fi

export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
if command -v mise &> /dev/null; then
    eval "$(mise activate bash)"
fi

# Only machines whose rendered gitconfig asks for a signing key need the key.
if ! git config --get user.signingkey &> /dev/null; then
    echo "No signing key configured for this machine; skipping GPG setup."
elif command -v bw &> /dev/null && command -v gpg &> /dev/null; then
    echo "Setting up GPG signing key from Bitwarden..."
    echo "Please log in to Bitwarden:"
    bw login
    bw get attachment jean.secsub.gpg --itemid cb631b83-b86e-4a40-aff9-b213014ca59c
    bw lock
    gpg --import jean.secsub.gpg
    rm jean.secsub.gpg
    echo "GPG key imported successfully."
else
    echo "WARN: bw or gpg not found. Skipping GPG key setup."
fi
