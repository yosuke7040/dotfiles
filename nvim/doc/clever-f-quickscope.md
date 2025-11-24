# clever-f & quick-scope ガイド

`f`/`F`/`t`/`T`による文字移動を劇的に強化する2つのプラグインの組み合わせ。

## プラグイン概要

### clever-f
- **リポジトリ**: [rhysd/clever-f.vim](https://github.com/rhysd/clever-f.vim)
- **機能**: `f`の後、続けて`f`/`F`を押すだけで次/前の文字へ移動できる

### quick-scope
- **リポジトリ**: [unblevable/quick-scope](https://github.com/unblevable/quick-scope)
- **機能**: `f`を押したときにターゲット文字をハイライト表示

## 基本的な使い方

### clever-fの基本操作

```
const userName = getUserName();
     ↑ カーソル

1. fN を押す → "N"にジャンプ
2. f を押す → 次の"N"にジャンプ（リピート）
3. F を押す → 前の"N"に戻る
```

**通常のVimとの違い:**
- 通常: `;`で次へ、`,`で前へ
- clever-f: `f`で次へ、`F`で前へ（直感的！）

### quick-scopeの動作

```
const userName = getUserName();

f を押すと...
      ^^      ^^^
      ピンク   黄色

ピンク = 1回の入力で到達可能
黄色  = 2回目の同じ文字
```

## 連携による強力なワークフロー

### シナリオ1: コード内の変数名を追跡

```javascript
function processUser() {
  const user = getUser();
  validateUser(user);
  saveUser(user);
  return user;
}
```

**操作:**
```
1. fu を押す → quick-scopeが全ての"u"をハイライト
2. u を入力 → 最初の"user"にジャンプ
3. f を連打 → 次々と"user"にジャンプ
```

### シナリオ2: 括弧の対応を確認

```go
func Calculate(a, b int) (int, error) {
   return (a + b), nil
}
```

**操作:**
```
1. f( を押す → 全ての"("がハイライト
2. ( を入力 → 最初の"("へ
3. f → 次の"("へ
4. F → 前の"("へ戻る
```

## 設定の詳細

### clever-f の設定

```lua
vim.g.clever_f_across_no_line = 0  -- 行をまたいで検索
vim.g.clever_f_smart_case = 1      -- スマートケース
vim.g.clever_f_fix_key_direction = 0  -- 方向を固定しない
```

**スマートケースの動作:**
- `fa` → "a"と"A"の両方にマッチ
- `fA` → "A"のみにマッチ

### quick-scope の設定

```lua
vim.g.qs_highlight_on_keys = {'f', 'F', 't', 'T'}  -- トリガーキー
vim.g.qs_max_chars = 150  -- 最大ハイライト数
```

**ハイライトカラー:**
- Primary（ピンク `#ff0058`）: 下線
- Secondary（黄色 `#ffff00`）: 下線

## 実践例

### 例1: 関数名の途中へジャンプ

```python
def calculate_user_statistics(user_data, filter_options):
    pass
```

**目的:** "statistics"の"s"へ移動

```
1. fs を押す → quick-scopeが全ての"s"を表示
2. s を入力 → "statistics"の最初の"s"へ
```

### 例2: 文字列内の特定文字へ

```javascript
const message = "Error: Failed to connect to database";
```

**目的:** "Failed"の"F"へ移動

```
1. fF を押す → "F"がハイライト
2. F を入力 → "Failed"へジャンプ
```

### 例3: 複数行にまたがる検索

```go
type User struct {
    Name  string
    Email string
    Age   int
}
```

**目的:** 全ての"string"を確認

```
1. fs を押す → 全ての"s"がハイライト
2. s → 最初の"string"へ
3. f → 次の"string"へ
4. f → さらに次へ（行をまたいで移動）
```

## tとTの使い方

`f`は文字の上に、`t`は文字の手前に移動します。

### fとtの違い

```
hello world
     ↑ fw → "w"の上
    ↑ tw → "w"の手前
```

**使い分け:**
- `f`: 文字を削除したい、文字から編集を始めたい
- `t`: 文字の直前にテキストを挿入したい

### 実践例: 引数の前にカンマを追加

```javascript
function add(a b) {  // カンマが抜けている
}

// 操作: tb → i, → Esc
function add(a, b) {
}
```

## トラブルシューティング

### quick-scopeのハイライトが見えない

1. **カラーが薄すぎる場合**
   - `vscode_plugins.lua`の`guisp`設定を確認
   - より目立つ色に変更可能

2. **そもそも表示されない場合**
   - VSCodeを再起動
   - `:hi QuickScopePrimary`で設定を確認

### clever-fが動作しない

1. **`f`を押しても通常の動作になる**
   - プラグインがロードされているか`:Lazy`で確認
   - 他のキーマッピングと競合していないか確認

2. **行をまたがない**
   - `vim.g.clever_f_across_no_line`を`0`に設定

## 他のプラグインとの組み合わせ

### with vim-metarepeat

```javascript
const foo1 = "value";
const foo2 = "value";
const foo3 = "value";

// 全ての"value"を"result"に変更
1. yiw で"result"をヤンク
2. fv → v → siw で最初を置換
3. f → . → f → . で残りを置換
```

### with nvim-surround

```javascript
hello world

// "world"を引用符で囲む
1. fw → w へジャンプ
2. ysiw" → "world"
```

## キーマッピング一覧

| キー | 機能 | 備考 |
|-----|------|------|
| `f{char}` | 文字へ前方ジャンプ | quick-scopeでハイライト |
| `F{char}` | 文字へ後方ジャンプ | |
| `t{char}` | 文字の手前へ前方ジャンプ | |
| `T{char}` | 文字の手前へ後方ジャンプ | |
| `f` (リピート) | 次の同じ文字へ | clever-fの機能 |
| `F` (リピート) | 前の同じ文字へ | clever-fの機能 |

## Tips

1. **小文字で検索**: 大文字小文字を気にせず検索できる（スマートケース）
2. **行をまたぐ**: 関数全体から変数を追跡できる
3. **quick-scopeを見てから決める**: ハイライトを見て、どの文字で移動するか決める
4. **tを活用**: 挿入モードに入る前の位置調整に便利

## まとめ

**clever-f + quick-scopeの強み:**
- ✅ ターゲットが視覚的にわかる
- ✅ `;`と`,`を覚えなくていい
- ✅ リピート移動が直感的
- ✅ コードの中を高速で移動できる

この2つのプラグインをマスターすると、マウスを使わずにカーソルを自在に動かせるようになります。
