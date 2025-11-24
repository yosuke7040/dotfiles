# im-select.nvim ガイド

Neovimのモード切り替え時に、IME（入力メソッド）を自動で切り替えるプラグイン。

## プラグイン概要

- **リポジトリ**: [keaising/im-select.nvim](https://github.com/keaising/im-select.nvim)
- **機能**: ノーマルモード時は英数入力、インサートモード時は前回の入力方式に自動切り替え
- **依存**: `im-select`コマンド（別途インストールが必要）

## 問題点と解決策

### 通常のVimでの日本語入力の問題

```markdown
これは日本語のテキストです。
```

**シナリオ:**
```
1. iで挿入モード → 日本語入力で「これは」と入力
2. Escでノーマルモードへ → 日本語入力のまま
3. jjと押したつもりが「じじ」と入力される
4. 手動でIMEを切り替える必要がある（ストレス！）
```

**問題点:**
❌ Escを押しても日本語入力が残る
❌ ノーマルモードのコマンドが効かない
❌ 毎回手動でIMEを切り替える必要がある

### im-select.nvimの解決策

```markdown
これは日本語のテキストです。
```

**シナリオ:**
```
1. iで挿入モード → 日本語入力で「これは」と入力
2. Escでノーマルモードへ → 自動的に英数入力に切り替わる
3. jjで2行下へ移動（正常に動作）
4. iで再び挿入モードへ → 自動的に日本語入力に戻る
```

**改善点:**
✅ Escで自動的に英数入力に切り替わる
✅ ノーマルモードのコマンドが確実に効く
✅ 挿入モードに戻ると前回の入力方式に戻る
✅ 手動切り替え不要

## インストール

### 1. im-selectコマンドのインストール

**macOS:**
```bash
brew tap daipeihust/tap
brew install im-select
```

**インストール確認:**
```bash
im-select
```

出力例（現在の入力ソースを表示）:
```
com.apple.keylayout.ABC
```

### 2. 利用可能な入力ソースの確認

```bash
im-select
```

**よく使う入力ソース:**
- `com.apple.keylayout.ABC` - 英数入力（U.S.）
- `com.apple.keylayout.US` - 英語（U.S.）
- `com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese` - 日本語（ローマ字入力）
- `com.apple.inputmethod.Kotoeri.Katakana` - カタカナ入力

### 3. im-select.nvimの設定

```lua
{
  "keaising/im-select.nvim",
  config = function()
    require("im_select").setup({
      default_im_select = "com.apple.keylayout.ABC",  -- ノーマルモードで使う入力ソース
      default_command = "im-select",  -- コマンド名
      set_default_events = { "VimEnter", "FocusGained", "InsertLeave", "CmdlineLeave" },
      set_previous_events = { "InsertEnter" },
    })
  end,
}
```

## 基本的な使い方

### 日本語ドキュメントの編集

```markdown
# タイトル

これは日本語のドキュメントです。
```

**ワークフロー:**
```
1. ノーマルモードで移動（jjkk、fなど）→ 英数入力
2. i で挿入モード → 自動的に日本語入力に
3. 「説明を追加」と入力
4. Esc → 自動的に英数入力に
5. yy でヤンク（正常に動作）
```

### コード内のコメント編集

```go
// ユーザー情報を取得
func GetUser() {
    // データベースから取得
    return user
}
```

**ワークフロー:**
```
1. /ユーザー で検索 → 見つかる（英数入力のまま日本語検索可能）
2. A でコメント追加モード → 自動的に日本語入力に
3. 「してDBに保存」と追加
4. Esc → 英数入力に戻る
5. j で次の行へ移動
```

## 動作の詳細

### モード別のIME状態

| モード | IME状態 |
|--------|---------|
| ノーマルモード | 英数入力（ABC） |
| 挿入モード | 前回の入力方式 |
| ビジュアルモード | 英数入力（ABC） |
| コマンドラインモード | 英数入力（ABC） |

### イベントトリガー

**英数入力に切り替わるタイミング:**
- `VimEnter` - Neovim起動時
- `FocusGained` - ウィンドウフォーカス時
- `InsertLeave` - 挿入モード終了時
- `CmdlineLeave` - コマンドライン終了時

**前回の入力方式に戻るタイミング:**
- `InsertEnter` - 挿入モード開始時

## 実践例

### 例1: マークダウンドキュメントの編集

```markdown
# VSCode Neovim プラグイン

このドキュメントでは、VSCode Neovimの設定について説明します。

## インストール
```

**ワークフロー:**
```
1. j で「このドキュメント」の行へ移動（英数入力）
2. A で行末に移動して挿入モード → 日本語入力に自動切り替え
3. 「詳しく」と追加入力
4. Esc → 英数入力に戻る
5. o で新しい行を作成 → 日本語入力に戻る
6. 「以下のセクションを参照してください。」と入力
7. Esc → 英数入力に戻る
```

### 例2: Goのコメント編集

```go
type User struct {
    ID   int
    Name string
}
```

**ワークフロー:**
```
1. O で上に新しい行を作成 → 日本語入力に
2. 「ユーザー情報を表す構造体」と入力
3. Esc → 英数入力に
4. cc で行を編集 → 日本語入力に
5. 「// ユーザー情報を表す構造体」と修正
6. Esc → 英数入力に
```

### 例3: コミットメッセージの作成

```
git commit
```

**エディタが開く:**
```


# Please enter the commit message...
```

**ワークフロー:**
```
1. i で挿入モード → 日本語入力に
2. 「ユーザー認証機能を追加」と入力
3. Enter → 空行
4. Enter → 詳細行へ
5. 「ログイン・ログアウト・セッション管理を実装」と入力
6. Esc → 英数入力に
7. :wq で保存
```

## 他のプラグインとの組み合わせ

### with nvim-surround

```markdown
この機能は**重要**です。
```

**ワークフロー:**
```
1. f重 で「重要」へ移動（clever-f、英数入力）
2. ysiw* → **重要** がマークダウン太字に
3. A で行末へ → 日本語入力に自動切り替え
4. 「設定してください」と追加
5. Esc → 英数入力に
```

### with substitute.nvim

```markdown
古い情報
古い情報
古い情報
```

**ワークフロー:**
```
1. i で挿入モード → 日本語入力に
2. 「新しい情報」と入力
3. Esc → 英数入力に
4. yiw でヤンク
5. *古い → 検索（英数入力のまま日本語検索）
6. siw で置換 → 「新しい情報」
7. n → . → n → . で繰り返し
```

### with clever-f

```markdown
このプラグインは高速な移動を実現します。
```

**ワークフロー:**
```
1. f高 で「高速」へ移動（英数入力のまま日本語文字へ移動可能）
2. ciw で単語変更 → 日本語入力に
3. 「効率的」と入力
4. Esc → 英数入力に
```

## 設定のカスタマイズ

### デフォルトの入力ソースを変更

```lua
require("im_select").setup({
  default_im_select = "com.apple.keylayout.US",  -- US配列を使う場合
})
```

### 特定のイベントを無効化

```lua
require("im_select").setup({
  default_im_select = "com.apple.keylayout.ABC",
  set_default_events = { "InsertLeave" },  -- InsertLeave時のみ切り替え
  set_previous_events = {},  -- 自動復帰を無効化
})
```

### 複数の入力ソースを使い分け

```lua
-- プロジェクトごとに設定を変える（init.luaで条件分岐）
if vim.fn.getcwd():match("japanese%-docs") then
  require("im_select").setup({
    default_im_select = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
  })
else
  require("im_select").setup({
    default_im_select = "com.apple.keylayout.ABC",
  })
end
```

## トラブルシューティング

### IMEが自動で切り替わらない

1. **im-selectコマンドが見つからない**
   ```bash
   which im-select
   ```
   出力がない場合 → `brew install im-select`

2. **パスが通っていない**
   ```lua
   require("im_select").setup({
     default_command = "/opt/homebrew/bin/im-select",  -- フルパス指定
   })
   ```

3. **プラグインがロードされていない**
   ```vim
   :Lazy
   ```
   でim-select.nvimを確認

### 入力ソース名がわからない

```bash
# 現在の入力ソースを確認
im-select

# 入力ソースを切り替えて再度確認
im-select
```

各入力ソースに切り替えて、そのたびに`im-select`を実行すると名前がわかります。

### VSCodeで動作しない

VSCode Neovimでは、一部の環境で正常に動作しない場合があります：
- VSCode自体のIME管理が優先される場合がある
- ターミナル版Neovimでは正常に動作

**回避策:**
- VSCodeの設定で`"keyboard.dispatch": "keyCode"`を試す
- または純粋なNeovimを使う

### 挿入モードに戻っても日本語にならない

```lua
-- set_previous_events が正しく設定されているか確認
require("im_select").setup({
  set_previous_events = { "InsertEnter" },  -- これが必要
})
```

## 使用上のコツ

### コツ1: 日本語検索も英数入力のまま

ノーマルモードでは英数入力なので：
```
/日本語 → Enterで検索できる
```
わざわざIMEを切り替える必要なし。

### コツ2: 挿入モードの入力方式は記憶される

前回日本語入力で終了した場合、次回の挿入モードも日本語入力から始まる。

### コツ3: コマンドラインモードも英数

`:s/old/new/`などのコマンドも英数入力で実行できる。

## まとめ

**im-select.nvimの強み:**
- ✅ Escで自動的に英数入力に切り替わる
- ✅ ノーマルモードのコマンドが確実に効く
- ✅ 挿入モードでは前回の入力方式に戻る
- ✅ 日本語ドキュメント編集のストレスが激減

**特におすすめのシーン:**
- マークダウンドキュメントの編集
- コード内の日本語コメント編集
- コミットメッセージの作成
- 日英混在のテキスト編集

**注意点:**
- `im-select`コマンドのインストールが必須
- VSCode Neovimでは環境により動作が不安定な場合がある
- macOS専用（他OSでは別のツールが必要）

im-select.nvimは、日本語と英語を頻繁に切り替える作業において、圧倒的にストレスを減らしてくれるプラグインです。一度使い始めると、手放せなくなるでしょう。
