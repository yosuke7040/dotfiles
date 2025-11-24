# プラグイン連携ワークフロー集

複数のプラグインを組み合わせた、実践的なワークフロー集。

## 🔥 最強の組み合わせ

### 1. 検索と一括置換

**使用プラグイン:**
- lasterisk（検索）
- hlslens（カウント表示）
- substitute.nvim（置換）
- vim-metarepeat（繰り返し）

**シナリオ:** 変数名`oldVar`を`newVar`に変更

```javascript
const oldVar = 42;
console.log(oldVar);
return oldVar + 10;
```

**操作手順:**
```
1. yiw で"newVar"をヤンク
2. "oldVar"の上で * → [1/3]
3. siw で置換 → "newVar"
4. n → [2/3]
5. . → 繰り返し
6. n → [3/3]
7. . → 完了
```

**キーシーケンス:** `yiw` → `*` → `siw` → `n.n.`

**メリット:**
- ✅ 各箇所を目視確認しながら置換
- ✅ レジスタが汚れない
- ✅ ドットコマンドで高速化
- ✅ 置換数が一目でわかる

---

### 2. 文字移動から編集へのシームレスな流れ

**使用プラグイン:**
- quick-scope（ターゲット表示）
- clever-f（リピート移動）
- nvim-surround（括弧追加）
- vim-metarepeat（繰り返し）

**シナリオ:** 複数の単語を引用符で囲む

```javascript
const first = value1;
const second = value2;
const third = value3;
```

**操作手順:**
```
1. fv → quick-scopeで"v"を確認
2. v を入力 → "value1"へジャンプ
3. ysiw" → "value1"
4. f → 次の"v"（value2）へ
5. . → 繰り返し → "value2"
6. f → . → "value3"
```

**キーシーケンス:** `fv` → `v` → `ysiw"` → `f.f.`

---

### 3. コードブロック間の高速移動と編集

**使用プラグイン:**
- vim-edgemotion（エッジ移動）
- lasterisk（検索）
- dial.nvim（数値操作）

**シナリオ:** 関数内の数値を確認・修正

```go
func process() {
    count := 0
    for i := 0; i < 10; i++ {
        count++
    }
    return count
}

func validate() {
    threshold := 10
    // ...
}
```

**操作手順:**
```
1. *0 で数値0を検索
2. Ctrl+j で次の関数へエッジ移動
3. n で次の数値へ
4. Ctrl+a で10を11に増加
```

---

### 4. 括弧の種類を一括変更

**使用プラグイン:**
- lasterisk（検索）
- nvim-surround（括弧変更）
- vim-metarepeat（繰り返し）

**シナリオ:** 全ての丸括弧を角括弧に変更

```python
result = (item1, item2)
data = (x, y, z)
values = (a, b)
```

**操作手順:**
```
1. f( で最初の"("を検索
2. cs)] で()を[]に変更
3. n で次の"("へ
4. . → n → . で残りも変更
```

**結果:**
```python
result = [item1, item2]
data = [x, y, z]
values = [a, b]
```

---

### 5. 日本語編集時の快適ワークフロー

**使用プラグイン:**
- im-select.nvim（IME切り替え）
- nvim-surround（マークダウン記法）
- clever-f（移動）

**シナリオ:** 日本語ドキュメントのキーワードを強調

```markdown
この機能は重要です。設定ファイルを編集してください。
```

**操作手順:**
```
1. i で挿入モード → 日本語入力で"重要"と入力
2. Esc → 自動的に英数入力に切り替わる（im-select）
3. f重 → clever-fで"重"へ移動
4. ysiw* → "**重要**"（マークダウン太字）
```

**メリット:**
- ✅ Escで自動的に英数入力
- ✅ ノーマルモードでのコマンド入力がスムーズ
- ✅ 再度インサートモードに入ると日本語入力に戻る

---

## 📋 シーン別ワークフロー

### リファクタリング

**タスク:** メソッド名を変更し、呼び出し箇所も全て修正

```typescript
class User {
    getName() { return this.name; }
}

const user = new User();
user.getName();
user.getName();
```

**ワークフロー:**
```
1. メソッド名を変更
   - ci( で"getFullName"に変更

2. 呼び出し箇所を検索
   - *getName → [1/3]

3. 一括置換
   - n → ciw → getFullName
   - n → . → n → .
```

