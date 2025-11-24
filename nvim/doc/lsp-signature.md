# lsp_signature.nvim ガイド

関数を入力中に、シグネチャ（引数情報）をリアルタイムで表示するプラグイン。

## プラグイン概要

- **リポジトリ**: [ray-x/lsp_signature.nvim](https://github.com/ray-x/lsp_signature.nvim)
- **機能**: 関数呼び出し時に引数のヒントをフローティングウィンドウで表示
- **要件**: Neovim 0.10+ とLSP設定

## 問題点と解決策

### 通常のコーディングでの課題

```javascript
fetch(url, options)
//     ↑ ここで何を渡せばいいか忘れた...
```

**従来の確認方法:**
```
1. 関数定義にジャンプ（gd）して確認
2. ドキュメントを見る
3. もう一度元の場所に戻る
```

**問題点:**
❌ 作業の流れが中断される
❌ 引数の順序や型を覚えておく必要がある
❌ オプション引数の確認が面倒

### lsp_signature.nvimの解決策

```javascript
fetch(
//     ↓ カーソル位置で自動的にヒントが表示される
// ┌─────────────────────────────────────┐
// │ fetch(url: string, options?: {      │
// │   method?: string,                  │
// │   headers?: Record<string, string>  │
// │ }): Promise<Response>               │
// └─────────────────────────────────────┘
```

**改善点:**
✅ 入力中にリアルタイムでシグネチャを表示
✅ 現在のパラメータがハイライト
✅ 複数のオーバーロードにも対応
✅ 作業の流れを中断しない

## 基本的な使い方

### 1. 関数呼び出し時の自動表示

```go
func ProcessUser(id int, name string, options UserOptions) error {
    // ...
}

// 使用時
ProcessUser(
//          ↑ カーソルがここに来ると自動的にシグネチャが表示される
```

**表示される内容:**
```
┌──────────────────────────────────────────────┐
│ ProcessUser(id: int, name: string,           │
│              options: UserOptions) error     │
│                                              │
│ id: ユーザーID                                │
│ name: ユーザー名                              │
│ options: 処理オプション                        │
└──────────────────────────────────────────────┘
```

### 2. パラメータハイライト

```typescript
function createUser(email: string, name: string, age: number) {
    // ...
}

createUser("test@example.com",
//                             ↑ カーソル位置
```

**表示:**
```
createUser(email: string, name: string, age: number)
                          ^^^^^^^^^^^^^ ← 現在のパラメータがハイライト
```

### 3. 仮想テキストヒント

```python
def calculate(x: int, y: int, operation: str = "add") -> int:
    pass

calculate(10,
#            ↑ 仮想テキスト: 🐼 y: int, operation: str = "add"
```

### 4. 複数のオーバーロード

```typescript
// 関数に複数のシグネチャがある場合
function parse(data: string): Object;
function parse(data: Buffer): Object;
function parse(data: Array<number>): Object;

parse(
// ← 3つのシグネチャから選択可能（Ctrl+nで切り替え）
```

## 表示されるシグネチャの種類

### 関数の引数情報

```javascript
fetch(url, options)
//    ↓ 表示される
// fetch(url: string, options?: RequestInit): Promise<Response>
```

### メソッドチェーン

```javascript
array
  .filter(x => x > 0)
  .map(
//     ↓ 表示される
// map<U>(callbackfn: (value: number, index: number, array: number[]) => U): U[]
```

### コンストラクタ

```typescript
new Date(
//       ↓ 表示される
// Date(year: number, month: number, date?: number, hours?: number, ...)
```

### ジェネリック関数

```go
func Map[T, U any](items []T, fn func(T) U) []U {
    // ...
}

Map(numbers,
//           ↓ 表示される
// Map[int, string](items: []int, fn: func(int) string) []string
```

## 実践例

### 例1: REST APIの呼び出し

```javascript
async function fetchUser(userId, options) {
    // fetch関数を使う
    const response = await fetch(
        // ↓ シグネチャが表示される
        // fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>
        `/api/users/${userId}`,
        {
            // ↓ optionsの中身でもシグネチャが表示される
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        }
    );
}
```

### 例2: データベースクエリ

```go
// クエリ関数
func Query(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
    // ...
}

// 使用時
rows, err := Query(
    // ↓ シグネチャ表示
    // Query(ctx: context.Context, query: string, args: ...interface{}) (*sql.Rows, error)
    ctx,
    "SELECT * FROM users WHERE id = ? AND status = ?",
    userId,
    "active",
    // ↑ 各引数の意味が明確
)
```

### 例3: 複雑な設定オブジェクト

```typescript
interface ServerConfig {
    host: string;
    port: number;
    ssl?: {
        cert: string;
        key: string;
    };
    timeout?: number;
}

function createServer(config: ServerConfig) {
    // ...
}

createServer({
    // ↓ 各フィールドを入力するたびにヒントが表示される
    host: "localhost",
    port: 8080,
    ssl: {
        cert:
        // ↓ ssl.certのヒント: string
    }
})
```

### 例4: 高階関数

```python
def retry(func: Callable, max_attempts: int = 3, delay: float = 1.0) -> Any:
    """関数を指定回数リトライする"""
    pass

# 使用時
retry(
    # ↓ シグネチャ表示
    # retry(func: Callable, max_attempts: int = 3, delay: float = 1.0) -> Any
    fetch_data,
    max_attempts=5,
    #            ↑ パラメータ名もヒントに表示
    delay=2.0
)
```

## 設定のカスタマイズ

### ウィンドウの外観変更

```lua
require("lsp_signature").setup({
  handler_opts = {
    border = "single"  -- "rounded", "double", "shadow"から選択
  },
  max_width = 120,     -- より広いウィンドウ
  max_height = 20,     -- より高いウィンドウ
})
```

### ヒントのプレフィックス変更

```lua
require("lsp_signature").setup({
  hint_enable = true,
  hint_prefix = "📝 ",  -- アイコンを変更
  -- または hint_prefix = "→ ",  -- シンプルな矢印
})
```

### 表示タイミングの調整

```lua
require("lsp_signature").setup({
  always_trigger = true,   -- 常に表示（デフォルト: false）
  close_timeout = 2000,    -- 2秒後に自動で閉じる
  floating_window_above_cur_line = false,  -- カーソルの下に表示
})
```

### トグルキーの設定

```lua
require("lsp_signature").setup({
  toggle_key = "<C-k>",          -- Ctrl+kでシグネチャのトグル
  select_signature_key = "<C-n>", -- Ctrl+nで次のシグネチャへ
})
```

**使用例:**
```
Ctrl+k → シグネチャを手動で表示/非表示
Ctrl+n → 複数のオーバーロードを切り替え
```

## 他のプラグインとの組み合わせ

### with im-select.nvim

```javascript
// 日本語コメントから英語入力に自動切り替わる
fetch(
//    ↑ ここで日本語入力のまま引数を入力しようとしても、
//      im-select.nvimが英数入力に切り替えてくれる
```

### with nvim-cmp（補完プラグイン）

```typescript
createUser(
//         ↓ 補完候補とシグネチャヒントが同時に表示される
//         email: "t..." ← 補完候補
//
//         createUser(email: string, ...) ← シグネチャヒント
```

### with clever-f

```go
ProcessUser(userId,
//                  ↑ clever-fでuserNameへ移動
//                  ↓ シグネチャは継続して表示
```

## VSCode Neovimでの動作について

### 重要：VSCode Neovimでは動作しません（無効化推奨）

**結論:**
- ❌ **VSCode Neovim**: プラグインは**動作しません**（このdotfilesでは無効化済み）
- ✅ **ターミナル版Neovim**: 完全に動作します

### なぜVSCode Neovimで動かないのか

**技術的な理由:**

1. **フローティングウィンドウの非対応**
   - VSCode NeovimはNeovimの機能をVSCodeのUI上で再現する拡張機能
   - Neovimの`nvim_open_win()`（フローティングウィンドウAPI）がVSCode側に実装されていない
   - 公式ドキュメントにも「独自のUIを提供するプラグインはサポートされない」と明記

2. **仮想テキストも不安定**
   - VSCode Neovimは仮想テキスト（extmarks）のサポートが限定的
   - インサートモード中のUIプラグインに制約がある
   - `nvim_win_set_cursor: Invalid window id`などのエラーが発生

3. **実用上の問題**
   - プラグインをロードしてもエラーが発生する
   - 表示されない、または動作が不安定
   - VSCodeのネイティブ機能の方が確実

### このdotfilesでの設定

**VSCode環境では自動的に無効化されています：**

```lua
{
  "ray-x/lsp_signature.nvim",
  cond = not vim.g.vscode,  -- VSCode環境では読み込まない
  event = "InsertEnter",
  config = function()
    -- ターミナルNeovim用の設定のみ
    require("lsp_signature").setup({
      floating_window = true,
      -- その他の設定...
    })
  end,
}
```

**VSCodeでは代わりにネイティブ機能を使用します。**

### VSCodeのネイティブ機能（推奨）

**VSCodeのパラメータヒント:**
- `Ctrl+Shift+Space` で手動表示
- VSCodeの設定で自動表示も可能
- フローティングウィンドウで表示される
- エラーなく安定して動作

**設定方法（VSCode settings.json）:**
```json
{
  "editor.parameterHints.enabled": true,
  "editor.inlayHints.enabled": "on"
}
```

### 動作する機能の比較

| 機能 | ターミナルNeovim | VSCode Neovim | VSCodeネイティブ |
|-----|-----------------|---------------|-----------------|
| フローティングウィンドウ | ✅ 完全動作 | ❌ 動作しない | ✅ 動作 |
| 仮想テキストヒント | ✅ 動作 | ❌ 不安定/エラー | ✅ Inlay Hints |
| パラメータハイライト | ✅ 動作 | ❌ 動作しない | ✅ 動作 |
| 複数シグネチャ切り替え | ✅ 動作 | ❌ 動作しない | ✅ 動作 |
| 安定性 | ✅ 安定 | ❌ エラー発生 | ✅ 安定 |

### VSCode環境での推奨アプローチ

**ベストプラクティス:**
1. lsp_signature.nvimは無効化（このdotfilesでは既に無効化済み）
2. VSCodeのネイティブなパラメータヒント機能を使用
3. `Ctrl+Shift+Space`で手動表示、または自動表示を有効化

## トラブルシューティング

### VSCode Neovimでシグネチャが表示されない

**これは正常です。**

このdotfilesでは、VSCode環境で**lsp_signature.nvimは自動的に無効化**されています。理由：

1. VSCode Neovimでは動作が不安定（`nvim_win_set_cursor: Invalid window id`エラー）
2. フローティングウィンドウも仮想テキストも正しく動作しない
3. VSCodeのネイティブ機能の方が確実で安定している

**代わりにVSCodeのネイティブ機能を使ってください：**

1. **手動表示**: `Ctrl+Shift+Space` でパラメータヒントを表示
2. **自動表示を有効化**: VSCodeの設定で以下を追加
   ```json
   {
     "editor.parameterHints.enabled": true
   }
   ```

**プラグインが無効化されているか確認：**
```vim
:Lazy
```
を実行して、lsp_signature.nvimが**リストに表示されない**ことを確認してください。表示されないのが正常です。

### ターミナルNeovimでシグネチャが表示されない

1. **LSPが動作していない**
   ```vim
   :LspInfo
   ```
   でLSPの状態を確認

2. **プラグインがロードされていない**
   ```vim
   :Lazy
   ```
   でlsp_signature.nvimを確認（ターミナルNeovimでは表示されるはず）

3. **挿入モードで試す**
   - シグネチャはインサートモード時のみ表示
   - 関数の`(`を入力した直後に表示

### nvim_win_set_cursor エラーが出る

このエラーは、VSCode環境でlsp_signature.nvimが動作しようとして失敗している証拠です。

**解決方法：**
1. VSCodeを完全に再起動
2. `:Lazy`でlsp_signature.nvimが**表示されない**ことを確認
3. 表示される場合は、設定ファイルが正しく読み込まれていない可能性

### フローティングウィンドウが見づらい（ターミナルNeovimのみ）

```lua
require("lsp_signature").setup({
  handler_opts = {
    border = "double"  -- ボーダーを変更
  },
  transparency = 10,   -- 透明度を調整
})
```

### 表示が遅い

```lua
require("lsp_signature").setup({
  timer_interval = 100,  -- 更新間隔を短く（デフォルト: 200）
})
```

### 複数のシグネチャが切り替わらない

```lua
require("lsp_signature").setup({
  select_signature_key = "<C-n>",  -- 切り替えキーを設定
})
```

## 対応言語

lsp_signature.nvimはLSPを使用するため、LSPサーバーがある言語なら全て対応:

| 言語 | LSPサーバー | 対応状況 |
|-----|------------|---------|
| Go | gopls | ✅ 完全対応 |
| TypeScript/JavaScript | tsserver | ✅ 完全対応 |
| Python | pyright/pylsp | ✅ 完全対応 |
| Rust | rust-analyzer | ✅ 完全対応 |
| C/C++ | clangd | ✅ 完全対応 |
| Java | jdtls | ✅ 完全対応 |
| C# | omnisharp | ✅ 完全対応 |

## よくある使用パターン

### パターン1: 関数シグネチャの確認

```
1. 関数名を入力
2. ( を入力 → シグネチャが自動表示
3. 引数を入力しながらヒントを見る
```

### パターン2: オーバーロードの選択

```
1. 関数名を入力
2. ( を入力 → シグネチャ表示
3. Ctrl+n で次のオーバーロードへ
4. 適切なシグネチャを見つける
```

### パターン3: ドキュメントの確認

```
1. 関数の引数を入力中
2. シグネチャのドキュメント部分を読む
3. K（hover）で詳細を確認
```

## Tips

1. **シグネチャは自動表示**: `(`を入力すると自動的に表示される
2. **Kでホバー**: さらに詳しい情報は`K`でホバー表示
3. **仮想テキストヒント**: 行末に軽量なヒントが表示される
4. **複数のシグネチャ**: オーバーロードがある場合は切り替えキーで選択
5. **作業の流れを維持**: 定義にジャンプせずに引数情報を確認できる

## まとめ

**lsp_signature.nvimの強み:**
- ✅ 関数の引数情報をリアルタイムで表示
- ✅ 現在のパラメータを自動ハイライト
- ✅ 複数のオーバーロードに対応
- ✅ 作業の流れを中断しない
- ✅ LSPがある言語なら全て使える

**特におすすめのシーン:**
- 複雑なAPIを使う時
- 引数が多い関数を呼び出す時
- オプション引数の確認
- 型情報の確認

**VSCode Neovimでの注意:**
- フローティングウィンドウは制限あり
- 仮想テキストヒントの使用を推奨
- VSCodeのネイティブ機能と併用

lsp_signature.nvimは、コーディング中に関数のシグネチャを常に確認できるため、APIドキュメントを開く頻度が大幅に減り、開発効率が向上します。

## 参考リンク

- [GitHub - ray-x/lsp_signature.nvim](https://github.com/ray-x/lsp_signature.nvim)
- [Neovim LSP Documentation](https://neovim.io/doc/user/lsp.html)
