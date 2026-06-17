# オーケストレーションパターン

この repo が推奨する agent orchestration patterns と、避けるべき anti-patterns のリファレンス catalog。複数 persona を調整する新しい slash command を追加する前、または既存 persona を「wrap」する新しい persona を導入する前に読む。

支配的なルール: **orchestrator は user（または slash command）である。personas は他の personas を呼び出さない。** Skills は persona の workflow 内で必須の hop である。

---

## 推奨パターン

### 1. 直接呼び出し（orchestration なし）

単一 persona、単一 perspective、単一 artifact。default で、最も安い option。

```
user → code-reviewer → report → user
```

**使う場面:** 作業が一つの artifact に対する一つの perspective で、一文で説明できる場合。

**例:**

- "Review this PR" → `code-reviewer`
- "`auth.ts` の security issues を探して" → `security-auditor`
- "checkout flow に足りない tests は？" → `test-engineer`

**Cost:** one round trip。orchestrated patterns は常にこれを baseline として比較する。

---

### 2. 単一 persona の slash command

一つの persona を project の skills と一緒に wrap する slash command。user が毎回 workflow を説明し直さなくて済む。

```
/review → code-reviewer（code-review-and-quality skill 付き）→ report
```

**使う場面:** 同じ setup で同じ single-persona invocation が繰り返し発生する場合。

**この repo の例:** `/review`、`/test`、`/code-simplify`。

**Cost:** 直接呼び出しと同じ。slash command は保存済み prompt にすぎない。

**Anti-signal:** slash command の本文がほぼ「どの persona を呼ぶか決める」なら削除し、user に直接 persona を呼んでもらう。

---

### 3. 並列 fan-out と merge

複数 personas が同じ input に対して同時に動き、それぞれ独立した report を作る。main agent context 内の merge step が、それらを単一の decision へ synthesize する。

```
                    ┌─→ code-reviewer    ─┐
/ship → fan out  ───┼─→ security-auditor ─┤→ merge → go/no-go + rollback
                    └─→ test-engineer    ─┘
```

**使う場面:**

- sub-tasks が本当に独立している（shared mutable state なし、ordering dependency なし）
- 各 sub-agent が own context window から benefit を得る
- merge step が main context に収まるほど小さい
- wall-clock latency が重要

**この repo の例:** `/ship`。

**Cost:** N 個の parallel sub-agent contexts + one merge turn。直接呼び出しより高いが、wall-clock は速く、各 sub-agent が single perspective に集中するため reports は良くなる。

**この pattern を採用する前の validation checklist:**

- [ ] ordering issues なしですべての sub-agents を同時に実行できるか？
- [ ] 各 persona は同じ finding を別 angle から見るだけでなく、異なる **種類** の finding を出すか？
- [ ] merge step は main agent の remaining context に収まるか？
- [ ] user の待ち時間に対して parallelism が実際に体感できるほど効くか？

いずれかが "no" なら、直接呼び出しまたは single-persona command に戻す。

---

### 4. user-driven slash commands による sequential pipeline

user が定義された順序で slash commands を実行し、context（または commit history）を引き継ぐ。orchestrator agent はいない。**user が orchestrator** である。

```
user runs:  /spec  →  /plan  →  /build  →  /test  →  /review  →  /ship
```

**使う場面:** workflow に dependencies があり（各 step が前 step の output を必要とする）、steps 間の human judgment に価値がある場合。

**この repo の例:** DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP lifecycle 全体。

**Cost:** step ごとに one sub-agent context。orchestration layer は存在しないため free。

**自動化しない理由:** LLM の "lifecycle orchestrator" は (a) hand-off のために要約する必要があり、steps 間の nuance を失う、(b) wrong-direction work を早期に捕まえる human checkpoints を飛ばす、(c) paraphrasing turns により token cost が二重になる。

---

### 5. research isolation（context preservation）

main context を汚染すべきでない大量の material を読む必要がある場合、research sub-agent を spawn し、digest だけを返させる。

```
main agent → research sub-agent（50 files を読む）→ digest → main agent continues
```

**使う場面:**

- main session を downstream task に集中させる必要がある
- investigation result が consumed input よりはるかに小さい
- main agent に考える余白が残ることで decision quality が上がる

