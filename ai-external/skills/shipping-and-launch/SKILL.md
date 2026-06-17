---
name: shipping-and-launch
description: 本番 launch を準備する。production へ deploy する準備をする場合に使う。launch 前チェックリスト、monitoring setup、staged rollout planning、または rollback strategy が必要な場合に使う。
---

# リリースとローンチ

## 概要

自信を持って ship する。目標は deploy することだけではない。monitoring を用意し、rollback plan を準備し、success の定義を理解したうえで安全に deploy することである。すべての launch は reversible、observable、incremental であるべきだ。

## 使う場面

- feature を初めて production へ deploy する
- users へ significant change を release する
- data または infrastructure を migrate する
- beta または early access program を開く
- risk を持つ deployment（つまりすべて）

## launch 前チェックリスト

### code quality

- [ ] すべての tests が通る（unit、integration、e2e）
- [ ] build が warnings なしで成功する
- [ ] lint と type checking が通る
- [ ] code reviewed and approved
- [ ] launch 前に解決すべき TODO comments がない
- [ ] production code に `console.log` debugging statements がない
- [ ] error handling が expected failure modes を cover する

### security

- [ ] code または version control に secrets がない
- [ ] `npm audit` に critical または high vulnerabilities がない
- [ ] user-facing endpoints すべてに input validation がある
- [ ] authentication と authorization checks がある
- [ ] security headers configured（CSP、HSTS など）
- [ ] authentication endpoints に rate limiting がある
- [ ] CORS は wildcard ではなく specific origins に設定されている

### performance

- [ ] Core Web Vitals が "Good" thresholds 内
- [ ] critical paths に N+1 queries がない
- [ ] images が optimized（compression、responsive sizes、lazy loading）
- [ ] bundle size が budget 内
- [ ] database queries に適切な indexes がある
- [ ] static assets と repeated queries に caching が設定されている

### accessibility

- [ ] all interactive elements で keyboard navigation が動く
- [ ] screen reader が page content と structure を伝えられる
- [ ] color contrast が WCAG 2.1 AA（text 4.5:1）を満たす
- [ ] modals と dynamic content の focus management が正しい
- [ ] error messages が説明的で form fields と関連づいている
- [ ] axe-core または Lighthouse に accessibility warnings がない

### infrastructure

- [ ] production に environment variables が設定されている
- [ ] database migrations が applied、または apply 準備済み
- [ ] DNS と SSL が configured
- [ ] CDN が static assets 用に configured
- [ ] logging と error reporting が configured
- [ ] health check endpoint が存在し、応答する

### documentation

- [ ] README が新しい setup requirements を反映
- [ ] API documentation が最新
- [ ] architectural decisions には ADRs がある
- [ ] changelog updated
- [ ] user-facing documentation updated（該当する場合）

## feature flag 戦略

deployment と release を分離するため、feature flags の背後で ship する:

```typescript
const flags = await getFeatureFlags(userId);

if (flags.taskSharing) {
  return <TaskSharingPanel task={task} />;
}

return null;
```

**Feature flag lifecycle:**

```
1. DEPLOY with flag OFF     → code は production にあるが inactive
2. ENABLE for team/beta     → production environment で internal testing
3. GRADUAL ROLLOUT          → users の 5% → 25% → 50% → 100%
4. MONITOR at each stage    → error rates、performance、user feedback を見る
5. CLEAN UP                 → full rollout 後に flag と dead code path を削除
```

**ルール:**
- 各 feature flag には owner と expiration date がある
- full rollout 後 2 週間以内に flags を cleanup する
- feature flags を nest しない（組み合わせが指数的に増える）
- CI では flag states（on/off）両方を test する

## staged rollout

### rollout sequence

```
1. DEPLOY to staging
   └── staging environment で full test suite
   └── critical flows の manual smoke test

2. DEPLOY to production (feature flag OFF)
   └── deployment succeeded を確認（health check）
   └── error monitoring を確認（new errors なし）

3. ENABLE for team (internal users だけ flag ON)
   └── team が production で feature を使う
   └── 24-hour monitoring window

4. CANARY rollout (users の 5% で flag ON)
   └── error rates、latency、user behavior を監視
   └── metrics を比較: canary vs. baseline
   └── 24-48 hour monitoring window

5. GRADUAL increase (25% -> 50% -> 100%)
   └── 各 step で同じ monitoring
   └── いつでも前 percentage へ rollback 可能

6. FULL rollout
   └── 1 週間 monitor
   └── feature flag を cleanup
```

