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
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y zsh git curl unzip build-essential
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y zsh git curl unzip gcc make
    else
        echo "ERROR: no supported package manager (need apt-get or dnf)." >&2
        exit 1
    fi
    chsh -s "$(command -v zsh)" || echo "WARN: could not change login shell; do it by hand."
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
