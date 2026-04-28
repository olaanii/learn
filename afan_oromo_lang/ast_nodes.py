from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional


class Node:
    pass


class Statement(Node):
    pass


class Expression(Node):
    pass


@dataclass
class Program(Node):
    statements: List[Statement] = field(default_factory=list)


@dataclass
class Identifier(Expression):
    name: str


@dataclass
class Literal(Expression):
    value: object


@dataclass
class ListLiteral(Expression):
    items: List[Expression]


@dataclass
class BinaryOp(Expression):
    left: Expression
    operator: str
    right: Expression


@dataclass
class UnaryOp(Expression):
    operator: str
    operand: Expression


@dataclass
class Call(Expression):
    function: Expression
    args: List[Expression]


@dataclass
class VarDecl(Statement):
    name: str
    value: Expression
    type_name: Optional[str] = None


@dataclass
class Assignment(Statement):
    name: str
    value: Expression


@dataclass
class ExprStatement(Statement):
    expression: Expression


@dataclass
class IfStatement(Statement):
    condition: Expression
    body: List[Statement]
    elif_parts: List[tuple[Expression, List[Statement]]] = field(default_factory=list)
    else_body: Optional[List[Statement]] = None


@dataclass
class WhileStatement(Statement):
    condition: Expression
    body: List[Statement]


@dataclass
class ForStatement(Statement):
    variable: str
    iterable: Expression
    body: List[Statement]


@dataclass
class ReturnStatement(Statement):
    value: Optional[Expression] = None


@dataclass
class Parameter(Node):
    name: str
    type_name: Optional[str] = None


@dataclass
class FunctionDef(Statement):
    name: str
    params: List[Parameter]
    body: List[Statement]
    return_type: Optional[str] = None


@dataclass
class PassStatement(Statement):
    pass


@dataclass
class BreakStatement(Statement):
    pass


@dataclass
class ContinueStatement(Statement):
    pass


@dataclass
class TryStatement(Statement):
    body: List[Statement]
    except_name: Optional[str]
    except_body: List[Statement]
    finally_body: Optional[List[Statement]] = None
