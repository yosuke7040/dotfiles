---
name: frontend-ui-engineering
description: 本番品質の UI を作る。ユーザー向けインターフェースを構築または変更する場合に使う。コンポーネント作成、レイアウト実装、状態管理、または出力が AI 生成らしさではなく本番品質の見た目と手触りを必要とする場合に使う。
---

# フロントエンド UI エンジニアリング

## 概要

アクセシブルで高性能、かつ視覚的に磨かれた本番品質のユーザーインターフェースを作る。目標は、AI が生成したものではなく、トップ企業のデザイン感度を持つエンジニアが作ったように見える UI である。つまり、本物のデザインシステム遵守、適切なアクセシビリティ、よく考えられた interaction patterns、そして汎用的な「AI aesthetic」を避けることを意味する。

## 使う場面

- 新しい UI コンポーネントまたはページを作る
- 既存のユーザー向けインターフェースを変更する
- responsive layout を実装する
- interactivity または state management を追加する
- visual または UX の問題を修正する

## コンポーネントアーキテクチャ

### ファイル構造

コンポーネントに関係するものを近くに置く:

```
src/components/
  TaskList/
    TaskList.tsx          # コンポーネント実装
    TaskList.test.tsx     # テスト
    TaskList.stories.tsx  # Storybook stories（使っている場合）
    use-task-list.ts      # custom hook（状態が複雑な場合）
    types.ts              # コンポーネント固有型（必要な場合）
```

### コンポーネントパターン

**設定より composition を優先する:**

```tsx
// 良い例: composable
<Card>
  <CardHeader>
    <CardTitle>タスク</CardTitle>
  </CardHeader>
  <CardBody>
    <TaskList tasks={tasks} />
  </CardBody>
</Card>

// 避ける: 過剰設定
<Card
  title="タスク"
  headerVariant="large"
  bodyPadding="md"
  content={<TaskList tasks={tasks} />}
/>
```

**コンポーネントは焦点を絞る:**

```tsx
// 良い例: 1 つのことをする
export function TaskItem({ task, onToggle, onDelete }: TaskItemProps) {
  return (
    <li className="flex items-center gap-3 p-3">
      <Checkbox checked={task.done} onChange={() => onToggle(task.id)} />
      <span className={task.done ? 'line-through text-muted' : ''}>{task.title}</span>
      <Button variant="ghost" size="sm" onClick={() => onDelete(task.id)}>
        <TrashIcon />
      </Button>
    </li>
  );
}
```

**データ取得と表示を分ける:**

```tsx
// Container: data を扱う
export function TaskListContainer() {
  const { tasks, isLoading, error } = useTasks();

  if (isLoading) return <TaskListSkeleton />;
  if (error) return <ErrorState message="タスクの読み込みに失敗しました" retry={refetch} />;
  if (tasks.length === 0) return <EmptyState message="まだタスクはありません" />;

  return <TaskList tasks={tasks} />;
}

// Presentation: rendering を扱う
export function TaskList({ tasks }: { tasks: Task[] }) {
  return (
    <ul role="list" className="divide-y">
      {tasks.map(task => <TaskItem key={task.id} task={task} />)}
    </ul>
  );
}
```

## 状態管理

**動く最も単純な方法を選ぶ:**

```
Local state (useState)           → コンポーネント固有の UI state
Lifted state                     → 2-3 個の sibling components で共有
Context                          → Theme、auth、locale（read-heavy、write-rare）
URL state (searchParams)         → filters、pagination、共有可能な UI state
Server state (React Query, SWR)  → cache 付き remote data
Global store (Zustand, Redux)    → app-wide に共有される複雑な client state
```

**3 階層を超える prop drilling は避ける。** props を使わない components を通して渡しているなら、context を導入するか component tree を再構成する。

## デザインシステム遵守

### AI っぽい見た目を避ける

AI 生成 UI には認識しやすいパターンがある。すべて避ける:

| AI の既定 | なぜ問題か | 本番品質 |
|-----------|------------|----------|
| 何でも purple/indigo | モデルは見た目に「安全」な palette へ寄るため、どの app も同じに見える | プロジェクトの実際の color palette を使う |
| 過剰な gradients | gradient は視覚ノイズを増やし、多くの design system と衝突する | design system に合う flat または subtle gradient |
| 何でも丸い（rounded-2xl） | 最大の角丸は「親しみやすさ」を示すが、本物の design の corner radii 階層を無視する | design system の一貫した border-radius |
| 汎用 hero sections | 実際の content や user need とつながらない template layout | content-first layout |
| Lorem ipsum 風 copy | placeholder text は実 content が示す layout 問題（長さ、折り返し、overflow）を隠す | 現実的な placeholder content |
| 全体に大きすぎる padding | 均等で過大な padding は視覚階層を壊し、画面を浪費する | 一貫した spacing scale |
| stock card grids | 均一 grid は information priority と scanning patterns を無視した layout shortcut | 目的に基づく layout |
| shadow-heavy design | shadow の層は content と競合し、低性能端末で rendering を遅くする | design system が指定しない限り subtle または no shadow |

### spacing と layout

一貫した spacing scale を使う。値を発明しない:

```css
/* scale を使う: 0.25rem 刻み（またはプロジェクトの scale） */
/* 良い */  padding: 1rem;      /* 16px */
/* 良い */  gap: 0.75rem;       /* 12px */
/* 悪い */  padding: 13px;      /* どの scale にもない */
/* 悪い */  margin-top: 2.3rem; /* どの scale にもない */
```

