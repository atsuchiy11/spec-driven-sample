# リサーチ: TODO 管理 API（技術選定）

**日付**: 2026-07-26 | **対象**: [plan.md](./plan.md)

技術選定は確定済み。以下は各決定の根拠・評価・trade-off。バージョンは 2026-07 時点の最新安定版。

## 評価マトリクス

### Web フレームワーク（Gin 確定）

Web フレームワークは **Gin で確定**。Go 1.22 の `net/http.ServeMux` がパスパラメータ・メソッド別ルーティングを標準化し、ルーティング性能は差別化要因でなくなった。差は開発体験・ミドルウェア合成・バインディング/バリデーションの手厚さに移行。Gin は `ShouldBindJSON` + `go-playground/validator` タグ、ルートグループ、成熟したミドルウェア群、2025 実測で採用率 48%（Gorilla 17 / Echo 16 / Fiber 11）を備える。TODO サンプルでは学習コスト最小・情報最多の定番であり、憲章の簡潔さ・YAGNI に合致。

参考採点（◎優 ○良 △可）: Gin=バインド/バリデ◎・MW◎・採用◎・学習◎、Echo=◎◎○○、chi=△◎○◎、net/http 1.22=△○△◎。

出典: JetBrains 2025 Go trends、Encore「Gin vs Echo vs Fiber」。

### DB アクセス比較

| 評価軸 | GORM（採用） | sqlc | pgx（生） | database/sql |
|---|---|---|---|---|
| 記述量（CRUD） | ◎ 規約で自動化 | ○ 定型は生成 | △ 冗長 | △ 最冗長 |
| 型安全 | △ 文字列・実行時 | ◎ 生成で保証 | ○ スキャン自己責任 | △ 手動スキャン |
| SQL 可視性 | △ 生成 SQL が隠れる | ◎ SQL が真実源 | ◎ 手書き | ◎ 手書き |
| マイグレーション連携 | ◎ AutoMigrate 内蔵 | △ 別途 | △ 別途 | △ 別途 |
| 学習コスト | ○ 規約習得 | ○ SQL+生成 | △ PG 固有 | ○ 標準のみ |
| パフォーマンス | △ 多件数/複雑で劣化 | ◎ ほぼ生 SQL | ◎ PG 最速 | ◎ 良好 |
| 動的クエリ | ◎ 得意 | △ 苦手 | ◎ 自由 | ◎ 自由 |
| 落とし穴 | ゼロ値更新/N+1/ロジック混入 | 動的クエリ不可 | 記述量/PG ロックイン | ボイラープレート |

出典: reintech 2026、JetBrains DB 比較、Bytebase 2025、dasroot 2025、glukhov。

## 決定

### 決定1: Gin
- **Decision**: `github.com/gin-gonic/gin`。
- **Rationale**: 採用率 No.1・バインド/バリデ標準搭載・学習最小。Go 1.22 でルーティング性能は差別化要因でないため開発体験と定番性で選ぶ。
- **Alternatives**: Echo（次点・idiomatic）、chi（軽量だがバインド自前）、net/http 1.22（依存ゼロだがバリデ/エラー整形を全自作）。
- **Trade-off・歯止め**: `Context` が薄くエラー整形は規約化が必要。ハンドラを薄く保ちロジックは service へ。

### 決定2: GORM + PostgreSQL
- **Decision**: `gorm.io/gorm` + `gorm.io/driver/postgres` + PostgreSQL 16。
- **Rationale**: CRUD 中心で規約自動化・AutoMigrate 内蔵が開発速度に直結、YAGNI に合致。少件数では性能十分。
- **Alternatives**: sqlc（型安全最良/動的弱）、pgx 生（最速/冗長）、database/sql（冗長）。
- **Trade-off・歯止め**: 型安全が弱く reflection オーバーヘッド・N+1・ゼロ値更新の落とし穴。(1) GORM 依存を repository 層に完全隔離、(2) 過度な抽象化しない、(3) 性能 critical 箇所のみ sqlc/pgx 差し替え可。本番マイグレーションが要れば AutoMigrate → golang-migrate。

