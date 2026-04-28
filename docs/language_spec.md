# Afan Oromo Beginner Language Specification (AOBL)

## 1) Target Language
AOBL translates to **Python 3** (`.py`).

## 2) Design Goal
A small, beginner-first programming language that uses Afan Oromo keywords to reduce English syntax barriers.

## 3) Keywords
| AOBL | Meaning in Python |
|---|---|
| `haa` | variable declaration/assignment |
| `yoo` | `if` |
| `yookaan` | `else` |
| `hanga` | `while` |
| `irra` ... `keessa` | `for` ... `in` |
| `hojii` | `def` |
| `deebi'i` | `return` |
| `maxxansi` | `print` |
| `fi` | `and` |
| `yookiin` | `or` |
| `miti` | `not` |
| `darbi` | `pass` |
| `kuti` | `break` |
| `itti_fufi` | `continue` |
| `yaali` / `qabsiisi` / `dhuma` | `try` / `except` / `finally` |

Natural beginner form also supported:
- `yoo (condition) ta'e:`
- `yoo hin ta'in:`

## 4) Syntax Rules (Beginner Subset)
- Blocks use indentation like Python.
- Variable declaration: `haa x = 5`
- Optional typing: `haa x: lakkoofsa = 5`
- Expressions:
  - Arithmetic: `+ - * /`
  - Comparison: `== < > <= >= !=`
- Conditionals:
  - `yoo x > 5:` ... `yookaan:` ...
- Loop:
  - `hanga x < 10:` ...
- Functions:
  - `hojii ida(a: lakkoofsa, b: lakkoofsa) -> lakkoofsa:`
  - `deebi'i a + b`

## 5) Beginner-Friendly Design
- Local-language keywords.
- Natural conditional form (`ta'e`, `hin ta'in`).
- Afan Oromo error messages from lexer/parser/type-checker.
- Structured translation through Lexer -> Parser(AST) -> Code Generator.

## 6) CLI
```bash
python translator.py program.or
```
Output: `program.py`

## 7) Validity Constraints
- Structured parsing is used (not text replacement).
- Unicode source is accepted.
- Generated code is valid Python syntax for supported constructs.
