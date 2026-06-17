---
name: git-workflow-and-versioning
description: ワークフローとして git の実践を構造化する。任意の code change を行う場合に使う。committing、branching、conflicts 解決、または複数の並列 stream にまたがる作業整理が必要な場合に使う。
---

# Git ワークフローとバージョニング

## 概要

Git は safety net である。commits は save points、branches は sandboxes、history は documentation として扱う。AI agents が高速に code を生成する状況では、規律ある version control が、変更を扱いやすく、review しやすく、revert 可能に保つ仕組みになる。

## 使う場面

常に。すべての code change は git を通る。

## 中核原則

### trunk-based development（推奨）

`main` を常に deployable に保つ。1 から 3 日以内に merge される短命 feature branches で作業する。長命 development branches は隠れた cost であり、diverge し、merge conflicts を作り、integration を遅らせる。DORA research は trunk-based development が high-performing engineering teams と相関することを一貫して示している。

```
main ──●──●──●──●──●──●──●──●──●──  (always deployable)
        ╲      ╱  ╲    ╱
         ●──●─╱    ●──╱    ← short-lived feature branches (1-3 days)
```

これは推奨既定である。gitflow や長命 branches を使う team も、atomic commits、小さな changes、descriptive messages という原則を自分たちの branching model へ適用できる。具体的な branching strategy より commit discipline が重要である。

- **Dev branches は cost である。** branch は生きる日数ごとに merge risk を蓄積する。
- **Release branches は許容される。** main が前進する中で release を安定化する必要がある場合。
- **Feature flags > long branches。** 未完成作業を数週間 branch に置くより、flags の背後へ deploy する。

### 1. 早く、頻繁に commit する

成功した各 increment は自分の commit を持つ。大きな uncommitted changes を溜めない。

```
作業 pattern:
  Implement slice → Test → Verify → Commit → Next slice

避ける:
  Implement everything → Hope it works → Giant commit
```

commits は save points である。次の変更で何かが壊れたら、最後の known-good state へ即座に戻れる。

### 2. atomic commits

各 commit は 1 つの論理的なことを行う:

```
# 良い例: 各 commit が自己完結している
a1b2c3d Add task creation endpoint with validation
d4e5f6g Add task creation form component
h7i8j9k Connect form to API and add loading state
m1n2o3p Add task creation tests (unit + integration)

# 悪い例: すべてが混ざっている
x1y2z3a Add task feature, fix sidebar, update deps, refactor utils
```

### 3. 説明的なメッセージ

commit messages は *what* だけでなく *why* を説明する:

```
feat: add email validation to registration endpoint

Prevents invalid email formats from reaching the database.
Uses Zod schema validation at the route handler level,
consistent with existing validation patterns in auth.ts.
```

**形式:**
```
<type>: <short description>

<optional body explaining why, not what>
```

**Types:**
- `feat`: 新機能
- `fix`: バグ修正
- `refactor`: bug fix でも feature 追加でもない code change
- `test`: tests の追加または更新
- `docs`: documentation のみ
- `chore`: tooling、dependencies、config

### 4. 関心ごとを分ける

formatting changes と behavior changes を混ぜない。refactors と features を混ぜない。種類の違う変更は separate commit、理想的には separate PR にする。

```
# 良い例: 関心ごとを分ける
git commit -m "refactor: extract validation logic to shared utility"
git commit -m "feat: add phone number validation to registration"

# 悪い例: 関心ごとが混ざっている
git commit -m "refactor validation and add phone number field"
```

**リファクタリングと機能作業は分ける。** 既存コードの refactoring と feature change は 2 つの別変更である。別々に提出する。これにより、review、revert、history understanding が容易になる。小さな cleanup（変数 rename）は reviewer discretion で feature commit に含めてよい。

### 5. 変更サイズを整える

commit/PR あたり約 100 行を目標にする。約 1000 行を超える変更は分割する。大きな変更の分割方法は `code-review-and-quality` を参照する。

```
~100 lines  → review しやすく、revert しやすい
~300 lines  → 単一論理変更なら許容
~1000 lines → smaller changes へ分割
```

## branch 戦略

### feature branches

```
main (always deployable)
  │
  ├── feature/task-creation    ← 1 feature per branch
  ├── feature/user-settings    ← parallel work
  └── fix/duplicate-tasks      ← bug fixes
```

- `main`（または team の default branch）から branch する
- branches は短命に保つ（1-3 日以内に merge）。長命 branches は隠れた cost
- merge 後に branch を削除する
- 未完成 features には長命 branches より feature flags を優先する

