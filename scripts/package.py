#!/usr/bin/env python3
"""Build the installable release ZIP; deliberately exclude tests and git metadata."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import re

root = Path(__file__).resolve().parents[1]
toc = (root / "IslandQuestAlert.toc").read_text()
version = re.search(r"^## Version: (.+)$", toc, re.MULTILINE).group(1).strip()
files = ["IslandQuestAlert.toc", "TaleItems.lua", "IslandQuestAlert.lua", "README.md", "API_RESEARCH.md", "LICENSE", "CHANGELOG.md"]
destination = root / "dist" / f"IslandQuestAlert-{version}.zip"
destination.parent.mkdir(exist_ok=True)
with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(root / name, f"IslandQuestAlert/{name}")
with ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert all(name.startswith("IslandQuestAlert/") for name in archive.namelist())
    for name in toc.splitlines():
        if name.strip() and not name.startswith("#"):
            assert f"IslandQuestAlert/{name.strip()}" in archive.namelist()
print(destination)
