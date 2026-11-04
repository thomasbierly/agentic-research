-- Mouse-first navigation, so the basics work without remembering keys.
--
--   * In a project folder (Git repo, Quarto or Python project) the file list
--     opens on the left at startup. One click opens a file or folder.
--   * Right-click anywhere in the text for a menu of everyday actions
--     (preview, analysis notebook, find a file, search, show/hide the file list).
--   * Press Space and wait: a menu of every shortcut appears (which-key).

-- The project folder: the nearest one above with a Quarto config, a Git repo
-- or a Python project (research projects keep _quarto.yml in paper/).
local function project_root()
  local start = vim.fn.argc() > 0 and vim.fn.fnamemodify(vim.fn.argv(0), ":p:h") or vim.fn.getcwd()
  local found = vim.fs.find({ "_quarto.yml", ".git", "pyproject.toml" }, { path = start, upward = true })[1]
  if not found or vim.fs.dirname(found) == vim.env.HOME then
    return nil
  end
  -- prefer the repo root over a Quarto folder inside it (paper/)
  local git = vim.fs.find(".git", { path = start, upward = true })[1]
  if git and vim.fs.dirname(git) ~= vim.env.HOME then
    return vim.fs.dirname(git)
  end
  return vim.fs.dirname(found)
end

-- The analysis notebook (marimo) runs in the project's run tab; this opens its
-- window, showing the notebook being edited if it is one.
function _G.open_analysis_notebook()
  local file = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(0, { ".git", "pyproject.toml" }) or project_root() or vim.fn.getcwd()
  vim.fn.jobstart({ "ws", "--open-notebook", root, file }, { detach = true })
end

-- Right-click menu entries, above Neovim's own (Copy, Paste, ...).
local function add_menu()
  local items = {
    { "Show\\ PDF\\ preview\\ (click\\ text\\ to\\ jump\\ here)", [[lua require("quarto_typst_sync").start()]] },
    { "Show\\ this\\ spot\\ in\\ the\\ preview", [[lua require("quarto_typst_sync").sync()]] },
    { "Open\\ the\\ analysis\\ notebook", [[lua open_analysis_notebook()]] },
    { "Find\\ a\\ file\\.\\.\\.", [[lua LazyVim.pick("files")()]] },
    { "Search\\ all\\ files\\ for\\ text\\.\\.\\.", [[lua LazyVim.pick("live_grep")()]] },
    { "Show\\ or\\ hide\\ the\\ file\\ list", [[Neotree toggle reveal]] },
  }
  for i, item in ipairs(items) do
    vim.cmd(("anoremenu 1.%d PopUp.%s <Cmd>%s<CR>"):format(i, item[1], item[2]))
  end
  vim.cmd("anoremenu 1.99 PopUp.-research- <Nop>")
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    add_menu()
    local root = project_root()
    if root then
      -- "show" opens the list without moving the cursor out of the text.
      vim.schedule(function()
        require("neo-tree.command").execute({ action = "show", dir = root })
      end)
    end
  end,
})

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          -- Quarto build output: hidden even before git status has loaded
          hide_by_name = { "_output", ".quarto" },
          hide_by_pattern = { "*_files" },
        },
      },
      window = {
        mappings = {
          -- open files and folders with a single click (default is double-click)
          ["<LeftRelease>"] = "open",
        },
      },
    },
  },
}
