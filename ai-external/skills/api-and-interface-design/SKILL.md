---
name: api-and-interface-design
description: 安定した API とインターフェース設計を案内する。API、モジュール境界、または任意の public interface を設計する場合に使う。REST または GraphQL endpoint の作成、モジュール間の型契約定義、frontend/backend 間の境界確立に使う。
---

# API とインターフェース設計

## 概要

誤用しにくい、安定してよく文書化されたインターフェースを設計する。良いインターフェースは、正しいことを簡単にし、間違ったことを難しくする。これは REST API、GraphQL schema、モジュール境界、コンポーネント props、コードの一部が別の部分と会話する任意の表面に適用される。

## 使う場面

- 新しい API endpoint を設計する
- モジュール境界またはチーム間契約を定義する
- コンポーネント props interface を作る
- API 形状へ影響する database schema を確立する
- 既存の public interface を変更する

## 中核原則

### Hyrum's Law

> API のユーザー数が十分に多ければ、契約で何を約束しているかにかかわらず、システムの観測可能な振る舞いはすべて誰かに依存される。

つまり、文書化されていない癖、エラーメッセージの文言、タイミング、順序を含むすべての public behavior は、ユーザーが依存した瞬間に事実上の契約になる。設計上の含意:

- **何を公開するかを意図的に決める。** 観測可能な振る舞いはすべて潜在的な約束である。
- **実装詳細を漏らさない。** ユーザーが観測できるなら、依存される。
- **設計時点で deprecation を計画する。** ユーザーが依存するものを安全に削除する方法は `deprecation-and-migration` を参照する。
- **テストだけでは不十分。** 完璧な contract tests があっても、Hyrum's Law により「安全」な変更が、未文書の振る舞いへ依存する実ユーザーを壊すことがある。

### One-Version Rule

同じ依存関係または API の複数バージョンから consumer に選ばせることを避ける。diamond dependency 問題は、異なる consumer が同じものの異なるバージョンを必要とすると発生する。一度に存在するバージョンは 1 つだけという世界を前提に設計する。fork ではなく extend する。

### 1. 契約を先に定義する

実装前にインターフェースを定義する。契約が仕様であり、実装はそれに従う。

```typescript
// 先に契約を定義する
interface TaskAPI {
  // task を作成し、server-generated fields を含む作成済み task を返す
  createTask(input: CreateTaskInput): Promise<Task>;

  // filters に一致する paginated tasks を返す
  listTasks(params: ListTasksParams): Promise<PaginatedResult<Task>>;

  // 単一 task を返すか、NotFoundError を投げる
  getTask(id: string): Promise<Task>;

  // 部分更新。提供された fields だけが変わる
  updateTask(id: string, input: UpdateTaskInput): Promise<Task>;

  // 冪等な削除。すでに削除済みでも成功する
  deleteTask(id: string): Promise<void>;
}
```

### 2. 一貫したエラー意味論

エラー戦略を 1 つ選び、全体で使う:

```typescript
// REST: HTTP status codes + structured error body
// すべての error response は同じ形に従う
interface APIError {
  error: {
    code: string;        // machine-readable: "VALIDATION_ERROR"
    message: string;     // human-readable: "Email is required"
    details?: unknown;   // 役立つ場合の追加文脈
  };
}

// status code mapping
// 400 → client が無効な data を送った
// 401 → 未認証
// 403 → 認証済みだが認可されていない
// 404 → resource が見つからない
// 409 → conflict（重複、version mismatch）
// 422 → validation failed（意味的に無効）
// 500 → server error（内部詳細は決して露出しない）
```

**パターンを混ぜない。** endpoint によって throw、null 返却、`{ error }` 返却が混ざると、consumer は挙動を予測できない。

### 3. 境界で検証する

内部コードは信頼する。外部入力が入るシステム端で検証する:

```typescript
// API 境界で検証する
app.post('/api/tasks', async (req, res) => {
  const result = CreateTaskSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid task data',
        details: result.error.flatten(),
      },
    });
  }

  // 検証後、内部コードは型を信頼する
  const task = await taskService.create(result.data);
  return res.status(201).json(task);
});
```

検証が属する場所:
- API route handlers（user input）
- Form submission handlers（user input）
- External service response parsing（third-party data。**必ず信頼できないものとして扱う**）
- Environment variable loading（configuration）

> **Third-party API responses は信頼できないデータである。** それを logic、rendering、decision-making へ使う前に、shape と content を検証する。侵害された、または不正な external service は、予期しない型、悪意ある content、指示のような text を返せる。

検証が属さない場所:
- 型契約を共有する内部関数間
- すでに検証済みコードから呼ばれる utility functions
- 自分の database から出たばかりの data

### 4. 変更より追加を優先する

既存 consumer を壊さずに interface を拡張する:

