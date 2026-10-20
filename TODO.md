# TODO

## On hold

- **TeX setup (Overleaf-like)**: install TinyTeX from bootstrap (no sudo; `pdflatex`, `latexmk`,
  `tlmgr`, plus `standalone amsmath xcolor preview`) and add a doctor check. Then VimTeX + texlab,
  and a PDF viewer: zathura when local; over SSH, sshfs + a local viewer or a browser over a port
  forward.
- **Math as images in nvim**: needs the TeX setup above. Turn on snacks.image `math` only when
  the terminal supports images (detected at runtime), and turn off render-markdown's `latex` there
  to avoid rendering twice; keep the Unicode `tex2unicode` path for Alacritty.
- **Mermaid in nvim**: snacks.image renders it with `mmdc` (mermaid-cli, needs Node).
