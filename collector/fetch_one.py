"""J-Quants から1銘柄の日足を取得し、件数と期間だけを表示する。

株価の値・API キー・応答本文は、どこにも出力しない（J-Quants の規約で生データの配布は禁止。
このリポジトリは公開なので、ログに出た時点で配布になりうる）。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable

BARS_DAILY_URL = "https://api.jquants.com/v2/equities/bars/daily"
DEFAULT_KEY_FILE = "/run/secrets/jquants_env"
INVALID_KEY_MESSAGE = "The incoming api key is invalid or expired."
CODE_PATTERN = re.compile(r"^[0-9A-Z]{4,5}$")  # 英字を含むコードがある（例 356A0）

EXIT_OK = 0
EXIT_USAGE = 1
EXIT_NO_KEY = 2
EXIT_AUTH = 3
EXIT_FORBIDDEN = 4
EXIT_NO_DATA = 5
EXIT_RATE_LIMIT = 6
EXIT_OTHER = 7

HttpGet = Callable[[str, dict[str, str]], tuple[int, bytes]]


class FetchError(Exception):
    """終了コードと、表示してよい情報（区分・HTTP ステータス・例外の型名）だけを持つ。"""

    def __init__(self, exit_code: int, label: str, status: int | None = None, cause: str | None = None):
        super().__init__(label)
        self.exit_code = exit_code
        self.label = label
        self.status = status
        self.cause = cause

    def describe(self) -> str:
        text = self.label
        if self.status is not None:
            text += f" HTTP {self.status}"
        if self.cause is not None:
            text += f" ({self.cause})"
        return text


class _Parser(argparse.ArgumentParser):
    # argparse の既定は exit 2 で、「キーが読めない」と区別できなくなるため
    def error(self, message: str) -> None:
        raise FetchError(EXIT_USAGE, "引数が正しくない")


def http_get(url: str, headers: dict[str, str]) -> tuple[int, bytes]:
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        with error:
            return error.code, error.read()


def read_key(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as file:
            lines = file.read().splitlines()
    except OSError as error:
        raise FetchError(EXIT_NO_KEY, "キーが読めない", cause=type(error).__name__) from None
    for line in lines:
        if line.startswith("JQUANTS_API_KEY="):
            value = line.split("=", 1)[1].strip().strip('"')
            if value:
                return value
    raise FetchError(EXIT_NO_KEY, "キーが読めない")


def parse_json(body: bytes, status: int) -> dict:
    try:
        payload = json.loads(body)
    except ValueError as error:  # JSONDecodeError と UnicodeDecodeError の両方
        raise FetchError(EXIT_OTHER, "応答を読めない", status, type(error).__name__) from None
    if not isinstance(payload, dict):
        raise FetchError(EXIT_OTHER, "応答の形が想定と違う", status)
    return payload


def classify_forbidden(body: bytes) -> FetchError:
    """403 の応答本文から、キーの問題か、それ以外（プラン外・URL の誤り）かを分ける。

    公式（レスポンスステータス）: キー無効のときの message は INVALID_KEY_MESSAGE。
    ただし message が常に付くとは限らない。本文は表示しないこと。
    """
    other = FetchError(EXIT_FORBIDDEN, "権限・プラン外・URL の誤りのどれか", 403)
    try:
        payload = json.loads(body)
    except ValueError:
        return other
    # 確信が持てないときは「それ以外」に倒す（「認証失敗」と出すと、人はキーを作り直しに行ってしまう）
    if isinstance(payload, dict) and payload.get("message") == INVALID_KEY_MESSAGE:
        return FetchError(EXIT_AUTH, "認証に失敗した", 403)
    return other


def fetch_all(code: str, key: str, get: HttpGet = http_get) -> list[dict]:
    rows: list[dict] = []
    pagination_key: str | None = None
    while True:
        params = {"code": code}
        if pagination_key:
            params["pagination_key"] = pagination_key
        try:
            status, body = get(f"{BARS_DAILY_URL}?{urllib.parse.urlencode(params)}", {"x-api-key": key})
        except OSError as error:  # URLError・タイムアウトなど。repr には URL が入るので型名だけ残す
            raise FetchError(EXIT_OTHER, "通信に失敗した", cause=type(error).__name__) from None

        if status == 210:
            raise FetchError(EXIT_NO_DATA, "データなし", status)
        if status == 403:
            raise classify_forbidden(body)
        if status == 429:
            # 公式: 失敗した要求も回数に数え、すぐにやり直すと制限が延びる。だから再試行しない
            raise FetchError(EXIT_RATE_LIMIT, "回数制限", status)
        if status != 200:
            raise FetchError(EXIT_OTHER, "API がエラーを返した", status)

        payload = parse_json(body, status)
        data = payload.get("data")
        if not isinstance(data, list):
            raise FetchError(EXIT_OTHER, "応答の形が想定と違う", status)
        rows.extend(data)
        pagination_key = payload.get("pagination_key")
        if not pagination_key:
            break
    if not rows:
        raise FetchError(EXIT_NO_DATA, "データなし", 200)
    return rows


def normalize_date(value: object) -> str:
    text = str(value)
    if re.fullmatch(r"\d{8}", text):
        text = f"{text[:4]}-{text[4:6]}-{text[6:]}"
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", text):
        raise FetchError(EXIT_OTHER, "応答の日付の形が想定と違う")
    return text


def summarize(code: str, rows: list[dict]) -> str:
    try:
        dates = sorted(normalize_date(row["Date"]) for row in rows)
    except (KeyError, TypeError):
        raise FetchError(EXIT_OTHER, "応答に日付が無い") from None
    return f"{code} {len(rows)} {dates[0]} {dates[-1]}"


def main(argv: list[str] | None = None, get: HttpGet = http_get) -> int:
    try:
        parser = _Parser(description="J-Quants から1銘柄の日足を取得し、件数と期間を表示する")
        parser.add_argument("code", help="銘柄コード（5桁。例 25590）")
        parser.add_argument("--key-file", default=DEFAULT_KEY_FILE)
        args = parser.parse_args(argv)
        if not CODE_PATTERN.fullmatch(args.code):
            raise FetchError(EXIT_USAGE, "銘柄コードの形が正しくない")

        key = read_key(args.key_file)
        rows = fetch_all(args.code, key, get)
        print(summarize(args.code, rows))
        return EXIT_OK
    except FetchError as error:
        print(error.describe(), file=sys.stderr)
        return error.exit_code
    except Exception as error:  # トレースバックには URL やヘッダが載りうるので、型名だけ出す
        print(f"想定外の失敗 ({type(error).__name__})", file=sys.stderr)
        return EXIT_OTHER


if __name__ == "__main__":
    sys.exit(main())
