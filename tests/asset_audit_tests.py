#!/usr/bin/env python3
"""Fast standard-library tests for tools/asset_audit.py."""

from __future__ import annotations

import json
import struct
import sys
import unittest
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "tools"))

import asset_audit  # noqa: E402


@contextmanager
def temporary_directory() -> Iterator[Path]:
    writable_root = PROJECT_ROOT / "captures" / "audit" / "asset_audit_test_workspace"
    writable_root.mkdir(parents=True, exist_ok=True)
    for child in writable_root.iterdir():
        if child.is_file():
            child.unlink()
    try:
        yield writable_root
    finally:
        for child in writable_root.iterdir():
            if child.is_file():
                child.unlink()


def make_glb(path: Path) -> None:
    png_header = b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + struct.pack(">II", 4, 8)
    document = {
        "asset": {"version": "2.0"},
        "scene": 0,
        "scenes": [{"nodes": [0, 1]}],
        "nodes": [{"name": "fixture_a", "mesh": 0}, {"name": "fixture_b", "mesh": 1}],
        "meshes": [
            {"name": "indexed", "primitives": [{"attributes": {"POSITION": 0}, "indices": 1, "material": 0}]},
            {"name": "non_indexed", "primitives": [{"attributes": {"POSITION": 2}, "material": 0}]},
        ],
        "accessors": [{"count": 4}, {"count": 6}, {"count": 9}],
        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(png_header)}],
        "buffers": [{"byteLength": len(png_header)}],
        "materials": [{"name": "fixture_material", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}}}],
        "textures": [{"source": 0}],
        "images": [{"name": "fixture_texture", "mimeType": "image/png", "bufferView": 0}],
    }
    json_chunk = json.dumps(document, separators=(",", ":")).encode("utf-8")
    json_chunk += b" " * ((4 - len(json_chunk) % 4) % 4)
    binary_chunk = png_header + b"\x00" * ((4 - len(png_header) % 4) % 4)
    total_length = 12 + 8 + len(json_chunk) + 8 + len(binary_chunk)
    payload = (
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<II", len(json_chunk), asset_audit.GLB_JSON_CHUNK)
        + json_chunk
        + struct.pack("<II", len(binary_chunk), asset_audit.GLB_BIN_CHUNK)
        + binary_chunk
    )
    path.write_bytes(payload)


