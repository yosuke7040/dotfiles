---
name: ci-cd-and-automation
description: パイプラインとして CI/CD の設定を自動化する。build と deployment pipelines を設定または変更する場合に使う。quality gates の自動化、CI 内 test runners の設定、deployment strategies の確立が必要な場合に使う。
---

# CI/CD と自動化

## 概要

tests、lint、type checking、build を通らない変更が production へ届かないよう、quality gates を自動化する。CI/CD は他のすべてのスキルを強制する仕組みである。人間やエージェントが見逃すものを捕まえ、すべての変更で一貫して実行する。

**Shift Left:** できるだけ pipeline の早い段階で問題を捕まえる。lint で捕まる bug は数分で済むが、production で捕まる同じ bug は何時間もかかる。checks を上流へ動かす。tests の前に static analysis、staging の前に tests、production の前に staging。

**Faster is Safer:** 小さな batch と頻繁な release は risk を増やすのではなく減らす。3 変更の deployment は 30 変更の deployment より debug しやすい。頻繁な release は release process 自体への信頼を育てる。

## 使う場面

- 新しいプロジェクトの CI pipeline を設定する
- automated checks を追加または変更する
- deployment pipelines を設定する
- 変更が automated verification を trigger すべきである
- CI failures を debug する

## quality gate pipeline

すべての変更は merge 前に次の gates を通る:

```
Pull Request Opened
    │
    ▼
┌─────────────────┐
│   LINT CHECK     │  eslint, prettier
│   ↓ pass         │
│   TYPE CHECK     │  tsc --noEmit
│   ↓ pass         │
│   UNIT TESTS     │  jest/vitest
│   ↓ pass         │
│   BUILD          │  npm run build
│   ↓ pass         │
│   INTEGRATION    │  API/DB tests
│   ↓ pass         │
│   E2E (optional) │  Playwright/Cypress
│   ↓ pass         │
│   SECURITY AUDIT │  npm audit
│   ↓ pass         │
│   BUNDLE SIZE    │  bundlesize check
└─────────────────┘
    │
    ▼
  Ready for review
```

**gate は省略できない。** lint が失敗したら lint を直す。rule を無効化しない。test が失敗したら code を直す。test を skip しない。

## GitHub Actions 設定

### 基本 CI pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      - name: Install dependencies
        run: npm ci
      - name: Lint
        run: npm run lint
      - name: Type check
        run: npx tsc --noEmit
      - name: Test
        run: npm test -- --coverage
      - name: Build
        run: npm run build
      - name: Security audit
        run: npm audit --audit-level=high
```

### database integration tests 付き

```yaml
  integration:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: ci_user
          POSTGRES_PASSWORD: ${{ secrets.CI_DB_PASSWORD }}
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - name: Run migrations
        run: npx prisma migrate deploy
        env:
          DATABASE_URL: postgresql://ci_user:${{ secrets.CI_DB_PASSWORD }}@localhost:5432/testdb
      - name: Integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://ci_user:${{ secrets.CI_DB_PASSWORD }}@localhost:5432/testdb
```

> **注意:** CI-only test databases でも、credentials は hardcode せず GitHub Secrets を使う。良い習慣を作り、test credentials の他 context への誤用を防ぐ。

### E2E tests

```yaml
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - name: Install Playwright
        run: npx playwright install --with-deps chromium
      - name: Build
        run: npm run build
      - name: Run E2E tests
        run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```

## CI failures をエージェントへ戻す

AI agents と CI の力は feedback loop にある。CI が失敗したら:

```
CI fails
    │
    ▼
failure output を copy
    │
    ▼
agent へ渡す:
"CI pipeline failed with this error:
[specific error]
Fix the issue and verify locally before pushing again."
    │
    ▼
Agent fixes → pushes → CI runs again
```

**主要 pattern:**

```
Lint failure → agent が `npm run lint --fix` を実行して commit
Type error   → agent が error location を読み、type を修正
Test failure → agent が debugging-and-error-recovery skill に従う
Build error  → agent が config と dependencies を確認
```

## deployment strategies

### preview deployments

すべての PR に manual testing 用 preview deployment を用意する:

```yaml
deploy-preview:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - uses: actions/checkout@v4
    - name: Deploy preview
      run: npx vercel --token=${{ secrets.VERCEL_TOKEN }}
