# テストパターンリファレンス

stack 全体でよく使う testing patterns のクイックリファレンス。`test-driven-development` skill と併用する。

## 目次

- [Test Structure（Arrange-Act-Assert）](#test-structurearrange-act-assert)
- [Test Naming Conventions](#test-naming-conventions)
- [Common Assertions](#common-assertions)
- [Mocking Patterns](#mocking-patterns)
- [React / Component Testing](#react--component-testing)
- [API / Integration Testing](#api--integration-testing)
- [E2E Testing（Playwright）](#e2e-testingplaywright)
- [テストのアンチパターン](#テストのアンチパターン)

## テスト構造（Arrange-Act-Assert）

```typescript
it('期待する振る舞いを説明する', () => {
  // Arrange: test data と preconditions を準備する
  const input = { title: 'テストタスク', priority: 'high' };

  // Act: test 対象の action を実行する
  const result = createTask(input);

  // Assert: outcome を検証する
  expect(result.title).toBe('テストタスク');
  expect(result.priority).toBe('high');
  expect(result.status).toBe('pending');
});
```

## テスト命名規則

```typescript
// パターン: [unit] [expected behavior] [condition]
describe('TaskService.createTask', () => {
  it('default の pending status で task を作成する', () => {});
  it('title が空なら ValidationError を投げる', () => {});
  it('title の whitespace を trim する', () => {});
  it('task ごとに unique ID を生成する', () => {});
});
```

## よく使う assertions

```typescript
// equality
expect(result).toBe(expected);           // strict equality (===)
expect(result).toEqual(expected);        // deep equality (objects/arrays)
expect(result).toStrictEqual(expected);  // deep equality + type matching

// truthiness
expect(result).toBeTruthy();
expect(result).toBeFalsy();
expect(result).toBeNull();
expect(result).toBeDefined();
expect(result).toBeUndefined();

// numbers
expect(result).toBeGreaterThan(5);
expect(result).toBeLessThanOrEqual(10);
expect(result).toBeCloseTo(0.3, 5);      // floating point

// strings
expect(result).toMatch(/pattern/);
expect(result).toContain('substring');

// arrays / objects
expect(array).toContain(item);
expect(array).toHaveLength(3);
expect(object).toHaveProperty('key', 'value');

// errors
expect(() => fn()).toThrow();
expect(() => fn()).toThrow(ValidationError);
expect(() => fn()).toThrow('specific message');

// async
await expect(asyncFn()).resolves.toBe(value);
await expect(asyncFn()).rejects.toThrow(Error);
```

## mock パターン

### 関数を mock する

```typescript
const mockFn = jest.fn();
mockFn.mockReturnValue(42);
mockFn.mockResolvedValue({ data: 'test' });
mockFn.mockImplementation((x) => x * 2);

expect(mockFn).toHaveBeenCalled();
expect(mockFn).toHaveBeenCalledWith('arg1', 'arg2');
expect(mockFn).toHaveBeenCalledTimes(3);
```

### module を mock する

```typescript
// module 全体を mock する
jest.mock('./database', () => ({
  query: jest.fn().mockResolvedValue([{ id: 1, title: 'テスト' }]),
}));

// specific exports を mock する
jest.mock('./utils', () => ({
  ...jest.requireActual('./utils'),
  generateId: jest.fn().mockReturnValue('test-id'),
}));
```

### 境界だけを Mock する

```
mock するもの:                  mock しないもの:
├── database calls              ├── internal utility functions
├── HTTP requests               ├── business logic
├── file system operations      ├── data transformations
├── external API calls          ├── validation functions
└── time / date（必要な場合）    └── pure functions
```

## React / component testing

```tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';

describe('TaskForm', () => {
  it('入力された data で form を submit する', async () => {
    const onSubmit = jest.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    // test ID ではなく accessible role / label で elements を探す
    await screen.findByRole('textbox', { name: /タイトル/i });
    fireEvent.change(screen.getByRole('textbox', { name: /タイトル/i }), {
      target: { value: '新しいタスク' },
    });
    fireEvent.click(screen.getByRole('button', { name: /作成/i }));

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({ title: '新しいタスク' });
    });
  });

  it('title が空なら validation error を表示する', async () => {
    render(<TaskForm onSubmit={jest.fn()} />);

    fireEvent.click(screen.getByRole('button', { name: /作成/i }));

    expect(await screen.findByText(/タイトルは必須です/i)).toBeInTheDocument();
  });
});
```

## API / integration testing

```typescript
import request from 'supertest';
import { app } from '../src/app';

describe('POST /api/tasks', () => {
  it('task を作成して 201 を返す', async () => {
    const response = await request(app)
      .post('/api/tasks')
      .send({ title: 'テストタスク' })
      .set('Authorization', `Bearer ${testToken}`)
      .expect(201);

    expect(response.body).toMatchObject({
      id: expect.any(String),
      title: 'テストタスク',
      status: 'pending',
    });
  });

  it('invalid input には 422 を返す', async () => {
    const response = await request(app)
      .post('/api/tasks')
      .send({ title: '' })
      .set('Authorization', `Bearer ${testToken}`)
      .expect(422);

    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('authentication なしでは 401 を返す', async () => {
    await request(app)
      .post('/api/tasks')
      .send({ title: 'テスト' })
      .expect(401);
  });
});
```

## E2E testing（Playwright）

```typescript
import { test, expect } from '@playwright/test';

test('user が task を作成して完了できる', async ({ page }) => {
  // navigate and authenticate
  await page.goto('/');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="password"]', 'testpass123');
  await page.click('button:has-text("ログイン")');

  // task を作成する
  await page.click('button:has-text("新しいタスク")');
  await page.fill('[name="title"]', '食料品を買う');
  await page.click('button:has-text("作成")');

  // task が表示されることを検証する
  await expect(page.locator('text=食料品を買う')).toBeVisible();

  // task を完了する
  await page.click('[aria-label="完了: 食料品を買う"]');
  await expect(page.locator('text=食料品を買う')).toHaveCSS(
    'text-decoration-line', 'line-through'
  );
});
```

## テストのアンチパターン

| アンチパターン | 問題 | より良い approach |
|---|---|---|
| implementation details を test する | refactor で壊れる | inputs / outputs を test する |
| 何でも snapshot にする | snapshot diff が review されない | specific values を assert する |
| shared mutable state | tests が互いを汚染する | test ごとに setup / teardown |
| third-party code を test する | 時間の無駄で、自分の bug ではない | boundary を mock する |
| CI を通すために tests を skip する | 本物の bugs を隠す | test を直すか削除する |
| `test.skip` を恒久利用する | dead code | 削除または修正する |
| assertion が広すぎる | regression を捕まえない | specific にする |
| async error handling がない | errors が飲まれ、false pass になる | async tests では常に `await` する |
