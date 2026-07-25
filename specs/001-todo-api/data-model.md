# データモデル: TODO 管理 API

**日付**: 2026-07-26 | **対象**: [plan.md](./plan.md) / [spec.md](./spec.md) / [architecture.md](./architecture.md)

## エンティティ: Todo

利用者が管理する 1 件のタスク。単一エンティティ、関連なし。

| フィールド | 型 | 必須 | 既定値 | 説明 / 制約 |
|-----------|-----|------|--------|-------------|
| `id` | UUID (string) | ○（自動） | 生成 | 一意識別子。作成時にサーバが UUID v4 を採番。クライアントからは指定不可 |
| `title` | string | ○ | — | 1〜256 文字。空・空白のみは不可（FR-002, FR-003） |
| `description` | string | — | `""` | 最大 1024 文字（FR-002） |
| `completed` | bool | — | `false` | 完了状態。作成時は常に false（FR-010） |
| `created_at` | timestamp | ○（自動） | 生成 | 作成日時。サーバ付与（FR-009） |
| `updated_at` | timestamp | ○（自動） | 生成 | 更新日時。更新のたびにサーバが更新（FR-009） |

## バリデーション規則

- `title`: トリム後 1〜256 文字。未指定・空・空白のみ・256 文字超 → 400（FR-003）。契約では `@minLength(1) @maxLength(256) @pattern("\\S")`。
- `description`: 1024 文字超 → 400。未指定は空文字扱い。
- `completed`: 作成（POST）では受け付けない（送られても無視し false）。更新（PUT）でのみ変更可（FR-010）。
- 未知の属性: 無視して処理（エラーにしない。spec エッジケース）。
- `id` / `created_at` / `updated_at`: リクエストで指定されても無視（サーバ管理）。

バリデーション違反時は RFC 7807 `problem+json` の `errors[]`（`field` / `code` / `message`）で不正項目を返す（FR-014）。

## API 表現（read / create / update の分離）

契約（[contracts/main.tsp](./contracts/main.tsp)）ではライフサイクルで 3 モデルに分ける。これらは **oapi-codegen が OpenAPI から生成する DTO**（`internal/api` パッケージ）であり、内部の `domain.Todo`（entity）とは別型。変換は handler が担い、usecase は domain 型のみ扱う（生成 DTO 非依存）。

- **TodoRead**: 全項目（`id`・タイムスタンプ含む）。読み取り応答。
- **TodoCreate**: `title`（必須）・`description`（任意）のみ。`completed`・`id`・日時は持たない。
- **TodoUpdate**: `title`・`description`・`completed`。`id`・日時は持たない。

## 永続化マッピング（GORM）

- entity `domain.Todo` が **永続化モデルを兼ねる**（GORM タグ付きの 1 struct を共有、変換ボイラープレートなし）。ただし `gorm.Model` / `gorm.DeletedAt` 等の GORM の**型**は domain に import せず、フィールドは `time.Time` / `string` 等の標準型に限る（タグ文字列のみ）。
- repository の **port（interface `TodoRepository`）は `domain` が所有**（依存性逆転）。GORM 実装は `internal/infra/repository` に置き、GORM 依存をそこへ隔離、`gorm.ErrRecordNotFound` は `apperror.NotFound` に変換して上位へ返す。
- テーブル `todos`。`id` は主キー（UUID、文字列 or `uuid` 型カラム）。
- `created_at` / `updated_at` は GORM の規約フィールドで自動管理。
- 起動時 `AutoMigrate(&domain.Todo{})` でスキーマ同期（[research.md](./research.md) 決定5）。
- 意味的バリデーション（上記「バリデーション規則」）は usecase が担い `errors[]` を生成する。oapi-codegen 生成コードはスキーマ制約を実行時強制しないため（[architecture.md](./architecture.md) 参照）。

### 重要: PUT 全項目置換の実装注意（GORM ゼロ値更新問題）

GORM は struct で `Updates` するとゼロ値（`false`/`0`/`""`）を無視するため、「`completed` を false に戻す」「`description` を空にする」が黙って無視される。全置換 PUT では致命的。

**推奨**: `db.Model(&Todo{}).Where("id = ?", id).Select("title","description","completed","updated_at").Updates(...)` で置換対象カラムを明示列挙（`created_at` は除外）。`RowsAffected == 0` で対象不在 → 404。`Save` はゼロ値主キーで INSERT にフォールバックする upsert 事故があるため使わない。詳細は [architecture.md](./architecture.md) の「PUT 実装方針」。

## 状態遷移

明示的な状態機械は持たない。`completed` は `false` ⇄ `true` を PUT（全項目置換）で切り替える。ライフサイクルは「作成 → （更新）* → 削除」。削除後の同一 `id` 取得は 404（FR-008, spec US1 シナリオ 10）。

## トレーサビリティ

- `title`/`description` 制約 → FR-002, FR-003
- 自動採番の `id`・日時 → FR-009
- `completed` 作成時 false 固定・更新でのみ変更 → FR-010
- 一覧は作成日時の降順 → FR-004
- 未検出時 404 → FR-008
- バリデーションエラーで不正項目提示 → FR-014
