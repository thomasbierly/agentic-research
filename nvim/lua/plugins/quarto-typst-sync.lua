-- Live Typst preview for Quarto documents, with click-to-source.
--
--   \qv  open the preview (an app window beside the editor); click any text in
--        it to jump to that line of the .qmd source
--   \qs  scroll the preview to the text under the cursor
--   \qx  stop the preview server
--
-- Keep `quarto preview --to typst` running (the `build` or `paper` tab that `ws` opens) with
-- `keep-typ: true` under format.typst in _quarto.yml: each save re-renders the
-- generated .typ and the preview updates from it. Logic: lua/quarto_typst_sync.lua

local ft = { "quarto", "markdown" }

return {
  {
    "chomosuke/typst-preview.nvim",
    opts = {
      -- Open previews (this one and plain .typ previews) as a standalone app
      -- window, which Hyprland tiles beside the terminal, not as a browser tab.
      open_cmd = "omarchy-launch-webapp %s",
      -- Use the system packages (pacman: tinymist, websocat), not downloads.
      dependencies_bin = { tinymist = "tinymist", websocat = "websocat" },
    },
    keys = {
      { "<localleader>qv", function() require("quarto_typst_sync").start() end, desc = "Quarto: Typst preview (click to jump)", ft = ft },
      { "<localleader>qs", function() require("quarto_typst_sync").sync() end, desc = "Quarto: scroll preview to cursor", ft = ft },
      { "<localleader>qx", function() require("quarto_typst_sync").stop() end, desc = "Quarto: stop Typst preview", ft = ft },
    },
  },
}
