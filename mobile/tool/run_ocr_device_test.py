#!/usr/bin/env python3
"""Run the real ML Kit fixture without shipping test assets in the app."""
import argparse
import base64
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default="emulator-5554")
    args = parser.parse_args()
    mobile = Path(__file__).resolve().parents[1]
    fixtures = mobile / "test/ocr/fixtures"
    defines = {
        "OCR_IMAGE_BASE64": base64.b64encode(
            (fixtures / "spss_tables.jpg").read_bytes()).decode("ascii"),
        "OCR_WORKBOOK_BASE64": base64.b64encode(
            (fixtures / "collinearity_diagnostics.xlsx").read_bytes()).decode("ascii"),
    }
    with tempfile.TemporaryDirectory(prefix="dytava-ocr-") as scratch:
        path = Path(scratch) / "defines.json"
        path.write_text(json.dumps(defines), encoding="utf-8")
        return subprocess.run([
            "flutter", "test", "integration_test/ocr_real_image_test.dart",
            "-d", args.device, f"--dart-define-from-file={path}",
        ], cwd=mobile).returncode


if __name__ == "__main__":
    raise SystemExit(main())