**例:** 「monorepo 全体で deprecated API の call sites をすべて見つける」「これら 30 ADRs が caching について何と言っているか summarize する」。

**Cost:** one isolated sub-agent context。代替が main context に hundreds of files を読むことなら、常に worth it。

**Claude Code では custom research persona ではなく built-in `Explore` subagent を使う。** `Explore` は Haiku で動き、write / edit tools が denied され、この pattern 専用に作られている。custom research subagent を定義するのは、`Explore` が合わない場合だけ（例: model が推測しない domain-specific system prompt が必要）。

---

## Claude Code 互換性

この catalog は harness-agnostic だが、多くの readers は Claude Code で使う。各 pattern が Claude Code primitives にどう mapping されるか、そして platform がこちらの rules をどこで enforce してくれるかを示す。

### personas の置き場所

Plugin subagents は plugin root の `agents/` に置く。この repo は plugin（`.claude-plugin/plugin.json`）なので、plugin が enabled のとき `agents/code-reviewer.md`、`agents/security-auditor.md`、`agents/test-engineer.md` は auto-discovered される。path configuration は不要。

### subagents vs. Agent Teams

Claude Code には二つの parallelism primitives がある。Pattern 3（parallel fan-out with merge）は **subagents** に対応する。teammates が互いに話す必要があるなら、代わりに **Agent Teams** を使う。

| | Subagents | Agent Teams |
|---|---|---|
| Coordination | main agent が fan out し、sub-agents は report back だけ | teammates が互いに message し、task list を共有する |
| Context | subagent ごとに own context window | teammate ごとに own context window |
| 使う場面 | reports を作る independent tasks | discussion が必要な collaborative work |
| Status | stable | experimental。`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` が必要 |
| Cost | 低い | 高い。teammate ごとに separate Claude instance |

**この repo の personas は両 mode で機能する。** subagents として spawn された場合（例: `/ship`）、main session へ findings を report する。teammates として spawn された場合（`Spawn a teammate using the security-auditor agent type…`）、互いの findings へ直接 challenge できる。persona definition は同じで、spawn context だけが違う。

微妙な点: persona の `skills` と `mcpServers` frontmatter fields は subagent として動く場合は honored されるが、**teammate として動く場合は ignored** される。teammates は regular session と同じく project / user settings から skills と MCP servers を load する。persona が特定 skill や MCP server の読み込みに依存するなら、両 mode で available になるよう session level で configure する。

### platform-enforced rules

この catalog の二つの rules は convention ではなく、Claude Code が enforce している。

- **「Subagents cannot spawn other subagents」**（docs の文言）。Anti-pattern B（persona-calls-persona）と Anti-pattern D（deep persona trees）は、Claude Code では構造上存在できない。
- **「No nested teams」**。teammates は自分の teams を spawn できない。同じ anti-patterns が team level でも block される。

つまり、この catalog の patterns を採用しても、contributors が誤って anti-patterns を作る心配は少ない。load に失敗するだけである。

### 知っておく built-in subagents

custom subagent を定義する前に、次が role を覆っていないか確認する。

| Built-in | Purpose |
|---|---|
| `Explore` | read-only codebase search and analysis。Pattern 5（research isolation）に使う。 |
| `Plan` | plan mode 中の read-only research。 |
| `general-purpose` | exploration と modification の両方を必要とする multi-step tasks。 |

これらを再定義しない。specialist personas（code-reviewer、security-auditor、test-engineer）はその上に layer する。

### plugin agents の frontmatter restrictions

Plugin subagents は `hooks`、`mcpServers`、`permissionMode` frontmatter fields を **support しない**。これらは silently ignored される。将来の persona がこれらを必要とするなら、user は file を `.claude/agents/` または `~/.claude/agents/` へ copy する必要がある。

plugin agents で動く fields は、`name`、`description`、`tools`、`disallowedTools`、`model`、`maxTurns`、`skills`、`memory`、`background`、`effort`、`isolation`、`color`、`initialPrompt`。cost を optimize したい場合は persona ごとに `model` を使う（例: `test-engineer` coverage scans は Haiku、`code-reviewer` は Sonnet、`security-auditor` は Opus）。