```typescript
// 良い例: optional fields を追加する
interface CreateTaskInput {
  title: string;
  description?: string;
  priority?: 'low' | 'medium' | 'high';  // 後から追加、optional
  labels?: string[];                       // 後から追加、optional
}

// 悪い例: 既存 field type を変える、または field を削除する
interface CreateTaskInput {
  title: string;
  // description: string;  // 削除。既存 consumer を壊す
  priority: number;         // string から変更。既存 consumer を壊す
}
```

### 5. 予測可能な命名

| パターン | 慣習 | 例 |
|----------|------|----|
| REST endpoints | 複数形名詞、動詞なし | `GET /api/tasks`, `POST /api/tasks` |
| Query params | camelCase | `?sortBy=createdAt&pageSize=20` |
| Response fields | camelCase | `{ createdAt, updatedAt, taskId }` |
| Boolean fields | is/has/can prefix | `isComplete`, `hasAttachments` |
| Enum values | UPPER_SNAKE | `"IN_PROGRESS"`, `"COMPLETED"` |

## REST API パターン

### Resource 設計

```
GET    /api/tasks              → tasks 一覧（filtering 用 query params 付き）
POST   /api/tasks              → task 作成
GET    /api/tasks/:id          → 単一 task 取得
PATCH  /api/tasks/:id          → task 更新（partial）
DELETE /api/tasks/:id          → task 削除

GET    /api/tasks/:id/comments → task の comments 一覧（sub-resource）
POST   /api/tasks/:id/comments → task へ comment 追加
```

### Pagination

list endpoint は paginate する:

```typescript
// Request
GET /api/tasks?page=1&pageSize=20&sortBy=createdAt&sortOrder=desc

// Response
{
  "data": [...],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalItems": 142,
    "totalPages": 8
  }
}
```

### Filtering

filter には query parameters を使う:

```
GET /api/tasks?status=in_progress&assignee=user123&createdAfter=2025-01-01
```

### 部分更新（PATCH）

partial object を受け付ける。提供されたものだけを更新する:

```typescript
// title だけが変わり、他は保たれる
PATCH /api/tasks/123
{ "title": "更新後のタイトル" }
```

## TypeScript interface パターン

### Variant には discriminated union を使う

```typescript
// 良い例: 各 variant が明示的
type TaskStatus =
  | { type: 'pending' }
  | { type: 'in_progress'; assignee: string; startedAt: Date }
  | { type: 'completed'; completedAt: Date; completedBy: string }
  | { type: 'cancelled'; reason: string; cancelledAt: Date };

// consumer は type narrowing を得る
function getStatusLabel(status: TaskStatus): string {
  switch (status.type) {
    case 'pending': return '未着手';
    case 'in_progress': return `進行中 (${status.assignee})`;
    case 'completed': return `${status.completedAt} に完了`;
    case 'cancelled': return `キャンセル: ${status.reason}`;
  }
}
```

### Input/Output を分ける

```typescript
// Input: caller が提供するもの
interface CreateTaskInput {
  title: string;
  description?: string;
}

// Output: system が返すもの（server-generated fields を含む）
interface Task {
  id: string;
  title: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;
}
```

### ID には branded types を使う

```typescript
type TaskId = string & { readonly __brand: 'TaskId' };
type UserId = string & { readonly __brand: 'UserId' };

// TaskId が期待される場所へ誤って UserId を渡すことを防ぐ
function getTask(id: TaskId): Promise<Task> { ... }
```

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「API ドキュメントは後で書く」 | 型こそドキュメントである。先に定義する。 |
| 「今は pagination は不要」 | 誰かが 100 件以上を持った瞬間に必要になる。最初から入れる。 |
| 「PATCH は複雑だから PUT だけにする」 | PUT は毎回 full object を要求する。client が実際に求めるのは PATCH である。 |
| 「必要になったら API versioning する」 | versioning なしの breaking change は consumer を壊す。最初から拡張可能に設計する。 |
| 「その未文書の振る舞いは誰も使っていない」 | Hyrum's Law: 観測可能なら誰かが依存する。すべての public behavior を約束として扱う。 |
| 「2 バージョンを維持すればよい」 | 複数バージョンは保守コストを増やし、diamond dependency 問題を作る。One-Version Rule を優先する。 |
| 「内部 API に契約はいらない」 | 内部 consumer も consumer である。契約は coupling を防ぎ、並列作業を可能にする。 |

## 危険信号

- 条件により異なる shape を返す endpoints
- endpoint 間で一貫しない error format
- 境界ではなく内部コード全体に散らばった validation
- 既存 field への breaking changes（type change、removal）
- pagination のない list endpoints
- REST URL 内の verbs（`/api/createTask`, `/api/getUsers`）
- third-party API response を validation または sanitization なしに使う

## 検証

API 設計後に確認する:

- [ ] すべての endpoint に typed input と output schemas がある
- [ ] error responses が単一で一貫した format に従う
- [ ] validation は system boundaries だけで行われる
- [ ] list endpoints が pagination をサポートする
- [ ] 新しい fields は additive かつ optional である（backward compatible）
- [ ] naming がすべての endpoints で一貫した慣習に従う
- [ ] API documentation または types が実装と一緒に commit されている
