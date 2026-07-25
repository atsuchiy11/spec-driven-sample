# [PROJECT_NAME] 憲章
<!-- 例: Spec 憲章, TaskFlow 憲章 など -->

## 基本原則

### [PRINCIPLE_1_NAME]
<!-- 例: I. ライブラリ優先 -->
[PRINCIPLE_1_DESCRIPTION]
<!-- 例: すべての機能は独立したライブラリとして着手する; ライブラリは自己完結し、単体でテスト可能でドキュメント化されていること; 明確な目的が必須 — 整理目的だけのライブラリは禁止 -->

### [PRINCIPLE_2_NAME]
<!-- 例: II. CLI インターフェース -->
[PRINCIPLE_2_DESCRIPTION]
<!-- 例: すべてのライブラリは CLI 経由で機能を公開する; テキスト入出力プロトコル: stdin/args → stdout, エラー → stderr; JSON と人間可読の両形式をサポート -->

### [PRINCIPLE_3_NAME]
<!-- 例: III. テストファースト（交渉不可） -->
[PRINCIPLE_3_DESCRIPTION]
<!-- 例: TDD 必須: テスト作成 → ユーザー承認 → テスト失敗を確認 → 実装; Red-Green-Refactor サイクルを厳格に適用 -->

### [PRINCIPLE_4_NAME]
<!-- 例: IV. 統合テスト -->
[PRINCIPLE_4_DESCRIPTION]
<!-- 例: 統合テストが必要な重点領域: 新規ライブラリの契約テスト, 契約変更, サービス間通信, 共有スキーマ -->

### [PRINCIPLE_5_NAME]
<!-- 例: V. 可観測性, VI. バージョニングと破壊的変更, VII. シンプルさ -->
[PRINCIPLE_5_DESCRIPTION]
<!-- 例: テキスト入出力でデバッグ容易性を確保; 構造化ログを必須とする; または: MAJOR.MINOR.BUILD 形式; または: シンプルに始める、YAGNI 原則 -->

## [SECTION_2_NAME]
<!-- 例: 追加の制約, セキュリティ要件, パフォーマンス基準 など -->

[SECTION_2_CONTENT]
<!-- 例: 技術スタックの要件, コンプライアンス基準, デプロイポリシー など -->

## [SECTION_3_NAME]
<!-- 例: 開発ワークフロー, レビュープロセス, 品質ゲート など -->

[SECTION_3_CONTENT]
<!-- 例: コードレビュー要件, テストゲート, デプロイ承認プロセス など -->

## ガバナンス
<!-- 例: 憲章は他のすべての慣行に優先する; 改訂にはドキュメント化・承認・移行計画が必要 -->

[GOVERNANCE_RULES]
<!-- 例: すべての PR/レビューは準拠を検証すること; 複雑さには正当化が必要; 実行時の開発ガイダンスには [GUIDANCE_FILE] を用いる -->

**バージョン**: [CONSTITUTION_VERSION] | **批准日**: [RATIFICATION_DATE] | **最終改訂日**: [LAST_AMENDED_DATE]
<!-- 例: バージョン: 2.1.1 | 批准日: 2025-06-13 | 最終改訂日: 2025-07-16 -->
