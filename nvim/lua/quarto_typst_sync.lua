-- Click-to-source for Quarto documents rendered through Typst.
--
-- Quarto turns the .qmd files into one Typst file (index.typ for a book, with
-- `keep-typ: true`), so a click in a Typst preview points into that generated
-- file, not the source. This module previews the generated file with
-- typst-preview.nvim's server and maps each click back to the .qmd line by
-- matching the words around the click point. Citations, cross-references and
-- markup are rewritten by Quarto, so they are masked out on both sides and the
-- match uses the plain prose around them.
--
-- Used by lua/plugins/quarto-typst-sync.lua (keys \qv, \qs, \qx).

local M = {}

local state = {
  server = nil, ---@type table?  typst-preview Server
  typ = nil, ---@type string?  generated .typ being previewed
  root = nil, ---@type string?  Quarto project root
  return_window = nil, ---@type string?  Hyprland address of the editor's window
}

local WINDOW = 6 -- words per phrase used for matching
local MAX_WINDOW = 14 -- longest phrase tried when a short one is ambiguous
local NEIGHBOUR_LINES = 8 -- typ lines searched around a click that has no prose

---------------------------------------------------------------------------
-- Text normalisation
---------------------------------------------------------------------------

local function blank(s)
  return string.rep(" ", #s)
end

-- Non-breaking space, dashes, curly quotes and ellipsis separate words; replace
-- them byte for byte so offsets survive.
local UNICODE_SEPARATORS = { "\194\160", "\226\128[\147-\149]", "\226\128[\152-\159]", "\226\128\166", "\226\136\146" }

local function separators(line)
  for _, pat in ipairs(UNICODE_SEPARATORS) do
    line = line:gsub(pat, blank)
  end
  return line
end

-- Replace Typst markup with spaces of the same length, so byte offsets survive.
local function mask_typ(line)
  line = separators(line)
  line = line:gsub("#ref%b()", blank)
  line = line:gsub("#cite%b()", blank)
  line = line:gsub("#link%b()", blank)
  line = line:gsub("#label%b()", blank)
  line = line:gsub("#[%a][%w%.%-]*", blank) -- #emph, #strong, #figure-note, ...
  line = line:gsub("<[%w%-%_:%.]+>", blank) -- labels
  line = line:gsub("\\", " ")
  line = line:gsub("~", " ")
  return line
end

-- Replace Quarto/Pandoc markup with spaces of the same length.
local function mask_qmd(line)
  line = separators(line)
  line = line:gsub("%[%-?@[^%]]*%]", blank) -- [@key; @key, p. 3] and [-@sec-x]
  line = line:gsub("%-?@[%w_][%w_:%.%-]*", blank) -- narrative @key
  line = line:gsub("%b{}", blank) -- {#sec-x}, {width="78%"}, {{< include >}}
  line = line:gsub("<[^>]*>", blank) -- html
  line = line:gsub("%]%b()", blank) -- link targets [text](url)
  return line
end

-- Words with their byte positions. UTF-8 bytes count as word characters.
local function tokens(masked)
  local out = {}
  for s, w, e in masked:gmatch("()([%w\128-\255]+)()") do
    out[#out + 1] = { w = w:lower(), s = s, e = e - 1 }
  end
  return out
end

-- " w1 w2 w3 " plus, for each word, the byte offset of its leading space.
local function joined(toks)
  local parts, offsets, pos = { " " }, {}, 1
  for i, t in ipairs(toks) do
    offsets[i] = pos
    parts[#parts + 1] = t.w .. " "
    pos = pos + #t.w + 1
  end
  return table.concat(parts), offsets
end

local function token_at_offset(offsets, pos)
  -- word index whose leading space is at pos (pos is the start of the found " phrase ")
  for i, o in ipairs(offsets) do
    if o == pos then
      return i
    end
  end
end

local function phrase(toks, from, to)
  local ws = {}
  for i = from, to do
    ws[#ws + 1] = toks[i].w
  end
  return " " .. table.concat(ws, " ") .. " "
end

-- Window start positions, nearest to the clicked word first.
local function window_starts(n_tokens, k, len)
  local centre = math.max(1, math.min(k - math.floor(len / 2), n_tokens - len + 1))
  local starts, seen = {}, {}
  for d = 0, n_tokens do
    for _, s in ipairs({ centre + d, centre - d }) do
      if s >= 1 and s + len - 1 <= n_tokens and not seen[s] then
        seen[s] = true
        starts[#starts + 1] = s
      end
    end
  end
  return starts
end

---------------------------------------------------------------------------
-- Quarto project files
---------------------------------------------------------------------------

function M.find_root(path)
  local found = vim.fs.find("_quarto.yml", { path = vim.fs.dirname(path), upward = true })[1]
  if found then
    return vim.fs.dirname(found)
  end
  -- research projects keep the paper in paper/: use it from anywhere in the repo
  local git = vim.fs.find(".git", { path = vim.fs.dirname(path), upward = true })[1]
  local paper = git and (vim.fs.dirname(git) .. "/paper/_quarto.yml")
  return paper and vim.uv.fs_stat(paper) and vim.fs.dirname(paper) or nil
end

-- .qmd files in book order (as listed in _quarto.yml), then any others.
local function source_files(root)
  local files, seen = {}, {}
  local function add(rel)
    local abs = vim.fs.normalize(root .. "/" .. rel)
    if not seen[abs] and vim.uv.fs_stat(abs) then
      seen[abs] = true
      files[#files + 1] = abs
    end
  end
  local yml = io.open(root .. "/_quarto.yml")
  if yml then
    for l in yml:lines() do
      local f = l:match("^%s*%-%s*([^%s#]+%.qmd)")
      if f then
        add(f)
      end
    end
    yml:close()
  end
  local skip = { _output = true, [".quarto"] = true, ["latex-original"] = true, convert = true, [".venv"] = true }
  for name, kind in vim.fs.dir(root, {
    depth = 4,
    skip = function(dir)
      return not skip[vim.fs.basename(dir)]
    end,
  }) do
    if kind == "file" and name:match("%.qmd$") then
      add(name)
    end
  end
  return files
end

-- Lines of a file, from its buffer when loaded (so unsaved edits count).
local function file_lines(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or {}
end

-- Search every line of `files` for `needle`; returns { file, lnum, offsets, pos } hits.
local function search(index, needle)
  local hits = {}
  for _, entry in ipairs(index) do
    local pos = entry.joined:find(needle, 1, true)
    if pos then
      hits[#hits + 1] = { entry = entry, pos = pos }
    end
  end
  return hits
end

local function build_index(files, masker)
  local index = {}
  for order, file in ipairs(files) do
    for lnum, text in ipairs(file_lines(file)) do
      local toks = tokens(masker(text))
      if #toks > 0 then
        local j, offsets = joined(toks)
        index[#index + 1] = { file = file, order = order, lnum = lnum, toks = toks, joined = j, offsets = offsets }
      end
    end
  end
  return index
end

-- Find where the words around byte `col` of `text` occur in `index`.
-- Returns { file, lnum, col } (col 0-based) or nil.
local function locate(text, col, masker, index, prefer_file)
  local toks = tokens(masker(text))
  if #toks == 0 then
    return nil
  end
  local k = #toks -- the clicked word
  for i, t in ipairs(toks) do
    if t.e >= col + 1 then
      k = i
      break
    end
  end

  -- hit.offset_in_window: how far the clicked word sits from the window start
  local function result(hit)
    local first = token_at_offset(hit.entry.offsets, hit.pos) or 1
    local idx = math.max(1, math.min(first + hit.offset_in_window, #hit.entry.toks))
    return { file = hit.entry.file, lnum = hit.entry.lnum, col = hit.entry.toks[idx].s - 1 }
  end

  local longest = math.min(MAX_WINDOW, #toks)
  local ambiguous
  for len = math.min(WINDOW, #toks), longest do
    local any = false
    for _, s in ipairs(window_starts(#toks, k, len)) do
      local hits = search(index, phrase(toks, s, s + len - 1))
      for _, h in ipairs(hits) do
        h.offset_in_window = k - s
      end
      if #hits == 1 then
        return result(hits[1])
      elseif #hits > 1 then
        any = true
        ambiguous = ambiguous or hits
      end
    end
    if not any then
      break -- nothing of this length matched more than once; longer will not help
    end
  end
  if ambiguous then
    for _, hit in ipairs(ambiguous) do
      if hit.entry.file == prefer_file then
        return result(hit)
      end
    end
    return result(ambiguous[1])
  end
end

--- Map a position in the generated .typ to the .qmd source.
---@param typ_lines string[]
---@param row integer 1-based
---@param col integer 0-based byte column
---@param root string
---@return { file: string, lnum: integer, col: integer }?
function M.typ_to_qmd(typ_lines, row, col, root, prefer_file)
  local index = build_index(source_files(root), mask_qmd)
  local hit = locate(typ_lines[row] or "", col, mask_typ, index, prefer_file)
  if hit then
    return hit
  end
  -- Clicked on a line without matchable prose (a table cell, a caption wrapper):
  -- use the nearest line that has some, landing at its start.
  for d = 1, NEIGHBOUR_LINES do
    for _, r in ipairs({ row - d, row + d }) do
      if typ_lines[r] then
        hit = locate(typ_lines[r], 0, mask_typ, index, prefer_file)
        if hit then
          return hit
        end
      end
    end
  end
end

--- Map a .qmd position to the generated .typ.
---@return { lnum: integer, col: integer }?
function M.qmd_to_typ(qmd_text, col, typ_path)
  local index = build_index({ typ_path }, mask_typ)
  local hit = locate(qmd_text, col, mask_qmd, index)
  return hit and { lnum = hit.lnum, col = hit.col } or nil
end

---------------------------------------------------------------------------
-- Preview server
---------------------------------------------------------------------------

local function hypr_active_window()
  if vim.fn.executable("hyprctl") == 0 then
    return nil
  end
  local out = vim.fn.system({ "hyprctl", "activewindow", "-j" })
  local ok, info = pcall(vim.json.decode, out)
  return ok and type(info) == "table" and info.address or nil
end

local function focus_editor()
  if state.return_window then
    vim.fn.jobstart({ "hyprctl", "dispatch", "focuswindow", "address:" .. state.return_window })
  end
end

-- Pick a window in this tab to show the source in: the current one unless it is
-- a special buffer (file tree, terminal, ...).
local function target_window()
  local cur = vim.api.nvim_get_current_win()
  if vim.bo[vim.api.nvim_win_get_buf(cur)].buftype == "" then
    return cur
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
      return win
    end
  end
  return cur
end

local function on_click(event)
  local path = event.filepath
  local row, col = event.start.row + 1, math.max(event.start.column, 0)
  local win = target_window()

  if path ~= state.typ then
    -- Clicked something from a real Typst source (template, figure): open it as is.
    vim.api.nvim_set_current_win(win)
    vim.cmd.edit(vim.fn.fnameescape(path))
    pcall(vim.api.nvim_win_set_cursor, win, { row, col })
    focus_editor()
    return
  end

  local prefer = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
  local hit = M.typ_to_qmd(vim.fn.readfile(state.typ), row, col, state.root, prefer)
  if not hit then
    vim.notify("No matching source line for that spot (index.typ:" .. row .. ")", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_set_current_win(win)
  if vim.fs.normalize(vim.api.nvim_buf_get_name(0)) ~= hit.file then
    vim.cmd.edit(vim.fn.fnameescape(hit.file))
  end
  pcall(vim.api.nvim_win_set_cursor, 0, { hit.lnum, hit.col })
  vim.cmd("normal! zz")
  focus_editor()
end

local function generated_typ(root, buf_path)
  local index = root .. "/index.typ"
  if vim.uv.fs_stat(root .. "/index.qmd") then
    return index
  end
  return (buf_path:gsub("%.qmd$", ".typ"))
end

local function start_server()
  require("lazy").load({ plugins = { "typst-preview.nvim" } })
  local servers = require("typst-preview.servers")
  servers.init(state.typ, "document", function(server)
    state.server = server
    servers.listen_scroll(server, function(event)
      vim.schedule(function()
        on_click(event)
      end)
    end)
    -- (the plugin opens the preview window itself, via open_cmd)
    vim.notify("Preview running: click in it to jump to the source")
  end)
end

function M.start()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local root = M.find_root(buf_path ~= "" and buf_path or vim.fn.getcwd() .. "/x")
  if not root then
    vim.notify("Not inside a Quarto project (no _quarto.yml found)", vim.log.levels.ERROR)
    return
  end
  if state.server then
    require("typst-preview.utils").visit(state.server.link) -- reopen the window
    return
  end
  state.root = root
  state.typ = generated_typ(root, buf_path)
  state.return_window = hypr_active_window()

  if vim.uv.fs_stat(state.typ) then
    start_server()
    return
  end
  vim.notify("Rendering with Quarto to create " .. vim.fs.basename(state.typ) .. " ...")
  vim.system({ "quarto", "render", "--to", "typst", "-M", "keep-typ:true" }, { cwd = root }, function(res)
    vim.schedule(function()
      if res.code ~= 0 or not vim.uv.fs_stat(state.typ) then
        vim.notify("Quarto render failed:\n" .. (res.stderr or ""), vim.log.levels.ERROR)
        return
      end
      start_server()
    end)
  end)
end

function M.stop()
  if state.server then
    require("typst-preview.servers").remove(state.typ)
  end
  state.server = nil
end

--- Scroll the preview to the text under the cursor.
function M.sync()
  if not state.server then
    vim.notify("Preview is not running (\\qv starts it)", vim.log.levels.WARN)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local hit = M.qmd_to_typ(vim.api.nvim_get_current_line(), cursor[2], state.typ)
  if not hit then
    vim.notify("Could not find this line in the preview", vim.log.levels.WARN)
    return
  end
  state.server.write(vim.json.encode({
    event = "panelScrollTo",
    filepath = state.typ,
    line = hit.lnum - 1,
    character = hit.col,
  }) .. "\n")
end

return M
