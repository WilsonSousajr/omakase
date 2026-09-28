"""Tests for apps/apple/tools/swiftpm_scratch.py (#297)."""

import importlib.util
import os
from pathlib import Path

REPO = Path(os.environ.get("REPO_ROOT", Path(__file__).resolve().parents[3]))
_spec = importlib.util.spec_from_file_location("swiftpm_scratch", REPO / "apps/apple/tools/swiftpm_scratch.py")
swiftpm_scratch = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(swiftpm_scratch)


class FakeWorktreeList:
    """Stands in for `git worktree list`, which the test image cannot run."""

    def __init__(self, worktrees: list[Path]):
        self.worktrees = worktrees
        self.asked_from: list[Path] = []

    def __call__(self, checkout: Path) -> list[Path]:
        self.asked_from.append(checkout)
        return self.worktrees


def test_scratch_dir_is_the_checkout_name_plus_a_path_hash(tmp_path):
    name = swiftpm_scratch.scratch_dir(tmp_path, Path("/wt/omakase/feat-x")).name
    assert name.startswith("feat-x-")
    assert len(name) == len("feat-x-") + 8


def test_checkouts_with_the_same_name_get_different_scratch_dirs(tmp_path):
    first = swiftpm_scratch.scratch_dir(tmp_path, Path("/a/omakase"))
    second = swiftpm_scratch.scratch_dir(tmp_path, Path("/b/omakase"))
    assert first != second


def test_reads_the_paths_from_worktree_list_porcelain():
    porcelain = "worktree /a\nHEAD 1f\nbranch refs/heads/develop\n\nworktree /b c\nHEAD 2e\ndetached\nprunable gone\n\n"
    assert swiftpm_scratch.worktree_paths(porcelain) == [Path("/a"), Path("/b c")]


def test_removed_worktrees_scratch_dirs_are_pruned_issue297(tmp_path):
    root = tmp_path / "cache"
    live = tmp_path / "live"
    live.mkdir()
    kept = swiftpm_scratch.scratch_dir(root, live)
    kept.mkdir(parents=True)
    removed = swiftpm_scratch.scratch_dir(root, tmp_path / "removed")
    removed.mkdir()
    legacy = root / "store-224"
    legacy.mkdir()
    assert swiftpm_scratch.prune_stale(root, [live]) == sorted([removed, legacy])
    assert kept.is_dir()
    assert not removed.exists()
    assert not legacy.exists()


def test_a_worktree_git_still_lists_but_whose_folder_is_gone_is_pruned(tmp_path):
    root = tmp_path / "cache"
    live = tmp_path / "live"
    live.mkdir()
    swiftpm_scratch.scratch_dir(root, live).mkdir(parents=True)
    orphan = swiftpm_scratch.scratch_dir(root, tmp_path / "deleted-by-hand")
    orphan.mkdir()
    swiftpm_scratch.prune_stale(root, [live, tmp_path / "deleted-by-hand"])
    assert not orphan.exists()


def test_stray_files_in_the_cache_root_are_pruned(tmp_path):
    live = tmp_path / "live"
    live.mkdir()
    stray = tmp_path / "cache" / "notes.txt"
    stray.parent.mkdir()
    stray.write_text("x")
    swiftpm_scratch.prune_stale(stray.parent, [live])
    assert not stray.exists()


def test_nothing_is_pruned_when_no_worktree_is_live(tmp_path):
    entry = tmp_path / "cache" / "feat-x-00000000"
    entry.mkdir(parents=True)
    assert swiftpm_scratch.prune_stale(tmp_path / "cache", [tmp_path / "gone"]) == []
    assert entry.is_dir()


def test_a_missing_cache_root_prunes_nothing(tmp_path):
    assert swiftpm_scratch.prune_stale(tmp_path / "absent", [tmp_path]) == []


def test_main_prints_the_scratch_dir_and_prunes_the_rest(tmp_path, capsys):
    root = tmp_path / "cache"
    stale = root / "swiftpm-s2"
    stale.mkdir(parents=True)
    worktrees = FakeWorktreeList([tmp_path])
    argv = ["--cache-root", str(root), "--checkout", str(tmp_path)]
    assert swiftpm_scratch.main(argv, list_worktrees=worktrees) == 0
    out, err = capsys.readouterr()
    assert out == f"{swiftpm_scratch.scratch_dir(root, tmp_path)}\n"
    assert str(stale) in err
    assert not stale.exists()
    assert worktrees.asked_from == [tmp_path]
