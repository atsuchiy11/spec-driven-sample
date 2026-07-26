# アーキテクチャ設計: TODO 管理 API

**日付**: 2026-07-26 | **対象**: [plan.md](./plan.md) / [spec.md](./spec.md) / [contracts/main.tsp](./contracts/main.tsp)

前提: Go 1.26+ / Gin / GORM / PostgreSQL 16 / API キー認証（Bearer）/ id=UUID v4。API 契約は TypeSpec（`contracts/main.tsp`）を SSoT とし、`tsp compile` で OpenAPI 3.0.0 を生成、さらに **oapi-codegen（strict-server + Gin）** で Go の handler インターフェース・DTO・バインドを生成する。アーキテクチャは **クリーンアーキ寄り**（依存性逆転: repository の port を domain/usecase 側が所有）。憲章原則 V（簡潔さ・YAGNI）を各所で明示する。

## アーキテクチャ概要

**クリーンアーキ寄りの構成**を採る。依存方向を内向き（外側=HTTP/生成コード、内側=ドメイン）に統一し、**依存性逆転**により repository の interface（port）を **domain/usecase 側が所有**する。GORM 依存は最も外側の `infra/repository` に完全に閉じ込め、`*gorm.DB` や GORM 固有型を usecase / domain / handler に漏らさない。usecase は port（interface）にのみ依存し、具象の永続化実装を知らない（テスト時のモック差し替え・DB 交換耐性）。

**usecase 層は単一 `TodoUsecase` struct に CRUD を束ねる**。理由: spec に「`completed` は作成時 false 固定・更新でのみ変更可」「PUT は全項目置換」「`title` 1..256・空白のみ不可 等の意味的バリデーション」という repository でも handler でもないドメインルールがあり、その置き場所として usecase が自然（空の pass-through にならない）。ただし **interactor / input-output boundary / Unit of Work / 汎用リポジトリ / トランザクションマネージャ抽象は作らない**（YAGNI）。usecase は「意味的バリデーション + ドメインルール適用 + 単一 repository 呼び出し」に留める。

**HTTP 境界は oapi-codegen（strict-server + Gin）が生成する `StrictServerInterface` を handler が実装する**。リクエスト/レスポンスの DTO・バインドを契約（OpenAPI）から導出し、契約と実装のドリフトを構造的に排除する。usecase は生成 DTO に依存せず domain 型のみを扱う（変換は handler が担う）。

> 代替案: 純レイヤード（handler→service→repository、repository が interface を所有）でも spec は成立する。しかし port の所有が曖昧で GORM が上位層ににじむため、port を内側（domain）が所有する依存性逆転を採用しつつ、interactor/boundary 等の過剰な抽象は排除するのが落とし所（この判断は plan.md「複雑さの追跡」に記録）。

出典: CyberAgent「Clean Architecture in Go」、Three Dots Labs「Repository pattern in Go」、oneuptime「Repository Pattern」、dev.to「A good reason to create a service layer」。

## ディレクトリレイアウト

実装コードは全て `src/` 配下に置く。その中を Go 慣習（`src/cmd/`=エントリポイント、`src/internal/`=外部 import 不可の非公開実装）準拠で構成する。リソースが Todo 単一のため、クリーンアーキ寄りの層をパッケージで表現する。

```text
src/
├── cmd/
│   └── api/
│       └── main.go                 # 唯一の可動部: 設定読込→DI 配線→ルーティング→起動
└── internal/
    ├── config/
    │   └── config.go               # env を型付き struct へ。起動時一括読込&検証（fail-fast）
    ├── domain/
    │   ├── todo.go                 # エンティティ Todo（GORM タグ付き。GORM の「型」は import しない）
    │   └── repository.go           # repository port（interface TodoRepository）を domain が所有
    ├── usecase/
    │   └── todo_usecase.go         # TodoUsecase。port 依存、業務ルール（completed 固定/更新、PUT 全置換）+ 意味的バリデーション
    ├── infra/
    │   └── repository/
    │       └── gorm_todo_repository.go # GORM 実装（port を満たす）。*gorm.DB をここに閉じ込める
    ├── handler/
    │   └── todo_handler.go         # 生成 StrictServerInterface を実装。DTO↔domain 変換、usecase 呼出
    ├── api/
    │   ├── cfg.yaml                # oapi-codegen 設定（gin-server + strict-server + models）
    │   ├── generate.go             # //go:generate ディレクティブ
    │   └── todo.gen.go             # oapi-codegen 生成物（ServerInterface/StrictServerInterface/DTO、コミット対象）
    ├── middleware/
    │   └── auth.go                 # Authorization: Bearer 検証
    └── apperror/
        └── errors.go               # ドメインエラー型 + problem+json レンダラ（NotFound/Validation/Unauthorized）

tests/
└── integration/                    # httptest でハンドラ+ミドルウェア。testcontainers で PostgreSQL
                                    # 単体テストは各パッケージに *_test.go 同居（Go 慣用）

contracts/                          # TypeSpec 定義と生成 OpenAPI（api 契約の SSoT）
bruno/                              # Bruno .bru（受け入れテスト、bru run CLI）
docker-compose.yml                  # PostgreSQL 16
```

