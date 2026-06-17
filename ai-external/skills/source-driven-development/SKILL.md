---
name: source-driven-development
description: すべての実装判断を公式ドキュメントに基づかせる。古いパターンを避け、権威ある情報源に引用されたコードがほしい場合に使う。正しさが重要な framework または library で構築する場合に使う。
---

# ソース駆動開発

## 概要

framework 固有のコード判断は、すべて公式ドキュメントで裏付ける。記憶だけで実装しない。検証し、引用し、ユーザーが情報源を確認できるようにする。学習データは古くなり、API は deprecated になり、best practices は変化する。このスキルは、すべてのパターンがユーザー自身で確認できる権威ある情報源へたどれるようにし、信頼できるコードを提供する。

## 使う場面

- ユーザーが特定 framework の現在の best practices に従うコードを求めている
- boilerplate、starter code、プロジェクト全体でコピーされる pattern を作る
- ユーザーが documented、verified、または「正しい」実装を明示的に求めている
- framework の推奨アプローチが重要な機能（forms、routing、data fetching、state management、auth）を実装する
- framework-specific patterns を使うコードをレビューまたは改善する
- framework-specific code を記憶から書こうとしている

**使わない場面:**

- 正しさが特定 version に依存しない（変数名変更、typo 修正、ファイル移動）
- すべての version で同じように動く純粋ロジック（loops、conditionals、data structures）
- ユーザーが検証より速度を明示的に優先している（「とにかくすばやくやって」）

## プロセス

```
DETECT ──→ FETCH ──→ IMPLEMENT ──→ CITE
  │          │           │            │
  ▼          ▼           ▼            ▼
 stack?     関連 docs    文書化済み   sources
            を取得       pattern に   を示す
                         従う
```

### ステップ 1: stack と version を検出する

プロジェクトの dependency file を読み、正確な version を特定する:

```
package.json    → Node/React/Vue/Angular/Svelte
composer.json   → PHP/Symfony/Laravel
requirements.txt / pyproject.toml → Python/Django/Flask
go.mod          → Go
Cargo.toml      → Rust
Gemfile         → Ruby/Rails
```

見つけた内容を明示する:

```
検出した stack:
- React 19.1.0（package.json から）
- Vite 6.2.0
- Tailwind CSS 4.0.3
→ 関連 pattern の公式ドキュメントを取得します。
```

version が欠けている、または曖昧な場合は **ユーザーに質問する**。推測しない。どの pattern が正しいかは version で決まる。

### ステップ 2: 公式ドキュメントを取得する

実装する機能に対する具体的な documentation page を取得する。homepage ではなく、docs 全体でもなく、関連する page である。

**情報源の優先順位（権威順）:**

| 優先度 | 情報源 | 例 |
|--------|--------|----|
| 1 | 公式ドキュメント | react.dev, docs.djangoproject.com, symfony.com/doc |
| 2 | 公式 blog / changelog | react.dev/blog, nextjs.org/blog |
| 3 | Web standards references | MDN, web.dev, html.spec.whatwg.org |
| 4 | Browser/runtime compatibility | caniuse.com, node.green |

**権威ではない。一次情報源として引用しない:**

- Stack Overflow answers
- Blog posts または tutorials（人気があっても）
- AI-generated documentation または summaries
- 自分の学習データ（だから検証する）

**取得対象は精密にする:**

```
悪い: React homepage を取得
良い: react.dev/reference/react/useActionState を取得

悪い: "django authentication best practices" を検索
良い: docs.djangoproject.com/en/6.0/topics/auth/ を取得
```

取得後、主要 pattern を抽出し、deprecation warnings または migration guidance を記録する。

公式情報源同士が矛盾する場合（例: migration guide が API reference と矛盾する）、不一致をユーザーへ表面化し、検出した version に対してどの pattern が実際に動くか検証する。

### ステップ 3: 文書化された pattern に従って実装する

ドキュメントが示す内容に一致するコードを書く:

