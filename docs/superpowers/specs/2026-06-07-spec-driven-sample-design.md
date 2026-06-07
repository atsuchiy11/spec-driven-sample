# spec-driven-sample — 設計書

- **日付**: 2026-06-07
- **対象リポジトリ**: [`atsuchiy11/spec-driven-sample`](https://github.com/atsuchiy11/spec-driven-sample)
- **位置づけ**: 本書はサンプルリポジトリ**そのもの**の設計書（メタ設計）です。リポジトリ内で運用される `docs/specs/` `docs/plans/` `docs/stories/` `docs/brainstorms/` は、サンプルアプリ開発のための仕様駆動ワークフローの出力先であり、本書とは別物です。

## 1. 概要と目的

### 1.1 何を作るか
Claude Code 上で動く「AIによる仕様駆動開発」のサンプルリポジトリ。サンプルアプリは TODO REST API（Go + gin + GORM + PostgreSQL）だが、**主役はアプリではなくワークフロー**である。

### 1.2 主目的
プロセス見本（メタ）。`brainstorm → spec → plan → implement` という4段階のワークフローと、`.claude/` 配下の commands / agents / rules / skills が**どう組み合わさるか**を読者に見せる。

### 1.3 想定読者
Claude Code を使ってチーム開発を進めたい開発者・テックリード。Jira/GitHub を実務で使うエンジニアを優先。

### 1.4 非目標
- 本番運用に耐えるアプリの提供（アプリは最小限）
- Spec Kit / Kiro 等の既存ツールとの完全互換
- 多言語（Go以外）への移植

## 2. リポジトリ全体構造

```
spec-driven-sample/
├── .claude/
│   ├── commands/                  # 薄いオーケストレータ。CLIは直接叩かない
│   │   ├── brainstorm.md          # 任意ステージ
│   │   ├── spec.md
│   │   ├── plan.md
│   │   └── implement.md
│   ├── agents/                    # 外部I/Oの境界。CLIはここからのみ
│   │   ├── brainstorm-facilitator.md
│   │   ├── spec-author.md
│   │   ├── plan-author.md
│   │   ├── jira-bridge.md         # acli
│   │   ├── github-bridge.md       # gh
│   │   └── bruno-runner.md        # bru
│   ├── rules/                     # 全レイヤから読み取り可、書き込み無し
│   │   ├── coding-style.md        # Go: gofumpt, package命名, error wrap, Dependency Rule
│   │   ├── api-design.md          # REST規約, status code, レスポンス形状
│   │   ├── error-handling.md      # 層別エラー, errors.Is/As, panic禁止
│   │   ├── testing.md             # table-driven, t.Parallel, testcontainers方針
│   │   ├── openapi-style.md       # tags/summary/operationId/example
│   │   ├── db-conventions.md      # GORMタグ所在限定, forward-only migrations
│   │   ├── commit-convention.md   # Conventional Commits + Jira key
│   │   ├── pr-convention.md       # PR本文テンプレ, Closes <STORY>
│   │   ├── definition-of-done.md  # /brainstorm /spec /plan /implement それぞれ
│   │   └── naming.md              # ブランチ, ファイル, slug 規約
│   └── skills/                    # 副作用なしの判定・変換
│       ├── openapi-validate/      # spectral 結果を構造化
│       ├── jira-key-resolve/      # acli 結果から key 抽出
│       └── rules-lint/            # rules/ frontmatter 形式検査
├── docs/
│   ├── brainstorms/               # YYYY-MM-DD-<slug>.md（Jira無し）
│   ├── specs/                     # <EPIC>-<slug>.md
│   ├── plans/                     # <EPIC>-<slug>.md
│   ├── stories/                   # <STORY>-<slug>.md
│   └── superpowers/specs/         # 本書（メタ設計）
├── cmd/
│   └── api/main.go                # gin 起動エントリ
├── internal/
│   ├── gen/api/                   # oapi-codegen 出力（コミット, 手書き禁止）
│   │   ├── server.gen.go
│   │   ├── types.gen.go
│   │   └── spec.gen.go
│   ├── domain/                    # 純粋: entity, value object, domain errors
│   │   ├── todo/
│   │   └── errors.go
│   ├── usecase/                   # 1ユースケース1ファイル
│   │   └── todo/
│   │       ├── port.go            # InputPort + Repository (output port)
│   │       ├── create.go
│   │       ├── list.go
│   │       ├── update.go
│   │       ├── delete.go
│   │       └── dto.go
│   ├── adapter/
│   │   ├── handler/               # ServerInterface 実装、oapi型↔usecase DTO 変換
│   │   ├── middleware/            # error, request-id, logging, recover
│   │   └── repository/postgres/   # usecase.todo.Repository を GORM で実装
│   │       ├── todo_repo.go
│   │       └── model.go           # GORMタグはここだけ
│   └── infra/
│       ├── config/                # env, viper
│       ├── db/                    # gorm.Open + migration runner
│       └── server/                # gin engine + DI 配線
├── migrations/                    # golang-migrate, forward-only SQL
├── openapi/
│   └── todo-api.yaml              # 真実のAPI契約 (SSoT)
├── bruno/
│   └── todo-api/                  # .bru, 先頭 `# managed: true/false`
├── tools/tools.go                 # build tag で開発ツールを go.mod に固定
├── docker-compose.yml             # postgres:16（アプリ実機起動用）
├── Makefile
├── .golangci.yml
├── CLAUDE.md
├── README.md
├── LICENSE                        # MIT
├── go.mod
└── go.sum
```

## 3. ワークフロー

4段階。`brainstorm` は任意。

```
/brainstorm <topic>          (任意・Jira無し)
        ▼
/spec <brainstorm-path | topic>
        ▼
/plan <spec-path>
        ▼
/implement <STORY-KEY>
```

### 3.1 `/brainstorm <topic>`
1. **brainstorm-facilitator** が1問ずつ質問し探索
2. 出力: `docs/brainstorms/YYYY-MM-DD-<slug>.md`
3. Jira/GitHub 副作用なし、ファイル名 rename なし
4. 終了時に「`/spec docs/brainstorms/...` で正式仕様化できます」と案内

### 3.2 `/spec <brainstorm-path | topic>`
1. **spec-author** が要件整理 → `docs/specs/EPIC-XXX-<slug>.md`（プレースホルダ）と `openapi/<area>.yaml` を生成・更新。brainstorm を引き継ぐ場合は本文先頭に `Origin: docs/brainstorms/...` を埋める
2. **openapi-validate** skill が spectral で検証。失敗なら spec-author に差し戻し
3. **jira-bridge** が Epic を作成（既存トピックなら更新） → 返ってきた `<EPIC>` でファイル名を rename し、本文先頭の Jira バナーを埋める
4. **github-bridge** が `spec/<EPIC>-<slug>` ブランチを切り、Draft PR を作成（本文に Epic key と OpenAPI 差分サマリ）

### 3.3 `/plan <spec-path>`
1. **plan-author** が spec と OpenAPI を読み、実装順・依存関係を整理 → `docs/plans/<EPIC>-<slug>.md`
2. plan-author が同時に **Story 単位の細書きを `docs/stories/<EPIC>-<n>-<slug>.md` × N** として生成（受け入れ条件、Bruno参照、技術メモ）
3. **jira-bridge** が Story を一括作成（Epic 配下） → 返ってきた `<STORY>` で各 story ファイルを rename、plan.md にもキーを書き戻す
4. **bruno-runner** が `bruno/<area>/` の `.bru` を OpenAPI から再生成（`managed: true` のもののみ、差分は提示してユーザー承認）
5. **github-bridge** が plan PR をオープン（spec PR にリンク）

### 3.4 `/implement <STORY-KEY>`
1. `docs/stories/<STORY>-*.md` を読み着手対象を確定
2. **jira-bridge** が Story を In Progress に遷移、`story/<STORY>-<slug>` ブランチを切る
3. **コーディング**: `coding-style.md` `api-design.md` `error-handling.md` `db-conventions.md` を参照
4. **テスト**: `make gen lint test e2e`（後述）が全部 pass する状態へ
5. story ファイルに「実装メモ / 仕様からの逸脱 / 残課題」を追記
6. **github-bridge** が PR をオープン（テンプレは `pr-convention.md`、本文に `Closes <STORY>` と Bruno run サマリ）
7. PR マージ後の post-merge hook で **jira-bridge** が Done に遷移

## 4. 役割境界とコンポーネント

### 4.1 依存方向
```
commands/  ─呼ぶ─►  agents/  ─呼ぶ─►  skills/(純関数) + 外部CLI(acli/gh/bru/npx)
     ▲                  │
     └── 共有読み取り ──►  rules/ + CLAUDE.md
```

- **commands**: オーケストレーション専任。Bash で外部CLIを直接叩かない
- **agents**: 外部I/Oの境界。acli/gh/bru/npx は agents 経由でのみ
- **skills**: 副作用なしの判定・変換。`go test` で検証可能
- **rules**: 全レイヤから読み取り、書き込みなし

### 4.2 Goアプリ側の Clean Architecture 層
```
cmd/api/main.go ──► infra ──► adapter ──► usecase ──► domain
                                │             ▲
                                └─実装(repository)─┘
                                
adapter/handler ──► gen/api (oapi-codegen)  ※ HTTP境界の翻訳のみ
```

- **domain**: 純粋 Go、外部依存ゼロ。GORM タグ禁止
- **usecase**: domain のみ import 可。Repository **interface** は usecase 側に置く（consumer-owned interface, Go流）
- **adapter/handler**: gen/api 型と usecase DTO の翻訳のみ。ビジネスロジック禁止
- **adapter/repository/postgres**: domain entity ↔ GORM model の双方向 mapper を `model.go` に集約
- **infra**: 起動・接続・設定のみ。ビジネスロジック禁止

## 5. データフロー（OpenAPI を真実とする中心線）

### 5.1 SSoT
| 種類 | SSoT |
|---|---|
| API契約 | `openapi/<area>.yaml` |
| ビジネス仕様/文脈 | `docs/specs/<EPIC>-<slug>.md` |
| 実装計画 | `docs/plans/<EPIC>-<slug>.md` + `docs/stories/<STORY>-<slug>.md` |
| タスク状態 | Jira（keyはファイル先頭バナーで参照） |
| 統合テスト | `bruno/<area>/` |
| 単体/コンポーネントテスト | `*_test.go` |

### 5.2 派生関係
```
docs/brainstorms/  (任意)
        ▼
docs/specs/<EPIC>-*.md ──► openapi/todo-api.yaml
        │                          │
        ▼                          ├─ oapi-codegen ──► internal/gen/api/*.gen.go
docs/plans/<EPIC>-*.md             ├─ bruno-runner ──► bruno/todo-api/*.bru (managed)
docs/stories/<STORY>-*.md          └─ spectral lint
        │
        ▼
internal/adapter/handler ──► internal/usecase ──► internal/domain
                                    ▲
                                    └── implements ── internal/adapter/repository/postgres
```

### 5.3 設計上の約束
- `internal/gen/` への手書きはコミット拒否（CI で `git diff --exit-code`）
- `migrations/` は forward-only。down は書かない（ロールバックは新規マイグレーション）
- `bruno/<area>/` の `.bru` は先頭 `# managed: true/false` フラグで管理
  - `true`: OpenAPI から再生成可（上書き前に diff 提示）
  - `false`: 手書き保護（再生成スキップ）
- `tools/tools.go` で oapi-codegen / migrate / golangci-lint / spectral を `go.mod` に固定（バージョンドリフト防止）

## 6. エラーハンドリング

### 6.1 Goアプリ層のエラー
| 層 | エラー型 | 例 |
|---|---|---|
| domain | sentinel + custom struct | `domain.ErrTodoNotFound`, `domain.InvalidTitleError{...}` |
| usecase | `fmt.Errorf("...: %w", err)` で wrap | `usecase: create todo: %w` |
| adapter/repository | DBエラーを domain error にマップ | `gorm.ErrRecordNotFound` → `domain.ErrTodoNotFound` |
| adapter/handler | domain error → HTTP（`errors.As/Is` + middleware） | 404 / 422 / 500 |
| middleware | panic回収、構造化ログ、リクエストID付与 | gin Recovery 置換 |

### 6.2 HTTP エラーレスポンス（OpenAPI 上で `ErrorResponse` として定義）
```json
{
  "code": "todo_not_found",
  "message": "Todo not found",
  "details": [{ "field": "id", "issue": "no record" }],
  "request_id": "01HXX..."
}
```
- `code` は snake_case 固定（メッセージは多言語化前提で差し替え可）

### 6.3 エラー→ステータスのマップ
- `domain.ErrTodoNotFound` → 404
- `domain.InvalidTitleError`、その他バリデーション → 422
- 想定外 → 500 + 構造化ログ
- panic → middleware で 500 + stack trace

### 6.4 AIワークフロー側の失敗モード

| コンポーネント | 主な失敗 | 対処 |
|---|---|---|
| spec-author | OpenAPI 検証エラー、応答待ち中断 | 部分書き保存→再開時 diff 提示。Jira/GitHub 未呼び出し |
| jira-bridge | acli 失敗、key既存、権限不足 | **dry-run 先行**、失敗時はファイル rename しない |
| github-bridge | gh 認証切れ、PR既存、ブランチconflict | ブランチ作成は冪等、PR既存ならコメント追記、conflictはユーザー差し戻し |
| bruno-runner | 手書き上書き危険 | `managed: false` 尊重、生成は temp → diff 提示 |
| openapi-validate | spectral 違反 | 行+ルールIDを構造化結果で返す |

### 6.5 副作用順序ルール（`definition-of-done.md` で固定）
**ローカル成果物 → 外部API、の順で書く**。

1. ファイル書き込み → OpenAPI 検証 → ここまでなら破棄で完全リセット可
2. ここを越えてから acli/gh を叩く
3. Jira/GitHub 副作用後に失敗した場合、**自動ロールバックはしない**。状態をユーザー提示し、将来の `/recover <epic-key>` の余地を README に明示

### 6.6 ログ
- 構造化ログ: `log/slog`（標準）+ JSON、`request_id` を context 伝搬
- AI agent 実行ログ: `docs/.runs/<timestamp>-<command>.jsonl`、`.gitignore` 対象

## 7. テスト戦略

### 7.1 Goアプリ側ピラミッド
| 階層 | 対象 | ツール |
|---|---|---|
| Unit | domain | stdlib `testing` + table-driven |
| Unit | usecase | testify/mock または gomock（Repositoryモック） |
| Integration | adapter/repository/postgres | testcontainers-go + 実Postgres |
| Integration | adapter/handler | httptest + usecase モック |
| E2E | API全体 | docker compose + gin起動 + `bruno run` |
| Contract | OpenAPI 自体 | spectral lint |

`testing.md` 規約:
- table-driven 強制（`name`, `args`, `want` を持つ struct slice）
- `t.Parallel()` をデフォルト（共有状態がなければ）
- ヘルパは `t.Helper()` 必須
- モックは「使う側パッケージ内で interface 定義」のGo流
- ゴールデンファイル: `testdata/<test_name>.golden.json`、`-update` フラグで更新

### 7.2 testcontainers-go ハイブリッド
- **自動テスト**: testcontainers-go（`go test ./...` 1コマンドで完結）
- **手動触り/E2E**: `docker compose up` で長寿命 Postgres → `go run ./cmd/api` → Bruno

### 7.3 AIワークフロー側の検証
| 対象 | 方法 |
|---|---|
| Skills（純関数） | `.claude/skills/<name>/` には README.md（仕様）と Go ヘルパ（`helper.go`）を同居。`test/` に入力 fixture と期待 JSON ゴールデンを置き、`go test` で回す |
| Agents（外部I/O） | `.claude/agents/<name>/tests/*.expected.md`、手動 `/test-agent <name>` で実行、LLM-judge で pass/fail |
| Commands | `--dry-run` モード（ファイル書込なし・外部API なし）。CI 非実行、手動QA用 |
| Rules | `rules-lint` skill で frontmatter スキーマ検証（`id`, `applies_to`, `severity` 必須） |

### 7.4 Makefile 主要ターゲット
```make
gen          # oapi-codegen + bruno managed 再生成
lint         # gofumpt + goimports + golangci-lint + spectral + rules-lint
test         # go test ./... -race -cover（testcontainers含む）
test-unit    # short: -short フラグで integration を除外
e2e          # docker compose up → migrate → run api → bruno run
migrate-up   # golang-migrate up
migrate-new  # 新規マイグレーション雛形作成
agent-test   # 手動: ゴールデン会話テスト
```

### 7.5 CI（GitHub Actions）
1. **gen-check**: `make gen` → `git diff --exit-code`
2. **lint**: gofumpt / goimports / golangci-lint / spectral / rules-lint
3. **layer-check**: domain純度の守護
   - `grep -r 'gorm:' internal/domain internal/usecase` で hit → fail
   - `grep -rE 'gen/api|gorm.io' internal/domain internal/usecase` で hit → fail
4. **test**: `make test`（testcontainers-go 起動）
5. **e2e**: docker compose + migrate + api + bruno
6. **spec-coverage**（任意）: `docs/specs/*.md` ↔ `openapi/*.yaml` の対応、`docs/stories/*.md` の Jira key 埋め込みチェック

## 8. Definition of Done（各段階）

- **/brainstorm**: `docs/brainstorms/YYYY-MM-DD-<slug>.md` がコミット済み、`Origin` 空でも可
- **/spec**: spec.md + `openapi/*.yaml` が `spectral lint` pass、Epic 作成済み（key埋め込み）、Draft PR open
- **/plan**: plan.md + stories/*.md が揃い、各 story に Jira key、依存グラフ循環なし、PR open
- **/implement (per story)**: `make gen lint test e2e` 全 pass、対応 Story が Done 遷移、PR が `Closes <STORY>` 付きで open、story ファイルの「実装メモ」更新済み

## 9. 命名規則（要点、詳細は `naming.md`）

- ブランチ: `spec/<EPIC>-<slug>`, `plan/<EPIC>-<slug>`, `story/<STORY>-<slug>`
- コミット: `[<STORY>] feat(scope): subject`
- PR タイトル: `[<STORY>] <Story summary>`
- spec/plan ファイル名: `<EPIC>-<slug>.md`
- story ファイル名: `<STORY>-<slug>.md`
- brainstorm ファイル名: `YYYY-MM-DD-<slug>.md`（Jira keyなし）

## 10. 既知のトレードオフ / 将来余地

- **`/recover` コマンド**: 副作用後失敗の救済コマンドは現時点では未実装、README に「将来追加余地」として記載
- **`docs/.runs/`**: gitignore 対象。教材として履歴を残したい派は `docs/runs/`（dot無し）に切り替え可
- **多言語サンプル**: Go版を出発点とし、将来 TypeScript/Python サンプルを別ブランチで提供する余地
- **Sub-task階層**: Jira Sub-task はファイル化せず、Story 内のチェックリストで吸収
- **strict CA負荷**: domain ↔ DB model の mapper コードが増える。サンプルとしての教材価値を優先しこの形を採用

## 11. ライセンス
MIT
