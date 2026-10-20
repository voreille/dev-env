# TODO

## On hold

- **Math as images in nvim**: TinyTeX is installed, so this is unblocked. Turn on snacks.image `math` only when
  the terminal supports images (detected at runtime), and turn off render-markdown's `latex` there
  to avoid rendering twice; keep the Unicode `tex2unicode` path for Alacritty.
- **Mermaid in nvim**: snacks.image renders it with `mmdc` (mermaid-cli, needs Node).
- **texlab on old servers**: the release binary needs glibc >= 2.34; build it from source in
  bootstrap (like tree-sitter) if a server is older.
