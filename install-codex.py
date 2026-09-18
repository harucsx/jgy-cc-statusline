#!/usr/bin/env python3
"""Install the jgy status-line preset using Codex CLI's native footer."""

import argparse
import copy
import json
import os
from pathlib import Path
import stat
import sys
import tempfile

if sys.version_info < (3, 11):
    sys.exit("Python 3.11+ is required (uses the built-in tomllib module).")

import tomllib


PRESET = {
    "status_line": [
        "model-with-reasoning",
        "git-branch",
        "branch-changes",
        "context-used",
        "context-window-size",
        "five-hour-limit",
        "weekly-limit",
    ],
    "status_line_use_colors": True,
}


def statements(text):
    """Locate complete TOML statements, including multiline values and comments.

    Parsing each complete statement keeps strings containing '[tui]' or array
    brackets from being mistaken for section boundaries. The full document is
    validated separately before and after editing.
    """
    start = end = 0
    pending = ""
    for line in text.splitlines(keepends=True):
        pending += line
        end += len(line)
        try:
            value = tomllib.loads(pending)
        except tomllib.TOMLDecodeError:
            continue
        yield start, end, pending, value
        start = end
        pending = ""
    if pending:
        raise ValueError("Cannot safely locate TOML settings; use /statusline instead.")


def configure(text):
    """Replace only the two preset keys; preserve all other TOML text and values."""
    before = tomllib.loads(text)
    tui = before.get("tui", {})
    if not isinstance(tui, dict):
        raise ValueError("The tui setting must be a TOML table.")
    if all(tui.get(key) == value for key, value in PRESET.items()):
        return text

    newline = "\r\n" if "\r\n" in text else "\n"
    in_tui = False
    header_end = None
    found = set()
    edits = []
    for start, end, source, parsed in statements(text):
        if source.lstrip().startswith("["):
            in_tui = parsed == {"tui": {}}
            if in_tui:
                header_end = end
        elif in_tui:
            for key, value in PRESET.items():
                if key in parsed:
                    found.add(key)
                    edits.append((start, end, f"{key} = {json.dumps(value)}{newline}"))

    missing = "".join(
        f"{key} = {json.dumps(value)}{newline}"
        for key, value in PRESET.items() if key not in found
    )
    if missing:
        position = header_end if header_end is not None else len(text)
        prefix = "" if position == 0 or text[:position].endswith("\n") else newline
        if header_end is None:
            prefix += (newline if position else "") + "[tui]" + newline
        edits.append((position, position, prefix + missing))

    updated = text
    for start, end, replacement in sorted(edits, reverse=True):
        updated = updated[:start] + replacement + updated[end:]

    expected = copy.deepcopy(before)
    expected.setdefault("tui", {}).update(PRESET)
    try:
        after = tomllib.loads(updated)
    except tomllib.TOMLDecodeError:
        raise ValueError(
            "Cannot safely edit this TOML layout (for example, inline/dotted tui keys). "
            "Use /statusline or move those keys into a [tui] section. No config changed."
        ) from None
    if after != expected:
        raise ValueError("Configuration preservation check failed; no config changed.")
    return updated


def read_config(path):
    try:
        return path.read_bytes()
    except FileNotFoundError:
        return None


def save_config(path, original, updated):
    """Back up original bytes, then atomically replace the config in its directory."""
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if original is not None else 0o600
    if read_config(path) != original:
        raise ValueError("Configuration changed during installation; retry.")

    backup = None
    if original is not None:
        fd, name = tempfile.mkstemp(prefix=path.name + ".bak.", dir=path.parent)
        backup = Path(name)
        with os.fdopen(fd, "wb") as handle:
            handle.write(original)
            handle.flush()
            os.fsync(handle.fileno())

    fd, name = tempfile.mkstemp(prefix=".codex-statusline-", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, "wb") as handle:
            os.fchmod(handle.fileno(), mode)
            handle.write(updated)
            handle.flush()
            os.fsync(handle.fileno())
        if read_config(path) != original:
            raise ValueError("Configuration changed during installation; retry.")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)
    if path.read_bytes() != updated:
        raise ValueError(f"Config changed after saving; inspect {path}. Backup: {backup}")
    return backup


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--apply", action="store_true", help="apply the preset (default)")
    action.add_argument("--dry-run", action="store_true", help="validate and preview without writing")
    action.add_argument("--show", action="store_true", help="show only installed status-line settings")
    parser.add_argument("--config", type=Path, help="config.toml path; defaults to $CODEX_HOME/config.toml or ~/.codex/config.toml")
    args = parser.parse_args(argv)
    home = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").expanduser()
    path = (args.config or home / "config.toml").expanduser()
    # Update a symlink's target, preserving the user's link. A dangling link is an error.
    path = path.resolve(strict=True) if path.is_symlink() else path.resolve()
    original = read_config(path)
    text = original.decode("utf-8") if original is not None else ""
    before = tomllib.loads(text)

    if args.show:
        tui = before.get("tui", {})
        if not isinstance(tui, dict):
            raise ValueError("The tui setting must be a TOML table.")
        print(json.dumps({"config": str(path), "installed": {
            key: tui[key] for key in PRESET if key in tui
        }}, indent=2))
        return 0

    updated = configure(text).encode("utf-8")
    if args.dry_run:
        print(json.dumps({"config": str(path), "would_change": updated != (original or b""),
                          "preset": PRESET}, indent=2))
        print("Dry run: no files written.")
        return 0
    if updated == original:
        print(f"Already configured: {path}")
        return 0

    backup = save_config(path, original, updated)
    print(f"Configured: {path}")
    if backup:
        print(f"Backup: {backup}")
    print("Start a new Codex CLI session. Customize items with /statusline.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, UnicodeError, ValueError) as error:
        # TOML diagnostics may contain user config values; never print config content.
        message = "Invalid TOML; no config changed." if isinstance(error, tomllib.TOMLDecodeError) else str(error)
        print(f"Error: {message}", file=sys.stderr)
        sys.exit(1)
