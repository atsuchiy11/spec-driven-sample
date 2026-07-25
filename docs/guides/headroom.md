# headroom（Claude Code のコンテキスト圧縮）

[headroom](https://github.com/headroomlabs-ai/headroom) は、LLM に到達する前にコンテキストを圧縮してトークン消費を削減するツール。tool 出力・ログ・ファイル・RAG チャンク・会話履歴が対象。

> **本リポジトリの依存ではない。** 各自の開発環境に任意で導入する個人ツール。`mise.toml` や CI には含めない。この文書は導入した場合の運用手順を残すためのもの。

## 前提

- Apache-2.0 / Python + Rust
- 圧縮の実体は **proxy**。MCP server は proxy が圧縮した内容を復元する `headroom_retrieve` を提供する補助であり、MCP 単体では自動圧縮されない
- 公称効果: コーディングエージェント 15〜20% 削減、JSON 60〜95% 削減（本リポジトリでの実測はまだ無い）

## セットアップ（初回のみ）

### 1. インストール

```bash
uv tool install --python 3.14 "headroom-ai[mcp,code,proxy]"
```

Python バージョンと extras の指定には理由がある。

- **`--python 3.14`**: headroom のコア依存 `litellm` が Rust 拡張を持つようになり、ローカルの cargo が 1.85 未満だと `edition2024` 非対応でビルドに失敗する。`litellm` の依存条件は `python_full_version < "3.14"` なので、3.14 を選ぶと依存自体がスキップされてこの問題を回避できる。cargo が新しい環境なら 3.12 / 3.13 でも入る。
- **`proxy` extra**: CLI が起動時に全サブコマンドを読み込む実装のため、`[mcp,code]` だけだと `ModuleNotFoundError: No module named 'fastapi'` で `headroom --version` すら通らない。
- **`ml` extra は付けていない**: prose 圧縮モデル用に torch（約 2.5GB）が入る。JSON 圧縮（SmartCrusher）と AST 圧縮（CodeCompressor）は `code` extra だけで動く。

動作確認:

```bash
headroom --version
```

### 2. MCP server の登録

```bash
headroom mcp install --agent claude
```

`~/.claude.json` の global `mcpServers.headroom` に stdio エントリが追加される。実行前にバックアップを取っておくと戻しやすい。

```bash
cp ~/.claude.json ~/.claude.json.bak-headroom
```

### 3. alias の定義

`~/.zshrc` が chezmoi 管理下にある場合、直接編集すると `chezmoi apply` で消える。chezmoi 非管理の `~/.zshrc.local` に書く。

```bash
alias hclaude='ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude'
alias hproxy='headroom proxy --port 8787'
alias hstats='curl -s http://127.0.0.1:8787/stats | jq "{req:.requests.total, tokens:.tokens, skipped:.summary.uncompressed_requests, by_strategy:.compressions_by_strategy}"'
```

`export ANTHROPIC_BASE_URL=...` をシェル初期化に書いてはいけない。proxy が停止しているときに Claude Code が一切起動できなくなる。alias にして素の `claude` を退避経路として残す。

## 実行手順

**ターミナル 1** — proxy を常駐させる（開いたままにする）:

```bash
hproxy
```

`Press Ctrl+C to stop.` が表示されれば起動成功。

**ターミナル 2** — Claude Code を proxy 経由で起動:

```bash
hclaude
```

**削減量の確認**:

```bash
hstats
```

proxy を先に起動すること。順序が逆だと `hclaude` が接続に失敗する。

## 停止・切り戻し

- proxy 停止: ターミナル 1 で `Ctrl+C`。以後は素の `claude` を使う
- MCP 登録の取り消し: `cp ~/.claude.json.bak-headroom ~/.claude.json`
- アンインストール: `uv tool uninstall headroom-ai`

## トラブルシューティング

### `address already in use`

proxy が既に起動している。確認:

```bash
lsof -nP -iTCP:8787 -sTCP:LISTEN
```

### stats がすべてゼロのまま

`uncompressed_requests` に `prefix_frozen` が出ている場合は正常。プロンプトキャッシュの prefix を保護するため、会話冒頭は意図的に圧縮対象から外される。そこを圧縮すると cache miss が発生して逆にコストが増える。

削減が効き始めるのは、tool 出力（ファイル読み込み・grep 結果・JSON レスポンス）が蓄積してから。数十ターン回してから測る。

### 効果を判断する基準

常用に切り替えるかは、以下が揃ってから判断する。

- `tokens.savings_percent` が実測で 10% を超える
- `requests.failed` が 0 のまま
- レイテンシの悪化がない（`stats.latency` / `ttfb`）

## 留意点

- pre-1.0（v0.32 系）かつ公開から日が浅い。破壊的変更の可能性がある
- proxy モードは Claude Code の API トラフィックをローカルプロキシ経由に切り替える。認証情報がプロキシプロセスを通過する点は理解した上で使う
- データはローカル保持。外部通信は ONNX Runtime（`cdn.pyke.io`）とモデル（`huggingface.co`）の取得のみで、それぞれ `ORT_STRATEGY=system` / `HF_HUB_OFFLINE=1` で回避できる
- proxy 起動時のデフォルトはテレメトリ無効・loopback バインドのみ
