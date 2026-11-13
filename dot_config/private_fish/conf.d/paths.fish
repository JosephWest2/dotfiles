# Personal tool directories. These previously lived only in the universal
# fish_user_paths variable, so a fresh machine lost them (including ~/bin,
# where this repo's scripts land). Missing directories are skipped, so the
# list is safe on every machine. --path edits $PATH directly and leaves the
# universal fish_user_paths (which installers append to) alone.
# Earlier entries take precedence; directories already on PATH are skipped.
set -l dirs
for dir in \
        $HOME/bin \
        $HOME/.local/bin \
        $HOME/.cargo/bin \
        $HOME/go/bin \
        $HOME/.npm-global/bin \
        $HOME/.dotnet/tools \
        $HOME/nerd-dictation/nerd-dictation \
        /opt/rocm/bin
    test -d $dir; and set -a dirs $dir
end
set -q dirs[1]; and fish_add_path --path $dirs
