# Afan Oromo Programming Language (Beginner Translator)

This module implements an AST-based translator from `.or` Afan Oromo code to **Python 3**.

## Architecture

`.or source` -> `Lexer` -> `Parser (AST)` -> `Type Checker` -> `Python Generator`

## Files

- `translator.py` CLI entrypoint
- `afan_oromo_lang/lexer.py` tokenization with indentation support
- `afan_oromo_lang/parser.py` recursive descent parser
- `afan_oromo_lang/ast_nodes.py` AST model
- `afan_oromo_lang/type_checker.py` starter strong-typing checks
- `afan_oromo_lang/generator.py` Python code generation

## Run

```bash
python translator.py examples/program.or
python examples/program.py
```

## Project Deliverables

- Language specification: `docs/language_spec.md`
- Short report: `docs/short_report.md`
- Test programs (source + generated + output):
  - `examples/basic.or` / `examples/basic.py` / `examples/basic.out`
  - `examples/control_flow.or` / `examples/control_flow.py` / `examples/control_flow.out`
  - `examples/feature_demo.or` / `examples/feature_demo.py` / `examples/feature_demo.out`

## Supported features in this first milestone

- Variables and assignment
- Arithmetic and boolean expressions
- `if / elif / else`
- Natural conditional form: `yoo (condition) ta'e:` and `yoo hin ta'in:`
- `while`
- `for` loop (`irra ... keessa ...:`)
- Function definitions and return
- `try / except / finally` (`yaali / qabsiisi / dhuma`)
- List literals
- Basic typing annotations (`lakkoofsa`, `barruu`, `dhugaa`, `lakkf`)
- Afan Oromo error messages for lexer/parser/type mismatches

## Notes

- This is a structured parser (not simple string replacement).
- Unicode identifiers/keywords are supported.
- It is intentionally **Python-like**, but not yet a full Python-compatible language.