```

### feature flags

feature flags は deployment と release を分離する。未完成または risky な機能を flags の背後へ deploy すると、次が可能になる:

- **code を有効化せず ship する。** 早く main へ merge し、準備できたら enable する。
- **redeploy なしで rollback する。** code を revert せず flag を disable する。
- **新機能を canary する。** 1% の users、次に 10%、最後に 100% へ enable する。
- **A/B tests を行う。** feature あり/なしの behavior を比較する。

```typescript
if (featureFlags.isEnabled('new-checkout-flow', { userId })) {
  return renderNewCheckout();
}
return renderLegacyCheckout();
```

**Flag lifecycle:** Create → Enable for testing → Canary → Full rollout → flag と dead code を削除。永遠に残る flags は technical debt になる。作成時に cleanup date を設定する。

### staged rollouts

```
PR merged to main
    │
    ▼
  Staging deployment (auto)
    │ Manual verification
    ▼
  Production deployment (manual trigger or auto after staging)
    │
    ▼
  Monitor for errors (15-minute window)
    │
    ├── Errors detected → Rollback
    └── Clean → Done
```

### rollback plan

すべての deployment は戻せるようにする:

```yaml
name: Rollback
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to'
        required: true
jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Rollback deployment
        run: npx vercel rollback ${{ inputs.version }}
```

## environment management

```
.env.example        → commit する（developers 用 template）
.env                → commit しない（local development）
.env.test           → commit する（test environment、real secrets なし）
CI secrets          → GitHub Secrets / vault に保存
Production secrets  → deployment platform / vault に保存
```

CI は production secrets を持ってはならない。CI testing には別 secrets を使う。

## CI を超えた自動化

### Dependabot / Renovate

```yaml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
```

### build cop role

CI を green に保つ担当を決める。build が壊れたら、Build Cop の仕事は fix または revert することであり、壊した change の作者である必要はない。これにより、誰かが直すだろうという前提で broken builds が蓄積するのを防ぐ。

### PR checks

- **Required reviews:** merge 前に少なくとも 1 approval
- **Required status checks:** merge 前に CI pass 必須
- **Branch protection:** main への force-pushes 禁止
- **Auto-merge:** すべての checks が pass し approved なら自動 merge

## CI optimization

pipeline が 10 分を超える場合、impact 順に適用する:

```
Slow CI pipeline?
├── Cache dependencies
├── Run jobs in parallel
├── Only run what changed
├── Use matrix builds
├── Optimize the test suite
└── Use larger runners
```

例:
```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm run lint
```

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「CI が遅すぎる」 | pipeline を最適化する。省かない。5 分の pipeline は何時間もの debug を防ぐ。 |
| 「この変更は trivial だから CI を skip」 | trivial changes も build を壊す。CI は trivial changes では速い。 |
| 「test が flaky だから再実行でよい」 | flaky tests は実 bug を隠し、全員の時間を浪費する。flakiness を直す。 |
| 「CI は後で追加する」 | CI のない project は broken states を蓄積する。初日に設定する。 |
| 「manual testing で十分」 | manual testing は scale せず repeatable でもない。可能なものは自動化する。 |

## 危険信号

- project に CI pipeline がない
- CI failures が無視または黙殺される
- pipeline を通すために CI で tests を無効化する
- staging verification なしの production deploys
- rollback mechanism がない
- code または CI config files に secrets がある
- CI が長いのに最適化努力がない

## 検証

CI 設定または変更後に確認する:

- [ ] すべての quality gates がある（lint、types、tests、build、audit）
- [ ] pipeline がすべての PR と main への push で実行される
- [ ] failures が merge を block する（branch protection configured）
- [ ] CI results が development loop へ戻される
- [ ] secrets は code ではなく secrets manager に保存されている
- [ ] deployment に rollback mechanism がある
- [ ] test suite の pipeline が 10 分未満で走る