### branch 命名

```
feature/<short-description>   → feature/task-creation
fix/<short-description>       → fix/duplicate-tasks
chore/<short-description>     → chore/update-deps
refactor/<short-description>  → refactor/auth-module
```

## Worktrees の使用

並列 AI agent 作業には git worktrees を使い、複数 branches を同時に走らせる:

```bash
git worktree add ../project-feature-a feature/task-creation
git worktree add ../project-feature-b feature/user-settings

ls ../
  project/              ← main branch
  project-feature-a/    ← task-creation branch
  project-feature-b/    ← user-settings branch

git worktree remove ../project-feature-a
```

利点:
- 複数 agents が異なる features を同時に扱える
- branch switching が不要（各 directory が own branch を持つ）
- experiment が失敗したら worktree を削除できる。何も失わない
- explicitly merged するまで変更は隔離される

## save point パターン

```
Agent starts work
    │
    ├── Makes a change
    │   ├── Test passes? → Commit → Continue
    │   └── Test fails? → Revert to last commit → Investigate
    │
    └── Feature complete → All commits form a clean history
```

この pattern により、失う可能性がある作業は常に 1 increment 以下になる。agent が脱線した場合、`git reset --hard HEAD` で最後の成功状態へ戻れる。

## 変更要約

変更後は構造化された summary を提供する。review を容易にし、scope discipline を文書化し、意図しない変更を表面化する:

```
CHANGES MADE:
- src/routes/tasks.ts: POST endpoint に validation middleware を追加
- src/lib/validation.ts: Zod による TaskCreateSchema を追加

THINGS I DIDN'T TOUCH (intentionally):
- src/routes/auth.ts: 同様の validation gap があるが、この task の範囲外
- src/middleware/error.ts: error format は改善余地あり（別 task）

POTENTIAL CONCERNS:
- Zod schema は strict。extra fields を拒否する。望む挙動か確認してください。
- zod dependency を追加（72KB gzipped）。package.json にはすでに存在。
```

特に "DIDN'T TOUCH" section は重要である。scope discipline を行使し、勝手な renovation をしなかったことを示す。

## commit 前の衛生

各 commit 前に:

```bash
git diff --staged
git diff --staged | grep -i "password\|secret\|api_key\|token"
npm test
npm run lint
npx tsc --noEmit
```

git hooks で自動化する:

```json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md}": ["prettier --write"]
  }
}
```

## 生成ファイルの扱い

- project が期待する場合だけ generated files を commit する（例: `package-lock.json`、Prisma migrations）
- build output（`dist/`、`.next/`）、environment files（`.env`）、IDE config（共有でない `.vscode/settings.json`）は commit しない
- `.gitignore` には `node_modules/`、`dist/`、`.env`、`.env.local`、`*.pem` を含める

## debugging に Git を使う

```bash
git bisect start
git bisect bad HEAD
git bisect good <known-good-commit>

git log --oneline -20
git diff HEAD~5..HEAD -- src/
git blame src/services/task.ts
git log --grep="validation" --oneline
```

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「feature が終わったら commit する」 | 巨大 commit は review、debug、revert が不可能に近い。slice ごとに commit する。 |
| 「message は重要でない」 | messages は documentation である。未来の自分と agents が、何がなぜ変わったかを理解する必要がある。 |
| 「後で全部 squash する」 | squash は development narrative を壊す。最初から clean incremental commits を優先する。 |
| 「branches は overhead」 | 短命 branches は無料で、衝突を防ぐ。問題は長命 branches である。1-3 日以内に merge する。 |
| 「後でこの変更を分ける」 | 大きな変更は review しにくく、deploy が risky で、revert しにくい。提出前に分割する。 |
| 「.gitignore は不要」 | production secrets を持つ `.env` が commit されるまではそう見える。すぐ設定する。 |

## 危険信号

- 大きな uncommitted changes が蓄積する
- "fix"、"update"、"misc" のような commit messages
- formatting changes と behavior changes が混ざる
- project に `.gitignore` がない
- `node_modules/`、`.env`、build artifacts を commit する
- main から大きく diverge した長命 branches
- shared branches への force-pushing

## 検証

各 commit で確認する:

- [ ] commit は 1 つの logical thing を行う
- [ ] message が why を説明し、type conventions に従う
- [ ] commit 前に tests が通る
- [ ] diff に secrets がない
- [ ] formatting-only changes が behavior changes と混ざっていない
- [ ] `.gitignore` が standard exclusions をカバーしている