- `pkg/` は作らない（外部再利用予定なし → YAGNI）。
- 単体テストは各パッケージ内 `*_test.go` 同居、DB を伴う結合のみ `tests/integration/` に集約。
- 集約エラー変換は `middleware/error.go` を廃し、`apperror` の単一レンダラ + oapi-codegen の strict オプション（`ResponseErrorHandlerFunc` / `GinServerOptions.ErrorHandler`）に集約する（後述「エラーハンドリング」）。
- `src/internal/api/` は生成物専用。手書きしない（契約変更→再生成）。

出典: buanacoding「Structuring Go Projects 2025」、glukhov「Go Project Structure」。

## 層と依存方向

依存は**外→内の一方向**。内側は外側を知らない。port を内側（domain）が所有し、GORM 実装が外側からそれを満たす（依存性逆転）。

```text
main.go ──configures──▶ [ api(生成: Strict/ServerInterface) ]
                              │ NewStrictHandler + RegisterHandlers
                              ▼
                        [ handler ] ──▶ [ usecase ] ──▶ [ domain.TodoRepository (port) ]
                              │              │                        ▲
                    DTO↔domain 変換          │ 依存                    │ implements
                              ▼              ▼                        │
                        [ domain(entity) ] ◀────────── [ infra/repository(GORM) ] ──▶ PostgreSQL
        すべての層が参照 ──▶ [ domain / apperror(ドメインエラー) ]
```

| 層 | 責務 | 依存先 | GORM 可視性 |
|----|------|--------|-------------|
| api（生成） | `ServerInterface`/`StrictServerInterface`/DTO・バインド。ルーティング束ね（`RegisterHandlers`） | （自己完結、内部 import なし） | 不可 |
| handler | 生成 `StrictServerInterface` を実装。DTO↔domain 変換、usecase 呼出、`(nil, apperror)` でエラー委譲 | api（生成 DTO）, usecase, domain, apperror | 不可 |
| usecase | 業務ルール（completed 固定/更新、PUT 全置換）、意味的バリデーション、apperror 生成 | domain（port + entity）, apperror | 不可 |
| domain (port) | データアクセスの契約（`Create/FindAll/FindByID/Update/Delete`）を **domain が所有**、domain 型で入出力 | なし | 不可 |
| domain (entity) | エンティティ Todo | なし | GORM タグは持つ（型は import しない） |
| infra/repository (GORM 実装) | port を満たす。GORM クエリ、`gorm.ErrRecordNotFound → apperror.NotFound` 変換 | domain, GORM, apperror | **ここだけ可** |
| middleware | 認証（横断） | config, apperror | 不可 |
| apperror | ドメインエラー型 + problem+json レンダラ | なし | 不可 |
| config | env を型付き struct へ | なし | — |

**原則 V との整合**: interface は `TodoRepository` 1 本のみ。汎用 `Repository[T]` やジェネリック CRUD 基底、interactor/boundary は作らない。抽象は「テスト容易性」「GORM 隔離」という具体的見返りがある箇所に限定。**usecase は生成 DTO（`api` パッケージ）を import しない**——シグネチャは domain 型のみで表現し、DTO⇔domain 変換は handler に閉じる。

> GORM タグの置き場所: 完全なクリーン設計では「純ドメイン entity」と「永続化 struct」を分離するが、Todo 単一では冗長。**`domain.Todo` に GORM タグを付与し 1 struct 共有**とする。ただし `gorm.Model` / `gorm.DeletedAt` 等の GORM の**型**は domain に持ち込まず（タグ文字列のみ）、フィールドは `time.Time` / `string` 等の標準型に限る。API 境界へは必ず生成 DTO 経由で GORM を漏らさない（YAGNI 的妥協点）。

出典: CyberAgent「Clean Architecture in Go」、pawelgrzybek「Repository pattern」。

## 依存注入

**フレームワーク不使用の手動配線（constructor injection）**。wire/fx/dig は導入しない（配線対象が数個 → YAGNI）。`main.go` を唯一の可動部とし、下位層は依存を内部で `new` せずコンストラクタ引数で受け取る。

