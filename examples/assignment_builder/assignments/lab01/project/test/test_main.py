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
