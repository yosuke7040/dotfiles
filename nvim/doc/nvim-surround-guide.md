# nvim-surround 使い方ガイド

括弧、引用符、タグなどを効率的に操作できる強力なプラグイン。

## 基本コマンド

### 1. 追加（Add）: `ys{motion}{char}`

テキストを括弧や引用符で囲む。

| コマンド | 説明 | 例 |
|---------|------|-----|
| `ysiw"` | 単語を`"`で囲む | `hello` → `"hello"` |
| `ysiw'` | 単語を`'`で囲む | `hello` → `'hello'` |
| `ysiw)` | 単語を`()`で囲む（スペースなし） | `hello` → `(hello)` |
| `ysiw(` | 単語を`( )`で囲む（スペースあり） | `hello` → `( hello )` |
| `ysiw]` | 単語を`[]`で囲む | `hello` → `[hello]` |
| `ysiw}` | 単語を`{}`で囲む | `hello` → `{hello}` |
| `yss)` | 行全体を`()`で囲む | `const x = 42` → `(const x = 42)` |
| `yss{` | 行全体を`{}`で囲む | `return x` → `{ return x }` |

#### 関数呼び出しで囲む

```
value
↓ ysiwf（関数名を入力: console.log）
console.log(value)
```

### 2. 削除（Delete）: `ds{char}`

囲んでいる括弧や引用符を削除する。

| コマンド | 説明 | 例 |
|---------|------|-----|
| `ds"` | `"`を削除 | `"hello"` → `hello` |
| `ds'` | `'`を削除 | `'hello'` → `hello` |
| `ds)` | `()`を削除 | `(value)` → `value` |
| `ds]` | `[]`を削除 | `[1, 2, 3]` → `1, 2, 3` |
| `ds}` | `{}`を削除 | `{key: value}` → `key: value` |
| `dst` | HTMLタグを削除 | `<div>content</div>` → `content` |

### 3. 変更（Change）: `cs{old}{new}`

囲んでいる括弧や引用符を別のものに変更する。

| コマンド | 説明 | 例 |
|---------|------|-----|
| `cs"'` | `"`を`'`に変更 | `"hello"` → `'hello'` |
| `cs'<q>` | `'`をタグに変更 | `'hello'` → `<q>hello</q>` |
| `cs)]` | `()`を`[]`に変更 | `(value)` → `[value]` |
| `cs]{` | `[]`を`{}`に変更 | `[1, 2]` → `{ 1, 2 }` |
| `cst<div>` | タグを変更 | `<p>text</p>` → `<div>text</div>` |

### 4. ビジュアルモード: `S{char}`

選択した範囲を囲む。

```javascript
// 範囲をビジュアルモードで選択
hello world
^^^^^ ^^^^^ (viw で選択)
↓ S" を実行
"hello world"
```

## 実践例

### JavaScript/TypeScript

```javascript
// 変数を文字列リテラルに変更
const name = userName
           ↓ ysiw"
const name = "userName"

// 配列要素を括弧で囲む
arr.push(item)
        ↓ ysiw[
arr.push([item])

// 括弧を削除
console.log(value)
       ↓ ds)
console.log value

// 関数呼び出しを変更
console.log(value)
       ↓ csf（新しい関数名: JSON.stringify）
JSON.stringify(value)
```

### HTML/JSX

```html
<!-- タグを削除 -->
<div>content</div>
↓ dst
content

<!-- タグを変更 -->
<div>content</div>
↓ cst<p>
<p>content</p>

<!-- テキストをタグで囲む -->
content
↓ ysiw<div>
<div>content</div>
```

### Python

```python
# 文字列の引用符を変更
name = "Alice"
     ↓ cs"'
name = 'Alice'

# リストを括弧で囲む
items = [1, 2, 3]
      ↓ ysiw(
items = ([1, 2, 3])
```

### Go

```go
// 構造体リテラルを括弧で囲む
user := User{Name: "Alice"}
          ↓ ysiw)
user := (User{Name: "Alice"})

// 文字列リテラルを変更
msg := "Hello"
     ↓ cs"`
msg := `Hello`
```

## vim-metarepeatとの組み合わせ

nvim-surroundは`.`（ドット）コマンドで繰り返せるため、複数箇所で同じ操作を効率的に実行できます。

```javascript
const a = value1
const b = value2
const c = value3

// 操作手順
1. value1の上で ysiw"  → "value1"
2. value2の上で .      → "value2"
3. value3の上で .      → "value3"
```

## テキストオブジェクトとの組み合わせ

| コマンド | 説明 |
|---------|------|
| `ysip)` | 段落全体を`()`で囲む |
| `ysa"])` | `]`の中身を`()`で囲む（around） |
| `ysi])` | `]`の中身のみを`()`で囲む（inside） |

## 特殊文字

| 文字 | 説明 |
|-----|------|
| `(` または `)` | 括弧（スペースの有無で動作が異なる） |
| `{` または `}` | 波括弧 |
| `[` または `]` | 角括弧 |
| `<` または `>` | 山括弧またはHTMLタグ |
| `t` | HTMLタグ（`cst`、`dst`で使用） |
| `f` | 関数呼び出し（`ysiwf`で使用） |

## よく使うパターン

### 1. JSONの整形

```javascript
// オブジェクトキーを引用符で囲む
{ name: "Alice" }
  ↓ ysiw"
{ "name": "Alice" }
```

### 2. 条件式を括弧で囲む

```javascript
if x > 0
   ↓ ysiw)
if (x > 0)
```

### 3. 文字列の引用符切り替え

```javascript
const str = "Hello"
          ↓ cs"'
const str = 'Hello'
          ↓ cs'`
const str = `Hello`
```

## トラブルシューティング

### 動作しない場合

1. **プラグインがロードされているか確認**
   ```vim
   :Lazy
   ```
   でnvim-surroundがインストールされているか確認

2. **キーマッピングの競合をチェック**
   ```vim
   :map ys
   ```
   で既存のマッピングを確認

3. **VSCode Neovimの場合**
   - VSCodeを完全に再起動
   - `Ctrl+Shift+P` → "Reload Window"

## リファレンス

- 公式ドキュメント: https://github.com/kylechui/nvim-surround
- `:help nvim-surround` でヘルプを表示
