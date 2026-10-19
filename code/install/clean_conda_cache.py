#!/usr/bin/env python3

"""
CLEAN CONDA CACHE

Scan the conda package cache for corrupted extracted packages and
(optionally) remove them so conda will re-download and re-extract a
clean copy on the next install.

A package is considered corrupted when any file listed in its
info/paths.json does not match the recorded size_in_bytes or sha256.
This is the same integrity information conda uses to raise the
"SafetyError: ... appears to be corrupted" message during a transaction.

By default this runs in dry-run mode and only reports. Pass --delete to
actually remove the corrupted package directories.

Usage:
  clean_conda_cache.py [options]

Options:
  -h, --help        show this help and exit
  -d, --delete      delete corrupted package directories (default: report only)
  -c, --cache DIR   cache directory to scan (repeatable). Default: auto-detect
                    from `conda config --show pkgs_dirs`, falling back to
                    ~/conda-cache and <conda>/pkgs.
  -q, --quick       only check file sizes, skip the (slower) sha256 hashing
  -v, --verbose     report every corrupt file, not just the first per package
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def detect_cache_dirs():
    """Return the list of conda package cache directories."""
    dirs = []
    # Ask conda itself, if it is on PATH.
    conda = shutil.which("conda")
    if conda:
        try:
            out = subprocess.run(
                [conda, "config", "--show", "--json", "pkgs_dirs"],
                capture_output=True, text=True, timeout=30,
            )
            if out.returncode == 0:
                dirs.extend(json.loads(out.stdout).get("pkgs_dirs", []))
        except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
            pass
    # Common fallbacks.
    dirs.append(os.path.expanduser("~/conda-cache"))
    conda_prefix = os.environ.get("CONDA_PREFIX") or os.environ.get("CONDA_ROOT")
    if conda_prefix:
        dirs.append(os.path.join(conda_prefix, "pkgs"))

    # De-duplicate while keeping order; keep only existing directories.
    seen = set()
    result = []
    for d in dirs:
        d = os.path.abspath(os.path.expanduser(d))
        if d not in seen and os.path.isdir(d):
            seen.add(d)
            result.append(d)
    return result


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def check_package(pkg_dir, quick=False, verbose=False):
    """
    Check one extracted package directory against its info/paths.json.

    Returns a list of problem strings. An empty list means the package
    looks intact. A package with no readable paths.json is reported as a
    single problem so it can be inspected, but is NOT treated as corrupt
    for deletion purposes (see scan()).
    """
    problems = []
    paths_json = os.path.join(pkg_dir, "info", "paths.json")
    if not os.path.isfile(paths_json):
        return ["no info/paths.json (not a standard extracted package)"]

    try:
        with open(paths_json) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        return ["unreadable info/paths.json: %s" % e]

    for entry in data.get("paths", []):
        rel = entry.get("_path")
        if not rel:
            continue
        fp = os.path.join(pkg_dir, rel)

        # path_type defaults to hardlink when unspecified. Softlinks store
        # size_in_bytes / sha256 of their *target*, which need not exist in a
        # bare cache, so conda does not content-verify them either; we only
        # confirm the link itself is present. Directories carry no file to
        # check. So content verification applies to hardlinks only.
        path_type = entry.get("path_type", "hardlink")

        if path_type == "softlink":
            # lexists(): test the link itself, do not follow it.
            if not os.path.lexists(fp):
                problems.append("missing symlink: %s" % rel)
                if not verbose:
                    return problems
            continue

        if path_type == "directory":
            continue

        # Hardlink (or copied) regular file: verify it exists as a real file.
        if not os.path.isfile(fp):
            problems.append("missing: %s" % rel)
            if not verbose:
                return problems
            continue

        # Size check (cheap).
        expected_size = entry.get("size_in_bytes")
        if expected_size is not None:
            try:
                actual_size = os.path.getsize(fp)
            except OSError as e:
                problems.append("unreadable: %s (%s)" % (rel, e))
                if not verbose:
                    return problems
                continue
            if actual_size != expected_size:
                problems.append(
                    "size mismatch: %s (expected %d, actual %d)"
                    % (rel, expected_size, actual_size))
                if not verbose:
                    return problems
                continue

        if quick:
            continue

        # Hash check (authoritative).
        expected_sha = entry.get("sha256")
        if expected_sha:
            try:
                actual_sha = sha256_of(fp)
            except OSError as e:
                problems.append("unreadable: %s (%s)" % (rel, e))
                if not verbose:
                    return problems
                continue
            if actual_sha != expected_sha:
                problems.append("sha256 mismatch: %s" % rel)
                if not verbose:
                    return problems

    return problems


def iter_package_dirs(cache_dir):
    """Yield extracted package directories (those containing info/paths.json)."""
    try:
        entries = sorted(os.scandir(cache_dir), key=lambda e: e.name)
    except OSError as e:
        eprint("Cannot read cache dir %s: %s" % (cache_dir, e))
        return
    for e in entries:
        if e.is_dir() and os.path.isfile(
                os.path.join(e.path, "info", "paths.json")):
            yield e.path


def human_size(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return "%.1f %s" % (n, unit)
        n /= 1024


def dir_size(path):
    total = 0
    for root, _dirs, files in os.walk(path):
        for name in files:
            fp = os.path.join(root, name)
            try:
                total += os.path.getsize(fp)
            except OSError:
                pass
    return total


def scan(cache_dirs, delete=False, quick=False, verbose=False):
    corrupt = []  # list of (pkg_dir, problems)
    total_checked = 0

    for cache_dir in cache_dirs:
        print("Scanning cache: %s" % cache_dir)
        for pkg_dir in iter_package_dirs(cache_dir):
            total_checked += 1
            problems = check_package(pkg_dir, quick=quick, verbose=verbose)
            if problems:
                corrupt.append((pkg_dir, problems))
                print("  [CORRUPT] %s" % os.path.basename(pkg_dir))
                for p in problems:
                    print("            - %s" % p)

    print()
    print("Checked %d package(s); %d corrupt." % (total_checked, len(corrupt)))

    if not corrupt:
        return 0

    reclaimable = sum(dir_size(d) for d, _ in corrupt)
    print("Reclaimable space: %s" % human_size(reclaimable))

    if not delete:
        print()
        print("Dry run: nothing deleted. Re-run with --delete to remove the")
        print("corrupt package directories above. Conda will re-download and")
        print("re-extract clean copies on the next install.")
        return 1

    print()
    removed = 0
    for pkg_dir, _ in corrupt:
        try:
            shutil.rmtree(pkg_dir)
            print("  Removed: %s" % pkg_dir)
            removed += 1
        except OSError as e:
            eprint("  FAILED to remove %s: %s" % (pkg_dir, e))
    print()
    print("Removed %d of %d corrupt package(s)." % (removed, len(corrupt)))
    return 0 if removed == len(corrupt) else 2


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Remove corrupted packages from the conda cache.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__)
    parser.add_argument("-d", "--delete", action="store_true",
                        help="delete corrupt package dirs (default: report only)")
    parser.add_argument("-c", "--cache", action="append", metavar="DIR",
                        help="cache dir to scan (repeatable; default: auto)")
    parser.add_argument("-q", "--quick", action="store_true",
                        help="size check only, skip sha256 hashing")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="report every corrupt file per package")
    args = parser.parse_args(argv)

    cache_dirs = args.cache if args.cache else detect_cache_dirs()
    cache_dirs = [os.path.abspath(os.path.expanduser(d)) for d in cache_dirs]
    cache_dirs = [d for d in cache_dirs if os.path.isdir(d)]

    if not cache_dirs:
        eprint("Error: no conda cache directory found.")
        eprint("Specify one with --cache DIR.")
        return 1

    return scan(cache_dirs, delete=args.delete,
                quick=args.quick, verbose=args.verbose)


if __name__ == "__main__":
    sys.exit(main())
