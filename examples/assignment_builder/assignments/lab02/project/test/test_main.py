import sys
import pytest
from .. import main


def test_get_difference1():
    expected = 8
    actual = main.get_difference(10, 2)
    assert expected == actual


def test_get_difference2():
    expected = -3
    actual = main.get_difference(3, 6)
    assert expected == actual


def test_get_sum1():
    expected = 5
    actual = main.get_sum(2, 3)
    assert expected == actual


def test_get_sum2():
    expected = -3
    actual = main.get_sum(-2, -1)
    assert expected == actual
