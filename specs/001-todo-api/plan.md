# 実装計画: TODO 管理 API

**ブランチ**: `feat/todo-api-spec` | **日付**: 2026-07-25 | **仕様**: [spec.md](./spec.md)

**入力**: `specs/001-todo-api/spec.md` の機能仕様

**補足**: このタスクのスコープは**仕様と技術選定（Phase 1 設計まで）**。タスク分解（`/speckit-tasks`）と実装（`/speckit-implement`）は次フェーズ。

## 概要

単一リソース `Todo` の CRUD を提供する REST API。全エンドポイントを API キー（`Authorization: Bearer`）で保護する。データは PostgreSQL に永続化する。技術的アプローチは Go + Gin（HTTP/ミドルウェア）+ GORM（ORM）で、認証はミドルウェアで横断的に適用し、ハンドラ → リポジトリ（GORM）→ PostgreSQL の層構成とする。

## 技術的コンテキスト

**言語/バージョン**: Go 1.26+（`mise.toml` で 1.26.5 固定）

**主要な依存関係**（バージョンは 2026-07 時点の最新安定、詳細と根拠は [research.md](./research.md)）:
- `github.com/gin-gonic/gin` v1.12.0 — HTTP ルーティング、認証ミドルウェア
- `gorm.io/gorm` v1.31.2 + `gorm.io/driver/postgres` v1.6.0 — ORM / DB アクセス
- `github.com/google/uuid` v1.6.0 — UUID v4 生成
- `github.com/stretchr/testify` v1.11.1 — テストアサーション

**ストレージ**: PostgreSQL 16（ローカルは Docker Compose で起動）

**テスト**: Go 標準 `testing` + `net/http/httptest` + `testify`（単体/結合）、DB 結合は `testcontainers-go`（実 PostgreSQL）、外部受け入れは **Bruno**（`.bru` + `bru run` CLI）。役割分担は [architecture.md](./architecture.md) のテスト戦略。

**API 契約ツール**: **TypeSpec**（`contracts/main.tsp` を SSoT）→ `tsp compile` で OpenAPI（`contracts/openapi.yaml`）を生成。エラー形式は RFC 7807 `application/problem+json`。

**対象プラットフォーム**: Linux サーバー（コンテナ実行想定）

**プロジェクト種別**: web-service（backend のみの単一プロジェクト）

**パフォーマンス目標**: サンプル用途のため定量目標は設定しない（機能正当性を優先）

**制約**:
- 認証: API キーを `Authorization: Bearer <key>` で受領し、Gin ミドルウェアで検証。キーは環境変数で単一管理（`API_KEY`）
- `id` は UUID
- バリデーション: `title` 必須 1〜256 文字、`description` 任意 最大 1024 文字
- マイグレーションはサンプル簡易のため GORM `AutoMigrate`（本番相当が必要なら `golang-migrate` に差し替え可）

**規模/スコープ**: 単一リソース（Todo）+ 認証ミドルウェア。エンドポイント 5 本（POST/GET一覧/GET単一/PUT/DELETE）

## 憲章チェック

*ゲート: Phase 0 リサーチ前に通過必須。Phase 1 設計後に再チェックする。*

憲章 v1.0.0 の 5 原則に対する評価:

- **I. 仕様優先**: ✅ spec.md が先行し、承認済み。本計画は spec に基づく。
- **II. 単一の真実源（SSoT）**: ✅ 要件は spec、技術判断は本 plan、規約は `docs/conventions/` に分離。重複なし。
- **III. 受け入れ基準駆動**: ✅ spec に Given/When/Then を定義済み。contracts と quickstart で検証可能な形に落とす。
- **IV. 追跡可能性**: ✅ spec の FR/受け入れシナリオ → 本 plan の設計 → （次フェーズの tasks）へ辿れる構造。
- **V. 簡潔さ・YAGNI**: ⚠️ **要正当化**。Gin + GORM は標準 `net/http` + `database/sql` より重い。クリーンアーキ寄りの層（domain port / usecase 分離）と oapi-codegen 導入も抽象・ツールを増やす。→ いずれも「複雑さの追跡」で正当化する。ページング/検索/PATCH/マルチテナントは spec でスコープ外とし、先回り実装しない。interactor / boundary / Unit of Work / 汎用リポジトリは作らない。

**ゲート判定（Phase 0 前）**: 原則 V の逸脱を「複雑さの追跡」で正当化のうえ通過。他原則は適合。

**再チェック（Phase 1 設計後）**: ✅ 維持。research / architecture / data-model / contracts / quickstart は spec の FR・受け入れシナリオに対応づけ済み（原則 IV）。原則 V の歯止めを具体化: (1) GORM 依存を `infra/repository` に隔離し `gorm.ErrRecordNotFound → apperror.NotFound` 変換もそこで行う、repository の port（interface）は domain 側が所有（依存性逆転）、(2) handler へ生成 DTO 経由で GORM 型を漏らさない・usecase は生成 DTO（`api`）に依存しない、(3) PUT 全項目置換は GORM ゼロ値更新問題を `Model().Select(...列挙...).Updates()` で回避（`Save` の upsert 事故を避ける）、(4) トランザクションは単一集約 CRUD ゆえ暗黙単文のみ・Unit of Work 不採用、(5) DI は手動 constructor injection でコンテナ不使用、(6) oapi-codegen は生成物をコミット・go tool（Node 非依存）・エラー変換は 1 箇所に集約。スコープ外機能（ページング/検索/PATCH/マルチテナント）は設計に持ち込んでいない。新規に正当化を要する逸脱は「クリーンアーキ寄り層（domain port / usecase 分離）」「oapi-codegen 導入」「TypeSpec 導入」の 3 件で、いずれも「複雑さの追跡」に記録済み。

