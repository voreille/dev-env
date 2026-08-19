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

    tmux send-keys -t "$htop_pane" 'htop' C-m
    tmux send-keys -t "$nvtop_pane" 'nvtop' C-m
    tmux send-keys -t "$top_pane" 'top' C-m

    # Start in window 1.
    tmux select-window -t "$name:nvim"

    tmux attach -t "$name"
}
_conda_root() {
    local root

    # Explicit override, if ever needed.
    if [ -n "${DEV_CONDA_ROOT:-}" ] &&
        [ -f "$DEV_CONDA_ROOT/bin/activate" ]; then
        printf '%s\n' "$DEV_CONDA_ROOT"
        return 0
    fi

    # Common locations.
    for root in \
        "$HOME/miniconda" \
        "$HOME/miniconda3" \
        "$HOME/anaconda3"; do
        if [ -f "$root/bin/activate" ]; then
            printf '%s\n' "$root"
            return 0
        fi
    done

    echo "Could not find a Conda installation." >&2
    return 1
}
conda-on() {
    local root
    root="$(_conda_root)" || return 1

    source "$root/bin/activate"
}

tconda() {
    if [ -z "$TMUX" ]; then
        echo "tconda must be run inside tmux"
        return 1
    fi

    local root env pane

    root="$(_conda_root)" || return 1

    # Enable Conda in the current shell so we can enumerate environments.
    source "$root/bin/activate"

    env="$(
        conda env list |
            awk 'NF && $1 !~ /^#/ { print $1 }' |
            fzf --prompt="Conda env > "
    )"

    [ -n "$env" ] || return

    pane="$(
        tmux new-window \
            -n "$env" \
            -c "$PWD" \
            -P -F '#{pane_id}'
    )"

    tmux send-keys \
        -t "$pane" \
        "source \"$root/bin/activate\" && conda activate \"$env\"" \
        C-m
}
