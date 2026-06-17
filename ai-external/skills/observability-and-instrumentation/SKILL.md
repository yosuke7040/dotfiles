---
name: observability-and-instrumentation
description: 本番での振る舞いが見え、診断できるよう code を計装する。logging、metrics、tracing、alerting を追加する場合に使う。production で動く機能を ship し、それが動いている証拠が必要な場合に使う。production issue が報告されたが、手元の data から何が起きたか分からない場合に使う。
---

# オブザーバビリティと計測

## 概要

観測できない code は運用できない。observability は、code が出す telemetry を使い、外から「system は何をしていて、なぜそうしているか」に答える能力である。instrumentation は launch 後の後付けではない。tests と同じように feature と一緒に書く。telemetry なしで feature を ship すると、最初の user-reported bug は query ではなく発掘作業になる。

## 使う場面

- production で動く feature を作る
- 新しい service、endpoint、background job、external integration を追加する
- production incident の診断に時間がかかりすぎた
- alerting rules を設定またはレビューする
- I/O、retries、queues、cross-service calls を追加する PR をレビューする

**使わない場面:**
- 今起きている failure の診断。`debugging-and-error-recovery` を使う
- 測定済みの遅さの profiling と optimization。`performance-optimization` を使う
- launch-day monitoring checklist と rollback triggers。`shipping-and-launch` を参照する

## プロセス

### 1. instrument 前に「動いている」を定義する

問いのない telemetry は noise である。計測を追加する前に、この feature について on-call engineer が尋ねる 2 から 4 個の質問を書く:

```
FEATURE: checkout payment retry
QUESTIONS ON-CALL WILL ASK:
1. payments のうち first attempt 成功と retry 後成功の割合は？
2. permanent failure の理由は？ provider error、timeout、validation?
3. payment provider は普段より遅いか？
→ 下の各 signal は、このどれかに答える必要がある。
```

質問を名付けられないなら、まだ instrument する準備ができていない。すべてを log し、何も学べない。

### 2. 質問ごとに正しい signal を選ぶ

| Signal | 答えること | cost profile | 例 |
|--------|------------|--------------|----|
| **Structured log** | この specific case で何が起きたか | event ごと。traffic とともに増える | provider error code 付き `payment_failed` |
| **Metric** | aggregate でどれくらい頻繁か、どれくらい速いか | series ごとに固定。query が安い | provider calls の p99 latency |
| **Trace** | services をまたいで時間がどこへ消えたか | request ごと。通常 sampled | slow checkout を hop ごとに分解 |

目安: metrics は **何かが悪いこと** を教え、traces は **どこが悪いか** を教え、logs は **なぜ悪いか** を教える。

### 3. structured logging

prose ではなく events を log する。すべての log line は stable event name と machine-readable fields を持つ JSON object にする。

```typescript
// 悪い例: string interpolation。query しにくく一貫しない
logger.info(`Payment ${id} failed for user ${userId} after ${n} retries`);

// 良い例: stable event name + structured fields
logger.warn({
  event: 'payment_failed',
  paymentId: id,
  provider: 'stripe',
  errorCode: err.code,
  attempt: n,
}, 'payment failed');
```

**Log levels は一貫して使う:**

| Level | 意味 | on-call action |
|-------|------|----------------|
| `error` | invariant が壊れた。誰かが action すべき可能性 | Investigate |
| `warn` | degraded だが handled（retry succeeded、fallback used） | trends を見る |
| `info` | significant business event（order placed、job finished） | なし |
| `debug` | diagnostic detail | production では既定で off |

**Correlation IDs は必須。** system boundary で request ID を生成または受け入れ、すべての log line、span、outbound call に付ける。これがないと、interleaved logs から単一 request を再構築できない。

```typescript
app.use((req, res, next) => {
  req.id = req.headers['x-request-id'] ?? crypto.randomUUID();
  req.log = logger.child({ requestId: req.id });
  res.setHeader('x-request-id', req.id);
  next();
});
```

**secrets、tokens、passwords、full PII を log してはならない。** telemetry pipeline は典型的な data-leak path である。fields は allowlist し、request bodies 全体を log しない。

### 4. metrics

request-driven services では、すべての endpoint と external dependency に **RED** を instrument する。**R**ate、**E**rrors、**D**uration（average ではなく latency histogram）。resources（queues、pools、hosts）には **USE** を使う。**U**tilization、**S**aturation、**E**rrors。

```typescript
import { Histogram } from 'prom-client';

const httpDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route', 'status_class'],  // '200' ではなく '2xx'
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
});
```

**Cardinality が失敗モードである。** unique label combination は別 time series になる。labels は small fixed sets（route template、status class、provider name）にする。user IDs、raw URLs、error messages、unbounded values は labels にしない。logs と traces に入れる。

