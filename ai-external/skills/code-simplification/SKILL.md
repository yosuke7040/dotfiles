---
name: code-simplification
description: 明快さのためにコードを単純化する。振る舞いを変えずに明快さのためリファクタリングする場合に使う。コードは動くが、読む、保守する、拡張するうえで必要以上に難しい場合に使う。不要な複雑さが蓄積したコードをレビューする場合に使う。
---

# コード単純化

> [Claude Code Simplifier plugin](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/code-simplifier/agents/code-simplifier.md) に着想を得ている。ここでは、任意の AI コーディングエージェント向けの、モデル非依存でプロセス駆動のスキルとして調整している。

## 概要

正確な振る舞いを保ちながら、複雑さを減らしてコードを単純化する。目標は行数を減らすことではない。読みやすく、理解しやすく、変更しやすく、デバッグしやすいコードにすることである。すべての単純化は、次の単純なテストを通らなければならない。「新しいチームメンバーは、元のコードより速くこれを理解できるか。」

## 使う場面

- 機能が動き、テストも通るが、実装が必要以上に重く感じる
- コードレビューで読みやすさまたは複雑さの問題が指摘された
- 深いネスト、長い関数、不明瞭な名前に遭遇した
- 時間制約の中で書かれたコードをリファクタリングする
- ファイルをまたいで散らばった関連ロジックを統合する
- 重複または不整合を導入した変更のマージ後

**使わない場面:**

- コードがすでに clean で読みやすい。単純化のためだけに単純化しない
- まだコードの意味を理解していない。単純化の前に理解する
- コードが performance-critical で、「より単純な」版が測定可能に遅くなる
- モジュール全体を書き換える直前である。捨てるコードの単純化は労力の無駄である

## 5 つの原則

### 1. 振る舞いを正確に保つ

コードがすることを変えてはならない。表現だけを変える。すべての入力、出力、副作用、エラー挙動、エッジケースは同一でなければならない。単純化が振る舞いを保つか確信できないなら、その変更はしない。

```
各変更前に問う:
→ これはすべての入力に対して同じ出力を生むか
→ 同じエラー挙動を保つか
→ 同じ副作用と順序を保つか
→ 既存テストは変更なしで通るか
```

### 2. プロジェクトの慣習に従う

単純化とは、コードベースとの一貫性を高めることであり、外部の好みを押し付けることではない。単純化前に:

```
1. CLAUDE.md / プロジェクト慣習を読む
2. 近傍コードが似たパターンをどう扱っているか調べる
3. 次についてプロジェクトのスタイルに合わせる:
   - import 順序と module system
   - function declaration style
   - naming conventions
   - error handling patterns
   - type annotation depth
```

プロジェクト一貫性を壊す単純化は、単純化ではなく churn である。

### 3. 巧妙さより明快さを優先する

短い版を読むために頭の一時停止が必要なら、明示的なコードのほうがよい。

```typescript
// 不明瞭: 密な ternary chain
const label = isNew ? 'New' : isUpdated ? 'Updated' : isArchived ? 'Archived' : 'Active';

// 明快: 読みやすい mapping
function getStatusLabel(item: Item): string {
  if (item.isNew) return 'New';
  if (item.isUpdated) return 'Updated';
  if (item.isArchived) return 'Archived';
  return 'Active';
}
```

```typescript
// 不明瞭: inline logic 付き chained reduce
const result = items.reduce((acc, item) => ({
  ...acc,
  [item.id]: { ...acc[item.id], count: (acc[item.id]?.count ?? 0) + 1 }
}), {});

// 明快: 名前付きの中間ステップ
const countById = new Map<string, number>();
for (const item of items) {
  countById.set(item.id, (countById.get(item.id) ?? 0) + 1);
}
```

### 4. バランスを保つ

単純化には失敗モードがある。過剰な単純化である。次の罠に注意する:

- **過度な inline 化**: 概念に名前を与えていた helper を消すと、call site が読みにくくなる
- **無関係なロジックの結合**: 2 つの単純な関数を 1 つの複雑な関数へまとめるのは単純化ではない
- **「不要な」抽象化の削除**: 一部の抽象化は複雑さではなく、拡張性やテスト容易性のために存在する
- **行数最適化**: 少ない行数は目標ではない。理解しやすさが目標である

### 5. 変更された範囲に絞る

既定では、最近変更されたコードを単純化する。明示的に範囲拡大を求められていない限り、無関係なコードの drive-by refactor を避ける。範囲のない単純化は diff にノイズを作り、意図しない回帰を招く。

## 単純化プロセス

