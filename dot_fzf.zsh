# Setup fzf
# ---------
if [[ ! "$PATH" == */home/jean/.asdf/installs/fzf/0.38.0/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/jean/.asdf/installs/fzf/0.38.0/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/jean/.asdf/installs/fzf/0.38.0/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/jean/.asdf/installs/fzf/0.38.0/shell/key-bindings.zsh"