```
OK as label:    route="/api/tasks/:id"   status_class="5xx"   provider="stripe"
NEVER a label:  user_id, email, request_id, full URL, error message text
```

average ではなく percentiles を見る。average はひどい体験をしている 1% の users を隠す。histograms を使い、p50/p95/p99 を読む。

### 5. distributed tracing

OpenTelemetry を使う。vendor-neutral standard であり、auto-instrumentation は HTTP、gRPC、common DB clients をほぼ code なしで cover する。

```typescript
// tracing.ts。何より先に import される必要がある
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  serviceName: 'checkout-service',
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

manual spans は意味のある internal units of work（例: `applyDiscounts`、`chargeProvider`）だけに追加し、on-call が filter する attributes を付ける。HTTP headers や queue message metadata など、すべての async boundary で context を propagate する。通常は低率の head-based sampling、backend が対応するなら errors は 100% 保持する。

### 6. alerting

alerts は **users が感じる症状** に対して出す。原因ではない。

```
SYMPTOM (page-worthy):           CAUSE (dashboard, not a page):
error rate > 1% for 5 min        CPU at 85%
p99 latency > 2s                 one pod restarted
queue age > 10 min               disk at 70%
```

cause-based alerts は問題がないときに鳴り、予測しなかった failure を見逃す。symptom-based alerts は、原因に関係なく users が傷ついたときに鳴る。

alert 作成時の rules:

1. **actionable である。** response が「無視。self-heals」なら alert を削除する。
2. **runbook へ link する。** 3 行でもよい。意味、最初に実行する query、escalation path。
3. **threshold と duration** は SLO または historical data に基づく。推測ではない。
4. severity は **page**（user-facing、今 action）と **ticket**（degradation、今週 action）の 2 つだけにする。3 層目は noise になり、無視を学習させる。

### 7. telemetry 自体を検証する

instrumentation も code であり、間違える。完了扱いの前に path を発火させ、実際の output を見る:

- staging で error を強制 → `requestId` で logs を見つけ、fields が structured であることを確認
- test traffic を送る → expected labels と sane values の metric series が出ることを確認
- tracing UI で 1 request を services 横断で追う → broken spans なし
- 新しい alert を 1 回発火（threshold を一時的に下げる） → 正しい channel へ届き、runbook link が動くことを確認

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「動いたら logging を追加する」 | 「後」は最初の incident 後になりがちで、盲目だと気付く最も高価な瞬間である。作りながら instrument する。 |
| 「logs が多いほど observability が高い」 | unstructured noise は incident を遅くする。query できる 3 events は prose 300 行に勝る。 |
| 「console.log で今は十分」 | unstructured output は filter、correlate、alert ができない。structured logger の追加 cost は一度だけ 5 分である。 |
| 「壊れたら dashboards を見ればよい」 | 質問なしで作った dashboards は、答え以外のすべてを見せる。on-call questions から始める。 |
| 「重要そうなものは全部 alert し、後で tune する」 | noisy pager は無視を訓練する。tuning は起きず、本物の page を見逃す。 |
| 「metric label に user ID を入れると debug が楽」 | metrics backend が倒れる。high-cardinality lookup は logs と traces に属する。 |
| 「2 services しかないので tracing は過剰」 | 2 services でも logs だけでは cross-service latency に答えられない。auto-instrumentation の cost は小さい。 |

## 危険信号

- retries、queues、external calls を含む feature PR に telemetry がない
- structured fields ではなく string interpolation で作られた log lines
- correlation/request ID がない。各 log line が孤立している
- metrics labels に user IDs、raw URLs、error message text がある（cardinality bomb）
- latency を average だけで追い、percentiles がない
- 毎日鳴り、action なしに acknowledge される alerts
- user-facing error rate を監視せず、CPU や memory など causes で humans を page する
- logs に secrets、tokens、full request bodies が出る
- production feature が healthy である証拠が「自分の machine では動く」だけ

## 検証

feature を instrument した後に確認する:

- [ ] この feature の on-call questions が書かれており、各 signal がそのどれかに対応する
- [ ] すべての log output が structured（JSON）で、stable event names と各行の correlation ID を持つ
- [ ] log line に secrets、tokens、unredacted PII がない（実 output を spot-check）
- [ ] 新しい endpoint と external dependency すべてに bounded label sets の RED metrics がある
- [ ] latency は histogram で、p95/p99 が query できる
- [ ] tracing UI で単一 request を end-to-end に追え、broken spans がない
- [ ] すべての new alert が symptom-based で、runbook link を持ち、1 回 test-fired されている
- [ ] staging で誘発した failure を source を読まず telemetry だけで発見できた
