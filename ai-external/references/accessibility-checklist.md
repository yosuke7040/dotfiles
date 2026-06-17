# アクセシビリティチェックリスト

WCAG 2.1 AA compliance のクイックリファレンス。`frontend-ui-engineering` skill と併用する。

## 目次

- [必須チェック](#必須チェック)
- [よく使う HTML patterns](#よく使う-html-patterns)
- [テストツール](#テストツール)
- [クイックリファレンス: ARIA Live Regions](#クイックリファレンス-aria-live-regions)
- [よくある anti-patterns](#よくある-anti-patterns)

## 必須チェック

### キーボードナビゲーション

- [ ] すべての interactive elements が Tab key で focus 可能
- [ ] focus order が visual / logical order に沿っている
- [ ] focus が見える（focused elements に outline / ring がある）
- [ ] custom widgets が keyboard support を持つ（Enter で activate、Escape で close）
- [ ] keyboard trap がない（user は常に component から Tab で抜けられる）
- [ ] page 上部に skip-to-content link があり、keyboard focus 時に少なくとも visible
- [ ] modals は open 中に focus を trap し、close 時に focus を戻す

### スクリーンリーダー

- [ ] すべての images に `alt` text がある（decorative images は `alt=""`）
- [ ] すべての form inputs に関連 label がある（`<label>` または `aria-label`）
- [ ] buttons と links に説明的 text がある（「ここをクリック」ではない）
- [ ] icon-only buttons に `aria-label` がある
- [ ] page に `<h1>` が一つあり、headings の level が飛ばない
- [ ] dynamic content changes が通知される（`aria-live` regions）
- [ ] tables に scope 付き `<th>` headers がある

### 視覚

- [ ] text contrast が 4.5:1 以上（normal text）または 3:1 以上（large text、18px+）
- [ ] UI components の background に対する contrast が 3:1 以上
- [ ] 情報伝達を color だけに依存していない
- [ ] text を 200% まで resize しても layout が壊れない
- [ ] 1 秒に 3 回を超えて flashing する content がない

### フォーム

- [ ] すべての input に visible label がある
- [ ] required fields が示されている（color だけではない）
- [ ] error messages が具体的で field と関連付いている
- [ ] error state が color 以外でも見える（icon、text、border）
- [ ] form submission errors が summary され、focus 可能
- [ ] known fields が autocomplete を使う（例: `type="email" autocomplete="email"`）

### コンテンツ

- [ ] language が宣言されている（`<html lang="ja">` など）
- [ ] page に説明的な `<title>` がある
- [ ] links が周囲の text から区別できる（color だけではない）
- [ ] mobile の touch targets が 44x44px 以上
- [ ] meaningful empty states がある（blank screens ではない）

## よく使う HTML パターン

### ボタンとリンク

```html
<!-- action には <button> を使う -->
<button onClick={handleDelete}>タスクを削除</button>

<!-- navigation には <a> を使う -->
<a href="/tasks/123">タスクを見る</a>

<!-- div/span を button として使わない -->
<div onClick={handleDelete}>削除</div>  <!-- 悪い例 -->
```

### フォームラベル

```html
<!-- 明示的な label association -->
<label htmlFor="email">メールアドレス</label>
<input id="email" type="email" required />

<!-- 暗黙の wrapping -->
<label>
  メールアドレス
  <input type="email" required />
</label>

<!-- hidden label（visible label を優先） -->
<input type="search" aria-label="タスクを検索" />
```

### ARIA ロール

```html
<!-- Navigation -->
<nav aria-label="メインナビゲーション">...</nav>
<nav aria-label="フッターリンク">...</nav>

<!-- status messages -->
<div role="status" aria-live="polite">タスクを保存しました</div>

<!-- alert messages -->
<div role="alert">エラー: タイトルは必須です</div>

<!-- modal dialogs -->
<dialog aria-modal="true" aria-labelledby="dialog-title">
  <h2 id="dialog-title">削除の確認</h2>
  ...
</dialog>

<!-- loading states -->
<div aria-busy="true" aria-label="タスクを読み込み中">
  <Spinner />
</div>
```

### アクセシブルなリスト

```html
<ul role="list" aria-label="タスク">
  <li>
    <input type="checkbox" id="task-1" aria-label="完了: 食料品を買う" />
    <label htmlFor="task-1">食料品を買う</label>
  </li>
</ul>
```

## テストツール

```bash
# 自動監査
npx axe-core          # programmatic accessibility testing
npx pa11y             # CLI accessibility checker

# ブラウザ内
# Chrome DevTools → Lighthouse → Accessibility
# Chrome DevTools → Elements → Accessibility tree

# スクリーンリーダーテスト
# macOS: VoiceOver (Cmd + F5)
# Windows: NVDA (free) or JAWS
# Linux: Orca
```

## クイックリファレンス: ARIA Live Regions

| 値 | 振る舞い | 用途 |
|---|---|---|
| `aria-live="polite"` | 次の pause で通知 | status updates、保存確認 |
| `aria-live="assertive"` | 即時通知 | errors、time-sensitive alerts |
| `role="status"` | `polite` と同じ | status messages |
| `role="alert"` | `assertive` と同じ | error messages |

## よくあるアンチパターン

| アンチパターン | 問題 | 修正 |
|---|---|---|
| `div` を button として使う | focus できず、keyboard support がない | `<button>` を使う |
| `alt` text がない | screen readers から images が見えない | 説明的な `alt` を追加する |
| color-only states | 色覚特性のある users には見えない | icons、text、patterns を追加する |
| autoplaying media | 混乱を招き、止められない | controls を追加し、autoplay しない |
| ARIA なしの custom dropdown | keyboard / screen reader で使えない | native `<select>` または適切な ARIA listbox を使う |
| focus outlines を消す | users が現在位置を見失う | outlines を style し、削除しない |
| 空の links / buttons | 説明なしに「link」と読み上げられる | text または `aria-label` を追加する |
| `tabindex > 0` | natural tab order を壊す | `tabindex="0"` または `-1` だけ使う |
