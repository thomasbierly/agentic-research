-- Research workflow: Quarto documents, Jupyter kernels, notebooks, inline plots.
--
--   .qmd files   quarto-nvim + otter give completion/diagnostics inside code cells
--   run code     molten-nvim talks to a real Jupyter kernel (\mi to start one)
--   .ipynb       jupytext.nvim opens notebooks as Quarto text, saves back as .ipynb
--   plots        image.nvim draws them inline (Ghostty/Kitty only; foot gets text)
--
-- Keys (localleader is \):
--   \mi  start kernel      \rc  run cell        \ra  run cell + all above
--   \rl  run line          \r   run selection   \rA  run all cells
--   \os  open output       \oh  hide output     \qp  quarto preview
--   \ci  insert Zotero citation (Ctrl+X Ctrl+Z in insert mode; zotero-cite.lua)

-- Python for Neovim's remote plugins (molten-nvim): a dedicated venv with pynvim
-- and jupyter_client made by install.sh, so project environments stay untouched.
local nvim_python = vim.fn.expand("~/.local/share/nvim-python/bin/python")
if vim.fn.executable(nvim_python) == 1 then
  vim.g.python3_host_prog = nvim_python
end

-- Prose: wrap long paragraphs at word boundaries (one paragraph per line stays
-- readable), and indent the wrapped part of list items.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "quarto", "markdown", "typst" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
  end,
})

local graphics = vim.env.TERM_PROGRAM == "ghostty"
  or vim.env.TERM == "xterm-ghostty"
  or vim.env.TERM == "xterm-kitty"

return {
  {
    "3rd/image.nvim",
    cond = graphics,
    opts = {
      backend = "kitty",
      processor = "magick_cli", -- uses the imagemagick CLI; no luarocks needed
      integrations = {
        markdown = {
          enabled = true,
          only_render_image_at_cursor = true,
          filetypes = { "markdown", "quarto" },
        },
      },
      max_width = 100,
      max_height = 14,
      max_width_window_percentage = math.huge,
      max_height_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
    },
  },

  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",
    lazy = false, -- remote plugin; must be registered at startup
    dependencies = graphics and { "3rd/image.nvim" } or {},
    init = function()
      vim.g.molten_image_provider = graphics and "image.nvim" or "none"
      vim.g.molten_auto_open_output = false
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = true
      vim.g.molten_wrap_output = true
    end,
    config = function()
      local map = function(lhs, rhs, desc, mode)
        vim.keymap.set(mode or "n", lhs, rhs, { silent = true, desc = desc })
      end
      map("<localleader>mi", ":MoltenInit<CR>", "Molten: start kernel")
      map("<localleader>rl", ":MoltenEvaluateLine<CR>", "Molten: run line")
      map("<localleader>r", ":<C-u>MoltenEvaluateVisual<CR>gv", "Molten: run selection", "v")
      map("<localleader>os", ":noautocmd MoltenEnterOutput<CR>", "Molten: open output")
      map("<localleader>oh", ":MoltenHideOutput<CR>", "Molten: hide output")
      map("<localleader>md", ":MoltenDelete<CR>", "Molten: clear cell output")
    end,
  },

  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto", "markdown" },
    dependencies = { "jmbuhr/otter.nvim", "nvim-treesitter/nvim-treesitter" },
    opts = {
      lspFeatures = {
        enabled = true,
        chunks = "all",
        languages = { "python", "r", "julia", "bash", "lua", "html" },
      },
      codeRunner = { enabled = true, default_method = "molten" },
    },
    keys = {
      { "<localleader>rc", function() require("quarto.runner").run_cell() end, desc = "Quarto: run cell", ft = { "quarto", "markdown" } },
      { "<localleader>ra", function() require("quarto.runner").run_above() end, desc = "Quarto: run cell and above", ft = { "quarto", "markdown" } },
      { "<localleader>rA", function() require("quarto.runner").run_all() end, desc = "Quarto: run all cells", ft = { "quarto", "markdown" } },
      { "<localleader>qp", function() require("quarto").quartoPreview() end, desc = "Quarto: preview", ft = { "quarto", "markdown" } },
    },
  },

  {
    -- Open .ipynb as Quarto text (needs the `jupytext` CLI on PATH).
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = {
      style = "quarto",
      output_extension = "qmd",
      force_ft = "quarto",
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "markdown", "markdown_inline", "python", "r", "julia", "yaml", "typst", "latex" } },
  },
}
