# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/josephwest/miniconda3/bin/conda
    eval /home/josephwest/miniconda3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/home/josephwest/miniconda3/etc/fish/conf.d/conda.fish"
        . "/home/josephwest/miniconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/home/josephwest/miniconda3/bin" $PATH
    end
end
# <<< conda initialize <<<