### 決定3: 認証（API キー / Bearer）
- **Decision**: `Authorization: Bearer <key>` を Gin ミドルウェアで検証。正解キーは環境変数 `API_KEY` で単一管理。
- **Rationale**: 標準ヘッダを用い単一クライアント想定に最小構成。ヘッダ欠落・不一致は 401。
- **注意**: キー比較は `crypto/subtle.ConstantTimeCompare` で定数時間比較（タイミング攻撃回避）。
- **Alternatives**: `X-API-Key`（非標準）、クエリパラメータ（URL/ログ漏洩）、DB 管理の複数キー（YAGNI）。

### 決定4: 識別子（UUID）
- **Decision**: `id` は UUID v4（`github.com/google/uuid`、`uuid.New()`）。
- **Rationale**: 推測困難で列挙攻撃を防ぐ・分散生成可。
- **Alternatives**: 連番整数（件数推測・列挙されやすい）。

### 決定5: マイグレーション（AutoMigrate）
- **Decision**: 起動時 GORM `AutoMigrate`。
- **Rationale**: サンプルとして手順最小・単一テーブルで十分。
- **Alternatives**: golang-migrate（本番相当が要れば差し替え可）。

### 決定6: テスト（testing + httptest + testify + Bruno）
- **Decision**: Go 単体/結合は標準 `testing` + `net/http/httptest` + `testify`、外部受け入れは Bruno。詳細は [architecture.md](./architecture.md) のテスト戦略、[quickstart.md](./quickstart.md)。
- **Rationale**: 受け入れシナリオ（Given/When/Then）を HTTP レベルで検証でき原則 III に直結。

### 決定7: API コード生成（oapi-codegen / strict-server + Gin）
- **Decision**: `openapi.yaml` から `github.com/oapi-codegen/oapi-codegen/v2` で Go の HTTP 境界コードを生成する。生成モードは **strict-server + Gin**（`gin-server` + `strict-server` + `models` を併記）。handler が生成 `StrictServerInterface` を実装し usecase を呼ぶ。
- **Rationale**: 契約（OpenAPI = TypeSpec 由来）から handler インターフェース・DTO・バインドを導出し、契約と実装のドリフトを構造的に排除。手書き DTO/バインドの重複を削減。strict モードは req/res が型付きで、契約準拠がコンパイル時に強制される。
- **Alternatives**: 手書き handler + DTO（契約と二重管理でドリフト）、ogen（生成物が重厚・学習コスト）、swaggo（コード→OpenAPI の逆方向で SSoT が実装側になる）。
- **Trade-off・歯止め**: 生成コードは go-playground/validator を使わず OpenAPI スキーマ制約を実行時強制しない → 意味的 field 検証（`errors[]`）は usecase のドメイン検証で補完（後述）。歯止め: 生成物 `src/internal/api/*.gen.go` をコミット（Node/生成器なしでビルド可）、生成器は go tool（Node 非依存）、usecase は生成 DTO に依存させない、エラー変換は 1 箇所に集約。

### 決定8: アーキテクチャ（クリーンアーキ寄り / 依存性逆転）
- **Decision**: handler → usecase → repository の層構成で、repository の interface（port）を **domain/usecase 側が所有**する（依存性逆転）。GORM 実装は最も外側の `infra/repository` に隔離。usecase は単一 `TodoUsecase` struct に CRUD を束ねる。
- **Rationale**: 「completed 固定/PUT 全置換」等のドメイン規則の置き場所を明確化し、port を内側が持つことで GORM 実装を外へ隔離、テスト容易性・DB 交換耐性を得る。
- **Alternatives**: 素のレイヤード（repository が interface 所有）。port の所有が曖昧で GORM が上位層ににじむ。
- **Trade-off・歯止め**: 層追加は plan.md「複雑さの追跡」で正当化。interactor / input-output boundary / Unit of Work / 汎用リポジトリは**作らない**（過剰さの回避）。層は domain/usecase/handler/infra の最小 4 種に限定。

