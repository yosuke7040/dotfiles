# agent-gather-calendar-report

レポートの日付範囲に合わせてカレンダーを取得する:

```bash
# デフォルト（当日） — +agenda は未来のイベントのみ表示
gws calendar +agenda --today

# --yesterday または過去の日付 — timeMin/timeMax を指定して raw API を使用
gws calendar events list --params '{"calendarId":"primary","timeMin":"YESTERDAY_RFC3339","timeMax":"TODAY_RFC3339","singleEvents":true,"orderBy":"startTime"}'

# --days N（過去N日分）
gws calendar events list --params '{"calendarId":"primary","timeMin":"N_DAYS_AGO_RFC3339","timeMax":"NOW_RFC3339","singleEvents":true,"orderBy":"startTime"}'
```

**注意:** `gws calendar +agenda` は**未来**のイベントのみ表示する。過去の日付には `events list` で明示的に `timeMin`/`timeMax` を指定すること。

## フィルタリングルール

| 残す                      | 除外                            |
| ------------------------ | ------------------------------ |
| 1on1、レビュー、プランニング | 重複するスタンドアップ（1つだけ残す）|
| 外部ミーティング            | 辞退/キャンセル済み              |
| 意思決定ミーティング         | 成果のないルーティン同期          |
| 面接、デモ                 | 終日のFYIイベント                |
