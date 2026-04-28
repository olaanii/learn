from __future__ import annotations

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
    PassStatement,
    Program,
    ReturnStatement,
    TryStatement,
    UnaryOp,
    VarDecl,
    WhileStatement,
)


class CodeGenerator:
    def generate(self, program: Program) -> str:
        lines: list[str] = []
        for stmt in program.statements:
            lines.extend(self._emit_statement(stmt, 0))
        return "\n".join(lines) + "\n"

    def _emit_statement(self, stmt, indent: int) -> list[str]:
        prefix = "    " * indent
        if isinstance(stmt, VarDecl):
            return [f"{prefix}{stmt.name} = {self._emit_expr(stmt.value)}"]
        if isinstance(stmt, Assignment):
            return [f"{prefix}{stmt.name} = {self._emit_expr(stmt.value)}"]
        if isinstance(stmt, ExprStatement):
            return [f"{prefix}{self._emit_expr(stmt.expression)}"]
        if isinstance(stmt, ReturnStatement):
            if stmt.value is None:
                return [f"{prefix}return"]
            return [f"{prefix}return {self._emit_expr(stmt.value)}"]
        if isinstance(stmt, PassStatement):
            return [f"{prefix}pass"]
        if isinstance(stmt, BreakStatement):
            return [f"{prefix}break"]
        if isinstance(stmt, ContinueStatement):
            return [f"{prefix}continue"]
        if isinstance(stmt, WhileStatement):
            lines = [f"{prefix}while {self._emit_expr(stmt.condition)}:"]
            for item in stmt.body or [PassStatement()]:
                lines.extend(self._emit_statement(item, indent + 1))
            return lines
        if isinstance(stmt, ForStatement):
            lines = [f"{prefix}for {stmt.variable} in {self._emit_expr(stmt.iterable)}:"]
            for item in stmt.body or [PassStatement()]:
                lines.extend(self._emit_statement(item, indent + 1))
            return lines
        if isinstance(stmt, IfStatement):
            lines = [f"{prefix}if {self._emit_expr(stmt.condition)}:"]
            for item in stmt.body or [PassStatement()]:
                lines.extend(self._emit_statement(item, indent + 1))
            for cond, block in stmt.elif_parts:
                lines.append(f"{prefix}elif {self._emit_expr(cond)}:")
                for item in block or [PassStatement()]:
                    lines.extend(self._emit_statement(item, indent + 1))
            if stmt.else_body is not None:
                lines.append(f"{prefix}else:")
                for item in stmt.else_body or [PassStatement()]:
                    lines.extend(self._emit_statement(item, indent + 1))
            return lines
        if isinstance(stmt, FunctionDef):
            params = []
            for p in stmt.params:
                params.append(f"{p.name}: {p.type_name}" if p.type_name else p.name)
            sig = f"def {stmt.name}({', '.join(params)})"
            if stmt.return_type:
                sig += f" -> {stmt.return_type}"
            sig += ":"
            lines = [prefix + sig]
            for item in stmt.body or [PassStatement()]:
                lines.extend(self._emit_statement(item, indent + 1))
            return lines
        if isinstance(stmt, TryStatement):
            lines = [f"{prefix}try:"]
            for item in stmt.body or [PassStatement()]:
                lines.extend(self._emit_statement(item, indent + 1))
            header = "except Exception"
            if stmt.except_name:
                header += f" as {stmt.except_name}"
            header += ":"
            lines.append(prefix + header)
            for item in stmt.except_body or [PassStatement()]:
                lines.extend(self._emit_statement(item, indent + 1))
            if stmt.finally_body is not None:
                lines.append(f"{prefix}finally:")
                for item in stmt.finally_body or [PassStatement()]:
                    lines.extend(self._emit_statement(item, indent + 1))
            return lines

        raise TypeError(f"Unknown statement: {type(stmt)}")

    def _emit_expr(self, expr) -> str:
        if isinstance(expr, Identifier):
            if expr.name == "maxxansi":
                return "print"
            return expr.name
        if isinstance(expr, Literal):
            if isinstance(expr.value, str):
                return expr.value
            return repr(expr.value)
        if isinstance(expr, BinaryOp):
            op_map = {"fi": "and", "yookiin": "or"}
            op = op_map.get(expr.operator, expr.operator)
            return f"({self._emit_expr(expr.left)} {op} {self._emit_expr(expr.right)})"
        if isinstance(expr, UnaryOp):
            op = "not" if expr.operator == "miti" else expr.operator
            return f"({op} {self._emit_expr(expr.operand)})"
        if isinstance(expr, Call):
            args = ", ".join(self._emit_expr(a) for a in expr.args)
            return f"{self._emit_expr(expr.function)}({args})"
        if isinstance(expr, ListLiteral):
            return "[" + ", ".join(self._emit_expr(item) for item in expr.items) + "]"

        raise TypeError(f"Unknown expression: {type(expr)}")