```go
func main() {
    cfg := config.Load()                        // env を型付きで一括読込・検証（fail-fast）

    db := mustOpenGorm(cfg.DatabaseDSN)         // *gorm.DB。以降 GORM 型は infra/repository へのみ
    db.AutoMigrate(&domain.Todo{})              // サンプル簡易マイグレーション

    repo := repository.NewGormTodoRepository(db)     // domain.TodoRepository（port）を満たす
    uc   := usecase.NewTodoUsecase(repo)             // port に依存
    h    := handler.NewTodoHandler(uc)               // 生成 StrictServerInterface を実装

    // 生成 strict handler → ServerInterface へ。エラーはレンダラへ集約
    si := api.NewStrictHandlerWithOptions(h, nil, api.StrictHTTPServerOptions{
        RequestErrorHandlerFunc:  apperror.RenderGin, // バインド段階の構造エラー
        ResponseErrorHandlerFunc: apperror.RenderGin, // handler が返した apperror
    })

    r := gin.New()
    r.Use(gin.Recovery())
    r.Use(middleware.Auth(cfg.APIKey))               // 認証を全ルートに適用
    api.RegisterHandlersWithOptions(r, si, api.GinServerOptions{
        ErrorHandler: apperror.RenderGin,            // 生成 wrapper 段のエラーも同一レンダラへ
    })
    r.Run(cfg.Addr)
}
```

コンストラクタは port（`domain.TodoRepository`）を受け取る。handler は生成 `api.StrictServerInterface` を実装し、`NewStrictHandlerWithOptions` が `ServerInterface` へ変換、`RegisterHandlersWithOptions` がルーティングへ束ねる。エラー系はすべて `apperror.RenderGin`（problem+json レンダラ）へ集約する。

**原則 V との整合**: DI コンテナ・生成コード・reflection 配線を避け、明示的な数行の配線で全依存を追える（原則 IV 追跡可能性にも寄与）。

出典: reintech「Go Project Structure 2026」、service-pattern-go（GitHub）。

## エラーハンドリング（RFC 7807 problem+json に統一）

**ドメインエラーを `src/internal/apperror` に定義**し、**単一のレンダラ `apperror.RenderGin` 1 箇所**で HTTP ステータス + **RFC 7807 `application/problem+json`** へマッピングする。この形式は API 契約（[contracts/main.tsp](./contracts/main.tsp) の `Problem` モデル）を SSoT とし、実装はそれに合わせる。

**成功=型付き / 失敗=中央集約**の方針を採る:

- **成功パス**: handler（strict 実装）は生成レスポンス型（`TodosCreate201JSONResponse` / `...200JSONResponse` / `...204Response` 等）を返す。ステータス・`Location` ヘッダも型で表現され契約準拠が保証される。
- **失敗パス**: handler は `(nil, apperror.X)` を返す。生成された 4xx レスポンス型（`...400ApplicationProblemPlusJSONResponse` 等）は契約表現として存在するが、**エラー送出には使わず**、変換を 1 箇所へ集約する（意図的選択）。
- 合流点は 2 つ。いずれも `apperror.RenderGin` へ流す:
  1. strict の `ResponseErrorHandlerFunc(c, err)` — handler が返した `err`（= apperror）。
  2. `GinServerOptions.ErrorHandler` および strict の `RequestErrorHandlerFunc` — body unmarshal 失敗・型不一致・path param（uuid 形式）不正など「バインド段階」の構造エラー。

problem+json のボディ（契約準拠）:

```json
{
  "type": "about:blank",
  "title": "validation failed",
  "status": 400,
  "detail": "リクエストの検証に失敗しました",
  "errors": [
    { "field": "title", "code": "required", "message": "title must be 1..256 chars and not blank" },
    { "field": "description", "code": "too_long", "message": "description must be <= 1024 chars" }
  ]
}
```

- `errors[]` は **`{ field, code, message }`**（TypeSpec の `FieldError` と一致）。400 で必須、401/404 では省略。
- ドメインエラー種別と HTTP の対応を 1 箇所（`apperror.RenderGin` 内）で集中管理:

```go
func statusFor(k apperror.Kind) int {
    switch k {
    case apperror.KindValidation:   return 400
    case apperror.KindNotFound:     return 404
    case apperror.KindUnauthorized: return 401
    default:                        return 500
    }
}
```

