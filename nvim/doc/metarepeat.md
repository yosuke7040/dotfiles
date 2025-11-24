# vim-metarepeat ガイド

ドットコマンド（`.`）をプラグインの操作にも対応させる拡張プラグイン。

## プラグイン概要

- **リポジトリ**: [haya14busa/vim-metarepeat](https://github.com/haya14busa/vim-metarepeat)
- **依存**: [tpope/vim-repeat](https://github.com/tpope/vim-repeat)
- **機能**: プラグインの操作をドットコマンド（`.`）で繰り返せるようにする

## 通常のVimとの違い

### 通常のVimのドットコマンド

```javascript
const value = "old";
const data = "old";
```

**Vimの標準操作:**
```
1. ciw で"old"を"new"に変更
2. j で次の行へ
3. . で繰り返し → "new"に変わる
```

これは**Vimネイティブの操作**だからドットコマンドが効く。

### プラグイン操作のドットコマンド

```javascript
const value = "old";
const data = "old";
```

**substitute.nvimの場合（metarepeatなし）:**
```
1. siw で"old"を置換
2. j で次の行へ
3. . → 効かない！
```

**substitute.nvimの場合（metarepeatあり）:**
```
1. siw で"old"を置換
2. j で次の行へ
3. . → 効く！"new"に変わる
```

**改善点:**
✅ プラグインの操作もドットコマンドで繰り返せる
✅ 編集速度が劇的に向上
✅ substitute.nvim、nvim-surround、dial.nvimなどと連携

## 対応プラグインと使用例

### 1. substitute.nvim との連携

```javascript
const userName = "old";
const userId = "old";
const userEmail = "old";
```

**操作:**
```
1. yiw で"new"をヤンク
2. siw で最初の"old"を置換
3. j → . → "new"
4. j → . → "new"
```

**キーシーケンス:** `yiw` → `siw` → `j.j.`

### 2. nvim-surround との連携

```javascript
const first = value1;
const second = value2;
const third = value3;
```

**目的:** 全ての値を引用符で囲む

**操作:**
```
1. fv → v へジャンプ
2. ysiw" → "value1"
3. j → f → . → "value2"
4. j → f → . → "value3"
```

**結果:**
```javascript
const first = "value1";
const second = "value2";
const third = "value3";
```

### 3. dial.nvim との連携

```yaml
timeout: 100
retries: 100
delay: 100
```

**目的:** 全ての100を200に変更

**操作:**
```
1. "100"の上で 100 Ctrl+a → 200
2. j → . → 200
3. j → . → 200
```

### 4. exchange（substitute.nvim）との連携

```python
a, b = getValue()
x, y = getData()
p, q = getResult()
```

**目的:** 全ての左右を入れ替え

**操作:**
```
1. "a"の上で viw → X（マーク）
2. "b"の上で viw → X（交換）
3. j → viw → X → 移動 → viw → X
4. または j → . で繰り返し（状況による）
```

## 実践例

### 例1: 変数名の一括変更

```go
func processData() {
    oldVar := getData()
    fmt.Println(oldVar)
    result := transform(oldVar)
    return oldVar
}
```

**目的:** `oldVar`を`newVar`に変更

**操作:**
```
1. yiw で"newVar"をヤンク
2. *oldVar → [1/4] 全体を把握
3. siw → "newVar"
4. n → [2/4] → .
5. n → [3/4] → .
6. n → [4/4] → .
```

**キーシーケンス:** `yiw` → `*` → `siw` → `n.n.n.`

### 例2: 括弧の一括変更

```python
result = (item1, item2)
data = (x, y, z)
values = (a, b)
```

**目的:** 全ての丸括弧を角括弧に変更

**操作:**
```
1. f( で最初の"("を検索
2. cs)] で()を[]に変更
3. n で次の"("へ
4. . → 繰り返し
5. n → . → 完了
```

**結果:**
```python
result = [item1, item2]
data = [x, y, z]
values = [a, b]
```

### 例3: 数値の一括増加

```javascript
const test1 = createTest(10);
const test2 = createTest(10);
const test3 = createTest(10);
```

**目的:** 全ての10を20に変更

**操作:**
```
1. *10 → [1/3]
2. 10 Ctrl+a → 20
3. n → [2/3] → .
4. n → [3/3] → .
```

### 例4: 引用符の一括追加

```javascript
const config = {
    host: localhost,
    port: 5432,
    database: mydb,
};
```

**目的:** 全ての値を引用符で囲む

**操作:**
```
1. fl → l へジャンプ
2. ysiw" → "localhost"
3. j → fp → . → "5432"
4. j → fm → . → "mydb"
```

**結果:**
```javascript
const config = {
    host: "localhost",
    port: "5432",
    database: "mydb",
};
```

## 他のプラグインとの組み合わせ

### with lasterisk + hlslens + substitute.nvim

**最強の一括置換ワークフロー:**

```typescript
interface User {
    userId: number;
    userId: string;  // 間違い
    userId: boolean; // 間違い
}
```

**操作:**
```
1. yiw で"id"をヤンク
2. *userId → [1/3]
3. siw → "id"
4. n → [2/3] → . → "id"
5. n → [3/3] → . → "id"
```

**結果:**
```typescript
interface User {
    id: number;
    id: string;
    id: boolean;
}
```

### with clever-f + nvim-surround

```javascript
const value1 = data;
const value2 = data;
const value3 = data;
```

**操作:**
```
1. fv → v にジャンプ
2. ysiw" → "value1"
3. f → . → "value2"
4. f → . → "value3"
```

### with vim-edgemotion + dial.nvim

```yaml
# config1
version: 1.0.0

# config2
version: 1.0.0

# config3
version: 1.0.0
```

**操作:**
```
1. "0"の上で Ctrl+a → 1.0.1
2. Ctrl+j → 次のブロックへ
3. . → 1.0.1
4. Ctrl+j → .
```

## ドットコマンドが使えるプラグイン操作

### substitute.nvim

| 操作 | 説明 | ドットコマンド |
|-----|------|-------------|
| `siw` | 単語を置換 | ✅ 使える |
| `ss` | 行を置換 | ✅ 使える |
| `S` | 行末まで置換 | ✅ 使える |

### nvim-surround

| 操作 | 説明 | ドットコマンド |
|-----|------|-------------|
| `ysiw"` | 引用符で囲む | ✅ 使える |
| `ds"` | 引用符を削除 | ✅ 使える |
| `cs"'` | 引用符を変更 | ✅ 使える |

### dial.nvim

| 操作 | 説明 | ドットコマンド |
|-----|------|-------------|
| `Ctrl+a` | 数値を増加 | ✅ 使える |
| `Ctrl+x` | 数値を減少 | ✅ 使える |

## 実践的なワークフロー

### ワークフロー1: APIエンドポイントの修正

```javascript
fetch('/api/users');
axios.get('/api/users');
request('/api/users');
```

**目的:** 全ての`/api/users`を`/api/v2/users`に変更

**操作:**
```
1. '/api/users'を選択
2. * で検索 → [1/3]
3. ci' で'/api/v2/users'と入力
4. n → [2/3] → .
5. n → [3/3] → .
```

### ワークフロー2: ログレベルの変更

```python
logger.info("Starting process")
logger.info("Processing data")
logger.info("Completed")
```

**目的:** 全ての`info`を`debug`に変更

**操作:**
```
1. yiw で"debug"をヤンク
2. *info → [1/3]
3. siw → "debug"
4. n → . → n → .
```

### ワークフロー3: テストの真偽値反転

```yaml
test_user: true
test_admin: true
test_guest: true
```

**目的:** 全ての`true`を`false`に変更

**操作:**
```
1. *true → [1/3]
2. Ctrl+a → "false"
3. n → [2/3] → .
4. n → [3/3] → .
```

## vim-repeatとの違い

### vim-repeat（基本）

- プラグインの操作を1回だけ繰り返す
- vim-metarepeatの依存プラグイン

### vim-metarepeat（拡張）

- vim-repeatをさらに拡張
- より多くのプラグインに対応
- 複雑な操作も繰り返せる

## トラブルシューティング

### ドットコマンドが効かない

1. **vim-repeatがインストールされていない**
   ```vim
   :Lazy
   ```
   で`vim-repeat`を確認

2. **プラグインがmetarepeatに対応していない**
   - substitute.nvim: ✅ 対応
   - nvim-surround: ✅ 対応
   - dial.nvim: ✅ 対応
   - 他のプラグイン: 確認が必要

3. **操作が複雑すぎる**
   - マクロを使う方が適切な場合もある

### 期待と違う動作をする

1. **レジスタが変わった**
   - substitute.nvimの`yank_substituted_text = false`を確認

2. **検索位置がずれる**
   - `n`で次の検索結果に移動してから`.`を押す

## 効率化のコツ

### コツ1: パターン認識

同じ操作を3回以上繰り返す場合 → ドットコマンドを使う

### コツ2: 検索との組み合わせ

```
* → 操作 → n → . → n → . → ...
```

このパターンを体に覚えさせる。

### コツ3: プラグインの連携

```
f（clever-f）→ 操作（surround/substitute）→ f → .
```

移動と編集を組み合わせる。

### コツ4: 確認しながら置換

`:s///g`による一括置換と違い、各箇所を確認しながら置換できる。

## よく使うパターン

### パターン1: 検索→置換→繰り返し

```
* → siw → n → . → n → .
```

### パターン2: 移動→編集→移動→繰り返し

```
f → ysiw" → f → . → f → .
```

### パターン3: ブロック移動→編集→繰り返し

```
Ctrl+j → 操作 → . → Ctrl+j → .
```

### パターン4: 増減→移動→繰り返し

```
Ctrl+a → n → . → n → .
```

## まとめ

**vim-metarepeatの強み:**
- ✅ プラグイン操作もドットコマンドで繰り返せる
- ✅ 編集速度が劇的に向上
- ✅ substitute.nvim、nvim-surround、dial.nvimと相性抜群
- ✅ 検索（lasterisk）との組み合わせで最強

**最重要パターン:**
```
* → siw → n → . → n → .
```
（検索 → 置換 → 次へ → 繰り返し → 次へ → 繰り返し）

**おすすめの使い方:**
1. まず`*`で全体を把握（hlslensで件数確認）
2. `siw`で最初の置換
3. `n`で次へ移動（目視確認）
4. `.`で繰り返し
5. 不要な箇所は`n`でスキップ

vim-metarepeatは地味なプラグインですが、他のプラグインと組み合わせることで編集効率が何倍にもなります。特に`* → siw → n → .`のパターンは、マスターすれば手放せなくなるでしょう。
