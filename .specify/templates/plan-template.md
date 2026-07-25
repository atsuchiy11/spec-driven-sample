# 実装計画: [FEATURE]

**ブランチ**: `[###-feature-name]` | **日付**: [DATE] | **仕様**: [link]

**入力**: `/specs/[###-feature-name]/spec.md` の機能仕様

**補足**: このテンプレートは `/speckit-plan` コマンドが記入します。コマンドの定義に実行ワークフローが記述されています。

## 概要

[機能仕様から抽出: 主要な要件 + リサーチから得た技術的アプローチ]

## 技術的コンテキスト

<!--
  要対応: このセクションの内容を、プロジェクトの技術的詳細に置き換えてください。
  ここでの構成は、検討を進めるためのガイドとして参考情報を示すものです。
-->

**言語/バージョン**: [例: Python 3.11, Swift 5.9, Rust 1.75 または NEEDS CLARIFICATION]

**主要な依存関係**: [例: FastAPI, UIKit, LLVM または NEEDS CLARIFICATION]

**ストレージ**: [該当する場合。例: PostgreSQL, CoreData, ファイル または N/A]

**テスト**: [例: pytest, XCTest, cargo test または NEEDS CLARIFICATION]

**対象プラットフォーム**: [例: Linux サーバー, iOS 15+, WASM または NEEDS CLARIFICATION]

**プロジェクト種別**: [例: library/cli/web-service/mobile-app/compiler/desktop-app または NEEDS CLARIFICATION]

**パフォーマンス目標**: [ドメイン固有。例: 1000 req/s, 10k lines/sec, 60 fps または NEEDS CLARIFICATION]

**制約**: [ドメイン固有。例: <200ms p95, <100MB メモリ, オフライン対応 または NEEDS CLARIFICATION]

**規模/スコープ**: [ドメイン固有。例: 1万ユーザー, 100万 LOC, 50 画面 または NEEDS CLARIFICATION]

## 憲章チェック

*ゲート: Phase 0 リサーチ前に通過必須。Phase 1 設計後に再チェックする。*

[憲章ファイルにもとづいて決定されるゲート]

## プロジェクト構造

### ドキュメント（この機能）

```text
specs/[###-feature]/
├── plan.md              # このファイル（/speckit-plan コマンドの出力）
├── research.md          # Phase 0 の出力（/speckit-plan コマンド）
├── data-model.md        # Phase 1 の出力（/speckit-plan コマンド）
├── quickstart.md        # Phase 1 の出力（/speckit-plan コマンド）
├── contracts/           # Phase 1 の出力（/speckit-plan コマンド）
└── tasks.md             # Phase 2 の出力（/speckit-tasks コマンド — /speckit-plan では作成しない）
```

### ソースコード（リポジトリルート）
<!--
  要対応: 以下のプレースホルダのツリーを、この機能の具体的なレイアウトに
  置き換えてください。使わない選択肢は削除し、選んだ構造を実際のパス
  （例: apps/admin, packages/something）で展開してください。納品する計画に
  「Option」ラベルを含めてはいけません。
-->

```text
# [不要なら削除] Option 1: 単一プロジェクト（デフォルト）
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [不要なら削除] Option 2: Web アプリケーション（"frontend" + "backend" を検出した場合）
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [不要なら削除] Option 3: モバイル + API（"iOS/Android" を検出した場合）
api/
└── [上記 backend と同様]

ios/ または android/
└── [プラットフォーム固有の構造: 機能モジュール, UI フロー, プラットフォームテスト]
```

**構造の決定**: [選択した構造を記録し、上記で示した実際のディレクトリを参照する]

## 複雑さの追跡

> **憲章チェックに、正当化が必要な違反がある場合のみ記入する**

| 違反 | 必要な理由 | よりシンプルな代替案を却下した理由 |
|-----------|------------|-------------------------------------|
| [例: 4つ目のプロジェクト] | [現在のニーズ] | [3プロジェクトでは不十分な理由] |
| [例: リポジトリパターン] | [具体的な問題] | [DB 直接アクセスでは不十分な理由] |
