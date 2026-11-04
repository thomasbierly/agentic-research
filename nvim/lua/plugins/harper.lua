-- Harper: local grammar/style checking for prose (nothing leaves the machine).
-- Uses the system harper-ls from the `harper` package rather than Mason.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        harper_ls = {
          mason = false,
          filetypes = { "markdown", "quarto", "typst", "tex", "gitcommit", "text" },
          settings = {
            ["harper-ls"] = {
              dialect = "American", -- or "British", "Australian", "Canadian"
              -- per-project word list (citation keys, cross-reference ids, jargon):
              -- add a word from Neovim with the code action "Add to dictionary"
              workspaceDictPath = ".harper-dictionary.txt",
              linters = {
                SpellCheck = true,
                SentenceCapitalization = true,
                LongSentences = true,
                -- these fire on Quarto/Markdown markup rather than prose:
                Dashes = false,          -- "--" is Pandoc's en dash
                Spaces = false,          -- padding inside table rows
                NoFrenchSpaces = false,  -- same
                UnclosedQuotes = false,  -- attribute values such as {width="78%"}
                UseTitleCase = false,    -- its rule contradicts APA 7 title case
              },
              codeActions = { ForceStable = true },
            },
          },
        },
      },
    },
  },
}
