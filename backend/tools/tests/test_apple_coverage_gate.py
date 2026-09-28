"""Tests for apps/apple/tools/coverage_gate.py (#85)."""

import importlib.util
import json
import os
from pathlib import Path

REPO = Path(os.environ.get("REPO_ROOT", Path(__file__).resolve().parents[3]))
_spec = importlib.util.spec_from_file_location("coverage_gate", REPO / "apps/apple/tools/coverage_gate.py")
coverage_gate = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(coverage_gate)


def _codecov(files: list[tuple[str, int, int]]) -> dict:
    return {
        "data": [
            {
                "files": [
                    {"filename": name, "summary": {"lines": {"covered": covered, "count": count}}}
                    for name, covered, count in files
                ]
            }
        ]
    }


def test_counts_only_the_packages_sources():
    report = _codecov(
        [
            ("/x/OmakaseStore/Sources/OmakaseStore/Outbox.swift", 9, 10),
            ("/x/OmakaseStore/Tests/OmakaseStoreTests/OutboxTests.swift", 0, 50),
            ("/x/OmakaseAPI/Sources/OmakaseAPI/APIDay.swift", 0, 30),
        ]
    )
    assert coverage_gate.covered_lines(report, "OmakaseStore", []) == (9, 10)


def test_excludes_view_files():
    report = _codecov(
        [
            ("/x/OmakaseFeatures/Sources/OmakaseFeatures/TodayView.swift", 0, 40),
            ("/x/OmakaseFeatures/Sources/OmakaseFeatures/TodayModel.swift", 10, 10),
        ]
    )
    assert coverage_gate.covered_lines(report, "OmakaseFeatures", ["View.swift"]) == (10, 10)


def test_fails_below_and_passes_at_the_threshold(tmp_path):
    path = tmp_path / "codecov.json"
    path.write_text(json.dumps(_codecov([("/x/P/Sources/P/a.swift", 9, 10)])))
    assert coverage_gate.main(["--codecov", str(path), "--package", "P", "--threshold", "90"]) == 0
    assert coverage_gate.main(["--codecov", str(path), "--package", "P", "--threshold", "90.1"]) == 1
