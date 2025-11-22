return {
  "nvim-telescope/telescope.nvim",
  opts = function()
    local lga_actions = require "telescope-live-grep-args.actions"
    return {
      defaults = {
        -- 30%透明にする
        winblend = 30,
      },
      extensions = {
        -- https://github.com/nvim-telescope/telescope-live-grep-args.nvim
        live_grep_args = {
          auto_quoting = true,
          mappings = {
            i = {
              ["<C-m>"] = lga_actions.quote_prompt(),
            },
          },
        },
      },
    }
  end,
}

-- return {
--   "nvim-telescope/telescope.nvim",
--   dependencies = {
--     { "nvim-telescope/telescope-fzf-native.nvim", enabled = vim.fn.executable "make" == 1, build = "make" },
--     { "nvim-telescope/telescope-file-browser.nvim"},
--     { "nvim-telescope/telescope-live-grep-args.nvim"},
--   },
--   cmd = "Telescope",
--   opts = function()
--     local actions = require "telescope.actions"
--     local get_icon = require("astronvim.utils").get_icon
--     return {
--       defaults = {
--         git_worktrees = vim.g.git_worktrees,
--         prompt_prefix = get_icon("Selected", 1),
--         selection_caret = get_icon("Selected", 1),
--         path_display = { "truncate" },
--         sorting_strategy = "ascending",
--         layout_config = {
--           horizontal = { prompt_position = "top", preview_width = 0.55 },
--           vertical = { mirror = false },
--           width = 0.87,
--           height = 0.80,
--           preview_cutoff = 120,
--         },
--         mappings = {
--           i = {
--             ["<C-n>"] = actions.cycle_history_next,
--             ["<C-p>"] = actions.cycle_history_prev,
--             ["<C-j>"] = actions.move_selection_next,
--             ["<C-k>"] = actions.move_selection_previous,
--           },
--           n = { q = actions.close },
--         },
--         file_ignore_patterns = {
--           "node_modules",
--         },
--       },
--       extensions = {
--         fzf = {
--           fuzzy = true,
--           override_generic_sorter = true,
--           override_file_sorter = true,
--           case_mode = "smart_case",
--         },
-- --        file_browser = {
-- --          hijack_netrw = true,
-- --        },
-- --        live_grep_args = {
-- --          auto_quoting = true,
-- --        },
--       },
--     }
--   end,
--   config = require "plugins.configs.telescope",
-- }
