"""fetch_one を、本物の API を呼ばずに固定の応答で確かめる。

フィクスチャの株価はすべて合成値（実 API の応答は保存しない＝J-Quants の規約）。
"""

import contextlib
import io
import json
import os
import tempfile
import unittest

from collector import fetch_one

DUMMY_KEY = "DUMMY-TEST-KEY-0001"
# 合成の株価。出力に1つでも出たら漏れ
PRICE_VALUES = ["111.1", "122.2", "99.9", "115.5", "12345"]


def bar(date: str) -> dict:
    return {"Date": date, "Code": "25590", "O": 111.1, "H": 122.2, "L": 99.9, "C": 115.5, "Vo": 12345}


def ok(rows: list[dict], pagination_key: str | None = None) -> tuple[int, bytes]:
    payload: dict = {"data": rows}
    if pagination_key:
        payload["pagination_key"] = pagination_key
    return 200, json.dumps(payload).encode()


class FakeGet:
    """決まった応答を順に返す http_get の代わり。"""

    def __init__(self, *responses):
        self.responses = list(responses)
        self.calls: list[str] = []

    def __call__(self, url, headers):
        self.calls.append(url)
        response = self.responses.pop(0)
        if isinstance(response, BaseException):
            raise response
        return response


class FetchOneTest(unittest.TestCase):
    def setUp(self):
        handle, self.key_file = tempfile.mkstemp()
        with os.fdopen(handle, "w", encoding="utf-8") as file:
            file.write(f"JQUANTS_API_KEY={DUMMY_KEY}\n")

    def tearDown(self):
        os.remove(self.key_file)

    def run_main(self, get, code="25590", key_file=None, save=None):
        out, err = io.StringIO(), io.StringIO()
        argv = [code, "--key-file", key_file or self.key_file]
        if save is not None:
            argv.extend(["--save", save])
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = fetch_one.main(argv, get=get)
        output = out.getvalue() + err.getvalue()
        # (h) どのケースでも、キーと株価の値は出力に出ない
        self.assertNotIn(DUMMY_KEY, output)
        for value in PRICE_VALUES:
            self.assertNotIn(value, output)
        return status, out.getvalue(), err.getvalue()

    # (a)
    def test_two_pages_are_summed(self):
        get = FakeGet(
            ok([bar("2024-01-05"), bar("2024-01-04")], pagination_key="next"),
            ok([bar("2024-01-09")]),
        )
        status, out, _ = self.run_main(get)
        self.assertEqual(status, fetch_one.EXIT_OK)
        self.assertEqual(out.strip(), "25590 3 2024-01-04 2024-01-09")
        self.assertEqual(len(get.calls), 2)
        self.assertIn("pagination_key=next", get.calls[1])

    # (b)
    def test_empty_data_is_no_data(self):
        status, _, _ = self.run_main(FakeGet(ok([])))
        self.assertEqual(status, fetch_one.EXIT_NO_DATA)

    # (c)
    def test_210_is_no_data(self):
        status, _, _ = self.run_main(FakeGet((210, b"")))
        self.assertEqual(status, fetch_one.EXIT_NO_DATA)

    # (d)
    def test_403_invalid_key_is_auth_error(self):
        body = json.dumps({"message": fetch_one.INVALID_KEY_MESSAGE}).encode()
        status, _, err = self.run_main(FakeGet((403, body)))
        self.assertEqual(status, fetch_one.EXIT_AUTH)
        self.assertIn("認証に失敗した", err)

    # (e)
    def test_403_other_message_is_forbidden(self):
        body = json.dumps({"message": "plan does not include this data"}).encode()
        status, _, _ = self.run_main(FakeGet((403, body)))
        self.assertEqual(status, fetch_one.EXIT_FORBIDDEN)

    def test_403_without_message_is_forbidden(self):
        for body in (b"", b"{}", b"not json"):
            with self.subTest(body=body):
                status, _, _ = self.run_main(FakeGet((403, body)))
                self.assertEqual(status, fetch_one.EXIT_FORBIDDEN)

    # (f)
    def test_429_does_not_retry(self):
        get = FakeGet((429, b""), ok([bar("2024-01-04")]))
        status, _, err = self.run_main(get)
        self.assertEqual(status, fetch_one.EXIT_RATE_LIMIT)
        self.assertIn("回数制限", err)
        self.assertEqual(len(get.calls), 1)

    # (g)
    def test_other_failures(self):
        cases = {
            "400": (400, b'{"message": "bad"}'),
            "500": (500, b""),
            "broken json": (200, b"{not json"),
            "network": OSError("connection refused"),
        }
        for name, response in cases.items():
            with self.subTest(name):
                status, _, _ = self.run_main(FakeGet(response))
                self.assertEqual(status, fetch_one.EXIT_OTHER)

    def test_missing_key_file(self):
        status, _, err = self.run_main(FakeGet(), key_file="/nonexistent/jquants.env")
        self.assertEqual(status, fetch_one.EXIT_NO_KEY)
        self.assertIn("キーが読めない", err)

    def test_invalid_code(self):
        status, _, _ = self.run_main(FakeGet(), code="7203;rm")
        self.assertEqual(status, fetch_one.EXIT_USAGE)

    def test_save_csv_is_sorted_and_has_stable_columns(self):
        with tempfile.TemporaryDirectory() as directory:
            old_cwd = os.getcwd()
            os.chdir(directory)
            try:
                get = FakeGet(ok([
                    {**bar("20240105"), "Extra": "later"},
                    {**bar("20240104"), "Other": "first"},
                ]))
                status, out, _ = self.run_main(get, key_file=self.key_file, save="data/bars_25590.csv")
                self.assertEqual(status, fetch_one.EXIT_OK)
                self.assertEqual(out.splitlines()[1], "saved data/bars_25590.csv columns=Date,Code,O,H,L,C,Vo,Extra,Other")
                with open("data/bars_25590.csv", encoding="utf-8", newline="") as file:
                    content = file.read()
                self.assertEqual(content.splitlines()[0], "Date,Code,O,H,L,C,Vo,Extra,Other")
                self.assertEqual(content.splitlines()[1].split(",")[0], "2024-01-04")
                self.assertEqual(content.splitlines()[2].split(",")[0], "2024-01-05")
                self.assertEqual(len(content.splitlines()), 3)
            finally:
                os.chdir(old_cwd)

    def test_save_rejects_paths_outside_data(self):
        with tempfile.TemporaryDirectory() as directory:
            old_cwd = os.getcwd()
            os.chdir(directory)
            try:
                for path in ("out.csv", "../x.csv", "data/../x.csv"):
                    with self.subTest(path=path):
                        get = FakeGet(ok([bar("20240104")]))
                        status, _, err = self.run_main(get, key_file=self.key_file, save=path)
                        self.assertEqual(status, fetch_one.EXIT_USAGE)
                        self.assertIn("保存先は data/ の下だけ", err)
                        self.assertFalse(os.path.exists(path))
                        self.assertEqual(get.calls, [])  # 拒否する保存先のために API を呼ばない
            finally:
                os.chdir(old_cwd)

    def test_save_does_not_create_file_when_fetch_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            old_cwd = os.getcwd()
            os.chdir(directory)
            try:
                status, _, _ = self.run_main(FakeGet((500, b"")), key_file=self.key_file, save="data/bars_25590.csv")
                self.assertEqual(status, fetch_one.EXIT_OTHER)
                self.assertFalse(os.path.exists("data/bars_25590.csv"))
            finally:
                os.chdir(old_cwd)

    def test_save_output_does_not_contain_price_values(self):
        with tempfile.TemporaryDirectory() as directory:
            old_cwd = os.getcwd()
            os.chdir(directory)
            try:
                status, out, _ = self.run_main(FakeGet(ok([bar("20240104")])), key_file=self.key_file, save="data/bars_25590.csv")
                self.assertEqual(status, fetch_one.EXIT_OK)
                self.assertIn("saved data/bars_25590.csv", out)
            finally:
                os.chdir(old_cwd)


if __name__ == "__main__":
    unittest.main()
