#!/usr/bin/env bash
# Agentic Research: a research setup for Omarchy.
#
# Turns a fresh Omarchy install into a workspace for research projects that go
# from code to data analysis to paper, with an AI agent alongside you:
#
#   - Projects menu in the Omarchy menu (Super + Space): create a project
#     or open one in a Herdr workspace laid out for the work
#   - Quarto + Typst for papers and books, with a live PDF preview you can click
#     to jump to the source line in Neovim
#   - Python, Jupyter notebooks and DuckDB for analysis; Zotero for references
#   - Neovim additions: notebooks, citations, grammar checking, a file list and a
#     right-click menu so you can get around with the mouse
#
# Install:  git clone https://github.com/thomasbierly/agentic-research ~/.local/share/agentic-research
#           ~/.local/share/agentic-research/install.sh
# Update:   run install.sh again (it pulls the latest version first).
#
# Safe to run again: each step skips what is already done. It asks for your
# password once, to install packages.
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
NVIM="$HOME/.config/nvim"
STAMP="$(date +%Y%m%d-%H%M%S)"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Link $1 (in this repo) to $2. Anything already at $2 that is not our link is
# kept as $2.before-agentic-research-<time>.
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then return; fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    mv "$dst" "$dst.before-agentic-research-$STAMP"
    warn "kept your old ${dst/#$HOME/\~} as ${dst/#$HOME/\~}.before-agentic-research-$STAMP"
  fi
  ln -s "$src" "$dst"
  ok "${dst/#$HOME/\~}"
}

# ---- checks -------------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "Run this as yourself, not with sudo: it asks for your password when it needs it."
[[ -d /usr/share/omarchy || -d "$HOME/.local/share/omarchy" ]] \
  || die "This needs Omarchy (https://omarchy.org). Install Omarchy first, then run this again."
curl -fsS --max-time 10 https://archlinux.org >/dev/null 2>&1 \
  || die "No internet connection. Connect to the internet and try again."

if [[ -d "$REPO/.git" ]]; then
  step "Getting the latest version"
  git -C "$REPO" pull --ff-only --quiet 2>/dev/null && ok "up to date" || warn "could not update; continuing with this version"
fi

# ---- packages -----------------------------------------------------------------
step "Installing packages (asks for your password)"
PACMAN=(typst tinymist websocat uv duckdb harper jq imagemagick curl git)
AUR=(quarto-cli-bin zotero-bin)
if command -v omarchy-pkg-add >/dev/null; then
  omarchy-pkg-add "${PACMAN[@]}"
else
  sudo pacman -S --needed --noconfirm "${PACMAN[@]}"
fi
ok "Typst, tinymist, uv, DuckDB, Harper"
if command -v omarchy-pkg-aur-add >/dev/null; then
  omarchy-pkg-aur-add "${AUR[@]}"
else
  yay -S --needed --noconfirm "${AUR[@]}"
fi
ok "Quarto, Zotero"

step "Python tools"
uv tool install --quiet jupytext 2>/dev/null || uv tool upgrade --quiet jupytext
ok "jupytext (open .ipynb notebooks as text in Neovim)"
[[ -x ~/.local/share/nvim-python/bin/python ]] || uv venv --quiet ~/.local/share/nvim-python
uv pip install --quiet --python ~/.local/share/nvim-python/bin/python \
  pynvim jupyter-client ipykernel nbformat cairosvg pillow pyperclip matplotlib
ok "Python for Neovim notebooks (~/.local/share/nvim-python)"

# ---- the ws command and the Projects menu ---------------------------------------
step "Projects menu and the ws command"
link "$REPO/bin/ws" "$HOME/.local/bin/ws"
mkdir -p "$HOME/Projects"
"$REPO/bin/ws" --menu >/dev/null && ok "Projects menu (Super + Space > Projects)"

# ---- Neovim -----------------------------------------------------------------------
step "Neovim research plugins"
if [[ ! -f "$NVIM/init.lua" ]]; then
  [[ -f /etc/skel/.config/nvim/init.lua ]] || die "No Neovim config at $NVIM and no Omarchy copy to start from."
  cp -r /etc/skel/.config/nvim "$NVIM"
  ok "copied Omarchy's Neovim config to ~/.config/nvim"
fi
for f in "$REPO"/nvim/lua/plugins/*.lua; do
  link "$f" "$NVIM/lua/plugins/$(basename "$f")"
done
link "$REPO/nvim/lua/quarto_typst_sync.lua" "$NVIM/lua/quarto_typst_sync.lua"

# LazyVim language support: Typst, Python, Markdown/Quarto, and the file list
EXTRAS='["lazyvim.plugins.extras.lang.typst","lazyvim.plugins.extras.lang.python","lazyvim.plugins.extras.lang.markdown","lazyvim.plugins.extras.editor.neo-tree"]'
json="$NVIM/lazyvim.json"
[[ -f "$json" ]] || printf '{"extras":[],"version":8}\n' >"$json"
tmp=$(mktemp)
jq --argjson add "$EXTRAS" '.extras = ((.extras // []) + $add | unique)' "$json" >"$tmp" && mv "$tmp" "$json"
ok "LazyVim extras: Typst, Python, Markdown, file list"

echo "    Downloading Neovim plugins (a minute or two the first time)..."
nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || warn "plugin download reported a problem; open Neovim and run :Lazy to see it"
nvim --headless "+UpdateRemotePlugins" +qa >/dev/null 2>&1 || true
ok "plugins installed"

# ---- agent integration -------------------------------------------------------------
step "Claude Code in Herdr"
if ! command -v herdr >/dev/null; then
  warn "Herdr not found; update Omarchy (Super + Space > Update) and run this again"
elif [[ ! -d "$HOME/.claude" ]]; then
  warn "Claude Code has not been opened yet: after signing in (step 1 below), run this installer once more"
else
  herdr integration install claude >/dev/null 2>&1 && ok "Herdr shows when Claude is working or needs you" \
    || warn "could not set up the Herdr integration (run: herdr integration install claude)"
fi

# ---- done ----------------------------------------------------------------------------
cat <<'EOF'

==> Done. Three things only you can do:

  1. Sign in to Claude Code: open a terminal (Super + Enter), type  claude  and
     follow the login. A Claude Pro or Max subscription or an API key works.

  2. Zotero: open it once from the app launcher (Super + Alt + Space), then install the
     Better BibTeX add-on: download the .xpi from
     https://retorque.re/zotero-better-bibtex/installation/ and in Zotero choose
     Tools > Plugins > the gear icon > Install Plugin From File.

  3. GitHub (to back up your projects): in a terminal run  gh auth login

Then open the Omarchy menu (Super + Space) > Projects > New project…
EOF
