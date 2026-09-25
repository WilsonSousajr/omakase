"""Tests for the C.R.A.P. gate (#66). Pure functions, no database."""

import json
import os
from pathlib import Path

import pytest

from tools import crapcheck

TWO_BRANCHES = """\
def pick(flag):
    if flag:
        return "a"
    return "b"
"""


def _report(tmp_path: Path, files: dict[str, dict[str, list[int]]]) -> Path:
    """Write a coverage.py JSON report holding only what crapcheck reads."""
    path = tmp_path / "coverage.json"
    path.write_text(json.dumps({"files": files}))
    return path


class TestCrapFormula:
    def test_uncovered_function_scores_its_complexity_squared_plus_itself(self):
        # CC=3 at zero coverage is 3^2 * 1^3 + 3 = 12: omatty's threshold case.
        assert crapcheck.crap(3, 0.0) == 12.0

    def test_fully_covered_function_scores_its_complexity(self):
        assert crapcheck.crap(7, 1.0) == 7.0

    def test_partial_coverage_uses_the_cube_of_the_uncovered_share(self):
        assert crapcheck.crap(10, 0.5) == pytest.approx(100 * 0.125 + 10)


class TestFunctionCoverage:
    def test_share_of_executed_statements_inside_the_function(self):
        assert crapcheck.function_coverage(range(1, 5), {1, 2, 3}, {4}) == 0.75

    def test_lines_outside_the_function_do_not_count(self):
        assert crapcheck.function_coverage(range(10, 12), {1, 10, 11}, {2}) == 1.0

    def test_a_function_with_no_measured_statements_counts_as_uncovered(self):
        # Scoring it as covered would hide exactly the untested code the gate is for.
        assert crapcheck.function_coverage(range(1, 3), set(), set()) == 0.0


class TestScoreSource:
    def test_scores_each_function_with_its_complexity_and_coverage(self):
        scores = crapcheck.score_source("app/x.py", TWO_BRANCHES, executed={2, 3}, missing={4})
        assert [(s.name, s.complexity) for s in scores] == [("pick", 2)]
        assert scores[0].coverage == pytest.approx(2 / 3)

    def test_methods_are_scored_once_each(self):
        source = "class A:\n    def m(self):\n        return 1\n"
        scores = crapcheck.score_source("app/a.py", source, executed={1, 2, 3}, missing=set())
        assert [s.name for s in scores] == ["A.m"]


class TestGate:
    def test_a_score_equal_to_the_threshold_fails(self):
        # fail if crap >= threshold, as in omatty: CC=3 at 0% is caught exactly
        # at 12, not by a float's hair either side.
        score = crapcheck.Score("app/x.py", "f", 1, complexity=3, coverage=0.0)
        assert crapcheck.failures([score], threshold=12) == [score]

    def test_a_score_below_the_threshold_passes(self):
        score = crapcheck.Score("app/x.py", "f", 1, complexity=3, coverage=0.0)
        assert crapcheck.failures([score], threshold=12.1) == []


class TestMain:
    def test_passes_and_reports_the_margin(self, tmp_path, capsys):
        (tmp_path / "x.py").write_text(TWO_BRANCHES)
        report = _report(tmp_path, {"x.py": {"executed_lines": [1, 2, 3, 4], "missing_lines": []}})
        assert crapcheck.main(["--threshold", "18", "--report", str(report), "--root", str(tmp_path)]) == 0
        assert "margin" in capsys.readouterr().out

    def test_fails_when_a_function_reaches_the_threshold(self, tmp_path, capsys):
        (tmp_path / "x.py").write_text(TWO_BRANCHES)
        report = _report(tmp_path, {"x.py": {"executed_lines": [], "missing_lines": [1, 2, 3, 4]}})
        # CC=2 at 0%: 2^2 * 1 + 2 = 6
        assert crapcheck.main(["--threshold", "6", "--report", str(report), "--root", str(tmp_path)]) == 1
        assert "x.py:1 pick" in capsys.readouterr().out

    def test_refuses_a_report_older_than_the_source(self, tmp_path, capsys):
        # Coverage lines are positions: an old report against an edited file
        # scores whatever now sits at those lines, and looks just as trustworthy.
        source = tmp_path / "x.py"
        source.write_text(TWO_BRANCHES)
        report = _report(tmp_path, {"x.py": {"executed_lines": [1], "missing_lines": []}})
        os.utime(report, (1_000_000, 1_000_000))
        assert crapcheck.main(["--threshold", "18", "--report", str(report), "--root", str(tmp_path)]) == 2
        assert "older than" in capsys.readouterr().out

    def test_files_missing_from_the_report_are_out_of_scope(self, tmp_path):
        (tmp_path / "x.py").write_text(TWO_BRANCHES)
        (tmp_path / "admin.py").write_text("def unmeasured():\n    return 1\n")
        report = _report(tmp_path, {"x.py": {"executed_lines": [1, 2, 3, 4], "missing_lines": []}})
        scores = crapcheck.score_report(report, root=tmp_path)
        assert {s.path for s in scores} == {"x.py"}
