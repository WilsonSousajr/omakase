"""One SwiftPM scratch dir per checkout, and pruning of every other (#297).

Agents running in parallel worktrees each invented a private --scratch-path
to dodge SwiftPM's lock on a shared one, and nothing deleted them: ~100 dirs
of 100-500 MB filled ~/Library/Caches/omakase. A dir per checkout removes the
reason to invent one, and pruning the dirs of removed worktrees bounds the
cache at one build per live worktree. Prints the checkout's scratch dir:

    python3 tools/swiftpm_scratch.py --cache-root ~/Library/Caches/omakase/swiftpm --checkout "$PWD"
"""

import argparse
import hashlib
import shutil
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path


def scratch_dir(cache_root: Path, checkout: Path) -> Path:
    """The checkout's folder name plus a hash of its path, so two `omakase` clones don't collide.

    scratch_dir(Path("/c"), Path("/wt/feat-x")) -> Path("/c/feat-x-<8 hex>")
    """
    digest = hashlib.sha256(str(checkout).encode()).hexdigest()[:8]
    return cache_root / f"{checkout.name}-{digest}"


def worktree_paths(porcelain: str) -> list[Path]:
    """The checkout paths in `git worktree list --porcelain` output."""
    prefix = "worktree "
    return [Path(line.removeprefix(prefix)) for line in porcelain.splitlines() if line.startswith(prefix)]


def prune_stale(cache_root: Path, worktrees: list[Path]) -> list[Path]:
    """Deletes every entry of cache_root that is not a live worktree's scratch dir; returns them.

    A worktree whose folder is gone is not live. With none live, git failed or
    lied, so nothing is deleted.
    """
    live = {scratch_dir(cache_root, tree) for tree in worktrees if tree.is_dir()}
    if not live or not cache_root.is_dir():
        return []
    stale = sorted(entry for entry in cache_root.iterdir() if entry not in live)
    for entry in stale:
        if entry.is_dir() and not entry.is_symlink():
            shutil.rmtree(entry)
        else:
            entry.unlink()
    return stale


def git_worktrees(checkout: Path) -> list[Path]:
    """Every worktree of the checkout's repository, or [] when git fails."""
    listing = subprocess.run(
        ["git", "-C", str(checkout), "worktree", "list", "--porcelain"], capture_output=True, text=True, check=False
    )
    return worktree_paths(listing.stdout) if listing.returncode == 0 else []


def main(argv: list[str] | None = None, list_worktrees: Callable[[Path], list[Path]] = git_worktrees) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache-root", type=Path, required=True)
    parser.add_argument("--checkout", type=Path, required=True)
    args = parser.parse_args(argv)
    for entry in prune_stale(args.cache_root, list_worktrees(args.checkout)):
        print(f"pruned stale SwiftPM scratch {entry}", file=sys.stderr)
    print(scratch_dir(args.cache_root, args.checkout))
    return 0


if __name__ == "__main__":
    sys.exit(main())