### 複数 subagents を並列 spawn する

Claude Code では、parallel fan-out（Pattern 3）には **single assistant turn で複数の Agent tool calls を発行する** 必要がある。sequential turns は execution を serialize する。`/ship` はこれを明示している。新しい orchestrator command も同じように書くべき。

---

## worked example: competing-hypothesis debugging のための Agent Teams

この example は、`/ship` の subagent fan-out ではなく **Agent Teams** を使う場面を示す。遠目には二つの patterns は似ている。同じ三つの personas を spawn する。しかし価値の源泉が違う。

### scenario

> *Checkout が完了前にときどき約 30 秒 hang する。50 sessions に 1 回くらい起きる。logs に errors はない。先週の release 以降に始まった。*

もっともらしい root causes（mutually exclusive で、すべて symptoms に合う）:

1. 新しい payment-confirmation flow の race condition
2. auth check が時々 slow synchronous network call へ fall through する
3. cart size とともに scale する query の missing index
4. SDK が timeout 前に silently retry する flaky third-party API

単一 agent は最初にもっともらしい theory を選び、調査を止めがちである。`/ship` style の subagent fan-out なら各 persona が独立して report するが、reports は互いに出会わないため、間違った theories を rule out できない。

これは Agent Teams docs が説明する case そのもの。「複数の独立 investigators が互いの theory を積極的に disprove しようとすることで、生き残った theory が actual root cause である可能性が高くなる」。

### なぜこれは `/ship` job ではないか

| | `/ship`（subagents） | Agent Teams |
|---|---|---|
| Sub-agents が見るもの | 同じ diff、異なる lenses | shared task list と互いの messages |
| Output | 三つの independent reports → one merge | adversarial debate → consensus root cause |
| 適した場面 | known artifact への verdict が欲しい | hypotheses の中から artifact を **見つけたい** |

`/ship` は verdict。Agent Teams は investigation。

### setup（一度だけ、environment ごと）

Agent Teams は experimental。`~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Claude Code v2.1.32 以降が必要。この repo の personas は自動で picked up される。team-config files を手書きする必要はない。

### trigger prompt

lead session に natural language で入力する。

```
Users report checkout hangs for ~30 seconds intermittently after last
week's release. No errors in logs.

Create an agent team to debug this with competing hypotheses. Spawn
three teammates using the existing agent types:

  - code-reviewer  — investigate race conditions and blocking calls
                     in the checkout code path
  - security-auditor — investigate auth checks, session handling,
                       and any synchronous network calls added recently
  - test-engineer  — propose tests that would distinguish between the
                     hypotheses and check coverage gaps in checkout