## バージョンと依存（2026-07 時点、Go 1.26+）

| モジュールパス | 推奨バージョン | 備考 |
|---|---|---|
| `github.com/gin-gonic/gin` | v1.12.0（2026-02-28） | 最新安定 |
| `gorm.io/gorm` | v1.31.2（2026-06-22） | 最新安定 |
| `gorm.io/driver/postgres` | v1.6.0（2025-05-27） | PostgreSQL 16 対応 |
| `github.com/google/uuid` | v1.6.0 | `uuid.New()` で v4 |
| `github.com/stretchr/testify` | v1.11.1 | `assert`/`require` |

`testing` + `net/http/httptest` は Go 同梱でバージョン管理不要。

出典: 各 `pkg.go.dev` の versions タブ、`gin-gonic/gin` releases。

## 実装上の注意（要点）

### Gin
- **`ShouldBindJSON` を使う**（`BindJSON` は失敗時に自動 400+Abort でレスポンス形式が統一できない）。
- **`binding:"required"` とゼロ値の罠**: `required` は `false`/`0` を弾く。数値/真偽値の必須判定はポインタ型（`*bool`, `*int`）や独自バリデータを使う。
- **既定のバリデーションエラーが不親切** → `validator.ValidationErrors` へ型アサートしフィールド単位で整形、`RegisterTagNameFunc` で JSON タグ名を使用。
- **エラーは集約ミドルウェアで**: ハンドラは `c.Error(err)` に積み、後段ミドルウェアで一貫フォーマット + ステータス変換。内部情報は露出しない。

### GORM（最重要: PUT 全項目置換のゼロ値更新問題）
- GORM は struct で `Updates` すると **非ゼロ値フィールドしか UPDATE しない**。`false`/`0`/`""` が SET 句から脱落し、「完了フラグを false に戻す」が黙って無視される古典的バグ。
- `Save` は全フィールドを書くが、`ID` がゼロだと **INSERT にフォールバック（upsert 事故）**、カスケード保存の副作用もある。
- **回避（PUT 推奨形）**: `db.Model(&entity).Where("id = ?", id).Select("title","description","completed","updated_at").Updates(...)` で置換対象カラムを明示列挙（`created_at` は除外）。`RowsAffected == 0` で対象不在 → 404。詳細は [architecture.md](./architecture.md)。

出典: GORM 公式 Update、Donald Le、codestudy、GORM issue #7072、codingexplorations、DeepSource GO-E1005、Gin binding/validation 各記事。

## OpenAPI 定義 = TypeSpec、API テスト = Bruno

- **TypeSpec**: OpenAPI 定義は TypeSpec（`.tsp`）で記述し `tsp compile` で `openapi.yaml` を生成する。詳細な採用根拠・構成は [architecture.md](./architecture.md) のツールチェーン節、契約本体は [contracts/main.tsp](./contracts/main.tsp)。
  - 歯止め（Go に Node 同居）: TypeSpec 一式を `contracts/` に隔離し `package.json` 分離、生成物 `openapi.yaml` はコミット（Node 無しでも Go 側が参照可）、生成は独立ジョブに閉じ込め Go 開発に Node を強制しない。
- **Bruno**: 外部結合/受け入れは Bruno（`.bru` + `@usebruno/cli` の `bru run`）。Git ネイティブ・OSS・オフライン。README に元々 Bruno 記載あり、その方針を踏襲。testify（Go 内ロジック）と役割分担（契約/E2E=Bruno、単体/結合=testify）。

出典: Microsoft Learn TypeSpec overview、typespec.io、Speakeasy、usebruno.com、usebruno/bruno GitHub、byteiota。
