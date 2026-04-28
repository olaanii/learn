from __future__ import annotations

from dataclasses import dataclass, field

from .ast_nodes import (
    Assignment,
    BinaryOp,
    ForStatement,
    FunctionDef,
    Identifier,
    IfStatement,
    ListLiteral,
    Literal,
    Program,
    ReturnStatement,
    TryStatement,
    UnaryOp,
    VarDecl,
    WhileStatement,
)


class TypeErrorAfan(Exception):
    pass


@dataclass
class TypeEnv:
    env: dict[str, str] = field(default_factory=dict)

    def declare(self, name: str, type_name: str) -> None:
        self.env[name] = type_name

    def get(self, name: str) -> str | None:
        return self.env.get(name)


class TypeChecker:
    def __init__(self) -> None:
        self.env = TypeEnv()

    def check_program(self, program: Program) -> None:
        for stmt in program.statements:
            self.check(stmt)

    def check(self, node):
        if isinstance(node, VarDecl):
            value_type = self.check(node.value)
            declared = node.type_name or value_type
            if node.type_name and value_type != node.type_name:
                raise TypeErrorAfan("Dogoggora: type hin wal simne")
            self.env.declare(node.name, declared)
            return declared

        if isinstance(node, Assignment):
            existing = self.env.get(node.name)
            value_type = self.check(node.value)
            if existing and existing != value_type:
                raise TypeErrorAfan("Dogoggora: gosa hin walsimu")
            if not existing:
                self.env.declare(node.name, value_type)
            return value_type

        if isinstance(node, Identifier):
            known = self.env.get(node.name)
            return known or "unknown"

        if isinstance(node, Literal):
            if isinstance(node.value, bool):
                return "bool"
            if isinstance(node.value, int):
                return "int"
            if isinstance(node.value, float):
                return "float"
            if isinstance(node.value, str):
                return "str"
            return "unknown"
        if isinstance(node, ListLiteral):
            for item in node.items:
                self.check(item)
            return "list"

        if isinstance(node, BinaryOp):
            left = self.check(node.left)
            right = self.check(node.right)
            if node.operator in {"+", "-", "*"}:
                if left == right == "int":
                    return "int"
                if left in {"int", "float"} and right in {"int", "float"}:
                    return "float"
            if node.operator == "/":
                return "float"
            if node.operator in {"==", "!=", ">", "<", ">=", "<=", "fi", "yookiin"}:
                return "bool"
            return "unknown"

        if isinstance(node, UnaryOp):
            if node.operator == "miti":
                return "bool"
            return self.check(node.operand)

        if isinstance(node, ReturnStatement):
            return self.check(node.value) if node.value else "None"

        if isinstance(node, IfStatement):
            for s in node.body:
                self.check(s)
            for _, body in node.elif_parts:
                for s in body:
                    self.check(s)
            if node.else_body:
                for s in node.else_body:
                    self.check(s)
            return None

        if isinstance(node, WhileStatement):
            for s in node.body:
                self.check(s)
            return None
        if isinstance(node, ForStatement):
            self.env.declare(node.variable, "unknown")
            for s in node.body:
                self.check(s)
            return None
        if isinstance(node, TryStatement):
            for s in node.body:
                self.check(s)
            for s in node.except_body:
                self.check(s)
            if node.finally_body:
                for s in node.finally_body:
                    self.check(s)
            return None

        if isinstance(node, FunctionDef):
            inner = TypeChecker()
            inner.env.env = self.env.env.copy()
            for param in node.params:
                inner.env.declare(param.name, param.type_name or "unknown")
            for stmt in node.body:
                inner.check(stmt)
            return None

        return None
