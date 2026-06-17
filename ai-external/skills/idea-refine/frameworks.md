# アイデア出しフレームワークリファレンス

これらの framework は選択的に使う。アイデアに合う lens を選び、すべてを機械的に実行しない。目的は考えを解きほぐすことであって、checklist に従うことではない。

## SCAMPER

既存の idea に七つの操作を適用して変形する構造的な方法。

- **Substitute（置換）:** どの component、material、process を入れ替えられるか？中核 technology、target audience、business model を置き換えたらどうなるか？
- **Combine（結合）:** 別の product、service、idea と混ぜたらどうなるか？通常は一緒にならない二つを合わせると何が新しく生まれるか？
- **Adapt（適応）:** これに似たものは何か？他 industry、domain、時代から借りられる idea は？自然界に parallel はあるか？
- **Modify（拡大 / 縮小）:** 10 倍大きくしたら？10 倍小さくしたら？一つの feature を誇張したら？絶対最小まで削ったら？
- **Put to other uses（別用途）:** 他に誰が使えるか？他のどんな問題を解けるか？完全に別 context で使うと何が起きるか？
- **Eliminate（削除）:** feature を丸ごと消したらどうなるか？設定ゼロの version は？step が半分ならどう見えるか？
- **Reverse / Rearrange（反転 / 並べ替え）:** step を逆順にしたら？system の代わりに user が作業したら、またはその逆なら？value chain を反転したら？

**向いているもの:** 既存 product / feature の改善や再想像。greenfield idea には少し弱い。

## How Might We（HMW）

問題を「How Might We...」形式で機会へ言い換える。

- observation または pain point から始める
- 「How might we [望む outcome] for [specific user] without [key constraint]?」として言い換える
- 同じ問題を複数の HMW framing にする。framing が違えば solution も変わる

**良い HMW の性質:**

- 実行できるくらい狭い（「新規 users が最初の 5 分で関連 content を見つけられるようにする」）
- creative な solution を許すくらい広い（「recommendation sidebar を追加する」ではない）
- 創造性を強制する tension や constraint を含む

**悪い HMW の性質:**

- 広すぎる: 「users を happy にするには？」
- 狭すぎる: 「settings page に button を追加するには？」
- solution が埋め込まれている: 「support chatbot を作るには？」

**向いているもの:** 固まった考えの reframing。誰かが solution に固着しているとき、問題へ引き戻す。

## 第一原理思考

idea を基本的な真実まで分解し、そこから組み直す。

1. **真だと分かっていることは何か？** assumption でも convention でもなく、実際に true なもの。
2. **何を assumption しているか？** obvious に見えるものも含め、すべて書く。
3. **どの assumption を疑えるか？** それぞれに「これは物理法則か、それとも単に今までのやり方か？」と問う。
4. **真実から再構築する。** fundamental truth だけがあるなら何を作るか？

**向いているもの:** incremental thinking から抜けること。すべての idea が現状の小改善に見えるとき。

## Jobs to Be Done（JTBD）

ユーザーが欲しいと言うものではなく、達成しようとしていることに集中する。

- **functional job:** どの task を完了しようとしているか？
- **emotional job:** どんな気持ちになりたいか？
- **social job:** どう見られたいか？

形式: 「When I [situation], I want to [motivation], so I can [expected outcome].」

**重要な洞察:** 人は product を買うのではなく、job を片付けるために hire する。競合 product は同じ category にあるとは限らない。（Netflix は他の streaming service だけでなく睡眠とも競合する。）

**向いているもの:** 本当の問題の理解。正しいものを解いているか不確かなとき。

## 制約ベースのアイデア出し

意図的に制約を課し、creative な solution を強制する。

- **time constraint:** 「1 日しか build できないなら？」
- **feature constraint:** 「feature が一つだけなら？」
- **tech constraint:** 「 obvious な technology を使えないなら？」
- **cost constraint:** 「永久に無料でなければならないなら？」
- **audience constraint:** 「user が computer を一度も使ったことがないなら？」
- **scale constraint:** 「10 億 users に対応する必要があるなら？逆に 10 users だけなら？」

**向いているもの:** 複雑さを切ること。idea が大きくなりすぎている、または曖昧になりすぎているとき。

## Pre-mortem

idea がすでに失敗したと想像し、そこから逆算する。

1. 12 か月後。project は shipped したが失敗した。何が悪かったか？
2. technical、market、team、timing など、もっともらしい失敗理由をすべて列挙する。
3. 各 failure mode について、予防可能か？idea を変えるべき signal か？
4. 受け入れられる failure mode はどれか？project を kill するものはどれか？

**向いているもの:** Phase 2 evaluation。良さそうに見えるが pressure-test されていない idea の stress-test。

## 類推による着想

他 domain が似た問題をどう解いたかを見る。

- この問題の version をすでに解いた industry はどこか？
- [specific company/product] が作ったらどう見えるか？
- これと同じように働く natural system は何か？
- historical precedent はあるか？

鍵は表面的な類似ではなく、**構造的**な類似を見つけること。「Uber for X」は表面的。「見知らぬ人同士の trust problem を解く two-sided marketplace」は構造的。

**向いているもの:** Phase 1 expansion。 obvious な approach とは本当に違って見える variation の生成。
