---
name: documentation-and-adrs
description: 判断とドキュメントを記録する。architectural decisions を行う場合、public APIs を変更する場合、features を ship する場合、または将来の engineers と agents が codebase を理解するために必要な context を記録する場合に使う。
---

# ドキュメントと ADR

## 概要

コードだけでなく、判断を文書化する。最も価値あるドキュメントは *why*、つまり判断へ至った context、constraints、trade-offs を捉える。コードは *what* を示し、ドキュメントは *なぜこのように作ったか* と *どの alternatives を検討したか* を説明する。この context は、将来 codebase で作業する人間と agents に不可欠である。

## 使う場面

- 重要な architectural decision を行う
- competing approaches から選ぶ
- public API を追加または変更する
- user-facing behavior を変える feature を ship する
- 新しい team members または agents を project に onboard する
- 同じ説明を繰り返している

**使わない場面:** 自明な code を文書化しない。code がすでに言っていることを繰り返す comments を追加しない。捨てる prototypes の docs を書かない。

## アーキテクチャ判断記録（ADRs）

ADRs は重要な technical decisions の reasoning を記録する。書ける中で最も価値が高い documentation である。

### ADR を書く場面

- framework、library、major dependency を選ぶ
- data model または database schema を設計する
- authentication strategy を選ぶ
- API architecture（REST vs. GraphQL vs. tRPC）を決める
- build tools、hosting platforms、infrastructure を選ぶ
- 戻すのが高価な任意の判断

### ADR テンプレート

ADRs は `docs/decisions/` に sequential numbering で保存する:

```markdown
# ADR-001: primary database に PostgreSQL を使う

## 状態
採用 | ADR-XXX により置き換え | 非推奨

## 日付
2025-01-15

## 背景
task management application の primary database が必要である。主要要件:
- relational data model（users、tasks、teams と relationships）
- task state changes に ACID transactions
- task content の full-text search
- managed hosting available（small team、limited ops capacity）

## 判断
PostgreSQL と Prisma ORM を使う。

## 検討した代替案

### MongoDB
- 利点: flexible schema、始めやすい
- 欠点: data が本質的に relational。relationships を手動管理する必要がある
- 不採用理由: document store の relational data は複雑な joins または data duplication につながる

## 結果
- Prisma が type-safe database access と migration management を提供する
- Elasticsearch 追加なしで PostgreSQL full-text search を使える
- team は PostgreSQL knowledge が必要（標準 skill、low risk）
```

### ADR ライフサイクル

```
PROPOSED → ACCEPTED → (SUPERSEDED or DEPRECATED)
```

- **古い ADRs を削除しない。** historical context を保持する。
- 判断が変わったら、古い ADR を参照し supersede する新しい ADR を書く。

## インラインドキュメント

### comment する場面

*what* ではなく *why* を comment する:

```typescript
// 悪い例: code の言い換え
// counter を 1 増やす
counter += 1;

// 良い例: 自明でない意図を説明
// rate limit は sliding window を使う。fixed schedule ではなく window boundary で reset し、
// window edge の burst attacks を防ぐ。
if (now - windowStart > WINDOW_SIZE_MS) {
  counter = 0;
  windowStart = now;
}
```

### comment しない場面

```typescript
// self-explanatory code に comment しない
function calculateTotal(items: CartItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

// 今やるべきことを TODO として残さない
// TODO: add error handling  ← 今追加する

// commented-out code を残さない
// const oldImplementation = () => { ... }  ← 削除する。git に history がある
```

### 既知の落とし穴を文書化する

```typescript
/**
 * IMPORTANT: この関数は最初の render 前に呼ばなければならない。
 * hydration 後に呼ぶと、SSR 中に theme context が利用できないため
 * unstyled content が一瞬表示される。
 *
 * 完全な設計根拠は ADR-003 を参照。
 */
export function initializeTheme(theme: Theme): void {
  // ...
}
```

## API ドキュメント

public APIs（REST、GraphQL、library interfaces）について:

### Types と一緒に inline（TypeScript では推奨）

```typescript
/**
 * 新しい task を作成する。
 *
 * @param input - task creation data（title 必須、description 任意）
 * @returns server-generated ID と timestamps を持つ作成済み task
 * @throws {ValidationError} title が空または 200 文字超の場合
 * @throws {AuthenticationError} user が authenticated でない場合
 */
export async function createTask(input: CreateTaskInput): Promise<Task> {
  // ...
}
```

### REST APIs には OpenAPI / Swagger

```yaml
paths:
  /api/tasks:
    post:
      summary: Create a task
      responses:
        '201':
          description: タスクを作成しました
        '422':
          description: バリデーションエラー
```

## README 構成

すべての project は次を含む README を持つ:

```markdown
# プロジェクト名

この project が何をするかを 1 段落で説明。

## クイックスタート
1. repo を clone
2. dependencies を install: `npm install`
3. environment を設定: `cp .env.example .env`
4. dev server を実行: `npm run dev`

## コマンド
| コマンド | 説明 |
|---------|-------------|
| `npm run dev` | development server を開始 |
| `npm test` | tests を実行 |
| `npm run build` | production build |
| `npm run lint` | linter を実行 |

## アーキテクチャ
project structure と key design decisions の短い overview。
詳細は ADRs へ link。
```

## Changelog の保守

shipped features について:

```markdown
# 変更履歴

## [1.2.0] - 2025-01-20
### 追加
- Task sharing: users が team members と tasks を共有可能 (#123)

### 修正
- create button の rapid clicking で duplicate tasks が表示される問題 (#125)
```

## Agents 向けドキュメント

AI agent context には特別な配慮が必要:

- **CLAUDE.md / rules files**: agents が従う project conventions を文書化
- **Spec files**: agents が正しいものを作れるよう specs を更新
- **ADRs**: 過去の判断理由を理解させ、再決定を防ぐ
- **Inline gotchas**: 既知の罠に agents が落ちることを防ぐ

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「code は自己文書化している」 | code は what を示すが、why、rejected alternatives、constraints は示さない。 |
| 「API が安定したら docs を書く」 | docs は design の最初の test であり、API は文書化すると安定しやすい。 |
| 「誰も docs を読まない」 | agents は読む。未来の engineers も読む。3 か月後の自分も読む。 |
| 「ADRs は overhead」 | 10 分の ADR は、6 か月後に同じ判断を 2 時間議論することを防ぐ。 |
| 「comments は古くなる」 | *why* の comments は安定している。*what* の comments は古くなる。だから前者だけを書く。 |

## 危険信号

- written rationale のない architectural decisions
- documentation または types のない public APIs
- project の実行方法を説明しない README
- 削除ではなく commented-out code
- 何週間も残っている TODO comments
- 重要な architectural choices がある project に ADRs がない
- intent ではなく code を言い換える documentation

## 検証

文書化後に確認する:

- [ ] 重要な architectural decisions すべてに ADR がある
- [ ] README が quick start、commands、architecture overview を含む
- [ ] API functions に parameter と return type documentation がある
- [ ] known gotchas が重要な箇所に inline で文書化されている
- [ ] commented-out code が残っていない
- [ ] rules files（CLAUDE.md など）が最新で正確である
