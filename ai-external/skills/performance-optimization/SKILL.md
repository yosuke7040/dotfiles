---
name: performance-optimization
description: アプリケーション性能を最適化する。性能要件がある場合、性能回帰が疑われる場合、Core Web Vitals または load times の改善が必要な場合に使う。profiling により修正すべき bottleneck が見つかった場合に使う。
---

# 性能最適化

## 概要

最適化の前に測定する。測定なしの性能作業は推測であり、重要でないものへ複雑さを足す早すぎる最適化につながる。まず profile し、実際の bottleneck を特定し、修正し、再測定する。測定で重要だと証明されたものだけを最適化する。

## 使う場面

- 仕様に性能要件がある（load time budgets、response time SLAs）
- ユーザーまたは monitoring が遅さを報告している
- Core Web Vitals scores が閾値を下回っている
- 変更が regression を導入した疑いがある
- 大規模 dataset または high traffic を扱う機能を作る

**使わない場面:** 問題の証拠がないうちは最適化しない。早すぎる最適化は、得られる性能より高い複雑さを生む。

## Core Web Vitals 目標

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| **LCP** (Largest Contentful Paint) | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| **INP** (Interaction to Next Paint) | ≤ 200ms | ≤ 500ms | > 500ms |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

## 最適化ワークフロー

```
1. MEASURE  → real data で baseline を作る
2. IDENTIFY → actual bottleneck を見つける（仮定ではない）
3. FIX      → specific bottleneck に対処する
4. VERIFY   → 再測定し、改善を確認する
5. GUARD    → monitoring または tests を追加し regression を防ぐ
```

### ステップ 1: 測定する

補完的な 2 つのアプローチを両方使う:

- **Synthetic（Lighthouse、DevTools Performance tab）:** 制御された条件で再現可能。CI regression detection と specific issues の切り分けに向く。
- **RUM（web-vitals library、CrUX）:** 実ユーザーの実条件データ。修正が user experience を実際に改善したか検証するのに必要。

**Frontend:**
```bash
# synthetic: Chrome DevTools（または CI）の Lighthouse
# Chrome DevTools → Performance tab → Record
# Chrome DevTools MCP → Performance trace

# RUM: code 内の Web Vitals library
import { onLCP, onINP, onCLS } from 'web-vitals';

onLCP(console.log);
onINP(console.log);
onCLS(console.log);
```

**Backend:**
```bash
# response time logging
# application performance monitoring (APM)
# timing 付き database query logging

# simple timing
console.time('db-query');
const result = await db.query(...);
console.timeEnd('db-query');
```

### どこから測るか

症状で最初に測るものを決める:

```
何が遅いか
├── First page load
│   ├── Large bundle? --> bundle size を測り、code splitting を確認
│   ├── Slow server response? --> DevTools Network waterfall で TTFB を測る
│   │   ├── DNS long? --> known origins へ dns-prefetch / preconnect
│   │   ├── TCP/TLS long? --> HTTP/2、edge deployment、keep-alive を確認
│   │   └── Waiting (server) long? --> backend profile、queries と caching を確認
│   └── Render-blocking resources? --> CSS/JS blocking を network waterfall で確認
├── Interaction feels sluggish
│   ├── UI freezes on click? --> main thread を profile、long tasks (>50ms) を探す
│   ├── Form input lag? --> re-renders、controlled component overhead を確認
│   └── Animation jank? --> layout thrashing、forced reflows を確認
├── Page after navigation
│   ├── Data loading? --> API response times、waterfalls を測る
│   └── Client rendering? --> component render time、N+1 fetches を確認
└── Backend / API
    ├── Single endpoint slow? --> database queries を profile、indexes を確認
    ├── All endpoints slow? --> connection pool、memory、CPU を確認
    └── Intermittent slowness? --> lock contention、GC pauses、external deps を確認
```

### ステップ 2: bottleneck を特定する

代表的な bottleneck:

**Frontend:**

| 症状 | あり得る原因 | 調査 |
|------|--------------|------|
| Slow LCP | 大きな画像、render-blocking resources、遅い server | network waterfall、image sizes を確認 |
| High CLS | dimensions なし画像、late-loading content、font shifts | layout shift attribution を確認 |
| Poor INP | main thread 上の重い JavaScript、大きな DOM updates | Performance trace で long tasks を確認 |
| Slow initial load | 大きな bundle、多数の network requests | bundle size、code splitting を確認 |

**Backend:**

| 症状 | あり得る原因 | 調査 |
|------|--------------|------|
| Slow API responses | N+1 queries、missing indexes、unoptimized queries | database query log を確認 |
| Memory growth | leaked references、unbounded caches、large payloads | heap snapshot analysis |
| CPU spikes | synchronous heavy computation、regex backtracking | CPU profiling |
| High latency | missing caching、redundant computation、network hops | requests を stack 全体で trace |

### ステップ 3: よくあるアンチパターンを修正する

#### N+1 queries（backend）

```typescript
// 悪い例: N+1。owner ごとに task 1 件につき 1 query
const tasks = await db.tasks.findMany();
for (const task of tasks) {
  task.owner = await db.users.findUnique({ where: { id: task.ownerId } });
}

// 良い例: join/include 付き single query
const tasks = await db.tasks.findMany({
  include: { owner: true },
});
```

#### 上限のないデータ取得

