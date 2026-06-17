# アイデア出しセッション例

この例は、さまざまな種類の idea で良い ideation session がどう見えるかを示す。content だけでなく、rhythm、tone、structure を見ること。この skill は、曖昧な startup concept、既存 product の feature、process improvement のどれにも自然に馴染むべきである。

---

## 例 1: 曖昧な初期構想（完全な 3 フェーズ session）

**ユーザー呼び出し:** `/ideate 小さな地元レストランが大手 delivery platform と競争できるようにしたい`

### フェーズ 1: 理解して広げる

**Skill response:**

> **How might we** independent restaurants が、margin と brand を削る model に押し込まれずに、customers が delivery platforms に期待する reach と convenience を得られるようにするには？

大きな space です。研ぎ澄まします。

1. **「競争」のどの部分ですか？** Customer acquisition？Delivery logistics？Online ordering UX？Loyalty / retention？Platform fee による margin pressure？
2. **誰のために作っていますか？** Restaurant owner？Diner？両方？
3. **制約は何ですか？** Software を考えていますか？cooperative model？physical なもの？

**User responds:** 「Restaurant owners です。中心の痛みは、delivery apps に 25-30% commission を払っているのに、そこに customers がいるから opt out できないと感じていることです。software を考えていますが、open です。」

**Skill continues:**

問題は delivery logistics ではなく **customer dependency** です。platforms が customer relationship を所有し、restaurants は自分たちの customers への access を revenue の 30% で借りている。この leverage を壊すのが本筋です。

6 つの variation があります。

1. **Direct Channel Toolkit:** Restaurants に自分たちの branded ordering、web、SMS、軽量 app などを持たせ、既存 customers を off-platform へ移せるようにする。core bet: すでに restaurant を知っている customers は、十分簡単なら direct に order する。DoorDash と discovery で競う必要はなく、reordering で競えばよい。

2. **反転 — restaurant ではなく customer に課金する:** delivery fee model を反転したら？Customers が direct ordering に小さな premium を払う。restaurants は commission zero。「地元のお店を支える」と position する。bet: local business 支援に関心のある customers が、order ごとに 1-2 ドル多く払う。

3. **制約除去 — delivery が不要なら？** Platforms は discovery + ordering + delivery を bundle しているが、cost の大半（restaurant の commission も）は delivery。ordering と pickup だけ解いたら？pickup-first model。Restaurants は revenue を 100% 残し、customers は delivery fee を節約する。密な neighborhood で最も効く。

4. **組み合わせ — Restaurant Collective:** 一地域の 20-50 店の local restaurants が platform を共有し、cost を分け、相互 promotion する co-op model。個々の restaurants は marketing 予算がないが、neighborhood collective なら持てる。digital な「local food hall」と考える。

5. **Audience Shift — Regular Customers 向け:** new customers を獲得しようとしない。restaurant の既存 regulars、毎週来る人だけのために作る。loyalty / reorder tool を死ぬほど単純にする: 「いつもの？」で one-tap reorder。80/20 の bet: customers の 20% が revenue の 80% を作り、その人たちは restaurant を discover するために DoorDash を必要としていない。

6. **Expert Lens — Restaurant Owners が実際にすること:** 多くの小規模 restaurant owners は dashboard を見ていない。厨房にいる。「管理」を求める tool は失敗する。勝つ approach は、勝手に動くものかもしれない。2 週間 order していない regulars へ auto-text し、daily special を auto-post し、reorders を自動処理する。restaurant-side effort zero。

Variation 5 と 6 の組み合わせが面白い。platform に正面から勝とうとするのではなく、restaurant の best existing customers 向けの reordering / retention tool という超 narrow なものを作る。discovery なし、delivery なし、marketplace なし。ただ「regulars が direct order し続ける」だけ。

どの方向が気になりますか？

---

### フェーズ 2: 評価して収束する

**User responds:** 「regulars angle（5 と 6）が好きです。direct channel toolkit（1）は必要だけど boring に感じます。co-op idea（4）は面白いけど complex。1 + 5 + 6 を合わせた方向に集中したいです。」

**Skill response:**

良い直感です。この組み合わせには明確な thesis があります。**best customers との relationship を所有し、reordering を effortless にし、restaurant owner の effort を zero にする。** Stress-test します。

**方向 A: "Regulars Engine"（variations 5 + 6 の融合）**  
Restaurant の既存 repeat customers だけに集中する tool。auto-reorder、auto-engagement、zero management。