- API signatures は記憶ではなく docs から使う
- docs が新しい方法を示しているなら、新しい方法を使う
- docs が pattern を deprecated としているなら、deprecated version は使わない
- docs が扱っていないものは unverified として flag する

**docs と既存プロジェクトコードが衝突する場合:**

```
CONFLICT DETECTED:
既存コードベースは form loading state に useState を使っていますが、
React 19 docs はこの pattern に useActionState を推奨しています。
Source: react.dev/reference/react/useActionState

Options:
A) modern pattern（useActionState）を使う。current docs と一貫
B) 既存コード（useState）に合わせる。codebase と一貫
→ どちらを選びますか？
```

衝突を表面化する。黙って片方を選ばない。

### ステップ 4: sources を引用する

framework-specific pattern にはすべて citation を付ける。ユーザーはすべての判断を検証できなければならない。

**コードコメント内:**

```typescript
// React 19 の useActionState による form handling
// Source: https://react.dev/reference/react/useActionState#usage
const [state, formAction, isPending] = useActionState(submitOrder, initialState);
```

**会話内:**

```
form submission state には manual useState ではなく useActionState を使っています。
React 19 では manual isPending/setIsPending pattern の代わりにこの hook が使われます。

Source: https://react.dev/blog/2024/12/05/react-19#actions
該当箇所は async functions による pending states handling を説明しています。
```

**引用ルール:**

- shortened ではなく full URLs
- 可能なら anchors 付き deep link を優先する（例: `/useActionState#usage` は `/useActionState` より doc restructuring に強い）
- 自明でない判断を支える場合は、関連箇所を短く引用する
- platform features を推奨する場合は browser/runtime support data を含める
- pattern の documentation が見つからない場合は、明示的に言う:

```
UNVERIFIED: この pattern の公式ドキュメントを見つけられませんでした。
これは学習データに基づくため古い可能性があります。
本番利用前に検証してください。
```

検証できなかったことを正直に伝えるほうが、根拠のない自信より価値がある。

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「この API は自信がある」 | 自信は証拠ではない。学習データには、正しく見えるが current versions で壊れる古い pattern が含まれる。検証する。 |
| 「docs 取得は tokens の無駄」 | API を hallucinate するほうが無駄である。ユーザーが 1 時間 debug してから function signature 変更に気付く。1 回の fetch が何時間も防ぐ。 |
| 「docs には必要なものがない」 | docs が扱っていないこと自体が有用な情報である。その pattern は公式推奨ではないかもしれない。 |
| 「古いかもしれないと書けばよい」 | disclaimer は助けにならない。検証して引用するか、unverified と明確に flag する。曖昧な hedge が最悪である。 |
| 「単純なタスクだから確認不要」 | 間違った pattern の単純な task は template になる。ユーザーは deprecated form handler を 10 components へコピーしてから modern approach に気付く。 |

## 危険信号

- その version の docs を確認せず framework-specific code を書く
- API について source citation ではなく「I believe」「I think」と言う
- どの version に適用されるか知らない pattern を実装する
- official documentation ではなく Stack Overflow や blog posts を引用する
- 学習データに現れる deprecated APIs を使う
- 実装前に `package.json` / dependency files を読まない
- framework-specific decisions に source citations なしでコードを届ける
- 1 ページだけが関連するのに docs site 全体を取得する

## 検証

source-driven development で実装後に確認する:

- [ ] dependency file から framework と library versions を特定した
- [ ] framework-specific patterns について official documentation を取得した
- [ ] すべての sources は official documentation であり、blog posts や training data ではない
- [ ] コードは current version の documentation に示された patterns に従っている
- [ ] non-trivial decisions に full URLs 付き source citations がある
- [ ] deprecated APIs を使っていない（migration guides と照合済み）
- [ ] docs と existing code の衝突をユーザーへ表面化した
- [ ] 検証できなかったものは明示的に unverified と flag した
