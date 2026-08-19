tmux-work() {
    local name="work"
    local dir="$HOME/workspaces"

    # Reattach if the session already exists.
    if tmux has-session -t "$name" 2>/dev/null; then
        tmux attach -t "$name"
        return
    fi

    # 1: Neovim
    tmux new-session -d -s "$name" -n nvim -c "$dir"
    tmux send-keys -t "$name:nvim" 'nvim .' C-m

    # 2: Normal shell
    tmux new-window -t "$name" -n shell -c "$dir"

    # 3: Monitoring
    tmux new-window -t "$name" -n monitor -c "$dir"

    # Start with one full-size pane.
    local htop_pane
    htop_pane="$(tmux display-message -p -t "$name:monitor" '#{pane_id}')"

    # Small bottom pane (~25% height).
    local top_pane
    top_pane="$(
        tmux split-window \
            -v \
            -p 25 \
            -t "$htop_pane" \
            -c "$dir" \
            -P -F '#{pane_id}'
    )"

    # Split the large top area in two.
    local nvtop_pane
    nvtop_pane="$(
        tmux split-window \
            -h \
            -t "$htop_pane" \
            -c "$dir" \
            -P -F '#{pane_id}'
    )"

    tmux send-keys -t "$htop_pane"  'htop' C-m
    tmux send-keys -t "$nvtop_pane" 'nvtop' C-m
    tmux send-keys -t "$top_pane"   'top' C-m

    # Start in window 1.
    tmux select-window -t "$name:nvim"

    tmux attach -t "$name"
}

conda-on() {
    source "$HOME/miniconda/bin/activate"
}

tconda() {
    if [ -z "$TMUX" ]; then
        echo "tconda must be run inside tmux"
        return 1
    fi

    # Make conda available only in this shell.
    conda-on

    local env
    env="$(
        conda env list |
        awk 'NF && $1 !~ /^#/ { print $1 }' |
        fzf --prompt="Conda env > "
    )"

    [ -n "$env" ] || return

    # Create the new window in the current directory.
    local pane
    pane="$(
        tmux new-window \
            -n "$env" \
            -c "$PWD" \
            -P -F '#{pane_id}'
    )"

    # Activate the selected environment in its interactive shell.
    tmux send-keys \
        -t "$pane" \
        "source \"$HOME/miniconda3/etc/profile.d/conda.sh\" && conda activate \"$env\"" \
        C-m
}