class AssetAuditTests(unittest.TestCase):
    def test_triangle_counting_modes(self) -> None:
        self.assertEqual(asset_audit.triangle_count(4, 12), 4)
        self.assertEqual(asset_audit.triangle_count(5, 6), 4)
        self.assertEqual(asset_audit.triangle_count(6, 5), 3)
        self.assertIsNone(asset_audit.triangle_count(1, 12))

    def test_indexed_and_nonindexed_glb_geometry(self) -> None:
        with temporary_directory() as temporary:
            root = Path(temporary)
            fixture = root / "fixture.glb"
            make_glb(fixture)
            metrics, warnings = asset_audit.inspect_glb(fixture, root)
            self.assertEqual(metrics["mesh_count"], 2)
            self.assertEqual(metrics["primitive_count"], 2)
            self.assertEqual(metrics["index_count"], 6)
            self.assertEqual(metrics["vertex_count"], 13)
            self.assertEqual(metrics["triangle_estimate"], 5)
            self.assertTrue(metrics["triangle_estimate_complete"])
            self.assertEqual(warnings, [])

    def test_material_and_texture_metadata(self) -> None:
        with temporary_directory() as temporary:
            root = Path(temporary)
            fixture = root / "fixture.glb"
            make_glb(fixture)
            metrics, _ = asset_audit.inspect_glb(fixture, root)
            self.assertEqual(metrics["material_count"], 1)
            self.assertEqual(metrics["texture_count"], 1)
            self.assertEqual(metrics["image_count"], 1)
            self.assertEqual(metrics["largest_texture_dimension"], 8)
            self.assertEqual(metrics["images"][0]["width"], 4)
            self.assertEqual(metrics["images"][0]["height"], 8)
            self.assertEqual(metrics["approximate_uncompressed_texture_bytes"], 4 * 8 * 4)

    def test_small_gltf_metadata(self) -> None:
        with temporary_directory() as temporary:
            root = Path(temporary)
            fixture = root / "fixture.gltf"
            fixture.write_text(json.dumps({
                "asset": {"version": "2.0"},
                "scenes": [{}],
                "nodes": [{"mesh": 0}],
                "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}],
                "accessors": [{"count": 3}],
            }), encoding="utf-8")
            metrics, warnings = asset_audit.inspect_gltf(fixture, root)
            self.assertEqual(metrics["triangle_estimate"], 1)
            self.assertEqual(metrics["mesh_count"], 1)
            self.assertEqual(warnings, [])

    def test_budget_pass_warn_fail(self) -> None:
        rule = {"target_max": 10, "fail_above": 20}
        self.assertEqual(asset_audit.classify_limit(10, rule), "PASS")
        self.assertEqual(asset_audit.classify_limit(11, rule), "WARN")
        self.assertEqual(asset_audit.classify_limit(21, rule), "FAIL")

    def test_unknown_category_is_not_invented(self) -> None:
        categories = {"PROP": {}, "UNKNOWN": {}}
        category, source, warning = asset_audit.resolve_category(None, {"category": "building"}, categories)
        self.assertEqual(category, "UNKNOWN")
        self.assertEqual(source, "ASSET_LEDGER_UNMAPPED")
        self.assertIn("CATEGORY remains UNKNOWN", warning or "")

    def test_ledger_found_and_missing(self) -> None:
        rows = [{"asset_id": "AST_TEST", "original_filename": "fixture.glb", "export_glb": "assets/test/fixture.glb"}]
        found = asset_audit.match_asset_ledger("assets/test/fixture.glb", rows)
        missing = asset_audit.match_asset_ledger("assets/test/missing.glb", rows)
        self.assertEqual(found["status"], "FOUND")
        self.assertEqual(found["entry"]["asset_id"], "AST_TEST")
        self.assertEqual(missing["status"], "MISSING")

    def test_license_status_and_ai_permission_are_not_inferred(self) -> None:
        asset_entry = {"asset_id": "AST_TEST", "AI_processing_allowed": "UNKNOWN"}
        license_rows = [{"asset_id": "AST_TEST", "license": "CC0", "commercial_ok": "YES", "license_snapshot": "snapshot.txt", "AI_processing_allowed": "UNKNOWN"}]
        result = asset_audit.match_license_ledger(asset_entry, license_rows)
        self.assertEqual(result["status"], "FOUND")
        self.assertEqual(result["AI_PROCESSING_ALLOWED"], "UNKNOWN")

    def test_lfs_detection_interpretation(self) -> None:
        tracked = asset_audit.interpret_lfs_status("lfs", "assets/example.glb", True)
        regular_blob = asset_audit.interpret_lfs_status("lfs", "", True)
        self.assertEqual(tracked["status"], "YES")
        self.assertTrue(tracked["policy_applies"])
        self.assertEqual(regular_blob["status"], "NO")

    def test_malformed_glb_is_rejected(self) -> None:
        with temporary_directory() as temporary:
            root = Path(temporary)
            malformed = root / "bad.glb"
            malformed.write_bytes(b"not a glb")
            with self.assertRaises(asset_audit.AssetAuditError):
                asset_audit.inspect_glb(malformed, root)

    def test_rendered_output_is_deterministic(self) -> None:
        report = {
            "project_context": {},
            "summary": {"PASS": 0, "PASS WITH WARNINGS": 0, "FAIL": 0, "TOTAL": 0},
            "assets": [],
        }
        first = asset_audit.render_text(report)
        second = asset_audit.render_text(json.loads(json.dumps(report, sort_keys=True)))
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main(verbosity=2)
