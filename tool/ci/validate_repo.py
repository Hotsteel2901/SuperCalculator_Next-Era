#!/usr/bin/env python3
"""Fast repository-hygiene checks for the Codeberg (Forgejo Actions) pipeline.

This intentionally avoids the Flutter toolchain so it fits Codeberg's hosted
``codeberg-tiny`` runner (1 CPU / 2 GB / 2 min). It validates that the checked-in
manifests, localizations, license and icon family are internally consistent.
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
failures: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(message)


def png_size(path: Path) -> tuple[int, int] | None:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def ico_sizes(path: Path) -> list[tuple[int, int]]:
    data = path.read_bytes()
    if data[:4] != b"\x00\x00\x01\x00":
        return []
    count = struct.unpack("<H", data[4:6])[0]
    sizes = []
    for index in range(count):
        entry = data[6 + index * 16 : 6 + index * 16 + 16]
        width = entry[0] or 256
        height = entry[1] or 256
        sizes.append((width, height))
    return sizes


def expect_png(relative: str, size: int) -> None:
    path = ROOT / relative
    if not path.is_file():
        check(False, f"missing icon: {relative}")
        return
    actual = png_size(path)
    check(actual == (size, size), f"{relative} should be {size}x{size}, got {actual}")


def main() -> int:
    # 1. JSON manifests parse.
    for relative in (
        "docs/migration/feature-manifest.json",
        "docs/migration/golden_vectors.json",
        "flutter/assets/presets/function_presets.json",
        "flutter/web/manifest.json",
    ):
        path = ROOT / relative
        try:
            json.loads(path.read_text(encoding="utf-8"))
            check(True, "")
        except Exception as error:  # noqa: BLE001 - report the parse failure
            check(False, f"{relative} is not valid JSON: {error}")

    # 2. Localization parity between English and Simplified Chinese.
    def messages(name: str) -> set[str]:
        document = json.loads(
            (ROOT / f"flutter/lib/l10n/{name}").read_text(encoding="utf-8")
        )
        return {key for key in document if not key.startswith("@")}

    english = messages("app_en.arb")
    chinese = messages("app_zh.arb")
    check(english == chinese, f"ARB key mismatch: en-only={english - chinese} zh-only={chinese - english}")

    # 3. License.
    license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
    check("GNU AFFERO GENERAL PUBLIC LICENSE" in license_text, "LICENSE is not the AGPL text")
    check("Version 3" in license_text, "LICENSE is not version 3")

    # 4. Icon family.
    for relative, size in (
        ("flutter/web/icons/Icon-192.png", 192),
        ("flutter/web/icons/Icon-512.png", 512),
        ("flutter/web/icons/Icon-maskable-192.png", 192),
        ("flutter/web/icons/Icon-maskable-512.png", 512),
        ("flutter/web/favicon.png", 64),
        ("flutter/assets/branding/supercalculator-icon-512.png", 512),
    ):
        expect_png(relative, size)

    ios = ROOT / "flutter/assets/branding/ios/AppIcon.appiconset"
    for relative, size in (
        ("AppIcon-20x20@1x.png", 20),
        ("AppIcon-29x29@1x.png", 29),
        ("AppIcon-40x40@3x.png", 120),
        ("AppIcon-60x60@3x.png", 180),
        ("AppIcon-76x76@2x.png", 152),
        ("AppIcon-83.5x83.5@2x.png", 167),
        ("AppIcon-1024x1024@1x.png", 1024),
    ):
        actual = png_size(ios / relative)
        check(actual == (size, size), f"iOS {relative} should be {size}x{size}, got {actual}")

    macos = ROOT / "flutter/assets/branding/macos/AppIcon.appiconset"
    for relative, size in (
        ("icon_16x16.png", 16),
        ("icon_128x128@2x.png", 256),
        ("icon_512x512@2x.png", 1024),
    ):
        actual = png_size(macos / relative)
        check(actual == (size, size), f"macOS {relative} should be {size}x{size}, got {actual}")

    for density, size in (
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ):
        expect_png(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)

    ico = ico_sizes(ROOT / "SuperCalculator.ico")
    check(ico != [], "SuperCalculator.ico is missing or not an ICO")
    check((256, 256) in ico, "SuperCalculator.ico should include a 256x256 frame")

    check(
        (ROOT / "flutter/assets/branding/supercalculator-mark.svg").is_file(),
        "branding mark SVG is missing",
    )

    # 5. Android adaptive icon must expose a Material You monochrome layer.
    adaptive = (ROOT / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml").read_text(
        encoding="utf-8"
    )
    check("monochrome" in adaptive, "adaptive icon is missing the monochrome layer")
    for drawable in ("ic_launcher_background", "ic_launcher_foreground", "ic_launcher_monochrome"):
        check(
            (ROOT / f"android/app/src/main/res/drawable/{drawable}.xml").is_file(),
            f"missing adaptive drawable: {drawable}.xml",
        )

    if failures:
        print("Codeberg repository checks failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(f"Codeberg repository checks passed ({checks} assertions).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
