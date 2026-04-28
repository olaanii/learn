from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

from .ast_nodes import (
    Assignment,
    BinaryOp,
    BreakStatement,
    Call,
    ContinueStatement,
    ExprStatement,
    ForStatement,
    FunctionDef,
    Identifier,
    IfStatement,
    ListLiteral,
    Literal,
    Parameter,
    PassStatement,
    Program,
    ReturnStatement,
    TryStatement,
    UnaryOp,
    VarDecl,
    WhileStatement,
)
from .lexer import Token


class ParserError(Exception):
    pass


TYPE_MAP = {
    "lakkoofsa": "int",
    "dhugaa": "bool",
    "barruu": "str",
    "lakkf": "float",
}


@dataclass
class Parser:
    tokens: List[Token]
    pos: int = 0

    def parse(self) -> Program:
        statements = []
        while not self._match("EOF"):
            if self._match("NEWLINE"):
                self._advance()
                continue
            statements.append(self._parse_statement())
        return Program(statements)

    def _parse_statement(self):
        token = self._peek()
        needs_newline = True
        if token.type == "KW":
            if token.value == "haa":
                stmt = self._parse_var_decl()
            elif token.value == "yoo":
                stmt = self._parse_if()
                needs_newline = False
            elif token.value == "hanga":
                stmt = self._parse_while()
                needs_newline = False
            elif token.value == "irra":
                stmt = self._parse_for()
                needs_newline = False
            elif token.value == "hojii":
                stmt = self._parse_function()
                needs_newline = False
            elif token.value == "yaali":
                stmt = self._parse_try()
                needs_newline = False
            elif token.value == "deebi'i":
                self._advance()
                if self._match("NEWLINE"):
                    stmt = ReturnStatement(None)
                else:
                    stmt = ReturnStatement(self._parse_expression())
            elif token.value == "darbi":
                self._advance()
                stmt = PassStatement()
            elif token.value == "kuti":
                self._advance()
                stmt = BreakStatement()
            elif token.value == "itti_fufi":
                self._advance()
                stmt = ContinueStatement()
            else:
                stmt = ExprStatement(self._parse_expression())
        else:
            stmt = self._parse_assignment_or_expr()

        if needs_newline:
            self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
        return stmt

    def _parse_var_decl(self):
        self._consume_kw("haa")
        name = self._consume("IDENT", "Dogoggora: maqaa variable eegama").value
        type_name: Optional[str] = None
        if self._match(":"):
            self._advance()
            raw_type = self._consume("IDENT", "Dogoggora: gosa eegama").value
            type_name = TYPE_MAP.get(raw_type, raw_type)
        self._consume_op("=")
        value = self._parse_expression()
        return VarDecl(name=name, value=value, type_name=type_name)

    def _parse_if(self):
        self._consume_kw("yoo")
        condition = self._parse_if_condition()
        self._consume(":", "Dogoggora: ':' dhabame")
        self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
        body = self._parse_block()

        elif_parts = []
        else_body = None
        while self._match("KW", "yoo_tahe"):
            self._advance()
            elif_cond = self._parse_if_condition()
            self._consume(":", "Dogoggora: ':' dhabame")
            self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
            elif_parts.append((elif_cond, self._parse_block()))

        if self._match("KW", "yookaan") or self._match_sequence([("KW", "yoo"), ("KW", "hin"), ("KW", "ta'in")]):
            if self._match("KW", "yookaan"):
                self._advance()
            else:
                self._consume_kw("yoo")
                self._consume_kw("hin")
                self._consume_kw("ta'in")
            self._consume(":", "Dogoggora: ':' dhabame")
            self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
            else_body = self._parse_block()

        return IfStatement(condition=condition, body=body, elif_parts=elif_parts, else_body=else_body)

    def _parse_if_condition(self):
        if self._match("("):
            self._advance()
            condition = self._parse_expression()
            self._consume(")", "Dogoggora: ')' dhabame")
        else:
            condition = self._parse_expression()

        if self._match("KW", "ta'e"):
            self._advance()
        return condition


    def _parse_while(self):
        self._consume_kw("hanga")
        condition = self._parse_expression()
        self._consume(":", "Dogoggora: ':' dhabame")
        self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
        body = self._parse_block()
        return WhileStatement(condition=condition, body=body)

    def _parse_for(self):
        self._consume_kw("irra")
        variable = self._consume("IDENT", "Dogoggora: maqaa iterator eegama").value
        self._consume_kw("keessa")
        iterable = self._parse_expression()
        self._consume(":", "Dogoggora: ':' dhabame")
        self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
        body = self._parse_block()
        return ForStatement(variable=variable, iterable=iterable, body=body)

    def _parse_try(self):
        self._consume_kw("yaali")
        self._consume(":", "Dogoggora: ':' dhabame")
        self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
        body = self._parse_block()

        self._consume_kw("qabsiisi")
        except_name = None
        if self._match("IDENT"):
            except_name = self._advance().value
        self._consume(":", "Dogoggora: ':' dhabame")
        self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
        except_body = self._parse_block()

        finally_body = None
        if self._match("KW", "dhuma"):
            self._advance()
            self._consume(":", "Dogoggora: ':' dhabame")
            self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
            finally_body = self._parse_block()
        return TryStatement(body=body, except_name=except_name, except_body=except_body, finally_body=finally_body)

    def _parse_function(self):
        self._consume_kw("hojii")
        name = self._consume("IDENT", "Dogoggora: maqaa function eegama").value
        self._consume("(", "Dogoggora: '(' dhabame")
        params: List[Parameter] = []
        if not self._match(")"):
            while True:
                param_name = self._consume("IDENT", "Dogoggora: maqaa parameter eegama").value
                param_type = None
                if self._match(":"):
                    self._advance()
                    raw_type = self._consume("IDENT", "Dogoggora: gosa parameter eegama").value
                    param_type = TYPE_MAP.get(raw_type, raw_type)
                params.append(Parameter(param_name, param_type))
                if self._match(","):
                    self._advance()
                    continue
                break
        self._consume(")", "Dogoggora: ')' dhabame")
        return_type = None
        if self._match("ARROW"):
            self._advance()
            raw_type = self._consume("IDENT", "Dogoggora: gosa return eegama").value
            return_type = TYPE_MAP.get(raw_type, raw_type)
        self._consume(":", "Dogoggora: ':' dhabame")
        self._consume("NEWLINE", "Dogoggora: NEWLINE eegama")
        body = self._parse_block()
        return FunctionDef(name=name, params=params, body=body, return_type=return_type)

    def _parse_assignment_or_expr(self):
        if self._match("IDENT") and self._peek(1).type == "OP" and self._peek(1).value == "=":
            name = self._advance().value
            self._advance()
            value = self._parse_expression()
            return Assignment(name, value)
        return ExprStatement(self._parse_expression())

    def _parse_block(self):
        self._consume("INDENT", "Dogoggora: indentation eegama")
        statements = []
        while not self._match("DEDENT") and not self._match("EOF"):
            if self._match("NEWLINE"):
                self._advance()
                continue
            statements.append(self._parse_statement())
        self._consume("DEDENT", "Dogoggora: block hin cufamne")
        return statements

    def _parse_expression(self):
        return self._parse_or()

    def _parse_or(self):
        expr = self._parse_and()
        while self._match("KW", "yookiin"):
            op = self._advance().value
            expr = BinaryOp(expr, op, self._parse_and())
        return expr

    def _parse_and(self):
        expr = self._parse_equality()
        while self._match("KW", "fi"):
            op = self._advance().value
            expr = BinaryOp(expr, op, self._parse_equality())
        return expr

    def _parse_equality(self):
        expr = self._parse_comparison()
        while self._match("OP") and self._peek().value in {"==", "!="}:
            op = self._advance().value
            expr = BinaryOp(expr, op, self._parse_comparison())
        return expr

    def _parse_comparison(self):
        expr = self._parse_term()
        while self._match("OP") and self._peek().value in {">", ">=", "<", "<="}:
            op = self._advance().value
            expr = BinaryOp(expr, op, self._parse_term())
        return expr

    def _parse_term(self):
        expr = self._parse_factor()
        while self._match("OP") and self._peek().value in {"+", "-"}:
            op = self._advance().value
            expr = BinaryOp(expr, op, self._parse_factor())
        return expr

    def _parse_factor(self):
        expr = self._parse_unary()
        while self._match("OP") and self._peek().value in {"*", "/"}:
            op = self._advance().value
            expr = BinaryOp(expr, op, self._parse_unary())
        return expr

    def _parse_unary(self):
        if (self._match("OP") and self._peek().value == "-") or self._match("KW", "miti"):
            op = self._advance().value
            return UnaryOp(op, self._parse_unary())
        return self._parse_call()

    def _parse_call(self):
        expr = self._parse_primary()
        while self._match("("):
            self._advance()
            args = []
            if not self._match(")"):
                while True:
                    args.append(self._parse_expression())
                    if self._match(","):
                        self._advance()
                        continue
                    break
            self._consume(")", "Dogoggora: ')' dhabame")
            expr = Call(expr, args)
        return expr

    def _parse_primary(self):
        if self._match("NUMBER"):
            val = self._advance().value
            return Literal(float(val) if "." in val else int(val))
        if self._match("STRING"):
            return Literal(self._advance().value)
        if self._match("KW", "dhugaa"):
            self._advance()
            return Literal(True)
        if self._match("KW", "soba"):
            self._advance()
            return Literal(False)
        if self._match("KW", "maxxansi"):
            return Identifier(self._advance().value)
        if self._match("IDENT"):
            return Identifier(self._advance().value)
        if self._match("["):
            self._advance()
            items = []
            if not self._match("]"):
                while True:
                    items.append(self._parse_expression())
                    if self._match(","):
                        self._advance()
                        continue
                    break
            self._consume("]", "Dogoggora: ']' dhabame")
            return ListLiteral(items)
        if self._match("("):
            self._advance()
            expr = self._parse_expression()
            self._consume(")", "Dogoggora: ')' dhabame")
            return expr

        raise ParserError(f"Dogoggora: sirna dogoggora line {self._peek().line}")

    def _peek(self, offset=0):
        idx = min(self.pos + offset, len(self.tokens) - 1)
        return self.tokens[idx]

    def _advance(self):
        token = self.tokens[self.pos]
        self.pos += 1
        return token

    def _match(self, token_type, value=None):
        token = self._peek()
        if token.type != token_type:
            return False
        if value is not None and token.value != value:
            return False
        return True

    def _consume(self, token_type, msg):
        if not self._match(token_type):
            raise ParserError(msg)
        return self._advance()

    def _consume_op(self, value):
        if not self._match("OP") or self._peek().value != value:
            raise ParserError(f"Dogoggora: '{value}' dhabame")
        return self._advance()

    def _consume_kw(self, value):
        if not self._match("KW", value):
            raise ParserError(f"Dogoggora: '{value}' eegama")
        return self._advance()

    def _match_sequence(self, sequence):
        for offset, (token_type, token_value) in enumerate(sequence):
            token = self._peek(offset)
            if token.type != token_type:
                return False
            if token_value is not None and token.value != token_value:
                return False
        return True