- **Core bet:** Restaurant の top 20% customers は、体験が frictionless で personal なら direct ordering へ移る。restaurant は new customers ではなく、すでに持っている customers に 30% 払うのを止める必要がある。
- **User value:** 高く即時。direct reorder ごとに restaurant は 25-30% commission を節約する。regular が $30/week order するなら、customer 一人あたり年間約 $400 の fee 削減。50 regulars = 年 $20K。小規模 restaurant にとって real money。
- **Feasibility:** medium。ordering / payment tech は commodity。難しい部分は、(a) restaurant に manual work をさせずに "regulars" をどう identify / onboard するか、(b) cold start、つまり最初の reorder に必要な order history が delivery platform 側にあり、こちらにない問題。
- **Differentiation:** niche では高い。Platforms は marketplace dynamics（new customer discovery、driver logistics）に最適化している。「regulars を direct ordering に留める」ことだけに最適化しているところは少ない。DoorDash には小さすぎて気にされない。だから wedge として良い。
- **Hidden assumptions:**
  - regulars がもう一つの ordering method を install / use する
  - restaurant owners が customer contact info を共有する、または access を許す
  - direct ordering が dine-in revenue を cannibalize しない
- **Kill し得るもの:** customers が単に channel を変えないこと。習慣は強い。DoorDash が高くても phone にすでにある。

**方向 B: Direct Channel + Retention Hybrid（variation 1 + 5）**  
Restaurant の branded ordering に retention automation を足す。より complete だがより complex。

- **Core bet:** Restaurants は channel（order を受ける方法）と engine（customers をその channel に戻す方法）の両方が必要。
- **User value:** ceiling は高いが、両方が一緒に機能した場合だけ。ordering channel 単体は commodity（Square、Toast がすでにある）。retention layer 単体には retain する channel がない。
- **Feasibility:** 低い。二つの products を作り、それらが一緒ならより良いと期待している。
- **Differentiation:** medium。組み合わせは面白いが、各 piece には競合がある。
- **Hidden assumption:** これらを bundle する方が、たとえば Square Online の上に retention layer を partner として載せるより良いこと。
- **Kill し得るもの:** scope。二つをうまく作るのは、一つを作るより指数的に難しい。

**正直な読み:** 方向 A の方が鋭い bet です。方向 B は安全ですが differentiation は弱い。A の最大 risk は channel-switching problem、customers に新しい方法で order してもらうことです。そこを突破できれば（variation 6 の "zero effort" approach が助けるかもしれない。SMS reorder は app install が不要）、残りはついてきます。

一つ押し返したい点があります。variation 1 を「necessary but boring」と言いました。その「必要そうなもの」を入れたくなる instinct が product の focus を失わせます。regulars engine が効くなら、branded ordering channel は後で足せます。でも channel から作ると、ただの Square Online competitor になります。

---

### フェーズ 3: 鋭くして出荷する

**Skill produces:**

# ReOrder: 常連客に直接注文し続けてもらう

## 問題文

Independent restaurants が、最も重要な revenue にかかる 25-30% platform commission をなくしながら、best existing customers を direct ordering で retain できるようにするには？

## 推奨方向

**regulars-only retention engine** を作る。marketplace ではなく、full ordering platform でもない。一つの job に集中する。restaurant の repeat customers が effortless に direct reorder できるようにすること。

重要な insight は、restaurants が best customers を **見つける** 助けを必要としているわけではないこと。毎週火曜に来る人を知っている。必要なのは、それらの relationships を off-platform に移す手助け。そして owner は dashboard ではなく厨房にいるため、tool は勝手に動く必要がある。

SMS-first（app-first ではない）が likely right channel。「Marco's のいつもの木曜 order、いりますか？」という text と one-tap confirmation は、どんな app install より friction が低い。

## 検証すべき主要 assumption

- [ ] Repeat customers が普段の delivery app ではなく SMS / direct link で reorder する。5 restaurants、各 20 regulars で test し、4 weeks の conversion を測定する
- [ ] Restaurant owners が top 20-30 regulars を identify し、contact info を共有できる。10 owners にこれをするか聞いて test する
- [ ] Commission savings（order ごとに $8-10）が、owners に initial setup effort を払わせるほど motivator になる。platform fee pain について 10 owners に interview する

## MVP スコープ

- Restaurant が自分で identify した regular customers 向けの SMS-based reordering
- Restaurant owner が regulars を manual 追加（name + phone + usual order）。15-minute setup
- Customer は usual order の text を受け取り、reply で confirm し、link で pay する
- Restaurant は order を text / simple dashboard で受け取る
- Delivery なし。v1 は pickup only
- Discovery なし、marketplace なし、app なし

## やらないこと（と理由）

- **Delivery logistics** — delivery は高価で複雑な部分であり core problem ではない。pickup-first なら operational burden なしで demand を validate できる。
- **Customer acquisition / discovery** — それは platform の game。discovery で競うことは DoorDash の budget と競うこと。こちらは retention で競う。
- **Branded restaurant apps / websites** — commodity。Square と Toast がすでにやっている。別の branded channel は behavioral problem を解かない。
- **Menu management、POS integration** — scope creep。「いつもの」は dynamic menu を必要としない。static orders から始める。
- **Analytics dashboards** — owner は厨房にいる。reporting は active（login して chart を見る）ではなく passive（weekly text summary）にする。

