# vim-edgemotion ガイド

コードブロックの境界（エッジ）に素早く移動できるプラグイン。

## プラグイン概要

- **リポジトリ**: [haya14busa/vim-edgemotion](https://github.com/haya14busa/vim-edgemotion)
- **機能**: Ctrl+j/Ctrl+kで空白行を飛び越えてコードブロック間を高速移動

## 通常のVimとの違い

### 通常のVimの`{`/`}`移動

```go
func processUser() {
    user := getUser()
    // 処理
}
                      // ← 空白行
func validateUser() {
    // 検証
}
```

**通常のVim:**
```
{ → 前の空白行へ移動
} → 次の空白行へ移動
```

**問題点:**
- 空白行に止まるため、もう一度押す必要がある
- コードブロックの先頭/末尾に直接移動できない

### vim-edgemotionの場合

```go
func processUser() {    // ← Ctrl+k でここへ
    user := getUser()   // ← 現在のカーソル
    return user
}                       // ← Ctrl+j でここへ

func validateUser() {   // ← 2回目の Ctrl+j でここへ
    // 検証
}
```

**改善点:**
✅ 空白行を飛び越える
✅ コードブロックの境界に直接移動
✅ 関数間の移動が高速

## 基本的な使い方

### 1. 下方向への移動（Ctrl+j）

```javascript
function getUserName() {  // ← 今ここ
    return user.name;
}

function getUserEmail() {  // ← Ctrl+j でここへ
    return user.email;
}

function getUserAge() {    // ← もう一度 Ctrl+j でここへ
    return user.age;
}
```

**操作:**
```
Ctrl+j → 次の関数の先頭へ
Ctrl+j → さらに次の関数へ
```

### 2. 上方向への移動（Ctrl+k）

```python
def process():    # ← Ctrl+k でここへ
    pass

def validate():   # ← もう一度 Ctrl+k でここへ
    pass

def save():       # ← 今ここ
    pass
```

**操作:**
```
Ctrl+k → 前の関数の先頭へ
Ctrl+k → さらに前の関数へ
```

### 3. ブロック内の移動

```go
func Calculate(a, b int) int {  // ← Ctrl+k でここへ
    result := 0

    if a > b {                  // ← 今ここ
        result = a - b
    } else {
        result = b - a
    }

    return result               // ← Ctrl+j でここへ
}
```

## 実践例

### 例1: 関数間のレビュー

```typescript
function createUser(data: UserData) {  // [1]
    const user = new User(data);
    return user;
}

function updateUser(id: string, data: UserData) {  // [2]
    const user = findUser(id);
    user.update(data);
    return user;
}

function deleteUser(id: string) {  // [3]
    const user = findUser(id);
    user.delete();
}
```

**目的:** 各関数を順番に確認

**操作:**
```
1. [1]の関数の中で Ctrl+j → [2]の先頭へ
2. 関数の内容を確認
3. Ctrl+j → [3]の先頭へ
4. 確認完了
```

### 例2: クラスメソッド間の移動

```python
class UserService:
    def __init__(self):
        pass

    def get_user(self, id):     # ← 今ここ
        return self.db.find(id)

    def create_user(self, data):  # ← Ctrl+j でここへ
        return self.db.create(data)

    def update_user(self, id, data):  # ← もう一度 Ctrl+j
        return self.db.update(id, data)
```

### 例3: コードブロックのナビゲーション

```javascript
// ヘッダー部分
const config = {
    api: "/api/v1",
};

// メイン処理              // ← Ctrl+j でここへジャンプ
function main() {
    const data = fetchData();
    processData(data);
}

// ヘルパー関数           // ← もう一度 Ctrl+j
function fetchData() {
    return fetch(config.api);
}
```

## 他のプラグインとの組み合わせ

### with lasterisk + hlslens

```go
func processData() {
    data := getData()     // ← "data"で検索
    fmt.Println(data)
}

func validateData() {
    data := getInput()    // ← Ctrl+j で移動 → n で次の"data"へ
    check(data)
}
```

**ワークフロー:**
```
1. *data で検索 → [1/4]
2. Ctrl+j で次の関数へ移動
3. n で次の"data"を検索
4. 変数の使われ方を確認
```

### with dial.nvim

```yaml
# config1.yaml
version: 1.0.0

# config2.yaml
version: 2.0.0

# config3.yaml
version: 3.0.0
```

**ワークフロー:**
```
1. "1.0.0"の"0"で Ctrl+a → 1.0.1
2. Ctrl+j で次のブロックへ
3. . で繰り返し → 2.0.1
4. Ctrl+j → . → 3.0.1
```

### with substitute.nvim

```javascript
const userName = "old";

function getUser() {
    const userName = "old";  // ← Ctrl+j で移動
    return userName;
}

function saveUser() {
    const userName = "old";  // ← Ctrl+j で移動
    save(userName);
}
```

**ワークフロー:**
```
1. yiw で"new"をヤンク
2. siw で最初の"old"を置換
3. Ctrl+j で次のブロックへ移動
4. n で"old"を検索 → . で置換
5. Ctrl+j → n → .
```

### with clever-f

```go
func getUserName() string {  // ← Ctrl+j でここへ → fu → u で"User"へ
    return user.Name
}

func getUserEmail() string {
    return user.Email
}
```

**ワークフロー:**
```
1. Ctrl+j で次の関数へ移動（大まかな移動）
2. fu で"User"へ細かく移動（clever-f）
```

## 設定の詳細

```lua
-- キーマッピング
vim.keymap.set({'n', 'v'}, '<C-j>', '<Plug>(edgemotion-j)')
vim.keymap.set({'n', 'v'}, '<C-k>', '<Plug>(edgemotion-k)')
```

**カスタマイズ例:**
```lua
-- 別のキーに変更したい場合
vim.keymap.set({'n', 'v'}, '<leader>j', '<Plug>(edgemotion-j)')
vim.keymap.set({'n', 'v'}, '<leader>k', '<Plug>(edgemotion-k)')
```

## 実践的なワークフロー

### ワークフロー1: テストケースの確認

```javascript
describe("User Service", () => {
    test("should create user", () => {  // [1]
        const user = createUser(data);
        expect(user).toBeDefined();
    });

    test("should update user", () => {  // [2]
        const user = updateUser(id, data);
        expect(user.name).toBe("updated");
    });

    test("should delete user", () => {  // [3]
        deleteUser(id);
        expect(findUser(id)).toBeNull();
    });
});
```

**操作:**
```
1. [1]のテストで Ctrl+j → [2]へ
2. テスト内容を確認
3. Ctrl+j → [3]へ
4. 全テストを順番に確認完了
```

### ワークフロー2: エラーハンドリングの確認

```go
func ProcessRequest() error {
    data, err := fetchData()
    if err != nil {
        return err
    }

    result, err := process(data)  // ← Ctrl+j でここへ
    if err != nil {
        return err
    }

    err = save(result)            // ← Ctrl+j でここへ
    if err != nil {
        return err
    }

    return nil
}
```

**操作:**
```
1. *err で検索 → 全てのerrをハイライト
2. Ctrl+j でエラーチェック箇所にジャンプ
3. n で次のerrを確認
4. Ctrl+j → 次のエラーチェック箇所
```

### ワークフロー3: 設定ブロックの編集

```yaml
# Development
database:
  host: localhost
  port: 5432

# Staging              # ← Ctrl+j でここへ
database:
  host: staging.example.com
  port: 5432

# Production           # ← Ctrl+j でここへ
database:
  host: prod.example.com
  port: 5432
```

**操作:**
```
1. "localhost"をヤンク
2. Ctrl+j で次のブロックへ
3. ciw で"staging.example.com"に変更
4. Ctrl+j → ciw で"prod.example.com"に変更
```

## edgemotionの動作原理

### 空白行の定義

vim-edgemotionは以下を「エッジ」として認識します：

```
コード行
コード行
          ← 空白行（エッジ）
コード行
コード行
```

**エッジとして認識されるもの:**
- 完全な空白行
- インデントのみの行
- コメントだけの行

### インデントレベルの変化

```python
def outer():
    def inner():  # ← インデントが変わる（エッジ）
        pass
                  # ← 空白行（エッジ）
    return
                  # ← 空白行（エッジ）
def another():    # ← インデントが戻る（エッジ）
    pass
```

## トラブルシューティング

### Ctrl+jが効かない

1. **VSCodeのキーバインドと競合**
   - VSCodeの設定で`Ctrl+j`を無効化
   - または別のキーにマッピング

2. **プラグインがロードされていない**
   ```vim
   :Lazy
   ```
   でvim-edgemotionを確認

### 期待した位置に移動しない

1. **空白行が少ない**
   - コードブロック間に空白行がないと効果が薄い
   - フォーマッターで空白行を追加

2. **インデントが揃っていない**
   - インデントを整形すると動作が改善

## よく使う移動パターン

### パターン1: 関数を順番に確認

```
Ctrl+j → 確認 → Ctrl+j → 確認 → ...
```

### パターン2: 前の関数に戻る

```
Ctrl+j → Ctrl+j → Ctrl+k（戻る）
```

### パターン3: 大きくジャンプしてから微調整

```
Ctrl+j（大きく移動）→ fv（clever-fで微調整）
```

### パターン4: ブロック間を検索

```
Ctrl+j → n（検索）→ Ctrl+j → n → ...
```

## Tips

1. **コードブロック間は空白行を入れる**: edgemotionの効果を最大化
2. **Ctrl+j/kで大まかに移動**: その後clever-fで細かく調整
3. **検索と組み合わせる**: Ctrl+jで移動 → nで検索
4. **繰り返し操作と相性が良い**: Ctrl+j → 編集 → . → Ctrl+j → .

## まとめ

**vim-edgemotionの強み:**
- ✅ 関数間を素早く移動
- ✅ コードブロックの境界を自動認識
- ✅ 空白行を飛び越える
- ✅ 他のプラグインとの組み合わせで真価を発揮

**おすすめの使い方:**
- コードレビュー時の関数間移動
- 大きな移動はCtrl+j/k、細かい移動はclever-f
- 検索（lasterisk）と組み合わせて変数追跡

vim-edgemotionをマスターすると、大きなファイル内でも迷わず目的の場所に素早く移動できます。
