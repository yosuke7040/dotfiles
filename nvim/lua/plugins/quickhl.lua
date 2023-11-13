
-- return {
--   "t9md/vim-quickhl",
--   event = { "VeryLazy" },
--   config = function() 
--     local keymap = vim.keymap
--     keymap.set(
--       "<Space>",
--       "m",
--       '<Plug>(quickhl-manual-this)'
--     )
--     keymap.set(
--       "<Space>",
--       "c",
--       '<Plug>(quickhl-manual-clear)'
--     )
--     keymap.set(
--       "<Space>",
--       "M",
--       '<Plug>(quickhl-manual-reset)'
--     )
--   end,
-- }
  
return {
  "t9md/vim-quickhl",
  event = { "VeryLazy" },
  config = function() 
    local keymap = vim.keymap
    keymap.set(
      "n",  -- Normal mode
      -- "<Space>m",
      "<A-m>",
      '<Plug>(quickhl-manual-this)'
    )
    keymap.set(
      "n",  -- Normal mode
      -- "<Space>c",
      "<A-c>",
      '<Plug>(quickhl-manual-clear)'
    )
    keymap.set(
      "n",  -- Normal mode
      -- "<Space>M",
      "<A-M>",
      '<Plug>(quickhl-manual-reset)'
    )
  end,
}
