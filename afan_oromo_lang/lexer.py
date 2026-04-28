from __future__ import annotations

from dataclasses import dataclass
from typing import List


@dataclass
class Token:
    type: str
    value: str
    line: int
    column: int


KEYWORDS = {
    "haa",
    "yoo",
    "yookaan",
    "yoo_tahe",
    "hanga",
    "irra",
    "keessa",
    "hojii",
    "deebi'i",
    "maxxansi",
    "dhugaa",
    "soba",
    "fi",
    "yookiin",
    "miti",
    "kuti",
    "itti_fufi",
    "darbi",
    "ta'e",
    "hin",
    "ta'in",
    "yaali",
    "qabsiisi",
    "dhuma",
}


class LexerError(Exception):
    pass


class Lexer:
    def tokenize(self, source: str) -> List[Token]:
        tokens: List[Token] = []
        indent_stack = [0]
        lines = source.splitlines()

        for lineno, raw_line in enumerate(lines, start=1):
            if not raw_line.strip():
                continue
            if raw_line.lstrip().startswith("#"):
                continue

            indent = len(raw_line) - len(raw_line.lstrip(" "))
            if raw_line[:indent].count("\t"):
                raise LexerError("Dogoggora: tab hin eeyyamamu (spaces qofaan fayyadami)")

            if indent > indent_stack[-1]:
                indent_stack.append(indent)
                tokens.append(Token("INDENT", "", lineno, 1))
            else:
                while indent < indent_stack[-1]:
                    indent_stack.pop()
                    tokens.append(Token("DEDENT", "", lineno, 1))
                if indent != indent_stack[-1]:
                    raise LexerError("Dogoggora: indentation sirrii miti")

            tokens.extend(self._tokenize_line(raw_line.strip(), lineno))
            tokens.append(Token("NEWLINE", "", lineno, len(raw_line) + 1))

        while len(indent_stack) > 1:
            indent_stack.pop()
            tokens.append(Token("DEDENT", "", len(lines), 1))

        tokens.append(Token("EOF", "", len(lines) + 1, 1))
        return tokens

    def _tokenize_line(self, text: str, line: int) -> List[Token]:
        out: List[Token] = []
        i = 0
        while i < len(text):
            c = text[i]
            if c.isspace():
                i += 1
                continue

            if c in "(),:[]":
                out.append(Token(c, c, line, i + 1))
                i += 1
                continue

            if c in "+-*/":
                if c == "-" and i + 1 < len(text) and text[i + 1] == ">":
                    out.append(Token("ARROW", "->", line, i + 1))
                    i += 2
                else:
                    out.append(Token("OP", c, line, i + 1))
                    i += 1
                continue

            if c in "=<>!":
                if i + 1 < len(text) and text[i + 1] == "=":
                    out.append(Token("OP", c + "=", line, i + 1))
                    i += 2
                else:
                    out.append(Token("OP", c, line, i + 1))
                    i += 1
                continue

            if c == '"':
                start = i
                i += 1
                buf = []
                while i < len(text) and text[i] != '"':
                    if text[i] == "\\" and i + 1 < len(text):
                        buf.append(text[i : i + 2])
                        i += 2
                    else:
                        buf.append(text[i])
                        i += 1
                if i >= len(text):
                    raise LexerError("Dogoggora: barruu guutuu hin cufamne")
                i += 1
                out.append(Token("STRING", '"' + "".join(buf) + '"', line, start + 1))
                continue

            if c.isdigit():
                start = i
                has_dot = False
                while i < len(text) and (text[i].isdigit() or (text[i] == "." and not has_dot)):
                    has_dot = has_dot or text[i] == "."
                    i += 1
                out.append(Token("NUMBER", text[start:i], line, start + 1))
                continue

            if c.isalpha() or c == "_" or c == "'":
                start = i
                while i < len(text) and (text[i].isalnum() or text[i] in {"_", "'"}):
                    i += 1
                word = text[start:i]
                token_type = "KW" if word in KEYWORDS else "IDENT"
                out.append(Token(token_type, word, line, start + 1))
                continue

            raise LexerError(f"Dogoggora: jecha hin beekamne '{c}' line {line}")

        return out