### typography

type hierarchy を尊重する:

```
h1 → ページタイトル（1 ページ 1 つ）
h2 → セクションタイトル
h3 → サブセクションタイトル
body → 既定テキスト
small → secondary/helper text
```

heading level を飛ばさない。見出しでない content に見出し style を使わない。

### color

- semantic color tokens を使う: `text-primary`、`bg-surface`、`border-default`。raw hex values は避ける
- 十分な contrast を確保する（通常 text は 4.5:1、大きい text は 3:1）
- 情報伝達を色だけに頼らない（icons、text、patterns も使う）

## アクセシビリティ（WCAG 2.1 AA）

すべてのコンポーネントは次を満たす:

### keyboard navigation

```tsx
// すべての interactive element は keyboard accessible でなければならない
<button onClick={handleClick}>クリック</button>        // ✓ 既定で focusable
<div onClick={handleClick}>クリック</div>               // ✗ focusable ではない
<div role="button" tabIndex={0} onClick={handleClick}    // ✓ ただし <button> を優先
     onKeyDown={e => {
       if (e.key === 'Enter') handleClick();
       if (e.key === ' ') e.preventDefault();
     }}
     onKeyUp={e => {
       if (e.key === ' ') handleClick();
     }}>
  クリック
</div>
```

### ARIA labels

```tsx
// visible text がない interactive element に label を付ける
<button aria-label="ダイアログを閉じる"><XIcon /></button>

// form input に label を付ける
<label htmlFor="email">メール</label>
<input id="email" type="email" />

// visible label がない場合は aria-label を使う
<input aria-label="タスクを検索" type="search" />
```

### focus management

```tsx
// content が変わったら focus を移動する
function Dialog({ isOpen, onClose }: DialogProps) {
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (isOpen) closeRef.current?.focus();
  }, [isOpen]);

  // open 中は dialog 内へ focus を trap する
  return (
    <dialog open={isOpen}>
      <button ref={closeRef} onClick={onClose}>閉じる</button>
      {/* dialog content */}
    </dialog>
  );
}
```

### 意味のある empty / error states

```tsx
// blank screen を表示しない
function TaskList({ tasks }: { tasks: Task[] }) {
  if (tasks.length === 0) {
    return (
      <div role="status" className="text-center py-12">
        <TasksEmptyIcon className="mx-auto h-12 w-12 text-muted" />
        <h3 className="mt-2 text-sm font-medium">タスクはありません</h3>
        <p className="mt-1 text-sm text-muted">新しいタスクを作成して始めましょう。</p>
        <Button className="mt-4" onClick={onCreateTask}>タスクを作成</Button>
      </div>
    );
  }

  return <ul role="list">...</ul>;
}
```

## responsive design

mobile first で設計し、その後広げる:

```tsx
// Tailwind: mobile-first responsive
<div className="
  grid grid-cols-1      /* Mobile: single column */
  sm:grid-cols-2        /* Small: 2 columns */
  lg:grid-cols-3        /* Large: 3 columns */
  gap-4
">
```

次の breakpoints でテストする: 320px、768px、1024px、1440px。

## loading と transitions

```tsx
// Skeleton loading（content には spinner ではなく skeleton）
function TaskListSkeleton() {
  return (
    <div className="space-y-3" aria-busy="true" aria-label="タスクを読み込み中">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="h-12 bg-muted animate-pulse rounded" />
      ))}
    </div>
  );
}

// 体感速度のための optimistic updates
function useToggleTask() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: toggleTask,
    onMutate: async (taskId) => {
      await queryClient.cancelQueries({ queryKey: ['tasks'] });
      const previous = queryClient.getQueryData(['tasks']);

      queryClient.setQueryData(['tasks'], (old: Task[]) =>
        old.map(t => t.id === taskId ? { ...t, done: !t.done } : t)
      );

      return { previous };
    },
    onError: (_err, _taskId, context) => {
      queryClient.setQueryData(['tasks'], context?.previous);
    },
  });
}
```

## 関連資料

詳細なアクセシビリティ要件とテストツールは `references/accessibility-checklist.md` を参照する。

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「アクセシビリティはあればよいもの」 | 多くの法域で法的要件であり、エンジニアリング品質基準でもある。 |
| 「responsive は後でやる」 | responsive design の後付けは、最初から作るより 3 倍難しい。 |
| 「design が final ではないので styling は省く」 | design system defaults を使う。unstyled UI は reviewer へ壊れた第一印象を与える。 |
| 「これは prototype だから」 | prototype は本番コードになる。土台を正しく作る。 |
| 「AI aesthetic で今は十分」 | 低品質のシグナルになる。最初からプロジェクトの実際の design system を使う。 |

## 危険信号

- 200 行を超える components（分割する）
- inline styles または arbitrary pixel values
- error states、loading states、empty states の欠落
- keyboard navigation testing がない
- 状態を示す唯一の手段が色である（text や icons なしの red/green）
- 汎用的な「AI look」（purple gradients、oversized cards、stock layouts）

## 検証

UI 構築後に確認する:

- [ ] component が console errors なしで render される
- [ ] すべての interactive elements が keyboard accessible である（ページを Tab で移動）
- [ ] screen reader がページ内容と構造を伝えられる
- [ ] responsive: 320px、768px、1024px、1440px で動く
- [ ] loading、error、empty states がすべて処理されている
- [ ] プロジェクトの design system（spacing、colors、typography）に従っている
- [ ] dev tools または axe-core に accessibility warnings がない
