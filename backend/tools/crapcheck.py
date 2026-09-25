"""The C.R.A.P. gate: per-function complexity x coverage (#66).

    CRAP(f) = CC(f)^2 * (1 - coverage(f))^3 + CC(f)

ruff bounds how branchy a function may be, and the coverage gate bounds how
much of the backend the suite reaches. Neither notices that the branchiest
function is the one no test reaches; this does. Ported from omatty's
tools/crapcheck, with the same two rules:

- A score fails when it is **>= the threshold**, so CC=3 at zero coverage is
  caught at exactly 12 rather than by a float's hair either side.
- A report older than the source is refused, not scored. Coverage lines are
  positions; an old report against an edited file scores whatever now sits
  at those lines, and the wrong answer looks exactly as trustworthy.

Usage (after pytest wrote coverage.json)::

    python -m tools.crapcheck --threshold 18 --report coverage.json
"""

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from radon.complexity import cc_visit
from radon.visitors import Function

EXIT_OK, EXIT_OVER, EXIT_STALE = 0, 1, 2
TOP_ROWS = 5


@dataclass(frozen=True)
class Score:
    """One function's complexity and coverage, and the C.R.A.P. they make."""

    path: str
    name: str
    line: int
    complexity: int
    coverage: float

    @property
    def crap(self) -> float:
        return crap(self.complexity, self.coverage)


def crap(complexity: int, coverage: float) -> float:
    """C.R.A.P. score: ``crap(3, 0.0) == 12.0``."""
    return complexity**2 * (1 - coverage) ** 3 + complexity


def function_coverage(lines: range, executed: set[int], missing: set[int]) -> float:
    """Share of the measured statements in ``lines`` that ran.

    A function with no measured statement counts as uncovered: calling it
    covered would hide exactly the code this gate exists to find.
    """
    ran = len(executed.intersection(lines))
    total = ran + len(missing.intersection(lines))
    return ran / total if total else 0.0


def _functions(source: str) -> list[Function]:
    # radon flattens methods into the block list alongside their classes;
    # keeping only Function blocks scores each method exactly once.
    return [block for block in cc_visit(source) if isinstance(block, Function)]


def score_source(path: str, source: str, executed: set[int], missing: set[int]) -> list[Score]:
    """Score every function and method in one file's source."""
    return [
        Score(
            path=path,
            name=block.fullname,
            line=block.lineno,
            complexity=block.complexity,
            coverage=function_coverage(range(block.lineno, block.endline + 1), executed, missing),
        )
        for block in _functions(source)
    ]


def _read_report(report: Path) -> dict[str, dict[str, list[int]]]:
    return json.loads(report.read_text())["files"]


def score_report(report: Path, root: Path) -> list[Score]:
    """Score every file the coverage report measured; the report sets the scope."""
    scores: list[Score] = []
    for path, measured in _read_report(report).items():
        source = (root / path).read_text()
        scores += score_source(path, source, set(measured["executed_lines"]), set(measured["missing_lines"]))
    return scores


def stale_sources(report: Path, root: Path) -> list[str]:
    """Measured files edited after the report was written."""
    written = report.stat().st_mtime
    return [path for path in _read_report(report) if (root / path).stat().st_mtime > written]


def failures(scores: list[Score], threshold: float) -> list[Score]:
    """Scores at or over the threshold."""
    return [score for score in scores if score.crap >= threshold]


def _row(score: Score) -> str:
    return (
        f"  crap {score.crap:5.1f}  cc {score.complexity:2d}  cov {score.coverage:6.1%}"
        f"  {score.path}:{score.line} {score.name}"
    )


def _print_summary(scores: list[Score], threshold: float) -> None:
    ranked = sorted(scores, key=lambda score: score.crap, reverse=True)
    for score in ranked[:TOP_ROWS]:
        print(_row(score))
    worst = ranked[0].crap if ranked else 0.0
    # Printed on every run, clean or not: a gate that only ever says "clean"
    # gives no warning before it breaks.
    print(f"worst {worst:.1f} against a threshold of {threshold:g}: margin {threshold - worst:.1f}")


def _parse(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--threshold", type=float, default=18)
    parser.add_argument("--report", type=Path, default=Path("coverage.json"))
    parser.add_argument("--root", type=Path, default=Path())
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the gate; returns the process exit status."""
    args = _parse(argv)
    stale = stale_sources(args.report, args.root)
    if stale:
        print(f"{args.report} is older than {len(stale)} source file(s), e.g. {stale[0]}; rerun the tests first")
        return EXIT_STALE
    scores = score_report(args.report, args.root)
    _print_summary(scores, args.threshold)
    over = failures(scores, args.threshold)
    for score in over:
        print(f"FAIL {_row(score).strip()}")
    return EXIT_OVER if over else EXIT_OK


if __name__ == "__main__":
    raise SystemExit(main())