- **バリデーションの責務分離**（重要: oapi-codegen strict-server は go-playground/validator を使わず、OpenAPI スキーマ制約 minLength/maxLength/pattern を実行時強制しない）:
  - **構文/型/path uuid 形式**は生成 wrapper が検出し、バインド段階の合流点（`GinServerOptions.ErrorHandler` / strict `RequestErrorHandlerFunc`）で汎用 400 problem 化。
  - **意味的 field 検証**（`title` 1..256・空白のみ不可、`description` ≤1024、作成時 `completed` を受け付けない 等）は **usecase** が担う。`domain.CreateParams.Validate()` / `UpdateParams.Validate()`（手書き、`[]apperror.FieldError` を集約）で `apperror.Validation{Fields}` を返し、`errors[]`（field/code/message）を確実に生成。
  - kin-openapi の request-validation middleware は**不採用**（YAGNI: ドメイン検証と重複し、生成エラーが RFC7807 field 形式でない）。go-playground/validator も domain を検証ライブラリに結合させないため手書き `Validate()` を第一推奨（代替として言及に留める）。
- 認証失敗は `middleware.Auth` が `apperror.Unauthorized` を `apperror.RenderGin` でレンダリングして `c.Abort()`。
- repository の `gorm.ErrRecordNotFound` は **infra/repository の GORM 実装内で** `apperror.NotFound` に変換（GORM 型を上流へ漏らさない = 原則 V の歯止め）。
- `Content-Type: application/problem+json` を付与。5xx は内部詳細を隠蔽し `log/slog` にのみ記録。

**原則 V との整合**: エラー→HTTP 変換を 1 箇所（`apperror.RenderGin`）に集約し、handler の重複分岐を排除。種別は spec 要求の 3 つ + フォールバック 500 のみ。

出典: Gin 公式「Error handling middleware」、Joseph Woodward「Global Error Handling」、RFC 7807。

## DTO とモデル分離 / PUT 実装方針

### DTO とドメインモデルの分離

**DTO は oapi-codegen が OpenAPI から生成する**（`api` パッケージの `TodoCreate` / `TodoUpdate` / `TodoRead` / `Problem` 等）。手書きの `dto.go` は持たない。バインド（JSON→リクエストオブジェクト）は strict-server が担う。**GORM モデルを直接 JSON で返さず、handler で生成 DTO へ詰め替える**（唯一の変換点）。理由: GORM 内部の漏出防止、クライアントが設定してはならない項目（`id`/`created_at`、作成時 `completed`）を契約で制御、API 契約（TypeSpec/OpenAPI）と内部 domain の疎結合。

変換の流れ（handler が唯一の変換点。usecase シグネチャに生成 DTO を出さない）:

```text
入力: api.TodoCreate（生成 DTO） ──handler──▶ domain.CreateParams ──usecase──▶ domain.Todo
出力: domain.Todo ──handler──▶ api.TodoRead（生成 DTO） ──▶ api.TodosCreate201JSONResponse
```

- 生成 DTO 名・フィールドは OpenAPI（＝TypeSpec）由来。`title` 必須、`description` 任意（`*string`）、`completed` は `TodoUpdate` のみ、`id`/`created_at`/`updated_at` は `TodoRead` のみ、という契約が型に反映される。
- usecase へ渡す入力は domain 側の `domain.CreateParams{Title, Description}` / `domain.UpdateParams{Title, Description, Completed}`（生成 DTO ではなく domain 型）。これにより usecase は `api` パッケージ非依存。
- `description` は任意ゆえ `*string`（未指定 null と空文字の区別）。TypeSpec 契約では `description` 既定 `""` のため、レスポンス整形時に null を空文字へ寄せるかは実装時に統一する。

### PUT 全項目置換の実装（GORM ゼロ値更新問題の回避）

`Updates(struct)` はゼロ値を無視し `completed=false`/`description=""` が更新されない silent failure。全置換 PUT では致命的。

| 方式 | 挙動 | 評価 |
|------|------|------|
| `Save(&todo)` | 全カラム更新。ただし PK 不在/一致 0 行で **Create にフォールバック（upsert 事故）** | ✗ 非推奨 |
| `Model(&Todo{}).Where("id=?",id).Select(...列挙...).Updates(...)` | ゼロ値含む指定カラムを更新、無ければ作成しない | ✅ **推奨** |
| `map[string]any` で明示 | ゼロ値含む・柔軟だが型安全性↓ | △ 代替可 |

**推奨**: `Select("title","description","completed","updated_at").Updates(...)` で対象カラム明示列挙（`created_at` は除外）。`RowsAffected == 0` で対象不在 → `apperror.NotFound`。この実装は `infra/repository` の GORM 実装内に置く（GORM 型はここに閉じる）。

