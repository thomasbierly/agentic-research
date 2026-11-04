-- Insert a citation from Zotero (Better BibTeX "Cite as you write" picker).
-- \ci in Quarto/Markdown pops up Zotero's search box; pick one or more papers
-- and the Pandoc citation (e.g. [@knuth1984]) is inserted at the cursor.
-- Zotero must be running.
local function cite()
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local url = "http://127.0.0.1:23119/better-bibtex/cayw?format=pandoc&brackets=1"
  vim.notify("Zotero: pick a citation…")
  vim.system({ "curl", "-s", "--max-time", "300", url }, { text = true }, function(res)
    vim.schedule(function()
      local text = vim.trim(res.stdout or "")
      if res.code ~= 0 then
        vim.notify("Zotero isn't running (start it and try again)", vim.log.levels.WARN)
      elseif text ~= "" and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_set_current_win(win)
        vim.api.nvim_put({ text }, "c", true, true)
      end
    end)
  end)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "quarto", "markdown" },
  callback = function(ev)
    vim.keymap.set("n", "<localleader>ci", cite, { buffer = ev.buf, desc = "Zotero: insert citation" })
    vim.keymap.set("i", "<C-x><C-z>", cite, { buffer = ev.buf, desc = "Zotero: insert citation" })
  end,
})

return {}
