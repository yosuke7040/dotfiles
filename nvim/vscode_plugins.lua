-- VSCode Neovim プラグイン設定
-- lazy.nvimを使用したプラグイン管理

-- lazy.nvimのインストールパス
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- プラグインの設定
require("lazy").setup({
  -- clever-f: f/F/t/Tの強化
  {
    "rhysd/clever-f.vim",
    config = function()
      -- fを押した後、続けてfまたはFで次/前の文字に移動
      vim.g.clever_f_across_no_line = 0  -- 行をまたいで検索（1で無効化）
      vim.g.clever_f_smart_case = 1      -- スマートケース（小文字なら大文字小文字無視）
      vim.g.clever_f_fix_key_direction = 0  -- fとFの方向を固定しない
      vim.g.clever_f_chars_match_any_signs = nil  -- 記号にマッチする文字

      -- ハイライト設定
      vim.g.clever_f_mark_cursor = 1           -- カーソル位置をマーク
      vim.g.clever_f_mark_char = 1             -- 検索文字をハイライト
      vim.g.clever_f_hide_cursor_on_cmdline = 1  -- コマンドライン表示時にカーソルを隠す

      -- タイムアウト設定（ミリ秒）
      vim.g.clever_f_timeout_ms = 0  -- 0で無効（常にclever-fモード）
    end,
  },

  -- quick-scope: f/F/t/Tのターゲット文字をハイライト
  {
    "unblevable/quick-scope",
    config = function()
      -- トリガーキー（0で常に有効、1で手動トリガー）
      vim.g.qs_highlight_on_keys = {'f', 'F', 't', 'T'}

      -- 最大ハイライト数
      vim.g.qs_max_chars = 150

      -- 遅延設定（ミリ秒）
      vim.g.qs_delay = 0

      -- 受け入れ可能な文字（デフォルトは全ての表示可能文字）
      -- vim.g.qs_accepted_chars = {'a', 'b', 'c', ...}  -- カスタマイズ可能

      -- ハイライトカラー設定（下線のみに色をつける）
      vim.cmd([[
        highlight QuickScopePrimary gui=underline guisp='#ff0058' cterm=underline
        highlight QuickScopeSecondary gui=underline guisp='#ffff00' cterm=underline
      ]])
    end,
  },

  -- dial.nvim: Ctrl-a/Ctrl-xの拡張（数値、日付、真偽値などの増減）
  {
    "monaqa/dial.nvim",
    config = function()
      local augend = require("dial.augend")
      require("dial.config").augends:register_group{
        default = {
          augend.integer.alias.decimal,   -- 10進数
          augend.integer.alias.hex,        -- 16進数
          augend.date.alias["%Y/%m/%d"],   -- 日付 (YYYY/MM/DD)
          augend.date.alias["%Y-%m-%d"],   -- 日付 (YYYY-MM-DD)
          augend.date.alias["%H:%M:%S"],   -- 時刻 (HH:MM:SS)
          augend.constant.alias.bool,      -- true/false
          augend.semver.alias.semver,      -- セマンティックバージョン (1.2.3)
        },
      }

      -- キーマッピング
      vim.keymap.set("n", "<C-a>", require("dial.map").inc_normal(), {noremap = true})
      vim.keymap.set("n", "<C-x>", require("dial.map").dec_normal(), {noremap = true})
      vim.keymap.set("v", "<C-a>", require("dial.map").inc_visual(), {noremap = true})
      vim.keymap.set("v", "<C-x>", require("dial.map").dec_visual(), {noremap = true})
      vim.keymap.set("v", "g<C-a>", require("dial.map").inc_gvisual(), {noremap = true})
      vim.keymap.set("v", "g<C-x>", require("dial.map").dec_gvisual(), {noremap = true})
    end,
  },

  -- laterisk.nvim: */# 検索の拡張（スマート検索）
  {
    "rapan931/lasterisk.nvim",
    config = function()
      -- キーマッピング
      vim.keymap.set('n', '*', function() require("lasterisk").search() end, { noremap = true, silent = true })
      vim.keymap.set('n', 'g*', function() require("lasterisk").search({ is_whole = false }) end, { noremap = true, silent = true })
      vim.keymap.set('x', '*', function() require("lasterisk").search() end, { noremap = true, silent = true })
      vim.keymap.set('x', 'g*', function() require("lasterisk").search({ is_whole = false }) end, { noremap = true, silent = true })
    end,
  },

  -- nvim-hlslens: 検索結果の数を表示、検索体験を向上
  {
    "kevinhwang91/nvim-hlslens",
    config = function()
      require('hlslens').setup({
        calm_down = true,  -- 一定時間後に検索カウント表示を自動で消す
        nearest_only = false,  -- すべての検索結果を表示
        nearest_float_when = 'auto',  -- フロート表示のタイミング
      })

      -- キーマッピング（検索と統合）
      local kopts = {noremap = true, silent = true}
      vim.keymap.set('n', 'n', [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('n', 'N', [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('n', '*', [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('n', '#', [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('n', 'g*', [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('n', 'g#', [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

      -- 検索ハイライトをクリア
      vim.keymap.set('n', '<Esc>', '<Cmd>noh<CR>', kopts)
    end,
  },

  -- substitute.nvim: 置換操作を改善
  -- registerを汚さずにyankした内容と置き換える
  {
    "gbprod/substitute.nvim",
    config = function()
      require("substitute").setup({
        on_substitute = nil,
        yank_substituted_text = false,
        preserve_cursor_position = false,
        modifiers = nil,
        highlight_substituted_text = {
          enabled = true,
          timer = 500,  -- ミリ秒
        },
      })

      -- キーマッピング
      vim.keymap.set("n", "s", require('substitute').operator, { noremap = true })
      vim.keymap.set("n", "ss", require('substitute').line, { noremap = true })
      vim.keymap.set("n", "S", require('substitute').eol, { noremap = true })
      vim.keymap.set("x", "s", require('substitute').visual, { noremap = true })

      -- 交換操作（exchange）
      vim.keymap.set("n", "sx", require('substitute.exchange').operator, { noremap = true })
      vim.keymap.set("n", "sxx", require('substitute.exchange').line, { noremap = true })
      vim.keymap.set("x", "X", require('substitute.exchange').visual, { noremap = true })
      vim.keymap.set("n", "sxc", require('substitute.exchange').cancel, { noremap = true })
    end,
  },

  -- vim-edgemotion: コードブロックのエッジへ移動
  {
    "haya14busa/vim-edgemotion",
    config = function()
      -- キーマッピング（ノーマルモード＆ビジュアルモード）
      -- 注意: Ctrl+j/Ctrl+kはVSCodeと競合する可能性があります
      vim.keymap.set('n', '<C-j>', '<Plug>(edgemotion-j)', { noremap = true, silent = true })
      vim.keymap.set('n', '<C-k>', '<Plug>(edgemotion-k)', { noremap = true, silent = true })
      vim.keymap.set('v', '<C-j>', '<Plug>(edgemotion-j)', { noremap = true, silent = true })
      vim.keymap.set('v', '<C-k>', '<Plug>(edgemotion-k)', { noremap = true, silent = true })
    end,
  },

  -- vim-metarepeat: .（ドットコマンド）でプラグイン操作を繰り返す
  -- lasterisk との組み合わせで選択したもの一気に書き換える
  {
    "haya14busa/vim-metarepeat",
    -- 依存関係: vim-repeat（tpope/vim-repeat）
    dependencies = { "tpope/vim-repeat" },
    config = function()
      -- vim-metarepeatは自動的に動作するため、特別な設定は不要
      -- プラグインが提供する操作を.で繰り返せるようになります
    end,
  },

  -- im-select.nvim: IME（日本語入力）を自動切り替え
  {
    "keaising/im-select.nvim",
    config = function()
      require('im_select').setup({
        -- デフォルトのIM（ノーマルモード時の入力メソッド）
        default_im_select = "com.apple.keylayout.ABC",  -- macOS: 英数

        -- インサートモードを抜けた時、自動的にデフォルトIMに切り替える
        default_command = 'macism',

        -- バッファごとにIMの状態を記憶
        set_default_events = { "VimEnter", "FocusGained", "InsertLeave", "CmdlineLeave" },

        -- 前回のIMを復元するイベント
        set_previous_events = { "InsertEnter" },
      })
    end,
  },

  -- nvim-surround: 括弧・引用符などを効率的に追加・変更・削除
  {
    "kylechui/nvim-surround",
    version = "*", -- 最新の安定版を使用
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- デフォルト設定を使用
        -- キーマッピング:
        --   ys{motion}{char}  : 追加 (例: ysiw" で単語を"で囲む)
        --   ds{char}          : 削除 (例: ds" で"を削除)
        --   cs{old}{new}      : 変更 (例: cs"' で"を'に変更)
        --   S{char} (visual)  : ビジュアルモードで囲む
      })
    end,
  },

  -- lsp_signature.nvim: 関数シグネチャのヒント表示
  -- 注意: VSCode Neovimでは動作が不安定なため、ターミナルNeovimでのみ使用
  --       VSCodeではネイティブのパラメータヒント（Ctrl+Shift+Space）を使用推奨
  {
    "ray-x/lsp_signature.nvim",
    cond = not vim.g.vscode,  -- VSCode環境では無効化
    event = "InsertEnter",
    config = function()
      -- ターミナルNeovim用の設定（VSCodeでは無効化されている）
      require("lsp_signature").setup({
        bind = true,  -- LSPに自動バインド
        hi_parameter = "LspSignatureActiveParameter",  -- 現在のパラメータをハイライト

        -- フローティングウィンドウ設定
        floating_window = true,
        floating_window_above_cur_line = true,
        floating_window_off_x = 1,
        floating_window_off_y = 0,
        handler_opts = {
          border = "rounded",  -- ボーダースタイル
        },
        doc_lines = 10,  -- ドキュメントの表示行数
        max_height = 12,
        max_width = 80,
        wrap = true,

        -- ヒント設定
        hint_enable = true,  -- 仮想テキストでヒントを表示
        hint_prefix = "🐼 ",  -- ヒントのプレフィックス
        hint_scheme = "String",  -- ヒントのハイライトグループ
        hint_inline = false,  -- インラインヒント（false推奨）

        -- 表示タイミング
        always_trigger = false,  -- 常に表示（false推奨）
        auto_close_after = nil,
        close_timeout = 4000,

        -- その他
        extra_trigger_chars = {},
        timer_interval = 200,
        toggle_key = nil,
        select_signature_key = nil,
        zindex = 200,
        padding = "",
        transparency = nil,
        shadow_blend = 36,
        shadow_guibg = "Black",

        -- デバッグ
        debug = false,
        log_path = vim.fn.stdpath("cache") .. "/lsp_signature.log",
        verbose = false,
      })
    end,
  },
})