```go
// src/internal/infra/repository/gorm_todo_repository.go
func (r *gormTodoRepo) Update(ctx context.Context, t *domain.Todo) error {
    res := r.db.WithContext(ctx).
        Model(&domain.Todo{}).
        Where("id = ?", t.ID).
        Select("title", "description", "completed", "updated_at").
        Updates(map[string]any{
            "title": t.Title, "description": t.Description,
            "completed": t.Completed, "updated_at": time.Now(),
        })
    if res.Error != nil { return res.Error }
    if res.RowsAffected == 0 { return apperror.NotFound("todo not found") }
    return nil
}
```

**原則 V との整合**: PUT は「全置換」という spec 意味論に直結する最小実装。PATCH（部分更新）は spec 外なので実装しない（YAGNI）。

出典: GORM 公式 Update、Coding Explorations「Update vs Save」、codestudy「Boolean not updating to false」。

## 横断関心事（context / tx / config / log）

- **context 伝播**: `c.Request.Context()` を handler→service→repository へ引数第一で貫通、repository で `db.WithContext(ctx)`。独自 context キーは詰めない（YAGNI）。
- **トランザクション境界**: 各エンドポイントは単一集約 Todo への単一操作のみ。GORM は単文 `Create/Updates/Delete` を暗黙に単一トランザクションで実行するため、**明示トランザクション・Unit of Work は不要**（YAGNI）。複数テーブル横断が出た時に service へ `db.Transaction` を導入する（plan.md に記録）。
- **設定管理**: 起動時に一括で型付き struct へ読込・検証し下位へ注入（fail-fast）。Viper のような重量級は避け、`os.LookupEnv` の薄い loader か `kelseyhightower/envconfig`（struct タグ + required/default）で十分（env のみ・ファイル config 不要）。

```go
type Config struct {
    Addr        string `envconfig:"ADDR" default:":8080"`
    APIKey      string `envconfig:"API_KEY" required:"true"`
    DatabaseDSN string `envconfig:"DATABASE_DSN" required:"true"`
}
```

  テスト注意: `os.Setenv` は非スレッドセーフ。env を触るテストは `t.Setenv` を使い `t.Parallel()` しない。
- **ロギング**: 標準 `log/slog`（構造化）。外部依存を足さない。Gin アクセスログ + エラーミドルウェアで 5xx 時にサーバ側詳細を slog 記録（クライアントには隠蔽）。

出典: oneuptime「Go Configuration Handling」、env.dev「Go Environment Variables」。

## テスト戦略

3 層で構成し、spec の受け入れシナリオ（Given/When/Then）を最外周で担保する。

1. **単体テスト（service / バリデーション）**: repository interface の**モック**（手書き fake か `testify/mock`）を注入。DB 不要で高速。`completed` 固定・PUT 全置換の意味論・DTO 変換を検証。各パッケージに `*_test.go` 同居。
2. **結合テスト（httptest でハンドラ + ミドルウェア）**: Gin ルータ全体を `httptest` で起動し、認証 MW + handler + service + repository を通した HTTP 検証。401/404/400/200 の分岐、problem+json 形（`errors[]`）、PUT 全置換の反映。DB は下記 testcontainers で実 PostgreSQL（GORM ゼロ値更新挙動を含め検証）。
3. **外部受け入れテスト（Bruno）**: 起動済み API にブラックボックス受け入れ。`.bru` で各エンドポイント + 認証ヘッダを定義し `bru run` CLI で実行。TypeSpec 由来 OpenAPI 契約との整合を E2E 確認。

### DB を伴う結合テスト: 推奨 = testcontainers-go

| 選択肢 | 長所 | 短所 | 推奨 |
|--------|------|------|------|
| **testcontainers-go** | 実 PostgreSQL をコードから起動・自動管理・クリーン分離、専用 Postgres モジュール、2025/26 デファクト | Docker 必須・メモリ消費 | ★ 推奨 |
| dockertest (ory) | 軽量 | 機能最小 | 代替可 |
| ローカル/共有 DB | 起動速い | 環境ドリフト・汚染・再現性弱 | ✗ 非推奨 |

パターン: 「パッケージごとに Postgres コンテナ 1 つ + テストごとにマイグレート済み DB を分離」。`TestMain` でコンテナ起動、`t.Cleanup` で後始末。

**原則 V との整合**: モックは repository interface に対してのみ（既存抽象を再利用、テスト専用抽象を新設しない）。testcontainers は「実 DB 挙動の再現」という具体的見返りがあり導入正当。

出典: oneuptime「Integration Tests with Testcontainers」、testcontainers.com、Storj「Go Integration Tests with Postgres」、mortenvistisen「Integration testing with Docker」。