## 未解決の質問

- Restaurant customers への SMS marketing の legal / compliance landscape は？
- 「usual」orders の menu / price changes をどう扱うか？
- regular customer list を manual entry ではなく既存 POS data から bootstrap する方法はあるか？
- pricing model は？per-order fee？monthly subscription？

---

## 例 2: 既存 product 内の機能アイデア（codebase-aware）

**ユーザー呼び出し:** `/ideate document editor に real-time collaboration を追加する`

### フェーズ 1: 理解して広げる

**Skill response:**

> **How might we** 複数人が同じ document を同時に、chaotic ではなく natural に感じる形で編集できるようにするには？

codebase を scan したところ、block-based editor architecture と persistence 用 REST API を使っています。WebSocket infrastructure はまだありません。これは重要な context です。いくつか質問します。

1. **Collaboration pattern はどれですか？** 同じ paragraph を同時編集する（Google Docs style）？別々の section で作業する（Notion style）？一人が編集し、他が review / comment する？
2. **同時 users は何人ですか？** 2-3 人（pair editing）？10 人以上（team workspace）？
3. **なぜ今ですか？** Customer requests？Competitive pressure？Internal need？

**User responds:** 「2-5 people で、たいてい別 sections を作業します。customers が何度も求めています。modern editor なら当然あると思われ、Notion に deals を失っています。」

**Skill continues:**

competitive pressure という framing が重要です。これは differentiator ではなく checkbox feature（検討対象に残るための must-have）かもしれません。そうなら投資量が変わります。

document model は independent blocks と flat ordering system を使っています（`src/models/document.ts:45`）。これは好都合です。block-level granularity なら character-level editing より conflicts が少ない。

5 つの variation です。

1. **Block-Level Locking（最も単純な path）:** 誰かが block 編集を始めたら、他の人には lock する。presence indicator（「Alex is editing...」）は見えるが、別 block は自由に編集できる。conflict resolution は不要。既存 block model がこれを支える。`locked_by` field と presence 用 WebSocket layer を追加する。

2. **反転 — Async-First Collaboration:** real-time co-editing ではなく async に寄せる。Inline suggestions、comments、proposed edits を document owner が merge する。suggestion mode だが primary collaboration model として扱う。bet: 2-5 people が別 sections で作業するなら、async の方が real-time より良いかもしれない。

3. **単純化 — Presence Without Co-Editing:** 誰が document を見ていて、どの section を見ているかを示す（cursors、margin avatars）が、simultaneous editing は有効にしない。人々は口頭で coordination する。primitive に聞こえるが、engineering cost 10% で value 80% かもしれない。

4. **組み合わせ — Collaboration + Version Branches:** document の "branches" を作り、各自が独立編集してから merge できるようにする。編集中は conflict がなく、merge UI を作る。既存 versioning system に合う。

5. **10x Version — AI-Mediated Collaboration:** 複数人が section に欲しいことを記述し、AI が inputs を draft に synthesize し、それを全員で iterate する。誰も同じ text を直接編集しない。全員が影響を与える。radical で早すぎる可能性はあるが、名付ける価値はある。

architecture と competitive context を踏まえると、variation 1 または 3 を推します。deals を落とさないために必要なのは shipped することであり、つまり checkbox を満たす最小版が必要です。variation 1 は real co-editing を提供します。variation 3 はさらに安いですが、「real-time が必要」という checkbox を満たさない可能性があります。

---

*Phase 2 では、「minimum viable co-editing（1 または 3）」と「differentiated collaboration model（2 または 4）」に cluster し、competitive checkbox を早く満たすべきか、selling point になるものへ投資すべきかを評価する。*

*フェーズ 3 では、block-level locking を MVP として推奨する one-pager を作る。やらないことリストには character-level CRDT（複雑すぎる）、offline sync（2-5 users には不要）、AI features（premature）を含める。*

---

## 例 3: process / workflow idea（非 product）

**ユーザー呼び出し:** `/ideate weekly team retrospectives のもっと良い運営方法。最近 stale で、みんな嫌がっている`

### フェーズ 1: 理解して広げる

**Skill response:**

> **How might we** retrospectives を、人々が耐える recurring meeting ではなく、team が楽しみにするほど genuinely useful なものにするには？

広げる前に聞きます。

1. **何が stale ですか？** 毎回同じ format？同じ人だけ話す？Action items が終わらない？Topics が繰り返しに感じる？
2. **Team size と dynamic は？** 5 人全員が話す？それとも 15 人中 3 人が dominate？
3. **あなたにとって good retro はどう見えますか？** うまくいった retro はありましたか？何が違いましたか？

