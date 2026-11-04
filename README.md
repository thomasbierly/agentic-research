# Agentic Research

A research setup for [Omarchy](https://omarchy.org): one place to write the
software, analyse the data and write the paper, with an AI agent working
alongside you.

The step-by-step guide, with screenshots, starting from installing Omarchy:
**https://thomasbierly.com/agentic-researcher/**

## What you get

- **Projects** in the Omarchy menu (Super + Space): *New project…* creates a
  folder with `src/` (code), `data/`, `analysis/` ([marimo](https://marimo.io) notebooks) and `paper/`
  (Quarto), a Python environment and a Git repository, and opens it.
- Each project opens in a **Herdr workspace** with tabs for the work:

  | Tab | What runs there |
  |---|---|
  | work | Neovim beside Claude Code |
  | analysis | a shell for your software and command-line tools, and your marimo notebooks: press Enter there (or right-click in the editor) to open them in their own window. Notebooks can use SQL and connect to databases; passwords go in `.env`, which Git ignores |
  | paper | Quarto, re-rendering the paper to PDF each time you save |
  | review | Hunk: every change, by you or the agent, line by line; leave a note on any line and Claude answers it there |
  | git | lazygit: save versions and back them up to GitHub |

  Reopening a project after a restart brings all of these back.
- **Neovim additions** for research writing: a file list and a right-click
  menu, so the mouse works; a PDF preview where clicking any sentence jumps to
  it in the source; Zotero citations; Jupyter notebooks; grammar checking with
  Harper, which runs on your machine.

## Install

On a computer running Omarchy, open a terminal (Super + Enter) and run:

```sh
git clone https://github.com/thomasbierly/agentic-research ~/.local/share/agentic-research
~/.local/share/agentic-research/install.sh
```

It asks for your password once, to install packages, and tells you the three
things only you can do afterwards (signing in to Claude Code, Zotero's Better
BibTeX add-on, GitHub). Run `install.sh` again at any time to update.

Anything the installer would replace is kept next to it with a
`.before-agentic-research-<date>` suffix.

## Everyday use

| To | Do |
|---|---|
| start a project | Super + Space > Projects > New project… |
| open a project | Super + Space > Projects > its name |
| open a file | click it in the file list on the left |
| see the PDF | right-click in the text > Show PDF preview, then click any sentence to jump there |
| open the analysis notebook | right-click in the text > Open the analysis notebook |
| cite a paper | `\ci` in a `.qmd` file (Zotero must be open) |
| switch tabs | Alt + 1 … 5 |
| find any shortcut | press Space in Neovim and wait |

Grammar checking defaults to American English. To change it, edit
`dialect` in `nvim/lua/plugins/harper.lua` in this folder (`British`,
`Australian` or `Canadian`).

## What's in here

- `install.sh`: the installer
- `bin/ws`: opens and creates projects, and builds the Projects menu
- `nvim/`: the Neovim plugins, linked into `~/.config/nvim`

MIT licence. By [Thomas Bierly](https://thomasbierly.com).
