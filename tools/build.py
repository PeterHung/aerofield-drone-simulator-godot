#!/usr/bin/env python3
"""Import, verify, and export with Godot; optional portable export templates."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    "macos": (0, "macOS", "macos.zip", "macos/AEROFIELD-macOS.zip"),
    "web": (1, "Web", "web_nothreads_release.zip", "web/index.html"),
    "windows": (2, "Windows", "windows_release_x86_64.exe", "windows/AEROFIELD.exe"),
    "linux": (3, "Linux", "linux_release.x86_64", "linux/AEROFIELD.x86_64"),
}


def run(godot, *arguments):
    command = [godot, "--headless", "--path", str(ROOT), *arguments]
    print("Running:", " ".join(command), flush=True)
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=300)
    print(result.stdout, flush=True)
    if result.returncode or re.search(r"(?:SCRIPT ERROR:|ERROR:|FAIL:)", result.stdout):
        raise RuntimeError("Godot validation or export failed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--templates", type=Path, help="Directory containing extracted official templates")
    parser.add_argument("--targets", nargs="+", choices=TARGETS, default=["macos", "web"])
    args = parser.parse_args()
    godot = shutil.which(args.godot) or args.godot
    run(godot, "--editor", "--import", "--quit")
    run(godot, "--script", "tests/test_simulator.gd")
    run(godot, "--script", "tests/test_ui.gd")
    preset_file = ROOT / "export_presets.cfg"
    original = preset_file.read_text()
    presets = original
    if args.templates:
        template_dir = args.templates.resolve()
        for target in args.targets:
            index, _, filename, _ = TARGETS[target]
            template = template_dir / filename
            if not template.is_file():
                raise FileNotFoundError(template)
            # JSON quoting is appropriate here: this is Godot config, never shell input.
            start = presets.index(f"[preset.{index}.options]")
            end = presets.find("\n[preset.", start + 1)
            if end < 0:
                end = len(presets)
            section = presets[start:end]
            for mode in ("debug", "release"):
                section = section.replace(f'custom_template/{mode}=""',
                                          f"custom_template/{mode}={json.dumps(str(template))}")
            presets = presets[:start] + section + presets[end:]
    try:
        preset_file.write_text(presets)
        for target in args.targets:
            _, preset, _, relative = TARGETS[target]
            destination = ROOT / "builds" / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            run(godot, "--export-release", preset, str(destination))
            if target == "macos":
                with zipfile.ZipFile(destination, "a", zipfile.ZIP_DEFLATED) as archive:
                    for license_file in sorted((ROOT / "assets" / "licenses").glob("*.txt")):
                        archive.write(license_file, "Licenses/" + license_file.name)
                    archive.write(ROOT / "assets" / "fonts" / "OFL.txt", "Licenses/NotoSansTC-OFL.txt")
            else:
                package(target, destination.parent)
    finally:
        preset_file.write_text(original)
    packages = sorted((ROOT / "builds").glob("**/*.zip"))
    checksum_file = ROOT / "builds" / "SHA256SUMS.txt"
    checksum_file.write_text("".join(
        f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n" for p in packages))
    print("Packages:")
    for package_file in packages:
        print(package_file, package_file.stat().st_size)


def package(target, directory):
    for license_file in sorted((ROOT / "assets" / "licenses").glob("*.txt")):
        shutil.copyfile(license_file, directory / license_file.name)
    shutil.copyfile(ROOT / "assets" / "fonts" / "OFL.txt", directory / "NotoSansTC-OFL.txt")
    if target == "web":
        shutil.copyfile(ROOT / "tools" / "serve_web.py", directory / "serve_web.py")
        (directory / "README.txt").write_text(
            "AEROFIELD Godot Web\n執行 python3 serve_web.py --open，再開啟 http://127.0.0.1:8437/\n"
            "需要支援 WebGL 2 的桌面瀏覽器。請勿直接以 file:// 開啟 index.html。\n")
        launcher = directory / "啟動 AEROFIELD Web.command"
        launcher.write_text('#!/bin/zsh\ncd "$(dirname "$0")"\nexec python3 serve_web.py --open\n')
        launcher.chmod(0o755)
        (directory / "啟動 AEROFIELD Web.bat").write_text(
            '@echo off\r\ncd /d "%~dp0"\r\npython serve_web.py --open\r\npause\r\n')
    archive = directory / f"AEROFIELD-{target.capitalize()}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
        for path in sorted(directory.iterdir()):
            if path.is_file() and path != archive:
                zipped.write(path, path.name)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
