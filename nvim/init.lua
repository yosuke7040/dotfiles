if vim.g.vscode then
  -- VSCode Neovim

  local config_path = vim.fn.stdpath('config')

  -- プラグインの読み込み
  dofile(config_path .. '/vscode_plugins.lua')

  -- キーマップの読み込み
  dofile(config_path .. '/vscode_keymaps.lua')
else
  -- Ordinary Neovim
end