### ステップ 1: 触る前に理解する（Chesterton's Fence）

何かを変更または削除する前に、それが存在する理由を理解する。これは Chesterton's Fence である。道路を横切る柵を見て、なぜあるのか分からないなら、取り壊してはならない。まず理由を理解し、その理由がまだ成り立つかを判断する。

```
単純化前に答える:
- このコードの責務は何か
- 何がこれを呼ぶか。これは何を呼ぶか
- エッジケースとエラー経路は何か
- 期待する振る舞いを定義するテストはあるか
- なぜこのように書かれた可能性があるか（性能、プラットフォーム制約、歴史的理由）
- git blame を確認する。このコードの元の文脈は何か
```

これらに答えられないなら、単純化の準備ができていない。さらに文脈を読む。

### ステップ 2: 単純化の機会を特定する

次のパターンを探す。どれも曖昧な臭いではなく、具体的なシグナルである。

**構造的複雑さ:**

| パターン | シグナル | 単純化 |
|----------|----------|--------|
| 深いネスト（3 階層以上） | 制御フローを追いにくい | 条件を guard clause または helper function へ抽出 |
| 長い関数（50 行以上） | 複数責務 | 説明的な名前を持つ焦点の合った関数へ分割 |
| ネストした三項演算子 | 読むのに mental stack が必要 | if/else chain、switch、lookup object へ置換 |
| boolean parameter flags | `doThing(true, false, true)` | options object または別関数へ置換 |
| 繰り返される条件 | 同じ `if` check が複数箇所にある | よく名付けた predicate function へ抽出 |

**命名と読みやすさ:**

| パターン | シグナル | 単純化 |
|----------|----------|--------|
| 汎用名 | `data`、`result`、`temp`、`val`、`item` | 内容を説明する名前へ変更: `userProfile`、`validationErrors` |
| 省略名 | `usr`、`cfg`、`btn`、`evt` | 普遍的な略語（`id`、`url`、`api`）以外は完全な単語を使う |
| 誤解を招く名前 | `get` という名前なのに状態も変更する | 実際の振る舞いを反映する名前へ変更 |
| 「何を」のコメント | `// increment counter` が `count++` の上にある | コメントを削除する。コードだけで十分明確 |
| 「なぜ」のコメント | `// Retry because the API is flaky under load` | 残す。コードでは表現できない意図を持つ |

**冗長性:**

| パターン | シグナル | 単純化 |
|----------|----------|--------|
| 重複ロジック | 同じ 5 行以上が複数箇所にある | 共有関数へ抽出 |
| dead code | 到達不能 branch、未使用変数、コメントアウトされた block | 本当に dead だと確認してから削除 |
| 不要な抽象化 | 価値を追加しない wrapper | wrapper を inline 化し、下位関数を直接呼ぶ |
| 過剰設計パターン | factory-for-a-factory、strategy-with-one-strategy | 単純で直接的なアプローチへ置換 |
| 冗長な type assertion | すでに推論されている型への cast | assertion を削除 |

### ステップ 3: 変更を段階的に適用する

単純化は 1 つずつ行う。各変更後にテストを実行する。**リファクタリング変更は、機能追加やバグ修正とは別に提出する。** リファクタリングと機能追加を含む PR は 2 つの PR である。分割する。

```
各単純化について:
1. 変更を行う
2. テストスイートを実行する
3. テストが通る → コミットする（または次の単純化へ進む）
4. テストが失敗する → 戻して再検討する
```

複数の単純化を 1 つの未検証変更へまとめない。何かが壊れたとき、どの単純化が原因か知る必要がある。

**500 のルール:** リファクタリングが 500 行を超えて触る場合、手作業ではなく automation（codemods、sed scripts、AST transforms）へ投資する。その規模の手作業編集はエラーを生みやすく、レビューも疲弊する。

### ステップ 4: 結果を検証する

すべての単純化後、一歩引いて全体を評価する:

```
before / after を比較する:
- 単純化後の版は本当に理解しやすいか
- コードベースと一貫しない新しいパターンを導入していないか
- diff は clean でレビュー可能か
- チームメイトはこの変更を承認するか
```

「単純化後」の版が理解しにくい、またはレビューしにくいなら戻す。すべての単純化が成功するわけではない。

## 言語別指針

### TypeScript / JavaScript

