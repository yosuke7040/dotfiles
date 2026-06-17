# パフォーマンスチェックリスト

web application performance のクイックリファレンス。`performance-optimization` skill と併用する。

## 目次

- [Core Web Vitals Targets](#core-web-vitals-targets)
- [TTFB Diagnosis](#ttfb-diagnosis)
- [Frontend Checklist](#frontend-checklist)
- [Backend Checklist](#backend-checklist)
- [Measurement Commands](#measurement-commands)
- [Common Anti-Patterns](#common-anti-patterns)

## Core Web Vitals 目標

| 指標 | 良好 | 改善が必要 | 不良 |
|---|---|---|---|
| LCP（Largest Contentful Paint） | <= 2.5s | <= 4.0s | > 4.0s |
| INP（Interaction to Next Paint） | <= 200ms | <= 500ms | > 500ms |
| CLS（Cumulative Layout Shift） | <= 0.1 | <= 0.25 | > 0.25 |

## TTFB 診断

TTFB が遅い（> 800ms）場合、DevTools Network waterfall で各 component を確認する。

- [ ] **DNS resolution** が遅い → known origins に `<link rel="dns-prefetch">` または `<link rel="preconnect">` を追加する
- [ ] **TCP / TLS handshake** が遅い → HTTP/2 を enable し、edge deployment を検討し、keep-alive を確認する
- [ ] **server processing** が遅い → backend を profile し、slow queries を確認し、caching を追加する

## フロントエンドチェックリスト

### 画像

- [ ] images は modern formats（WebP、AVIF）を使う
- [ ] images は responsive sizing（`srcset` と `sizes`）を使う
- [ ] images と `<source>` elements に明示的な `width` と `height` がある（art direction で CLS を防ぐ）
- [ ] below-the-fold images は `loading="lazy"` と `decoding="async"` を使う
- [ ] Hero / LCP images は `fetchpriority="high"` を使い、lazy loading しない

### JavaScript

- [ ] bundle size は 200KB gzipped 未満（initial load）
- [ ] routes と heavy features は dynamic `import()` で code splitting
- [ ] tree shaking が enabled（dependency が ESM を ship し、`sideEffects: false` を mark していることを verify）
- [ ] `<head>` に blocking JavaScript がない（`defer` または `async` を使う）
- [ ] heavy computation は Web Workers へ offload（該当する場合）
- [ ] expensive components が same props で re-render する場合は `React.memo()`
- [ ] `useMemo()` / `useCallback()` は profiling で benefit が示された場所だけ
- [ ] long tasks（> 50ms）を分割し、main thread を空ける。INP の主 lever
- [ ] long-running loops 内で `yieldToMain` pattern を使い、chunks 間で input events が走れるようにする
- [ ] 利用可能なら modern scheduling APIs を使う: `scheduler.yield()`（preferred）、priority 付き `scheduler.postTask()`、必要時だけ yield する `isInputPending()`
- [ ] deferrable / non-urgent work（analytics flush、prefetch、warmup）には `requestIdleCallback`
- [ ] non-critical work を event handlers から defer し、interaction response を遅らせない（例: analytics、logging）
- [ ] third-party scripts は `async` / `defer` で読み込み、size を audit し、heavy な場合は facade を挟む（chat widgets、embeds）

### CSS

- [ ] critical CSS を inline または preload している
- [ ] non-critical styles に render-blocking CSS がない
- [ ] production で CSS-in-JS runtime cost がない（extraction を使う）

### フォント

- [ ] font families は 2-3、各 2-3 weights に制限（追加 weight は request 増）
- [ ] WOFF2 format のみ（最小で広く対応。WOFF / TTF / EOT は避ける）
- [ ] 可能なら self-hosted（third-party font CDNs は DNS + TCP + TLS round-trips を追加）
- [ ] LCP-critical fonts は preload: `<link rel="preload" as="font" type="font/woff2" crossorigin>`
- [ ] render blocking を避けるため `font-display: swap`（non-critical は `optional`）
- [ ] `unicode-range` で subset し、page に必要な glyphs だけ ship する
- [ ] 複数 weights / styles が必要なら variable fonts を検討（一つの file が多数を置き換える）
- [ ] font swap による CLS を減らすため fallback font metrics を `size-adjust`、`ascent-override`、`descent-override` で調整
- [ ] custom font の前に system font stack を検討する

### Network

- [ ] static assets は long `max-age` + content hashing で cache
- [ ] API responses は適切な場所で cache（`Cache-Control`）
- [ ] HTTP/2 または HTTP/3 enabled
- [ ] known origins に resources を preconnect（`<link rel="preconnect">`）
- [ ] critical non-image resources に `fetchpriority` を使う（例: key `<link rel="preload">`、above-the-fold `<script>`）。`<img>` だけではない
- [ ] 不要な redirects がない

### Rendering

- [ ] layout thrashing（forced synchronous layouts）がない
- [ ] animations は `transform` と `opacity` を使う（GPU-accelerated）
- [ ] long lists は virtualization を使う（例: `react-window`）
- [ ] 不要な full-page re-renders がない
- [ ] off-screen sections に `content-visibility: auto` と `contain-intrinsic-size` を使い、non-visible areas の layout / paint を skip
- [ ] `unload` event handlers がなく、HTML responses に `Cache-Control: no-store` がない。back / forward cache（bfcache）eligibility を保つ

## バックエンドチェックリスト

### データベース

- [ ] N+1 query patterns がない（eager loading / joins を使う）
- [ ] queries に適切な indexes がある
- [ ] list endpoints は paginated（`SELECT * FROM table` は絶対にしない）
- [ ] connection pooling が configured
- [ ] slow query logging が enabled

### API

- [ ] response times < 200ms（p95）
- [ ] request handlers に synchronous heavy computation がない
- [ ] individual calls の loops ではなく bulk operations
- [ ] response compression（gzip / brotli）
- [ ] 適切な caching（in-memory、Redis、CDN）

### インフラ

- [ ] static assets に CDN
- [ ] server が users に近い場所にある（または edge deployment）
- [ ] horizontal scaling が configured（必要な場合）
- [ ] load balancer 向け health check endpoint

## 測定コマンド

### INP field data と DevTools workflow

1. **field data first** — optimize 前に [CrUX Vis](https://developer.chrome.com/docs/crux/vis) または RUM tool で real-user INP を確認する
2. **slow interactions を identify** — DevTools → Performance panel → interaction 中に record。clicks / keystrokes が trigger する long tasks を探す
3. **mid-range Android で test** — INP issues は slow hardware でだけ表面化することが多い。real device または DevTools CPU throttling（4x-6x slowdown）を使う

```bash
# Lighthouse CLI
npx lighthouse https://localhost:3000 --output json --output-path ./report.json

# bundle analysis
npx webpack-bundle-analyzer stats.json
# Vite の場合:
npx vite-bundle-visualizer

# bundle size を確認する
npx bundlesize

# code 内の Web Vitals
import { onLCP, onINP, onCLS } from 'web-vitals';
onLCP(console.log);
onINP(console.log);
onCLS(console.log);

# interaction-level detail 付き INP（attribution build）
import { onINP } from 'web-vitals/attribution';
onINP(({ value, attribution }) => {
  const { interactionTarget, inputDelay, processingDuration, presentationDelay } = attribution;
  console.log({ value, interactionTarget, inputDelay, processingDuration, presentationDelay });
});
```

## よくあるアンチパターン

| アンチパターン | 影響 | 修正 |
|---|---|---|
| N+1 queries | DB load が線形に増える | joins、includes、batch loading を使う |
| unbounded queries | memory exhaustion、timeouts | 常に paginate し、LIMIT を追加する |
| missing indexes | data 増加に伴う slow reads | filtered / sorted columns に indexes を追加する |
| layout thrashing | jank、dropped frames | DOM reads をまとめ、次に writes をまとめる |
| unoptimized images | slow LCP、wasted bandwidth | WebP、responsive sizes、lazy load を使う |
| large bundles | slow Time to Interactive | code split、tree shake、deps audit |
| blocking main thread | poor INP、unresponsive UI | `scheduler.yield()` / `yieldToMain` で long tasks を chunk し、Web Workers へ offload |
| memory leaks | memory 増加、最終的な crash | listeners、intervals、refs を cleanup する |
