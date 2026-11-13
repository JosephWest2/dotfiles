# Personal integration; leave config.fish available to installers.
# If conda init has also been run locally, remove that duplicate initialization.
#
# `conda shell.fish hook` starts Python and took ~390 ms, nearly all of fish's
# startup time. Its output only changes when conda itself changes, so cache it
# and regenerate when the base environment's history (appended on every
# install/update) is newer than the cache.
set -l __conda_root "$HOME/miniconda3"
if test -x "$__conda_root/bin/conda"
    set -l cache_dir (set -q XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo $HOME/.cache)/fish
    set -l cache "$cache_dir/conda-hook.fish"
    if not test -s "$cache"; or test "$__conda_root/conda-meta/history" -nt "$cache"; or test "$__conda_root/bin/conda" -nt "$cache"
        mkdir -p "$cache_dir"
        if "$__conda_root/bin/conda" shell.fish hook >"$cache.tmp" 2>/dev/null
            mv -f "$cache.tmp" "$cache"
        else
            rm -f "$cache.tmp"
        end
    end
    if test -s "$cache"
        source "$cache"
    else
        "$__conda_root/bin/conda" shell.fish hook | source
    end
end
