#!/bin/bash
set -e

if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
elif grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    OS="Linux"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
else
    echo "Unknown OS. Exiting."
    exit 1
fi

echo "Detected OS: $OS"

if [[ "$OS" == "Linux" ]]; then
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential zsh unzip
		chsh -s $(which zsh)
    else
        echo "No supported package manager found."
        exit 1
    fi
elif [[ "$OS" == "macOS" ]]; then
    if ! xcode-select -p &> /dev/null; then
        xcode-select --install
    fi
fi

if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    # The official installer handles both macOS and Linux
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
    
if ! command -v chezmoi &> /dev/null; then
    echo "Installing chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply "git@github.com:jeandek/dotfiles.git"
else
    chezmoi init --apply "git@github.com:jkernier/dotfiles.git"
fi

echo "Setting up GPG signing key from Bitwarden..."

# Ensure we have access to the newly installed tools
export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:$PATH"
if command -v mise &> /dev/null; then
    eval "$(mise activate bash)"
fi

if command -v bw &> /dev/null && command -v gpg &> /dev/null; then
    echo "Please log in to Bitwarden:"
    bw login
    bw get attachment jean.secsub.gpg --itemid cb631b83-b86e-4a40-aff9-b213014ca59c
    bw lock
    gpg --import jean.secsub.gpg
    rm jean.secsub.gpg
    echo "GPG key imported successfully."
else
    echo "Warning: Bitwarden (bw) or gnupg (gpg) not found. Skipping GPG key setup."
fi