## プロジェクト構造

### ドキュメント（この機能）

```text
specs/001-todo-api/
├── plan.md              # このファイル
├── research.md          # 技術選定（比較・決定・バージョン）
├── architecture.md      # アーキテクチャ設計（層・DI・エラー・テスト戦略）
├── data-model.md        # データモデル（Todo・バリデーション・GORM 実装注意）
├── quickstart.md        # 検証ガイド（TypeSpec 生成・Bruno・testcontainers）
├── contracts/           # API 契約（TypeSpec を SSoT、OpenAPI は生成物）
│   ├── main.tsp         #   契約本体（真実源）
│   ├── tspconfig.yaml   #   エミッタ設定
│   ├── package.json     #   TypeSpec ツールチェーン（Node）
│   ├── openapi.yaml     #   tsp compile の生成物（コミット対象）
│   └── README.md        #   生成手順・方針
└── checklists/
    └── requirements.md  # spec 品質チェックリスト
```

### ソースコード（リポジトリルート）

単一プロジェクト（backend のみ）を採用。Go の慣習に沿い `cmd/`（エントリポイント）と `internal/`（非公開実装）を技術レイヤ別に構成する。※ 以下は**次フェーズ（implement）で作成する想定レイアウト**であり、本タスクでは生成しない。設計の詳細（層の責務・依存方向・DI・エラー・PUT 実装）は [architecture.md](./architecture.md)。

```text
cmd/
└── api/
    └── main.go                  # 唯一の可動部: 設定読込→DI 配線→ルーティング→起動

internal/
├── config/config.go             # env を型付き struct へ（起動時一括読込・fail-fast）
├── domain/                      # entity（todo.go、GORM タグ付・型は import しない）+ repository port（repository.go）
├── usecase/todo_usecase.go      # TodoUsecase（port 依存）。業務ルール（completed 固定/更新、PUT 全置換）+ 意味的検証
├── infra/repository/            # GORM 実装（port を満たす。GORM 依存をここに隔離）
├── handler/                     # 生成 StrictServerInterface を実装。DTO↔domain 変換
├── api/                         # oapi-codegen 生成物（*.gen.go）+ cfg.yaml + generate.go
├── middleware/                  # auth.go（Bearer 検証）
└── apperror/errors.go           # ドメインエラー + problem+json レンダラ（Validation/NotFound/Unauthorized）

tests/
└── integration/                 # httptest + testcontainers（実 PostgreSQL）
                                 # 単体は各パッケージに *_test.go 同居（Go 慣用）

bruno/                           # Bruno .bru（受け入れテスト）
docker-compose.yml               # PostgreSQL 16
```

**構造の決定**: クリーンアーキ寄りの層構成（handler → usecase → repository、port は domain 所有＝依存性逆転）。HTTP 境界は oapi-codegen（strict-server + Gin）生成コードを handler が実装。原則 V の歯止めとして、(1) GORM 依存は `internal/infra/repository` に閉じ込め、port は domain 側が所有、(2) handler へは生成 DTO 経由で GORM 型を漏らさず usecase は生成 DTO 非依存、(3) 汎用リポジトリ・DI コンテナ・Unit of Work・interactor は作らない。エラーは `apperror` の単一レンダラ 1 箇所で RFC 7807 `problem+json` に変換する。

## 複雑さの追跡

> 憲章チェックの原則 V（簡潔さ・YAGNI）の逸脱に対する正当化。

| 違反 | 必要な理由 | よりシンプルな代替案を却下した理由 |
|-----------|------------|-------------------------------------|
| Gin フレームワーク採用 | 実務相当のサンプルを示す。認証ミドルウェアの合成・ルーティングを慣用的な形で提示できる | 標準 `net/http`（Go1.22 ServeMux）でも実装可能だが、ミドルウェア合成やバインディングを自前実装する必要があり、実務でよく使う型を示せない |
| GORM（ORM）採用 | ORM マッピング・`AutoMigrate` を含む一般的な永続化パターンを学べる。CRUD の記述量を抑える | 標準 `database/sql` + `pgx` はより単純だが SQL を都度手書きする必要があり、サンプルの主眼（実務パターン提示）から外れる。歯止めとして `infra/repository` に閉じ込め、依存の漏れを防ぐ |
| クリーンアーキ寄り層（domain port / usecase 分離） | 「completed 固定・PUT 全置換」等のドメインルールの置き場所を明確化し、port を domain が所有して GORM 実装を外へ隔離、テスト容易性・DB 交換耐性を得る | 素のレイヤード（repository が interface 所有）でも動くが port の所有が曖昧で GORM が上位層ににじむ。interactor / boundary / Unit of Work / 汎用リポジトリは作らず、層は domain/usecase/handler/infra の最小 4 種に限定 |
| oapi-codegen（strict-server + Gin）導入 | OpenAPI（SSoT）から handler I/F・DTO・バインドを生成し、契約と実装のドリフトを構造的に排除。手書き DTO/バインドの重複を削減 | 手書き handler + DTO は契約と二重管理でドリフトしやすい。歯止めとして生成物をコミット、生成器は go tool（Node 非依存）、usecase は生成型に依存させない、エラー変換は 1 箇所に集約 |
| TypeSpec ツールチェーン（Node）導入 | OpenAPI を手書きせず単一の型定義から生成し、契約のドリフトを防ぐ。oapi-codegen の入力 SSoT | 手書き OpenAPI YAML は冗長で重複・ドリフトしやすい。歯止めとして TypeSpec を `contracts/` に隔離し、生成物 `openapi.yaml` をコミット、Go 開発に Node を強制しない |
