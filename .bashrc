export PATH=/home/$USERNAME/.local/share/hub-linux/bin:$PATH

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
   . "$NVM_DIR/nvm.sh"  # This loads nvm
   . "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    nvm use default >> /dev/null
fi

export PYENV_ROOT="$HOME/.pyenv"

if [ -d "$HOME/.pyenv/bin" ]; then
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi

if [ -d "$HOME/.local/share/hub-linux" ]; then
    export PATH=$HOME/.local/share/hub-linux/bin:$PATH
    eval "$(hub alias -s)"
fi

if starship --version 2> /dev/null > /dev/null ; then
    eval "$(starship init bash)"
fi

export SDKMAN_DIR="$HOME/.sdkman"
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

if [ -f "/usr/share/bash-completion/completions/git" ]; then
   source /usr/share/bash-completion/completions/git
fi

complete -W "\`grep -oE '^[a-zA-Z0-9_.-]+:([^=]|$)' ?akefile | sed 's/[^a-zA-Z0-9_.-]*$//'\`" make
