from translator import translate_source


def test_basic_translation():
    src = "\n".join(
        [
            "haa x: lakkoofsa = 5",
            "haa y: lakkoofsa = 3",
            "maxxansi(x + y)",
            "",
        ]
    )
    out = translate_source(src)
    assert "x = 5" in out
    assert "y = 3" in out
    assert "print((x + y))" in out


def test_if_else_translation():
    src = "\n".join(
        [
            "haa x = 5",
            "yoo x > 2:",
            "    maxxansi(x)",
            "yookaan:",
            "    maxxansi(0)",
            "",
        ]
    )
    out = translate_source(src)
    assert "if (x > 2):" in out
    assert "else:" in out


def test_natural_if_and_for_and_try_translation():
    src = "\n".join(
        [
            "haa tarree = [1, 2, 3]",
            "irra item keessa tarree:",
            "    yoo (item > 1) ta'e:",
            "        maxxansi(item)",
            "    yoo hin ta'in:",
            "        darbi",
            "yaali:",
            "    maxxansi(1 / 0)",
            "qabsiisi dogoggora:",
            "    maxxansi(\"Dogoggora argame\")",
            "",
        ]
    )
    out = translate_source(src)
    assert "for item in tarree:" in out
    assert "if (item > 1):" in out
    assert "except Exception as dogoggora:" in out


def test_while_and_function_return_translation():
    src = "\n".join(
        [
            "hojii ida(a: lakkoofsa, b: lakkoofsa) -> lakkoofsa:",
            "    deebi'i a + b",
            "haa x = 0",
            "hanga x < 2:",
            "    maxxansi(ida(x, 5))",
            "    x = x + 1",
            "",
        ]
    )
    out = translate_source(src)
    assert "def ida(a: int, b: int) -> int:" in out
    assert "return (a + b)" in out
    assert "while (x < 2):" in out