```typescript
// 単純化: 不要な async wrapper
// 変更前
async function getUser(id: string): Promise<User> {
  return await userService.findById(id);
}
// 変更後
function getUser(id: string): Promise<User> {
  return userService.findById(id);
}

// 単純化: 冗長な条件代入
// 変更前
let displayName: string;
if (user.nickname) {
  displayName = user.nickname;
} else {
  displayName = user.fullName;
}
// 変更後
const displayName = user.nickname || user.fullName;

// 単純化: 手動 array 構築
// 変更前
const activeUsers: User[] = [];
for (const user of users) {
  if (user.isActive) {
    activeUsers.push(user);
  }
}
// 変更後
const activeUsers = users.filter((user) => user.isActive);

// 単純化: 冗長な boolean return
// 変更前
function isValid(input: string): boolean {
  if (input.length > 0 && input.length < 100) {
    return true;
  }
  return false;
}
// 変更後
function isValid(input: string): boolean {
  return input.length > 0 && input.length < 100;
}
```

### Python

```python
# 単純化: 冗長な dictionary 構築
# 変更前
result = {}
for item in items:
    result[item.id] = item.name
# 変更後
result = {item.id: item.name for item in items}

# 単純化: early return による nested conditionals
# 変更前
def process(data):
    if data is not None:
        if data.is_valid():
            if data.has_permission():
                return do_work(data)
            else:
                raise PermissionError("No permission")
        else:
            raise ValueError("Invalid data")
    else:
        raise TypeError("Data is None")
# 変更後
def process(data):
    if data is None:
        raise TypeError("Data is None")
    if not data.is_valid():
        raise ValueError("Invalid data")
    if not data.has_permission():
        raise PermissionError("No permission")
    return do_work(data)
```

### React / JSX

```tsx
// 単純化: 冗長な conditional rendering
// 変更前
function UserBadge({ user }: Props) {
  if (user.isAdmin) {
    return <Badge variant="admin">Admin</Badge>;
  } else {
    return <Badge variant="default">User</Badge>;
  }
}
// 変更後
function UserBadge({ user }: Props) {
  const variant = user.isAdmin ? 'admin' : 'default';
  const label = user.isAdmin ? 'Admin' : 'User';
  return <Badge variant={variant}>{label}</Badge>;
}

// 単純化: intermediate component を通した prop drilling
// 変更前: context または composition がよりよく解けるか検討する。
// これは判断が必要である。自動リファクタリングせず、指摘として出す。
```

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「動いているから触る必要はない」 | 読みにくい動作コードは、壊れたときに直しにくい。今単純化すれば、将来の変更すべてで時間を節約する。 |
| 「行数が少なければ常に単純」 | 1 行のネスト三項演算子は、5 行の if/else より単純ではない。単純さは行数ではなく理解速度である。 |
| 「この無関係なコードもさっと単純化する」 | 範囲外の単純化は noisy diff を作り、意図しないコードで回帰を招く。集中する。 |
| 「型があるから自己文書化されている」 | 型は構造を文書化するが、意図は文書化しない。よく名付けられた関数は、type signature が説明する *what* より *why* をよく説明する。 |
| 「この抽象化は後で役立つかもしれない」 | 推測上の抽象化を残さない。今使われていなければ、価値のない複雑さである。削除し、必要になったら再追加する。 |
| 「元の作者には理由があったはず」 | かもしれない。git blame を確認し、Chesterton's Fence を適用する。ただし蓄積した複雑さには理由がないことも多い。圧力下の反復の残滓である。 |
| 「この機能を追加しながらリファクタリングする」 | リファクタリングと機能作業は分ける。混ざった変更はレビュー、revert、履歴理解を難しくする。 |

## 危険信号

- テストを変更しないと通らない単純化（おそらく振る舞いを変えている）
- 元より長く、追いにくい「単純化」後のコード
- プロジェクト慣習ではなく自分の好みに合わせた rename
- 「コードがきれいになるから」とエラー処理を削る
- 完全には理解していないコードを単純化する
- 多数の単純化を 1 つの大きくレビューしにくいコミットへまとめる
- 求められていないのに現在タスク範囲外のコードをリファクタリングする

## 検証

単純化作業の完了後に確認する:

- [ ] 既存テストが変更なしですべて通る
- [ ] ビルドが新しい warning なしで成功する
- [ ] linter/formatter が通る（スタイル回帰なし）
- [ ] 各単純化がレビュー可能な段階的変更である
- [ ] diff が clean であり、無関係な変更が混ざっていない
- [ ] 単純化後のコードがプロジェクト慣習に従っている（CLAUDE.md または同等のものと照合済み）
- [ ] エラー処理が削除または弱体化されていない
- [ ] dead code が残っていない（未使用 import、到達不能 branch）
- [ ] チームメイトまたはレビューエージェントが、純改善として承認できる