```typescript
// 悪い例: 全 records を取得
const allTasks = await db.tasks.findMany();

// 良い例: limits 付き pagination
const tasks = await db.tasks.findMany({
  take: 20,
  skip: (page - 1) * 20,
  orderBy: { createdAt: 'desc' },
});
```

#### 画像最適化漏れ（Frontend）

```html
<!-- 悪い例: dimensions なし、format optimization なし -->
<img src="/hero.jpg" />

<!-- 良い例: Hero / LCP image。art direction + resolution switching、高 priority -->
<picture>
  <source media="(max-width: 767px)" srcset="/hero-mobile-400.avif 400w, /hero-mobile-800.avif 800w" sizes="100vw" width="800" height="1000" type="image/avif" />
  <source media="(max-width: 767px)" srcset="/hero-mobile-400.webp 400w, /hero-mobile-800.webp 800w" sizes="100vw" width="800" height="1000" type="image/webp" />
  <source srcset="/hero-800.avif 800w, /hero-1200.avif 1200w, /hero-1600.avif 1600w" sizes="(max-width: 1200px) 100vw, 1200px" width="1200" height="600" type="image/avif" />
  <source srcset="/hero-800.webp 800w, /hero-1200.webp 1200w, /hero-1600.webp 1600w" sizes="(max-width: 1200px) 100vw, 1200px" width="1200" height="600" type="image/webp" />
  <img src="/hero-desktop.jpg" width="1200" height="600" fetchpriority="high" alt="Hero image description" />
</picture>

<!-- 良い例: below-the-fold image。lazy load + async decoding -->
<img src="/content.webp" width="800" height="400" loading="lazy" decoding="async" alt="Content image description" />
```

#### 不要な再レンダー（React）

```tsx
// 悪い例: render ごとに new object を作り、children が re-render する
function TaskList() {
  return <TaskFilters options={{ sortBy: 'date', order: 'desc' }} />;
}

// 良い例: stable reference
const DEFAULT_OPTIONS = { sortBy: 'date', order: 'desc' } as const;
function TaskList() {
  return <TaskFilters options={DEFAULT_OPTIONS} />;
}

// expensive components には React.memo を使う
const TaskItem = React.memo(function TaskItem({ task }: Props) {
  return <div>{/* expensive render */}</div>;
});

// expensive computations には useMemo を使う
function TaskStats({ tasks }: Props) {
  const stats = useMemo(() => calculateStats(tasks), [tasks]);
  return <div>{stats.completed} / {stats.total}</div>;
}
```

#### 大きな bundle size

```typescript
// modern bundlers（Vite、webpack 5+）は、dependency が ESM を提供し、
// package.json で `sideEffects: false` と示していれば named imports を tree-shaking する。
// import style を変える前に profile する。実際の gain は splitting と lazy loading から来る。

// 良い例: 重く、めったに使わない機能の dynamic import
const ChartLibrary = lazy(() => import('./ChartLibrary'));

// 良い例: Suspense で包んだ route-level code splitting
const SettingsPage = lazy(() => import('./pages/Settings'));
```

#### caching 漏れ（backend）

```typescript
// よく読まれ、めったに変わらない data を cache
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes
let cachedConfig: AppConfig | null = null;
let cacheExpiry = 0;

async function getAppConfig(): Promise<AppConfig> {
  if (cachedConfig && Date.now() < cacheExpiry) return cachedConfig;
  cachedConfig = await db.config.findFirst();
  cacheExpiry = Date.now() + CACHE_TTL;
  return cachedConfig;
}
```

## performance budget

budgets を設定し、強制する:

```
JavaScript bundle: < 200KB gzipped（initial load）
CSS: < 50KB gzipped
Images: < 200KB per image（above the fold）
Fonts: < 100KB total
API response time: < 200ms（p95）
Time to Interactive: < 3.5s on 4G
Lighthouse Performance score: ≥ 90
```

**CI で強制:**
```bash
npx bundlesize --config bundlesize.config.json
npx lhci autorun
```

## 関連資料

詳細な performance checklists、optimization commands、anti-pattern reference は `references/performance-checklist.md` を参照する。

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「後で最適化する」 | performance debt は複利で増える。明らかな anti-pattern は今直し、micro-optimizations は defer する。 |
| 「自分の machine では速い」 | あなたの machine はユーザーの machine ではない。代表的な hardware と network で profile する。 |
| 「この最適化は明らか」 | 測っていなければ分からない。先に profile する。 |
| 「100ms はユーザーに気づかれない」 | 100ms の遅延が conversion rates に影響することが示されている。ユーザーは思うより気付く。 |
| 「framework が性能を扱ってくれる」 | framework は一部の問題を防ぐが、N+1 queries や oversized bundles は直せない。 |

## 危険信号

- profiling data なしで最適化する
- data fetching に N+1 query patterns がある
- pagination のない list endpoints
- dimensions、lazy loading、responsive sizes のない images
- review なしに bundle size が増える
- production monitoring がない
- `React.memo` と `useMemo` をどこにでも使う（使いすぎは使わなすぎと同じくらい悪い）

## 検証

性能関連変更後に確認する:

- [ ] before/after measurements が存在する（具体的な数値）
- [ ] specific bottleneck が特定され、対処されている
- [ ] Core Web Vitals が "Good" thresholds 内である
- [ ] bundle size が大きく増えていない
- [ ] 新しい data fetching code に N+1 queries がない
- [ ] 設定されている場合、performance budget が CI で通る
- [ ] 既存テストが通る（最適化が振る舞いを壊していない）
