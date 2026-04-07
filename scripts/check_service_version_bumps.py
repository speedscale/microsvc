#!/usr/bin/env python3

import pathlib
import subprocess
import sys
import xml.etree.ElementTree as ET


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


def discover_services():
    services = []
    if not BACKEND_ROOT.exists():
        return services

    for item in sorted(BACKEND_ROOT.iterdir()):
        pom = item / "pom.xml"
        if item.is_dir() and pom.exists():
            services.append(item.name)
    return services


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


def read_project_version(xml_text):
    root = ET.fromstring(xml_text)
    version_elem = root.find("./{*}version")
    if version_elem is None or version_elem.text is None:
        raise ValueError("Missing project <version> in pom.xml")
    return version_elem.text.strip()


def read_base_file(base_sha, file_path):
    git_path = file_path.as_posix()
    return run_git(["show", f"{base_sha}:{git_path}"])


def main():
    if len(sys.argv) != 3:
        print(
            "Usage: check_service_version_bumps.py <base-sha> <head-sha>",
            file=sys.stderr,
        )
        return 2

    base_sha = sys.argv[1]
    head_sha = sys.argv[2]

    services = set(discover_services())
    if not services:
        print("No backend services found; skipping version bump check.")
        return 0

    changed_files = [
        line.strip()
        for line in run_git(
            ["diff", "--name-only", "--diff-filter=ACDMRT", base_sha, head_sha]
        ).splitlines()
        if line.strip()
    ]

    changed_services = set()
    services_requiring_bump = set()

    for changed_file in changed_files:
        parts = pathlib.PurePosixPath(changed_file).parts
        if len(parts) < 3 or parts[0] != "backend":
            continue

        service = parts[1]
        if service not in services:
            continue

        changed_services.add(service)
        service_relative_path = "/".join(parts[2:])
        if not is_doc_or_infra_only(service_relative_path):
            services_requiring_bump.add(service)

    if not services_requiring_bump:
        if changed_services:
            service_list = ", ".join(sorted(changed_services))
            print(
                "Only docs/infra changes detected under services "
                f"({service_list}); version bump not required."
            )
        else:
            print("No service code changes detected; version bump not required.")
        return 0

    failures = []
    for service in sorted(services_requiring_bump):
        pom_path = pathlib.Path("backend") / service / "pom.xml"
        head_pom = REPO_ROOT / pom_path
        if not head_pom.exists():
            failures.append(f"- {service}: missing {pom_path.as_posix()} in PR branch")
            continue

        try:
            base_version = read_project_version(read_base_file(base_sha, pom_path))
            head_version = read_project_version(head_pom.read_text(encoding="utf-8"))
        except subprocess.CalledProcessError:
            failures.append(
                f"- {service}: unable to read {pom_path.as_posix()} from base commit {base_sha}"
            )
            continue
        except (ET.ParseError, ValueError) as exc:
            failures.append(
                f"- {service}: invalid pom.xml format in {pom_path.as_posix()} ({exc})"
            )
            continue

        if base_version == head_version:
            failures.append(
                f"- {service}: project <version> unchanged ({head_version}) in {pom_path.as_posix()}"
            )

    if failures:
        print("Version bump check failed for service code changes:\n")
        print("\n".join(failures))
        print(
            "\nAction: bump the affected service version(s) in backend/<service>/pom.xml "
            "before merging."
        )
        return 1

    services_ok = ", ".join(sorted(services_requiring_bump))
    print(f"Version bump check passed for service code changes in: {services_ok}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
