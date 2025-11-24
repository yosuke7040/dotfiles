# substitute.nvim ガイド

レジスタを汚さずに置換・交換ができる画期的なプラグイン。

## プラグイン概要

- **リポジトリ**: [gbprod/substitute.nvim](https://github.com/gbprod/substitute.nvim)
- **機能**: クリップボードの内容でテキストを置換、レジスタが汚れない

## 通常のVimとの問題点

### 従来の置換方法

```javascript
const foo = "old";
const bar = "old";
const baz = "old";
```

**通常のVimでの置換:**
```
1. yiw で"new"をヤンク → レジスタに"new"
2. ciw → Ctrl+r 0 で"old"を"new"に置換
3. ヤンクしたはずの"new"が、削除した"old"で上書き
4. もう一度置換しようとしても、レジスタには"old"しかない
```

**問題点:**
❌ 置換するたびにレジスタが上書き
❌ 同じ内容で複数箇所を置換できない
❌ 毎回ヤンクし直す必要がある

## substitute.nvimの解決策

```lua
yank_substituted_text = false  -- 削除したテキストをレジスタに保存しない
```

これにより、何度置換してもレジスタの内容が保持されます。

## 基本的な使い方

### 置換（Substitute）

#### 1. `s{motion}` - モーションで指定

```javascript
const value = "old";
```

**操作:**
```
1. yiw で"new"をヤンク
2. "old"の上で siw → "new"に置換
```

#### 2. `ss` - 行全体を置換

```javascript
const value = "old";  // この行全体
```

**操作:**
```
yiw ("new") → ss → const value = "new";
```

#### 3. `S` - カーソル位置から行末まで

```javascript
const value = "old";
            ↑ カーソル
```

**操作:**
```
yiw ("new") → S → const value = "new";
```

#### 4. `s` (ビジュアルモード) - 選択範囲を置換

```javascript
const userName = "John";
      ^^^^^^^^ 選択
```

**操作:**
```
yiw ("firstName") → viw → s → const firstName = "John";
```

---

### 交換（Exchange）

2つのテキストを入れ替える強力な機能。

#### 1. `sx{motion}` - 交換対象をマーク

```javascript
function calculate(first, second) {
                   ^^^^^
}
```

**操作:**
```
1. "first"の上で sxiw → マーク
2. "second"の上で sxiw → 交換実行

結果:
function calculate(second, first) {
}
```

#### 2. `sxx` - 行全体を交換

```python
line1 = "first"
line2 = "second"
```

**操作:**
```
1. line1で sxx → マーク
2. line2で sxx → 交換

結果:
line2 = "second"
line1 = "first"
```

#### 3. `X` (ビジュアルモード) - 選択範囲を交換

```go
a, b := getValue()
```

**操作:**
```
1. "a"を選択 → X → マーク
2. "b"を選択 → X → 交換

結果:
b, a := getValue()
```

#### 4. `sxc` - 交換をキャンセル

```
sxiw でマークしたけど、やっぱりやめる
→ sxc でキャンセル
```

---

## 実践例

### 例1: 変数名の一括変更

```go
func processData() {
    oldVar := getData()
    fmt.Println(oldVar)
    return oldVar
}
```

**目的:** `oldVar`を`newVar`に変更

**操作:**
```
1. yiw ("newVar")
2. *oldVar → [1/3]
3. siw → "newVar"
4. n → . → n → .
```

**キーシーケンス:** `yiw` → `*` → `siw` → `n.n.`

---

### 例2: 引数の順序を入れ替え

```typescript
function createUser(email: string, name: string) {
    return { email, name };
}
```

**目的:** 引数の順序を変更

**操作:**
```
1. "email"の上で sxiw → マーク
2. "name"の上で sxiw → 交換

結果:
function createUser(name: string, email: string) {
    return { email, name };  // ここも変える必要あり
}
```

---

### 例3: 代入の左右を入れ替え

```python
x, y = get_coordinates()
```

**目的:** `x`と`y`を入れ替え

**操作:**
```
1. "x"を選択（viw）→ X
2. "y"を選択（viw）→ X

結果:
y, x = get_coordinates()
```

---

### 例4: JSON キーと値の入れ替え

```javascript
const config = {
    timeout: 3000,
    retries: 5
};
```

**目的:** `timeout`を`5`に、`retries`を`3000`に

**操作:**
```
1. "3000"の上で sxiw
2. "5"の上で sxiw

結果:
const config = {
    timeout: 5,
    retries: 3000
};
```

---

## vim-metarepeatとの連携

substitute.nvimの操作は`.`コマンドで繰り返せます。

```javascript
const a = "old";
const b = "old";
const c = "old";
```

**操作:**
```
1. yiw ("new")
2. siw → "new"
3. j → . → "new"
4. j → . → "new"
```

**さらに効率化:** lasteriskと組み合わせ

```
yiw → * → siw → n → . → n → .
```

---

## lasteriskとの最強コンボ

```typescript
interface User {
    userId: number;
    userId: string;  // 間違い
    userId: boolean; // 間違い
}
```

**修正手順:**
```
1. yiw ("id")
2. *userId → [1/3]
3. siw → "id"
4. n → [2/3] → .
5. n → [3/3] → .

結果:
interface User {
    id: number;
    id: string;
    id: boolean;
}
```

---

## 設定の詳細

```lua
require("substitute").setup({
  yank_substituted_text = false,  -- 重要！レジスタを汚さない
  preserve_cursor_position = false,  -- カーソル位置を保持しない
  highlight_substituted_text = {
    enabled = true,  -- 置換したテキストをハイライト
    timer = 500,     -- 500ms間ハイライト表示
  },
})
```

### highlight_substituted_textの効果

置換後、500ms間だけ変更箇所が光ります：
```
siw → "new" に変わる → 一瞬ハイライト → 通常表示
```

これにより、何が変わったか視覚的に確認できます。

---

## キーマッピング一覧

### 置換（Substitute）

| キー | 機能 | 例 |
|-----|------|-----|
| `s{motion}` | モーションで置換 | `siw`, `sip`, `sa"` |
| `ss` | 行全体を置換 | - |
| `S` | 行末まで置換 | - |
| `s` (visual) | 選択範囲を置換 | `viw` → `s` |

### 交換（Exchange）

| キー | 機能 | 例 |
|-----|------|-----|
| `sx{motion}` | テキストをマーク/交換 | `sxiw`, `sxip` |
| `sxx` | 行全体をマーク/交換 | - |
| `X` (visual) | 選択範囲をマーク/交換 | `viw` → `X` |
| `sxc` | 交換をキャンセル | - |

---

## よくある使用パターン

### パターン1: 単語を別の単語に置換

```
yiw → siw
```

### パターン2: 文字列全体を置換

```
yi" → si"
```

### パターン3: 複数箇所を同じ内容で置換

```
yiw → * → siw → n → . → n → .
```

### パターン4: 2つの変数を入れ替え

```
sxiw → (移動) → sxiw
```

---

## トラブルシューティング

### レジスタが汚れる

**原因:** `yank_substituted_text`が`true`になっている

**解決:**
```lua
yank_substituted_text = false
```

### ハイライトが表示されない

**原因:** `highlight_substituted_text.enabled`が`false`

**解決:**
```lua
highlight_substituted_text = {
  enabled = true,
}
```

### 交換がキャンセルできない

**原因:** `sxc`のキーマッピングが設定されていない

**確認:**
```vim
:map sxc
```

---

## 他のプラグインとの組み合わせ

### with lasterisk + hlslens

```
* → [1/5] → siw → n → . → n → .
```
→ 詳細: [search-plugins.md](./search-plugins.md)

### with nvim-surround

```
yiw → siw (置換) → ysiw" (引用符で囲む)
```

### with clever-f

```
fv → siw (置換) → f → . (次も置換)
```

---

## Tips

1. **まずヤンク**: 置換する前に必ずヤンク
2. **レジスタ確認**: `:reg`でレジスタの内容を確認
3. **ハイライトで確認**: 置換後のハイライトで変更箇所を確認
4. **交換は2回**: `sx`は2回押して完了
5. **キャンセル機能**: 間違えたら`sxc`

---

## まとめ

**substitute.nvimの強み:**
- ✅ レジスタが汚れない
- ✅ 同じ内容で複数箇所を置換できる
- ✅ テキストの交換が簡単
- ✅ ドットコマンドで繰り返せる
- ✅ ハイライトで視覚的に確認

**特におすすめの組み合わせ:**
- `lasterisk` + `substitute.nvim` + `vim-metarepeat`

この3つを使いこなせば、リファクタリングが爆速になります。
