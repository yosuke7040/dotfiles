# lasterisk & hlslens ガイド

検索操作を強化する2つのプラグインの組み合わせで、快適な検索・置換ワークフローを実現。

## プラグイン概要

### lasterisk.nvim
- **リポジトリ**: [rapan931/lasterisk.nvim](https://github.com/rapan931/lasterisk.nvim)
- **機能**: `*`で検索してもカーソルが動かない

### nvim-hlslens
- **リポジトリ**: [kevinhwang91/nvim-hlslens](https://github.com/kevinhwang91/nvim-hlslens)
- **機能**: 検索結果の数と現在位置を表示

## 通常のVimとの違い

### 通常のVimの`*`検索

```javascript
const userName = "John";  // ← カーソル
const userName = "Jane";
const userName = "Bob";

* を押すと...
const userName = "John";
const userName = "Jane";  // ← ここにジャンプ（勝手に移動！）
const userName = "Bob";
```

**問題点:**
- カーソルが次の一致箇所に勝手に移動
- 現在位置を見失う
- 何個マッチしたかわからない

### lasterisk + hlslensの場合

```javascript
const userName = "John";  // ← カーソル（ここに留まる）
const userName = "Jane";  // ハイライト
const userName = "Bob";   // ハイライト

* を押すと...
[1/3] と表示（現在位置と総数）
```

**改善点:**
✅ カーソ ルは動かない
✅ 全ての一致箇所がハイライト
✅ `[1/3]`のように総数が見える
✅ `n`で次へ、`N`で前へ移動

## 基本的な使い方

### 単語検索

```go
func getUserName() string {
    userName := getUser()
    return userName
}
```

**操作:**
```
1. "userName"の上で * を押す
   → [1/2] と表示、全ての"userName"がハイライト
2. n を押す
   → [2/2] 次の"userName"へ移動
3. N を押す
   → [1/2] 前の"userName"へ戻る
```

### 部分マッチ検索（`g*`）

```javascript
const user = getUser();
const userName = getUserName();
const userEmail = getUserEmail();
```

**`*`の場合（完全一致）:**
```
"user"の上で * → "user"のみマッチ（userName等は除外）
```

**`g*`の場合（部分マッチ）:**
```
"user"の上で g* → user, userName, userEmail 全てマッチ
```

## 連携による強力なワークフロー

### with substitute.nvim + vim-metarepeat

**シナリオ: 変数名の一括変更**

```javascript
const oldName = "John";
console.log(oldName);
return oldName;
```

**操作:**
```
1. yiw で"newName"をヤンク（別の場所で）
2. "oldName"の上で * を押す
   → [1/3] 全ての"oldName"がハイライト
3. siw で置換
   → "newName"に変わる、レジスタは汚れない
4. n で次へ移動
   → [2/3]
5. . で繰り返し
   → "newName"に変わる
6. n → .
   → [3/3] 最後の"oldName"も変更
```

**キーシーケンス:**
```
yiw → * → siw → n → . → n → .
```

### ビジュアルモードでの検索

```python
# 選択した文字列を検索
error_message = "Connection failed"
```

**操作:**
```
1. "Connection failed"を範囲選択（viw等）
2. * を押す
   → 選択したテキストで検索
```

## hlslensの詳細機能

### 検索カウント表示

```
[1/5]  : 1番目/全5箇所
[3/5]  : 3番目/全5箇所
[5/5]  : 最後の箇所
```

### 自動消去機能

```lua
calm_down = true  -- 一定時間後に自動で表示が消える
```

- 検索後、数秒で`[1/5]`表示が自動的に消える
- 画面がすっきり保たれる

### ハイライトクリア

```
Esc を押す → 検索ハイライトを解除
```

## 実践例

### 例1: APIエンドポイントの一括変更

```javascript
fetch('/api/users');
axios.get('/api/users');
const url = '/api/users';
```

**目的:** `/api/users`を`/api/v2/users`に変更

```
1. '/api/users'を選択
2. * → [1/3]
3. ci' で'/api/v2/users'と入力
4. n → . → n → .
```

### 例2: エラーハンドリングの確認

```go
err := doSomething()
if err != nil {
    return err
}
log.Error(err)
```

**目的:** `err`の使用箇所を全て確認

```
1. "err"の上で * → [1/3]
2. n → [2/3] if文の"err"を確認
3. n → [3/3] log.Error の"err"を確認
```

### 例3: 型名の出現箇所を確認

```typescript
interface User {
    name: string;
}

function getUser(): User {
    const user: User = fetchUser();
    return user;
}
```

**操作:**
```
"User"の上で * → [1/3]
n で全ての"User"を巡回して確認
```

## 設定の詳細

### lasterisk の設定

```lua
-- 完全一致検索
vim.keymap.set('n', '*', function() require("lasterisk").search() end)

-- 部分一致検索
vim.keymap.set('n', 'g*', function() require("lasterisk").search({ is_whole = false }) end)
```

**`is_whole`オプション:**
- `true` (デフォルト): 単語境界を考慮（`\<word\>`）
- `false`: 部分マッチ

### hlslens の設定

```lua
require('hlslens').setup({
  calm_down = true,  -- 自動消去
  nearest_only = false,  -- 全ての結果を表示
  nearest_float_when = 'auto',  -- 表示タイミング
})
```

## キーマッピング一覧

| キー | 機能 | プラグイン |
|-----|------|-----------|
| `*` | カーソル下の単語を検索（完全一致） | lasterisk |
| `#` | カーソル下の単語を逆方向検索 | lasterisk |
| `g*` | カーソル下の単語を検索（部分一致） | lasterisk |
| `g#` | カーソル下の単語を逆方向検索（部分一致） | lasterisk |
| `n` | 次の検索結果へ（カウント表示） | hlslens |
| `N` | 前の検索結果へ（カウント表示） | hlslens |
| `Esc` | 検索ハイライトをクリア | hlslens |

## 他のプラグインとの組み合わせ

### with clever-f

```javascript
const userName = getUserName();

// ワークフロー
1. * で"userName"を検索 → 全体を把握
2. n で次へ移動
3. fu で"U"へ細かく移動 → clever-fで調整
```

### with vim-edgemotion

```go
func processUser() {  // ← ここから
    user := getUser()
    // ...
}  // ← ここまで

func validateUser() {
    // ...
}

// ワークフロー
1. * で"user"を検索
2. Ctrl+j で次の関数へエッジ移動
3. n で次の"user"へ
```

## よくある使用パターン

### パターン1: 変数の使用箇所を確認

```
* → n → n → n → ...
```

### パターン2: 一部だけ置換

```
* → n → siw → n → スキップ → n → siw
```

### パターン3: 検索結果の数を確認

```
* → [1/10] を見る → Esc
```

## トラブルシューティング

### カウント表示が出ない

1. **hlslensがロードされているか確認**
   ```vim
   :Lazy
   ```

2. **手動で起動**
   ```vim
   :lua require('hlslens').start()
   ```

### lasteriskでカーソルが動く

1. **設定を確認**
   - `vscode_plugins.lua`のlasterisk設定を確認

2. **キーマッピングの競合**
   - `:map *`で既存マッピングを確認

### 検索ハイライトが消えない

```
Esc を押す
```

または
```vim
:noh
```

## Tips

1. **まず`*`で全体を把握**: 変更前に全体像を確認
2. **`g*`で関連変数も検索**: `user`で`userName`も含めて検索
3. **カウント表示で進捗確認**: `[3/10]`を見ながら作業
4. **`Esc`でクリア**: 作業後は必ずハイライトを消す

## まとめ

**lasterisk + hlslensの強み:**
- ✅ 検索してもカーソルが動かない
- ✅ 検索結果の総数がわかる
- ✅ 現在位置が一目でわかる
- ✅ substitute.nvimとの相性抜群

この組み合わせにより、従来の`:s///g`による一括置換よりも、視覚的に確認しながら安全に置換できます。