---

### コードレビュー

**タスク:** 特定の変数の使われ方を全て確認

```go
func process(data []int) {
    result := calculate(data)
    if result > 0 {
        save(result)
    }
    return result
}
```

**ワークフロー:**
```
1. *result → [1/3] 全体を把握
2. n → [2/3] if文での使用を確認
3. n → [3/3] returnでの使用を確認
4. Esc → ハイライトクリア
```

---

### テスト作成

**タスク:** テストケースの数値を連番で生成

```javascript
const test1 = createTest(1);
const test1 = createTest(1);
const test1 = createTest(1);
```

**ワークフロー:**
```
1. ビジュアルブロックモードで選択（Ctrl+v）
2. 2行目・3行目を選択
3. g Ctrl+a → 連番生成

結果:
const test1 = createTest(1);
const test2 = createTest(2);
const test3 = createTest(3);
```

---

## 🎯 目的別プラグイン組み合わせ表

### 高速移動

| 目的 | プラグイン組み合わせ |
|-----|-------------------|
| 文字単位の移動 | quick-scope + clever-f |
| 関数間の移動 | vim-edgemotion |
| 変数の追跡 | lasterisk + clever-f |

### 効率的な編集

| 目的 | プラグイン組み合わせ |
|-----|-------------------|
| 一括置換 | lasterisk + substitute.nvim + vim-metarepeat |
| 括弧操作 | nvim-surround + vim-metarepeat |
| 数値操作 | dial.nvim + vim-metarepeat |
| テキスト交換 | substitute.nvim (exchange) |

### 検索・確認

| 目的 | プラグイン組み合わせ |
|-----|-------------------|
| 変数の使用箇所確認 | lasterisk + hlslens |
| 検索しながら置換 | lasterisk + hlslens + substitute.nvim |
| 部分一致検索 | lasterisk (g*) + hlslens |

---

## 💡 高度なテクニック

### テクニック1: 条件付き置換

**シナリオ:** 一部の箇所だけ置換したい

```javascript
const user = getUser();  // これは置換
const user = "John";     // これはスキップ
const user = getUser();  // これは置換
```

**操作:**
```
yiw (newUser) → * → siw → n → n (スキップ) → .
```

---

### テクニック2: マクロとの組み合わせ

**シナリオ:** 複雑な編集を繰り返す

```
1. qa でマクロ記録開始
2. * → siw → n
3. q で記録終了
4. @a で実行
5. @@ で繰り返し
```

---

### テクニック3: ビジュアルモードでの一括囲み

**シナリオ:** 複数行を括弧で囲む

```javascript
const a = 1;
const b = 2;
const c = 3;
```

**操作:**
```
1. Vjj で3行選択
2. S{ で波括弧で囲む

結果:
{
  const a = 1;
  const b = 2;
  const c = 3;
}
```

---

## 📊 効率化の測定

### 従来の方法 vs プラグイン使用

#### 変数名を10箇所変更する場合

**従来 (`:s///g`):**
```vim
:%s/oldVar/newVar/g
```
- ⏱️ 入力時間: 約5秒
- ⚠️ 確認なしで一括置換
- ❌ 間違えたら取り消しが大変

**プラグイン使用:**
```
* → siw → (n → .)×9
```
- ⏱️ 入力時間: 約3秒
- ✅ 各箇所を目視確認
- ✅ レジスタが汚れない
- ✅ 途中でスキップ可能

---

## 🔧 カスタマイズ例

### 自分だけのワークフロー作成

よく使う操作をキーマッピングに:

```lua
-- 検索→置換のワンキー化
vim.keymap.set('n', '<leader>cr', function()
  require("lasterisk").search()
  vim.defer_fn(function()
    require('substitute').operator()
  end, 100)
end)
```

---

## まとめ

プラグインの真価は**組み合わせ**にあります。

**おすすめの学習順序:**
1. まず単体で各プラグインに慣れる
2. 2つのプラグインを組み合わせる
3. 3つ以上の連携を試す
4. 自分のワークフローを確立

**最も重要な組み合わせ:**
- `*` + `siw` + `n` + `.` （検索と置換）
- `f` + `ysiw"` + `.` （移動と括弧追加）
- `Ctrl+j` + `*` （ブロック移動と検索）

これらをマスターすれば、編集速度が劇的に向上します。
