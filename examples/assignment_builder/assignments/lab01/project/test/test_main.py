import sys
import pytest
from .. import main


def test_get_name():
    expected = "Batman"
    actual = main.get_name()
    assert expected == actual


def test_get_age():
    expected = 30
    actual = main.get_age()
    assert expected == actual


def test_get_python_version():
    expected = sys.version
    actual = main.get_python_version()
    assert expected == actual


def test_get_greeting():
    expected = "It's nice to meet everyone."
    actual = main.get_greeting()
    assert expected == actual


def test_main():
    expected = 5
    actual = len(main.main())
    assert expected == actual
