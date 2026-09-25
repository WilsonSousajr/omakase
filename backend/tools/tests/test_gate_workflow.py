"""Tests that guard the gate itself (#66), after omatty's scripts/*_test.go.

A gate that stops checking does not fail; it goes on passing. A step dropped
in a merge conflict, a version that floats, or a coverage source that lists
half the apps are all invisible from a green run, which is how this repo's
coverage gate measured three of six apps for months. These tests fail instead.

The workflow and the pre-commit config live outside backend/. In CI they
are found relative to this file. In the dev container, docker-compose mounts
them read-only under REPO_ROOT.
"""

import os
import re
import tomllib
from pathlib import Path

import yaml

BACKEND = Path(__file__).resolve().parents[2]
REPO = Path(os.environ.get("REPO_ROOT", BACKEND.parent))
WORKFLOW = REPO / ".github" / "workflows" / "ci.yml"
GATE_SCRIPT = BACKEND / "gate.sh"
SETUP_COMMANDS = ("pip install",)


def _gate_steps() -> list[str]:
    """The gate job's commands, in order, without the environment setup."""
    steps = yaml.safe_load(WORKFLOW.read_text())["jobs"]["gate"]["steps"]
    runs = [step["run"].strip() for step in steps if "run" in step]
    return [run for run in runs if not run.startswith(SETUP_COMMANDS)]


def _script_steps() -> list[str]:
    lines = [line.strip() for line in GATE_SCRIPT.read_text().splitlines()]
    return [line for line in lines if line and not line.startswith(("#", "set ", "cd "))]


def _index_of(steps: list[str], prefix: str) -> int:
    matches = [i for i, step in enumerate(steps) if step.startswith(prefix)]
    assert matches, f"the gate has no step starting {prefix!r}; steps: {steps}"
    return matches[0]


class TestTheLocalGateIsTheCIGate:
    def test_gate_sh_runs_exactly_the_ci_steps_in_the_same_order(self):
        # One gate, two entry points. If they drift, "it passed locally"
        # stops meaning anything.
        assert _script_steps() == _gate_steps()


class TestStepOrder:
    def test_cheap_static_checks_run_before_the_test_suite(self):
        # Cheapest first: an architectural or schema violation should surface
        # in seconds, not after the suite.
        steps = _gate_steps()
        suite = _index_of(steps, "pytest")
        for cheap in ("ruff check", "ruff format", "lint-imports", "complexipy", "python manage.py check"):
            assert _index_of(steps, cheap) < suite, f"{cheap!r} runs after the test suite"

    def test_crap_gate_runs_straight_after_the_coverage_step(self):
        # It reads the coverage.json that step writes, and refuses a stale one.
        steps = _gate_steps()
        assert _index_of(steps, "python -m tools.crapcheck") == _index_of(steps, "pytest") + 1

    def test_the_hygiene_steps_are_present(self):
        steps = _gate_steps()
        for step in ("python manage.py makemigrations --check", "pip-audit -r requirements.txt"):
            _index_of(steps, step)


class TestThresholds:
    def test_coverage_gate_is_ninety_percent(self):
        assert "--cov-fail-under=90" in _gate_steps()[_index_of(_gate_steps(), "pytest")]

    def test_crap_threshold_in_ci_matches_the_tools_default(self):
        from tools import crapcheck

        step = _gate_steps()[_index_of(_gate_steps(), "python -m tools.crapcheck")]
        ci_threshold = float(re.search(r"--threshold (\S+)", step).group(1))
        assert ci_threshold == crapcheck._parse([]).threshold

    def test_coverage_measures_every_app(self):
        # The regression that started #66: source listed 3 of the 6 apps.
        config = tomllib.loads((BACKEND / "pyproject.toml").read_text())
        measured = set(config["tool"]["coverage"]["run"]["source"])
        apps = {path.parent.name for path in BACKEND.glob("*/apps.py")}
        assert apps <= measured, f"coverage does not measure {sorted(apps - measured)}"


class TestPins:
    def test_ci_and_the_image_run_the_same_exact_python(self):
        ci = yaml.safe_load(WORKFLOW.read_text())["env"]["PYTHON_VERSION"]
        image = re.search(r"^FROM python:(\S+)-slim", (BACKEND / "Dockerfile").read_text(), re.M).group(1)
        assert re.fullmatch(r"\d+\.\d+\.\d+", ci), f"CI pins Python {ci!r}, want an exact x.y.z"
        assert ci == image, f"CI runs Python {ci} but the image runs {image}"

    def test_every_requirement_is_pinned_exactly(self):
        for name in ("requirements.txt", "requirements-dev.txt"):
            for line in (BACKEND / name).read_text().splitlines():
                if line.strip() and not line.startswith("#"):
                    assert "==" in line, f"{name}: {line!r} is not pinned with =="

    def test_pre_commit_runs_the_same_ruff_as_the_gate(self):
        hooks = yaml.safe_load((REPO / ".pre-commit-config.yaml").read_text())["repos"]
        hook_rev = next(repo["rev"] for repo in hooks if "ruff" in repo["repo"]).lstrip("v")
        pinned = re.search(r"^ruff==(\S+)", (BACKEND / "requirements-dev.txt").read_text(), re.M).group(1)
        assert hook_rev == pinned, f"pre-commit runs ruff {hook_rev}, the gate runs {pinned}"


APPLE_GATE_SCRIPT = REPO / "apps" / "apple" / "gate.sh"
APPLE_SETUP = ("sudo xcode-select", "./install-tools.sh")


def _apple_ci_steps() -> list[str]:
    steps = yaml.safe_load(WORKFLOW.read_text())["jobs"]["apple-gate"]["steps"]
    runs = [step["run"].strip() for step in steps if "run" in step]
    return [run for run in runs if not run.startswith(APPLE_SETUP)]


def _apple_script_steps() -> list[str]:
    lines = [line.strip() for line in APPLE_GATE_SCRIPT.read_text().splitlines()]
    return [line for line in lines if line and not line.startswith(("#", "set ", "cd "))]


class TestTheAppleGateIsTheCIAppleGate:
    def test_gate_sh_runs_exactly_the_ci_steps_in_the_same_order(self):
        assert _apple_script_steps() == _apple_ci_steps()

    def test_cheap_checks_run_before_the_tests(self):
        steps = _apple_ci_steps()
        tests = _index_of(steps, "./test-packages.sh")
        for cheap in ("swift format lint", "swiftlint lint", "./check-layers.sh"):
            assert _index_of(steps, cheap) < tests

    def test_tools_are_pinned_exactly(self):
        pins = dict(
            line.split("=", 1)
            for line in (REPO / "apps/apple/tools.env").read_text().splitlines()
            if line and not line.startswith("#")
        )
        for tool in ("XCODE_VERSION", "SWIFTLINT_VERSION", "XCODEGEN_VERSION"):
            assert re.fullmatch(r"\d+(\.\d+)+", pins[tool]), f"{tool}={pins.get(tool)!r} is not an exact version"
