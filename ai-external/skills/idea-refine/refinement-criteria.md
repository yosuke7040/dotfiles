# 精錬と評価基準

Phase 2（評価して収束する）で idea direction を stress-test するための rubric。すべての基準がすべての idea に適用されるわけではない。具体 context でどの dimension が重要かは判断する。

## 中核の評価軸

### 1. User value

最も重要な軸。value が明確でなければ、他は何も意味を持たない。

**Painkiller vs. Vitamin:**

- **Painkiller:** 急性で頻繁な問題を解く。users は能動的に探す。現在の solution から乗り換える。兆候: 人が感情を込めて問題を語る、workaround を作っている、solution に支払う。
- **Vitamin:** あるとよい。少し良くするだけ。users はわざわざ動かない。兆候: 人が礼儀正しくうなずき、「cool」と言うが行動は変えない。

**聞く質問:**

- 今この問題を抱えている具体的な 3 人を名指しできるか？
- その人たちは今日どうしているか？（本当の competitor は常に現在の workaround。）
- 現在の approach から乗り換えるか？何があれば乗り換えるか？
- どれくらい頻繁にこの問題に遭遇するか？（daily problems > monthly problems）
- これは pull problem（users が求めている）か、push problem（あなたが欲しがるべきだと思っている）か？

**危険信号:**

- 「誰でも使える」 — specific user を名指しできないなら value は明確ではない
- 「X みたいだが better」 — marginal improvement は adoption をほとんど駆動しない
- 問題は real だが rare — 強度が高く頻度が低いものは product を正当化しにくい

### 2. Feasibility

本当に作れるか？技術的にだけでなく、実務的に。

**technical feasibility:**

- 中核 technology は存在し、信頼性高く動くか？
- 一番難しい technical problem は何か？既知の hard problem か、新規のものか？
- control できない third parties、APIs、data sources への依存はあるか？
- 最小 technical stack は何か？（答えが「多い」なら signal。）

**resource feasibility:**

- MVP を作る最小 team / effort はどれくらいか？
- 持っていない specialized expertise が必要か？
- regulatory、legal、compliance requirements はあるか？

**time-to-value:**

- users の前にどれくらい早く出せるか？
- months ではなく days/weeks で value を届ける version はあるか？
- critical path は何か？最初に起きる必要があるものは何か？

**危険信号:**

- 「まず [very hard research problem] を解けばよい」
- 同時に動く必要がある dependencies が複数ある
- MVP でも数か月かかる。おそらく最小ではない

### 3. Differentiation

何が本当に違うか？better ではなく **different**。

**聞く質問:**

- user が友人にこれを説明するとしたら何と言うか？その説明は compelling か？
- これだけが行う一つのことは何か？（一つも言えないなら問題。）
- その differentiation は durable か？competitor が 1 週間で copy できるか？
- 違いは users が本当に気にするものか、それとも builders だけが面白いと思うものか？

**differentiation の種類（強い順）:**

1. **新しい capability:** 以前は不可能だったことを行う
2. **10x improvement:** 重要 dimension で行動が変わるほど良い
3. **新しい audience:** 既存 capability を除外されていた人へ届ける
4. **新しい context:** 既存 solution が失敗する状況で機能する
5. **より良い UX:** 同じ capability を劇的に単純な体験にする
6. **安い:** 同じものを低コストにする（最も弱い。競争されやすい）

**危険信号:**

- differentiation が user experience ではなく technology だけにある
- 構造的理由なしに「faster / cheaper / prettier」と言っている
- 差別化する feature が、users が最も気にする feature ではない

## assumption audit

すべての idea direction について、assumption を三つの category に明示する。

### 成立必須（dealbreaker）

間違っていたら idea 全体を kill する assumption。build 前に validation が必要。

例: 「users が data を共有してくれる」 — 共有しないなら product 全体が動かない。

### 成立すべき（重要）

成功へ大きく影響するが idea は kill しない assumption。間違っていたら approach を調整できる。

例: 「users は人と話すより self-serve を好む」 — 間違っていたら go-to-market は変える必要があるが、core product はまだ成立する。

### 成立するとよい（あるとよい）

secondary features や optimizations に関する assumption。core が証明されるまで validation しない。

例: 「users は結果を teammates と共有したがる」 — growth feature であり、core value proposition ではない。

## 判断フレームワーク

方向を選ぶときは、この matrix で rank する。

|                    | Feasibility 高 | Feasibility 低 |
|--------------------|----------------|----------------|
| **Value 高**       | 最初にやる     | risk を取る価値あり |
| **Value 低**       | trivial なら   | やらない |

同じ quadrant の options は differentiation を tie-breaker にする。

## MVP スコープの原則

選んだ方向の MVP scope を定義するとき:

1. **一つの job をうまくやる。** MVP は exactly one user job を確実に満たすべき。三つの job を部分的にやらない。
2. **最も危険な assumption を先に。** MVP の主目的は、最も外れそうな assumption を test すること。
3. **feature-list ではなく time-box。** 「[timeframe] で build して test できるものは何か？」は「どの feature が必要か？」より良い。
4. **「やらないこと」リストは必須。** 何を切るか、なぜ切るかを明示する。scope creep を防ぎ、誠実な優先順位を強制する。
5. **恥ずかしくないなら待ちすぎた。** 初版は builder にとって不完全に感じるべき。そう感じないなら作りすぎている。
