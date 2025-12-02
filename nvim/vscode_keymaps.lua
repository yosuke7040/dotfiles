-- VSCode Neovim キーマッピング設定
-- VSCodeVimから移行した設定

local vscode = require('vscode-neovim')
local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }


-- ===========================================
-- 基本設定
-- ===========================================
-- leaderキーを設定
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ===========================================
-- インサートモードのキーバインド
-- ===========================================
-- jk で Esc
-- vscode側で設定しているためコメントアウト
-- vim.keymap.set('i', 'jk', '<Esc>', { noremap = true, silent = true })
-- vim.keymap.set('i', 'jj', '<Esc>', { noremap = true, silent = true })

-- ===========================================
-- ノーマルモードのキーバインド
-- ===========================================
-- Q で整形
vim.keymap.set('n', 'Q', 'gq', { noremap = true, silent = true })

-- Ctrl-c で Esc
vim.keymap.set('n', '<C-c>', '<Esc>', { noremap = true, silent = true })

-- U で Redo
vim.keymap.set('n', 'U', '<C-r>', { noremap = true, silent = true })

-- J で段落下移動
vim.keymap.set('n', 'J', '}', { noremap = true, silent = true })

-- K で段落上移動
vim.keymap.set('n', 'K', '{', { noremap = true, silent = true })

-- Y で行末までヤンク
vim.keymap.set('n', 'Y', 'y$', { noremap = true, silent = true })

-- M でマッチする括弧へ移動
vim.keymap.set('n', 'M', '%', { noremap = true, silent = true })

-- x でブラックホールレジスタに削除
vim.keymap.set('n', 'x', '"_x', { noremap = true, silent = true })

-- dy で行削除（ブラックホールレジスタ）
vim.keymap.set('n', 'dy', '"_dd', { noremap = true, silent = true })

-- D で行末まで削除（ブラックホールレジスタ）
vim.keymap.set('n', 'D', '"_D', { noremap = true, silent = true })

-- ===========================================
-- VSCode固有コマンド（エディタ分割・移動）
-- ===========================================
-- <leader>v で右に分割
vim.keymap.set('n', '<leader>v', function()
  vscode.call('workbench.action.splitEditorRight')
end, { noremap = true, silent = true })

-- <leader>s で下に分割
vim.keymap.set('n', '<leader>s', function()
  vscode.call('workbench.action.splitEditorDown')
end, { noremap = true, silent = true })

-- <leader>d でエディタを右のグループに移動
vim.keymap.set('n', '<leader>d', function()
  vscode.call('workbench.action.moveEditorToRightGroup')
end, { noremap = true, silent = true })

-- <leader>a でエディタを左のグループに移動
vim.keymap.set('n', '<leader>a', function()
  vscode.call('workbench.action.moveEditorToLeftGroup')
end, { noremap = true, silent = true })

-- <leader>r でリネーム
vim.keymap.set('n', '<leader>r', function()
  vscode.call('editor.action.rename')
end, { noremap = true, silent = true })

-- <leader>f でフォーマット
vim.keymap.set('n', '<leader>f', function()
  vscode.call('editor.action.formatDocument')
end, { noremap = true, silent = true })

-- ===========================================
-- タブ間での移動
-- ===========================================
-- <leader>h で前のグループにフォーカス
vim.keymap.set('n', '<leader>h', function()
  vscode.call('workbench.action.focusPreviousGroup')
end, { noremap = true, silent = true })

-- <leader>l で次のグループにフォーカス
vim.keymap.set('n', '<leader>l', function()
  vscode.call('workbench.action.focusNextGroup')
end, { noremap = true, silent = true })

-- ===========================================
-- ファイル検索
-- ===========================================
-- <leader>ff でファイル検索
vim.keymap.set('n', '<leader>ff', function()
  vscode.call('multiCommand.findFiles')
end, { noremap = true, silent = true })

-- <leader>fw で全体検索
vim.keymap.set('n', '<leader>fw', function()
  vscode.call('multiCommand.findWithinFiles')
end, { noremap = true, silent = true })

-- <leader>f/ でファイル内検索
vim.keymap.set('n', '<leader>f/', function()
  vscode.call('multiCommand.findCurrentFile')
end, { noremap = true, silent = true })

-- -- ===========================================
-- -- コードナビゲーション
-- -- ===========================================
-- gd で定義へ移動
vim.keymap.set('n', 'gd', function()
  vscode.call('editor.action.goToDeclaration')
end, { noremap = true, silent = true })

-- gi で実装へ移動
vim.keymap.set('n', 'gi', function()
  vscode.call('editor.action.goToImplementation')
end, { noremap = true, silent = true })

-- gh でホバー表示
vim.keymap.set('n', 'gh', function()
  vscode.call('editor.action.showHover')
end, { noremap = true, silent = true })

-- ===========================================
-- ビジュアルモードのキーバインド
-- ===========================================
-- Tab でインデント
vim.keymap.set('v', '<Tab>', '>', { noremap = true, silent = true })

-- Shift-Tab でアンインデント
vim.keymap.set('v', '<S-Tab>', '<', { noremap = true, silent = true })

-- p で上書きペースト（ヤンクを保持）
vim.keymap.set('v', 'p', 'P', { noremap = true, silent = true })

-- < でアンインデント後に選択を維持
vim.keymap.set('v', '<', '<gv', { noremap = true, silent = true })

-- > でインデント後に選択を維持
vim.keymap.set('v', '>', '>gv', { noremap = true, silent = true })

-- i<Space> でWORD単位のテキストオブジェクト
vim.keymap.set('v', 'i<Space>', 'iW', { noremap = true, silent = true })

-- ===========================================
-- オペレータ待機モードのキーバインド
-- ===========================================
-- i<Space> でWORD単位のテキストオブジェクト
vim.keymap.set('o', 'i<Space>', 'iW', { noremap = true, silent = true })