**User responds:** 「8 people で、実際に話すのは 3-4 人くらい。同じ 'what went well / what didn't / action items' format を 1 年続けています。action items は積み上がるだけで何も変わらない。みんな theater だと思っています。」

**Skill continues:**

action item problem が本当の signal です。retro の後で何も変わらないなら、人々が disengage するのは合理的です。meeting が stale なのではなく、**output layer が壊れている**。follow-through が機能すれば、format 自体は問題ないかもしれない。

6 つの variation です。

1. **Meeting ではなく Output を直す:** retro format は保ち、後で起きることを完全に変える。retro ごとに action item は最大一つ。meeting 中に owner と deadline を決める。次の retro は、その完了 action の 5-minute demo から始める。終わっていなければ、それ自体が retro topic になる。一つだけという制約が prioritization を強制する。

2. **反転 — Meeting をなくす:** synchronous retro を async に置き換える。全員が week 中に written reflections を提出する。rotating facilitator が themes を synthesize し、一つの change を提案する。「meeting」は合意 / 不合意のための 15-minute standup。bet: group で話すより writing の方が honest feedback を生む。

3. **Audience Shift — Quiet Ones 向け retro:** 話さない 4-5 人のために format を設計する。topic の anonymous submission、dot-voting、full-group discussion 前の small-group breakouts（pairs）。loud voices も参加するが、structure が domination を防ぐ。

4. **単純化 — One Question Retro:** 各 retro は一つの question だけを持ち、毎週変える。「何があなたを遅くした？」「team が知るべき学びは？」「働き方で一つ変えられるなら？」制約が breadth より depth を強制する。

5. **組み合わせ — Retro + Experimentation:** 各 retro output を hypothesis として扱う。「[change] により [outcome] が改善すると信じる」。2-week experiment として実行する。次の retro: 効いたか？keep、modify、kill。retro を built-in accountability 付き continuous improvement engine にする。

6. **Expert Lens — Facilitators が知っていること:** 経験ある facilitators は、retro killer の第一位は format ではなく safety の欠如だと言う。本当に悪いことを言うと consequences があると感じれば、人々は言わない。fix は structural ではなく、毎週 anonymous "team health check" score（1-5）から始めることかもしれない。safety が高いと retros は自然に改善する。

面白い tension があります。variations 1 と 5 は **output** problem（何も変わらない）を直す。variations 2、3、4 は **input** problem（同じ声、同じ topics）を直す。variation 6 は、両方とも deeper issue の symptoms だと言っている。本当の bottleneck はどこだと思いますか？

---

*Phase 2 では、試す effort（ほとんどは無料。次の meeting の運営を変えるだけ）、risk（variation 2 が最大の departure）、team の本当の問題が output（action items が死ぬ）か input（honesty が足りない）かで評価する。*

*フェーズ 3 では、zero-cost experiment として variation 1（一つの action item、翌週 demo）から始め、variation 3 の anonymous submission を組み合わせる one-pager を作る。やらないことリスト: new tools、elaborate facilitation techniques、budget が必要なもの。最初の fix は prep 0 minutes、$0 であるべき。*

---

## これらの例で見るべきこと

1. **言い直しが frame を変える。** 「restaurants が競争できるように」は「existing customers を retain する」になる。「real-time collaboration を追加する」は「chaos なしで同時作業できるようにする」になる。「stale retros を直す」は「output layer を直す」になる。

2. **質問は処方前に診断する。** 各 question は、これが実際にどの **種類** の problem かを決める。retro example は、問題が meeting format ではなく action item follow-through だと明らかにし、すべての variation を変える。

3. **Variations には理由がある。** 各 variation は、それが **なぜ** 存在するか（どの lens から生まれたか）を説明しており、単なる「何か」ではない。label（Inversion、Simplification など）は、user 自身がこの方法で考える手助けにもなる。

4. **Skill は意見を持つ。** 「1 または 3 を推します」「variation 6 は少し座って考える価値がある」。中立な options だけでなく、何が重要だと思うかと理由を伝える。

5. **Phase 2 は正直である。** Ideas は low differentiation や high complexity として指摘される。skill は押し返す。「その『必要なもの』を入れたくなる instinct が product の focus を失わせます。」

6. **出力は actionable である。** one-pager は考えることではなく、できること（validate assumptions、build MVP、experiment を試す）で終わる。

7. **「やらないこと」リストが実際に仕事をする。** specific で reasoned。各 item はやりたいかもしれないが、まだやるべきではないもの。

8. **Skill は context に適応する。** codebase-aware example は実際の architecture を参照する。process idea は product ではなく zero-cost experiments を生成する。framework は同じだが、output は domain に合う。
