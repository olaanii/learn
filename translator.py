#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from afan_oromo_lang.generator import CodeGenerator
from afan_oromo_lang.lexer import Lexer, LexerError
from afan_oromo_lang.parser import Parser, ParserError
from afan_oromo_lang.type_checker import TypeChecker, TypeErrorAfan


def translate_source(source: str) -> str:
    tokens = Lexer().tokenize(source)
    program = Parser(tokens).parse()
    TypeChecker().check_program(program)
    return CodeGenerator().generate(program)


def main() -> int:
    parser = argparse.ArgumentParser(description="Afan Oromo gara Python translator")
    parser.add_argument("input", type=Path, help="Faayila .or")
    parser.add_argument("-o", "--output", type=Path, help="Faayila output .py")
    args = parser.parse_args()

    src_path: Path = args.input
    out_path: Path = args.output or src_path.with_suffix(".py")

    try:
        translated = translate_source(src_path.read_text(encoding="utf-8"))
        out_path.write_text(translated, encoding="utf-8")
    except FileNotFoundError:
        print("Dogoggora: faayilli hin argamne")
        return 1
    except (LexerError, ParserError, TypeErrorAfan) as exc:
        print(str(exc))
        return 1

    print(f"Milkaa'e: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