### rollout 判断閾値

| Metric | Advance (green) | Hold and investigate (yellow) | Roll back (red) |
|--------|-----------------|-------------------------------|-----------------|
| Error rate | baseline の 10% 以内 | baseline より 10-100% 高い | baseline の 2x 超 |
| P95 latency | baseline の 20% 以内 | baseline より 20-50% 高い | baseline より 50% 超 |
| Client JS errors | new error types なし | sessions の <0.1% に new errors | sessions の >0.1% に new errors |
| Business metrics | neutral または positive | decline <5%（noise の可能性） | decline >5% |

### Roll Back する場面

次の場合は即 rollback:
- error rate が baseline の 2x を超える
- P95 latency が 50% 超増える
- user-reported issues が急増する
- data integrity issues が検出される
- security vulnerability が発見される

## monitoring と observability

### 監視するもの

```
Application metrics:
├── Error rate（total と endpoint 別）
├── Response time（p50, p95, p99）
├── Request volume
├── Active users
└── Key business metrics（conversion, engagement）

Infrastructure metrics:
├── CPU と memory utilization
├── Database connection pool usage
├── Disk space
├── Network latency
└── Queue depth（該当する場合）

Client metrics:
├── Core Web Vitals（LCP, INP, CLS）
├── JavaScript errors
├── client perspective の API error rates
└── Page load time
```

### error reporting

```typescript
class ErrorBoundary extends React.Component {
  componentDidCatch(error: Error, info: React.ErrorInfo) {
    reportError(error, {
      componentStack: info.componentStack,
      userId: getCurrentUser()?.id,
      page: window.location.pathname,
    });
  }
}

app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  reportError(err, {
    method: req.method,
    url: req.url,
    userId: req.user?.id,
  });

  res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: '問題が発生しました' },
  });
});
```

### launch 後検証

launch 後 1 時間で:

```
1. health endpoint が 200 を返す
2. error monitoring dashboard を確認（new error types なし）
3. latency dashboard を確認（regression なし）
4. critical user flow を手動で test
5. logs が流れ、読めることを確認
6. rollback mechanism が動くことを確認（可能なら dry run）
```

## rollback 戦略

すべての deployment には事前に rollback plan が必要である:

```markdown
## [Feature/Release] の rollback plan

### trigger conditions
- Error rate > 2x baseline
- P95 latency > [X]ms
- [specific issue] の user reports

### rollback steps
1. feature flag を disable（該当する場合）
   OR
1. previous version を deploy: `git revert <commit> && git push`
2. rollback を検証: health check、error monitoring
3. communication: rollback を team へ通知

### database considerations
- Migration [X] has a rollback: `npx prisma migrate rollback`
- 新 feature が挿入した data: [preserved / cleaned up]

### rollback 所要時間
- Feature flag: < 1 minute
- previous version redeploy: < 5 minutes
- Database rollback: < 15 minutes
```

## 関連資料

- security pre-launch checks は `references/security-checklist.md` を参照
- performance pre-launch checklist は `references/performance-checklist.md` を参照
- launch 前 accessibility verification は `references/accessibility-checklist.md` を参照

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「staging で動くから production でも動く」 | production には異なる data、traffic patterns、edge cases がある。deploy 後に monitor する。 |
| 「これに feature flags は不要」 | すべての feature は kill switch から利益を得る。「単純な」変更でも壊れる。 |
| 「monitoring は overhead」 | monitoring がないと、dashboard ではなく user complaints から問題を知ることになる。 |
| 「monitoring は後で追加する」 | launch 前に追加する。見えないものは debug できない。 |
| 「rollback は失敗を認めること」 | rollback は責任ある engineering である。壊れた feature を ship し続けることが失敗である。 |

## 危険信号

- rollback plan なしで deploy する
- production に monitoring または error reporting がない
- big-bang releases（すべて一度に、staging なし）
- expiration または owner のない feature flags
- deploy 後の最初の 1 時間を誰も monitor しない
- production environment configuration が code ではなく記憶で行われる
- 「金曜午後だけど ship しよう」

## 検証

deploy 前:

- [ ] Pre-launch checklist 完了（全 sections green）
- [ ] feature flag configured（該当する場合）
- [ ] rollback plan documented
- [ ] monitoring dashboards set up
- [ ] team notified of deployment

deploy 後:

- [ ] health check が 200 を返す
- [ ] error rate が normal
- [ ] latency が normal
- [ ] critical user flow が動く
- [ ] logs が流れている
- [ ] rollback が tested または ready であることを verified