Have them message each other directly to challenge each other's
theories. Update findings as consensus emerges. Only converge when
two teammates agree they can disprove the others'.
```

lead は既存 persona names を参照して三つの teammates を spawn する。persona body は各 teammate の system prompt に additional instructions として **append** される（lead が入れる team-coordination instructions の上に乗る）。上の trigger prompt が task になる。

### 何が起きるか

1. 各 teammate は own context window で動き、自分の lens から codebase を explore する。
2. Teammates は `message` を使い、findings を互いへ直接送る。lead が relay する必要はない。
3. shared task list は誰が何を investigating しているかを示す。`Ctrl+T`（in-process mode）または tmux pane（split mode）でいつでも見られる。
4. `code-reviewer` が sequential であるべき `Promise.all` を見つけると、race に auth call が関係していないか確認するため `security-auditor` に message する。`security-auditor` は確認して reply する。race が real issue だと confirm するか、counter-evidence を出す。
5. `test-engineer` は勝ちつつある theory を区別する focused integration test を提案し、team は consensus 宣言前にそれで verify する。
6. lead は converged finding を synthesize し、user に提示する。

`Shift+Down` で teammate を切り替えて typing すれば、任意の teammate を interrupt できる。間違った path に入った investigator の redirect に useful。

### cleanup する場面

investigation が root cause に到達したら、lead に伝える。

```
Clean up the team
```

cleanup は常に teammate ではなく lead 経由で行う（docs によると teammates は cleanup に必要な full team context を持たない）。

### cost expectation

三つの Sonnet teammates を 10-15 分ほど investigation させると、`/ship` で同じ三つの personas を subagents として spawn するより明らかに高い。justification は **conclusion quality**。wrong fix が高くつく production debugging では extra tokens は安い。routine PR review では `/ship` に留める。

### この scenario の anti-pattern

これを subagents fan-out の `/debug` slash command として作り直さない。Subagents は互いに message できないため、この pattern の価値である adversarial debate を失う。workflow が頻出するなら、subagents を誤用する slash command で wrap するのではなく、上の trigger prompt を snippet として文書化する。

### Agent Teams を使わない場面

- known diff に対する production-bound verdict → `/ship`（subagents）を使う。
- one artifact に対する one specialist perspective → direct persona invocation。
- sequential lifecycle（spec → plan → build）→ user-driven slash commands（Pattern 4）。
- read-heavy research with small digest → built-in `Explore` subagent。

正しい答えを出すために teammates が **互いに challenge する必要がある** ときだけ Agent Teams を使う。

---

## anti-patterns

### A. router persona（"meta-orchestrator"）

他の persona のどれを呼ぶか決めることを仕事にする persona。

```
/work → router-persona → "this needs a review" → code-reviewer → router（paraphrases）→ user
```

**失敗する理由:**

- domain value のない純粋な routing layer
- paraphrasing hops が二つ増える → information loss + token cost が約 2 倍
- user は review が欲しいと既に分かっていた。直接 `/review` を呼べた
- slash commands と `AGENTS.md` の intent mapping がすでに行う work を複製する

**代わりにすること:** slash commands を追加または精錬する。`AGENTS.md` に intent → command mapping を文書化する。

---

### B. Persona が別 persona を呼ぶ

auth code を見た `code-reviewer` が内部で `security-auditor` を呼び出す。

**失敗する理由:**

- Personas は single perspective を生むよう設計されている。chain するとそれが崩れる
- calling persona が渡す summary は、called persona が必要とする context を失う
- failure modes が増える（どの persona の output format が勝つ？誰の rules が適用される？）
- cost を user から隠す

**代わりにすること:** calling persona は report 内で follow-up audit を **recommend** する。user または slash command が second pass を実行する。

---

### C. paraphrase する sequential orchestrator

user の代わりに `/spec`、`/plan`、`/build` などを順に呼ぶ agent。

**失敗する理由:**

- wrong-direction work を捕まえる human checkpoints を失う
- 各 hand-off が context を summarize し、長い pipeline で drift が蓄積する
- token cost が二重になる: 各 step で orchestrator turn + sub-agent turn
- judgment が最も重要な地点で user agency を取り除く

**代わりにすること:** user を orchestrator のままにする。推奨 sequence を `README.md` に文書化し、users に invoke してもらう。

---

### D. 深い persona trees

`/ship` が `pre-ship-coordinator` を呼び、それが `quality-coordinator` を呼び、それが `code-reviewer` を呼ぶ。

**失敗する理由:**

- 各 layer が decision value なしに latency と tokens を増やす
- debugging が multi-level investigation になる
- leaf personas が複数 summary steps で context を失う

**代わりにすること:** orchestration depth は最大 1 に保つ（slash command → personas）。merge は main agent で行う。

---

## decision flow

新しい orchestrated workflow を検討するときは、この flow をたどる。

```
作業は one artifact に対する one perspective か？
├── Yes → direct invocation。終了。
└── No  → 同じ composition が繰り返されるか？
         ├── No  → direct invocation、ad hoc。終了。
         └── Yes → sub-tasks は independent か？
                  ├── No  → user が実行する sequential slash commands（Pattern 4）。
                  └── Yes → parallel fan-out with merge（Pattern 3）。
                           上の checklist で validate。
                           check が一つでも fail → single-persona command（Pattern 2）へ戻る。
```

---

## この catalog に新しい pattern を追加する場面

次を満たしてからだけ、新しい entry を追加する。

1. その pattern を real work で少なくとも二回使った
2. それを示すこの repo 内の concrete artifact を名指しできる
3. 既存 pattern ではうまくいかなかった理由を説明できる
4. anti-pattern shadow（人々が代わりに間違って作りそうなもの）を説明できる

早すぎる catalog entries は、誰も従わない aspirational documentation になる。
