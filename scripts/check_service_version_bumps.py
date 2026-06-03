#!/usr/bin/env python3

import pathlib
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
BACKEND_ROOT = REPO_ROOT / "backend"
DOC_EXTENSIONS = {".md", ".adoc", ".rst", ".txt"}


def run_git(args):
    result = subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def is_doc_or_infra_only(relative_path):
    lower = relative_path.lower()
    path_obj = pathlib.PurePosixPath(lower)

    if path_obj.suffix in DOC_EXTENSIONS:
        return True

    if "docs" in path_obj.parts:
        return True

    if path_obj.name in {"readme", "readme.md", "changelog.md"}:
        return True

    return False


def merge_base(commit_a, commit_b):
    return run_git(["merge-base", commit_a, commit_b]).strip()


def read_file_at(sha, file_path):
    return run_git(["show", f"{sha}:{file_path}"]).strip()


def main():
    if len(sys.argv) != 3:
        print(
            "Usage: check_service_version_bumps.py <base-sha> <head-sha>",
            file=sys.stderr,
        )
        return 2

    base_sha = sys.argv[1]
    head_sha = sys.argv[2]
    comparison_base_sha = merge_base(base_sha, head_sha)

    changed_files = [
        line.strip()
        for line in run_git(
            [
                "diff",
                "--name-only",
                "--diff-filter=ACDMRT",
                comparison_base_sha,
                head_sha,
            ]
        ).splitlines()
        if line.strip()
    ]

    # Check if any backend service code (non-doc) was changed
    has_service_code_change = False
    changed_service_dirs = set()
    for changed_file in changed_files:
        parts = pathlib.PurePosixPath(changed_file).parts
        if len(parts) < 3 or parts[0] != "backend":
            continue
        service_relative_path = "/".join(parts[2:])
        if not is_doc_or_infra_only(service_relative_path):
            has_service_code_change = True
            changed_service_dirs.add(parts[1])

    if not has_service_code_change:
        print("No backend service code changes detected; VERSION bump not required.")
        return 0

    # Check if VERSION file was bumped
    try:
        base_version = read_file_at(comparison_base_sha, "VERSION")
    except subprocess.CalledProcessError:
        base_version = "0.0.0"

    version_file = REPO_ROOT / "VERSION"
    head_version = version_file.read_text(encoding="utf-8").strip() if version_file.exists() else "0.0.0"

    if base_version == head_version:
        services_list = ", ".join(sorted(changed_service_dirs))
        print(f"VERSION bump required: backend service code changed ({services_list})")
        print(f"  VERSION is unchanged at {head_version}")
        print(
            "\nAction: bump VERSION before merging. pom.xml versions are"
            " synced automatically by CI post-merge."
        )
        return 1

    print(
        f"VERSION bumped ({base_version} -> {head_version});"
        f" pom.xml versions will be synced by CI post-merge."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
