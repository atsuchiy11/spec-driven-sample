<!--
Sync Impact Report
- Version change: (template) → 1.0.0
- Ratification: 初回批准（テンプレートから具体化）
- Modified principles: なし（新規制定）
- Added sections:
  - Core Principles（5原則）: I. 仕様優先 / II. 単一の真実源(SSoT) / III. 受け入れ基準駆動 / IV. 追跡可能性 / V. 簡潔さ・YAGNI
  - 追加制約（開発規約・成果物）
  - 開発ワークフロー（spec→plan→tasks→implement ゲート）
  - Governance
- Removed sections: なし
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md（Constitution Check と整合、変更不要を確認）
  - ✅ .specify/templates/spec-template.md（受け入れ基準セクションと整合、変更不要を確認）
  - ✅ .specify/templates/tasks-template.md（TDD/追跡可能性の分類と整合、変更不要を確認）
  - ✅ CLAUDE.md（憲章参照の記述と整合）
- Follow-up TODOs: なし
-->

# spec-driven-sample Constitution

## Core Principles

### I. 仕様優先（Spec-First, NON-NEGOTIABLE）

すべての機能は仕様（`spec.md`）から始める。承認済みの spec なしに実装へ進んではならない（MUST NOT）。
spec は「何を・なぜ」を定義し、実装の「どう」は plan 以降で扱う。曖昧な要件は
`/speckit-clarify` で解消してから plan に進む。

**根拠**: 本プロジェクトは spec 駆動開発のサンプルであり、仕様を起点とする流れそのものが
成果物である。実装先行は spec との乖離を生み、サンプルの価値を損なう。

### II. 単一の真実源（Single Source of Truth）

各ルール・各情報は 1 箇所にのみ定義する（MUST）。他所からは参照で繋ぎ、内容を複製してはならない
（MUST NOT）。規約の実体は `docs/conventions/`、AI 運用指示は `CLAUDE.md`、設計原則は本憲章に置く。
`CLAUDE.md` は薄いハブとして参照のみを持つ。

**根拠**: 重複した記述は必ず片方が古くなり矛盾を生む。参照に一本化することで、更新箇所を
1 つに保ち整合性を維持する。

### III. 受け入れ基準駆動

実装に着手する前に、受け入れ基準を Given/When/Then 形式で定義する（MUST）。受け入れ基準は spec に
記載し、テスト可能かつ検証可能であること。基準を満たさない実装は完了とみなさない（MUST NOT）。

**根拠**: 検証可能な基準を先に決めることで、完了の定義が明確になり、実装とレビューの判断が
主観に依存しなくなる。

### IV. 追跡可能性（Traceability）

spec → plan → tasks → code の連鎖を辿れる状態を保つ（MUST）。各 task は spec の要件または受け入れ基準に
対応づけ、PR は対応する spec / 機能を参照する。要件の出所が不明な実装を残してはならない（MUST NOT）。

**根拠**: 追跡可能性により、変更の影響範囲とその根拠を後から検証できる。spec 駆動フローの
再現性を担保する中核である。

### V. 簡潔さ・YAGNI

単純な構成から始める（MUST）。将来必要になるかもしれない機能を先回りで作らない（YAGNI）。
複雑さを導入する場合は plan の Complexity Tracking で正当化する（MUST）。正当化できない複雑さは
排除する（MUST NOT keep）。

**根拠**: 不要な複雑さは理解・保守のコストを増やす。サンプルとしての読みやすさを最優先する。

## 追加制約（開発規約・成果物）

- **開発規約**: コミット・ブランチ・PR の規約は `docs/conventions/` を SSoT とする。本憲章は
  git 運用の詳細を持たない（原則 II に従う）。
- **成果物の言語**: spec / plan / tasks などの spec 駆動成果物、および `docs/` は**日本語**で記述する。
  一方、**コミットメッセージ・ブランチ名・PR タイトルは英語**（`docs/conventions/` 参照）。
- **配置ルール**: ドキュメントは `docs/README.md` のカテゴリ配置ルールに従う。

## 開発ワークフロー

spec 駆動フロー（speckit）を標準の開発ワークフローとする。

1. **constitution** — 本憲章を定義・更新し、以降のゲートの基準とする。
2. **specify** — 機能仕様（spec）を作成する（原則 I・III）。
3. **plan** — 実装計画を作成する。冒頭の Constitution Check で本憲章との適合を確認する（原則 V）。
4. **tasks** — 依存順に並んだ実行可能なタスク一覧を生成する（原則 IV）。
5. **implement** — タスクを実行する。受け入れ基準の充足をもって完了とする（原則 III）。

各段階のゲートで本憲章に反する場合は、先に進まず spec / plan を修正する。`main` への統合は
PR 経由（`docs/conventions/pull-request.md` 参照）。

## Governance

- 本憲章はプロジェクトの他の慣行に優先する。憲章と規約が矛盾する場合は憲章を正とし、規約を修正する。
- **改訂手続き**: 憲章の変更は PR で提案し、変更理由を明記する。マージをもって発効する。
- **バージョニング**（セマンティックバージョニング）:
  - **MAJOR**: 原則の削除・後方非互換な再定義。
  - **MINOR**: 原則・セクションの追加、または指針の実質的拡張。
  - **PATCH**: 文言の明確化・誤字修正など非意味的な調整。
- **コンプライアンス確認**: plan の Constitution Check、および PR レビューで本憲章への適合を確認する。
  逸脱は plan の Complexity Tracking で正当化するか、解消してからマージする。
- 実行時の運用指示は `CLAUDE.md` を参照する。

**Version**: 1.0.0 | **Ratified**: 2026-07-25 | **Last Amended**: 2026-07-25
