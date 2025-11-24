# dial.nvim ガイド

数値・日付・真偽値・バージョン番号などを賢くインクリメント/デクリメントするプラグイン。

## プラグイン概要

- **リポジトリ**: [monaqa/dial.nvim](https://github.com/monaqa/dial.nvim)
- **機能**: Ctrl+a/Ctrl+xで様々な形式の値を増減できる

## 通常のVimとの違い

### 通常のVimの`Ctrl+a`/`Ctrl+x`

```javascript
const value = 42;
```

**操作:**
```
Ctrl+a → 43
Ctrl+x → 41
```

**問題点:**
- 数値しか対応していない
- 日付や真偽値は扱えない
- バージョン番号（1.2.3）も増減できない

### dial.nvimの場合

```javascript
const enabled = false;
const date = "2024-01-15";
const version = "1.2.3";
const count = 42;
```

**操作:**
```
"false"の上で Ctrl+a → "true"
"2024-01-15"の上で Ctrl+a → "2024-01-16"
"1.2.3"の上で Ctrl+a → "1.2.4"
"42"の上で Ctrl+a → "43"
```

**改善点:**
✅ 真偽値のトグル
✅ 日付の増減
✅ バージョン番号の対応
✅ 16進数・8進数・2進数の対応
✅ カスタムの増減リストを定義可能

## 基本的な使い方

### 1. 数値の増減

#### 10進数

```go
const count = 42
```

**操作:**
```
Ctrl+a → 43
Ctrl+x → 41
```

#### 16進数

```c
int color = 0xff00aa;
```

**操作:**
```
"0xff00aa"の上で Ctrl+a → 0xff00ab
```

#### 8進数・2進数

```python
octal = 0o755
binary = 0b1010
```

**操作:**
```
"0o755"の上で Ctrl+a → 0o756
"0b1010"の上で Ctrl+a → 0b1011
```

### 2. 日付の増減

```markdown
期限: 2024-01-15
```

**操作:**
```
"2024-01-15"の上で Ctrl+a → 2024-01-16
"2024-01-16"の上で Ctrl+x → 2024-01-15
```

**複数回の増減:**
```
5 Ctrl+a → 5日後の日付
10 Ctrl+x → 10日前の日付
```

### 3. 真偽値のトグル

```javascript
const enabled = false;
const isValid = true;
```

**操作:**
```
"false"の上で Ctrl+a → "true"
"true"の上で Ctrl+a → "false"
```

**対応する形式:**
- `true` ↔ `false`
- `True` ↔ `False`
- `TRUE` ↔ `FALSE`
- `yes` ↔ `no`
- `Yes` ↔ `No`
- `YES` ↔ `NO`

### 4. セマンティックバージョンの増減

```json
{
  "version": "1.2.3"
}
```

**操作:**
```
"1.2.3"の最後の数字で Ctrl+a → "1.2.4"
"1.2.3"の真ん中の数字で Ctrl+a → "1.3.0"
"1.2.3"の最初の数字で Ctrl+a → "2.0.0"
```

## 実践例

### 例1: テストケースの連番生成

```javascript
test('case 1', () => {});
test('case 1', () => {});
test('case 1', () => {});
```

**操作:**
```
1. ビジュアルブロックモード（Ctrl+v）で数字を選択
2. g Ctrl+a → 連番生成

結果:
test('case 1', () => {});
test('case 2', () => {});
test('case 3', () => {});
```

### 例2: バージョンアップ

```yaml
# package.yaml
version: 1.2.3
```

**目的:** パッチバージョンをインクリメント

**操作:**
```
"3"の上で Ctrl+a → 1.2.4
```

**目的:** マイナーバージョンをインクリメント

**操作:**
```
"2"の上で Ctrl+a → 1.3.0（パッチは自動的に0にリセット）
```

### 例3: 日付の範囲指定

```markdown
イベント期間: 2024-01-15 ~ 2024-01-15
```

**目的:** 終了日を1週間後に設定

**操作:**
```
2つ目の"2024-01-15"の上で 7 Ctrl+a → 2024-01-22
```

### 例4: 色コードの調整

```css
.button {
  background: #ff6600;
}
```

**目的:** 色を少し明るくする

**操作:**
```
"ff6600"の最後の"00"の上で Ctrl+a → #ff6601
```

### 例5: フラグのトグル

```yaml
# config.yaml
debug: false
verbose: false
cache: true
```

**操作:**
```
"false"の上で Ctrl+a → "true"
```

## 他のプラグインとの組み合わせ

### with vim-metarepeat

```python
enabled = false
active = false
visible = false
```

**操作:**
```
1. "false"の上で Ctrl+a → "true"
2. j → . → "true"（ドットコマンドで繰り返し）
3. j → . → "true"
```

### with lasterisk

```go
const count1 = 0
const count2 = 0
const count3 = 0
```

**操作:**
```
1. *0 で全ての"0"を検索
2. Ctrl+a → 1
3. n → [2/3] → Ctrl+a → 1
4. n → [3/3] → Ctrl+a → 1
```

### with vim-edgemotion

```javascript
function foo() {
  const version = "1.0.0";
}

function bar() {
  const version = "2.0.0";
}
```

**操作:**
```
1. Ctrl+j で次の関数へ移動
2. "0.0"の上で Ctrl+a → "0.1"
3. Ctrl+j → 次の関数
4. "0.0"の上で Ctrl+a → "0.1"
```

## 設定の詳細

### augends（増減可能な要素）の設定

```lua
local augend = require("dial.augend")
require("dial.config").augends:register_group({
  default = {
    -- 10進数（整数）
    augend.integer.alias.decimal,

    -- 16進数
    augend.integer.alias.hex,

    -- 日付（YYYY-MM-DD形式）
    augend.date.alias["%Y-%m-%d"],

    -- 真偽値
    augend.constant.alias.bool,

    -- セマンティックバージョン
    augend.semver.alias.semver,
  },
})
```

### キーマッピング

```lua
vim.keymap.set("n", "<C-a>", require("dial.map").inc_normal(), {noremap = true})
vim.keymap.set("n", "<C-x>", require("dial.map").dec_normal(), {noremap = true})
vim.keymap.set("v", "<C-a>", require("dial.map").inc_visual(), {noremap = true})
vim.keymap.set("v", "<C-x>", require("dial.map").dec_visual(), {noremap = true})
vim.keymap.set("v", "g<C-a>", require("dial.map").inc_gvisual(), {noremap = true})
vim.keymap.set("v", "g<C-x>", require("dial.map").dec_gvisual(), {noremap = true})
```

## 高度なテクニック

### カスタムaugendの作成

曜日を増減する例：

```lua
augend.constant.new({
  elements = {"月", "火", "水", "木", "金", "土", "日"},
  word = true,
  cyclic = true,
})
```

**使用例:**
```
「月曜日」→ Ctrl+a → 「火曜日」
```

### 英数字の増減

```lua
augend.constant.new({
  elements = {"a", "b", "c", "d", "e"},
  word = false,
  cyclic = true,
})
```

**使用例:**
```
section-a → Ctrl+a → section-b
```

## 実践的なワークフロー

### ワークフロー1: APIバージョンの一括更新

```yaml
endpoints:
  - url: /api/v1/users
  - url: /api/v1/posts
  - url: /api/v1/comments
```

**目的:** 全てのv1をv2に変更

**操作:**
```
1. *v1 で検索
2. "1"の上で Ctrl+a → "2"
3. n → [2/3] → .
4. n → [3/3] → .
```

### ワークフロー2: テストの日付を未来に設定

```javascript
const testCases = [
  { date: "2024-01-15", expected: true },
  { date: "2024-01-16", expected: false },
  { date: "2024-01-17", expected: true },
];
```

**目的:** 全ての日付を1ヶ月後に

**操作:**
```
1. ビジュアルブロックで日付を選択
2. 30 Ctrl+a → 全て30日後
```

### ワークフロー3: カウンターの初期化

```go
count1 := 100
count2 := 200
count3 := 300
```

**目的:** 全てを0にリセット

**操作:**
```
1. *100 で検索
2. 100 Ctrl+x → 0
3. n → 200の上
4. 200 Ctrl+x → 0
5. n → 300の上
6. 300 Ctrl+x → 0
```

## 対応する値の一覧

| 種類 | 形式 | 例 |
|-----|------|-----|
| 10進数 | `42` | 42 → 43 |
| 16進数 | `0xff` | 0xff → 0x100 |
| 8進数 | `0o755` | 0o755 → 0o756 |
| 2進数 | `0b1010` | 0b1010 → 0b1011 |
| 日付 | `YYYY-MM-DD` | 2024-01-15 → 2024-01-16 |
| 真偽値 | `true/false` | true → false |
| YES/NO | `yes/no` | yes → no |
| セマンティックバージョン | `X.Y.Z` | 1.2.3 → 1.2.4 |

## トラブルシューティング

### 数値が増減しない

1. **カーソルが数値の上にない**
   - 数値の上に正確にカーソルを置く
   - `w`や`e`で単語移動して位置調整

2. **対応していない形式**
   - `augends`の設定を確認
   - 必要なaugendが登録されているか確認

### 日付が正しく増減しない

1. **日付形式が一致しない**
   - `%Y-%m-%d`形式（2024-01-15）が基本
   - 他の形式が必要な場合は`augend.date`で追加

2. **月末の処理**
   - dial.nvimは自動的に月末を考慮
   - 2024-01-31 → Ctrl+a → 2024-02-29（うるう年）

### ビジュアルモードで連番にならない

1. **`g Ctrl+a`を使う**
   - 通常の`Ctrl+a`は全て同じ値に増加
   - `g Ctrl+a`で連番生成

## Tips

1. **カウント指定**: `5 Ctrl+a`で5ずつ増加
2. **ビジュアル連番**: `g Ctrl+a`で連番生成
3. **バージョン管理**: セマンティックバージョンはカーソル位置で増加箇所が変わる
4. **真偽値トグル**: Ctrl+aでtrue/falseを簡単に切り替え
5. **日付計算**: 日数指定で未来/過去の日付を簡単に計算

## まとめ

**dial.nvimの強み:**
- ✅ 数値以外にも対応（日付、真偽値、バージョン）
- ✅ 連番生成が簡単
- ✅ セマンティックバージョンに対応
- ✅ カスタムaugendで拡張可能
- ✅ vim-metarepeatでドットコマンドが使える

**おすすめの使い方:**
- テストケースの連番生成に`g Ctrl+a`
- 設定ファイルの真偽値切り替えに`Ctrl+a`
- バージョン番号の更新に`Ctrl+a`（カーソル位置に注意）

dial.nvimをマスターすると、手動で数値や日付を編集する手間が大幅に削減されます。
