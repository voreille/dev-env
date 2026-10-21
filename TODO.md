# TODO

## Planned

- **Cache cleanup (`scripts/clean`)**: servers run for months without clearing `/tmp`, and caches
  only grow. Default is a dry run listing what would go and its size; `--yes` deletes. Only
  touch files owned by `$USER`.
  - Delete (rebuilt on demand): `~/.cache/nvim/snacks/image`, `~/.cache/dev-env/pdf-follow`, and
    on the laptop the same pdf-follow dir.
  - `/tmp`, top level, own files with `-mtime +7`: `torchinductor_$USER` (slower next
    `torch.compile`), stale `github-copilot-*` (should no longer appear), `nvim.*` leftovers
    from crashes. Never `tmux-*` (live sessions) or `ssh-*` (agent sockets).
  - Only print the command, never run it (research caches, user decides): `rm -rf ~/.cache/pip`
    (23G on lxbelshark), `uv cache prune` (11G), `hf cache scan` / `hf cache delete` (29G,
    downloaded models), `~/.cache/pypoetry` (6.3G; `virtualenvs/` holds real Poetry envs),
    `~/.cache/torch/hub` (1.1G).
  - Optional: run the safe part at most once a day from `dotfiles/bash/bashrc` (stamp file in
    `~/.cache/dev-env`), since user crontabs may be blocked. Add a `doctor` line with the sizes.

## On hold

- **Math as images in nvim**: TinyTeX is installed, so this is unblocked. Turn on snacks.image `math` only when
  the terminal supports images (detected at runtime), and turn off render-markdown's `latex` there
  to avoid rendering twice; keep the Unicode `tex2unicode` path for Alacritty.
- **Mermaid in nvim**: snacks.image renders it with `mmdc` (mermaid-cli, needs Node; bootstrap's
  Node in `~/.local/opt/dev-env/node` could serve it).
- **texlab on old servers**: the release binary needs glibc >= 2.34; build it from source in
  bootstrap (like tree-sitter) if a server is older.
