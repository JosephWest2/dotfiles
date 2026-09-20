# Personal integration; leave config.fish available to installers.
# If conda init has also been run locally, remove that duplicate initialization.
if test -x "$HOME/miniconda3/bin/conda"
    "$HOME/miniconda3/bin/conda" shell.fish hook | source
end
