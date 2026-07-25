import "@typespec/http";
import "@typespec/openapi3";

using Http;

/**
 * TODO 管理 REST API。
 * 全エンドポイントは `Authorization: Bearer <key>` 認証が必須。
 * 仕様: specs/001-todo-api/spec.md
 */
@service(#{ title: "Todo Management API" })
@server("http://localhost:8080", "ローカル開発")
@useAuth(BearerAuth)
namespace TodoService;

// ---------------------------------------------------------------------------
// リソースモデル（read / create / update を明示分離）
// ---------------------------------------------------------------------------

/** 読み取り時の Todo 表現（id / タイムスタンプを含む完全形）。 */
model TodoRead {
  /** サーバ採番の UUID v4（読み取り専用）。 */
  @format("uuid")
  id: string;

  /** タイトル。1〜256 文字、空白のみは不可。 */
  @minLength(1)
  @maxLength(256)
  @pattern("\\S")
  title: string;

  /** 説明（任意）。最大 1024 文字。既定は空文字。 */
  @maxLength(1024)
  description: string;

  /** 完了フラグ。作成時は常に false。 */
  completed: boolean;

  /** 作成日時（サーバ管理・読み取り専用）。 */
  created_at: utcDateTime;

  /** 更新日時（サーバ管理・読み取り専用）。 */
  updated_at: utcDateTime;
}

/**
 * 作成リクエスト（POST /todos）。
 * `completed` は意図的に含めない → 送られても無視され、サーバは常に false を設定。
 * id / created_at / updated_at はサーバ採番のため存在しない。
 */
model TodoCreate {
  @minLength(1)
  @maxLength(256)
  @pattern("\\S")
  title: string;

  @maxLength(1024)
  description?: string = "";
}

/**
 * 全項目置換リクエスト（PUT /todos/{id}）。
 * `completed` は更新でのみ変更可能。id / タイムスタンプは含めない。
 */
model TodoUpdate {
  @minLength(1)
  @maxLength(256)
  @pattern("\\S")
  title: string;

  @maxLength(1024)
  description?: string = "";

  /** 未指定時は false として置換。 */
  completed?: boolean = false;
}

// ---------------------------------------------------------------------------
// エラーモデル（RFC 7807 problem+json + errors 拡張）
// ---------------------------------------------------------------------------

/** バリデーション失敗の項目単位詳細。 */
model FieldError {
  /** 不正だった項目名（例: "title"）。 */
  field: string;

  /** 機械可読なエラーコード（例: "required" / "too_long" / "blank"）。 */
  code: string;

  /** 人間可読な理由（例: "title must not be blank"）。 */
  message: string;
}

/**
 * RFC 7807 準拠のエラー本体。Status はステータスコードのリテラル型。
 * `@error` によりエミッタは失敗レスポンスとして扱う。
 */
@error
model Problem<Status extends int32> {
  @statusCode statusCode: Status;

  /** レスポンスのメディアタイプを application/problem+json に固定。 */
  @header contentType: "application/problem+json";

  /** 問題の種類を示す URI。既定は about:blank。 */
  type?: string = "about:blank";

  /** 問題種別の短い要約。 */
  title: string;

  /** HTTP ステータスコード。 */
  status: int32;

  /** この発生に固有の詳細説明。 */
  detail?: string;

  /** 発生箇所を示す URI 参照（任意）。 */
  instance?: string;

  /** 項目単位のバリデーションエラー（400 で使用）。 */
  errors?: FieldError[];
}

alias BadRequest = Problem<400>;
alias Unauthorized = Problem<401>;
alias NotFound = Problem<404>;

// ---------------------------------------------------------------------------
// 成功レスポンス（明示ステータス）
// ---------------------------------------------------------------------------

/** 201 Created。Location ヘッダと本体を返す。 */
model TodoCreated {
  @statusCode statusCode: 201;

  @header("Location")
  location?: string;

  @body todo: TodoRead;
}

/** 204 No Content（削除成功）。 */
model TodoDeleted {
  @statusCode statusCode: 204;
}

// ---------------------------------------------------------------------------
// エンドポイント
// ---------------------------------------------------------------------------

@route("/todos")
@tag("Todos")
interface Todos {
  /**
   * Todo を作成する。`completed` はリクエストにあっても無視され false になる。
   */
  @post
  @summary("Todo を作成")
  create(@body body: TodoCreate): TodoCreated | BadRequest | Unauthorized;

  /**
   * Todo を全件取得する。created_at の降順で返す。
   */
  @get
  @summary("Todo 一覧を取得")
  list(): TodoRead[] | Unauthorized;

  /** 単一の Todo を取得する。 */
  @get
  @route("{id}")
  @summary("Todo を取得")
  read(
    @path @format("uuid") id: string,
  ): TodoRead | Unauthorized | NotFound;

  /** Todo を全項目置換する。 */
  @put
  @route("{id}")
  @summary("Todo を置換")
  replace(
    @path @format("uuid") id: string,
    @body body: TodoUpdate,
  ): TodoRead | BadRequest | Unauthorized | NotFound;

  /** Todo を削除する。 */
  @delete
  @route("{id}")
  @summary("Todo を削除")
  delete(
    @path @format("uuid") id: string,
  ): TodoDeleted | Unauthorized | NotFound;
}
