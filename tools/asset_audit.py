#!/usr/bin/env python3
"""Static, read-only production-asset intake audit for PRIMALIS."""

from __future__ import annotations

import argparse
import base64
import csv
import json
import re
import struct
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Callable, Iterable
from urllib.parse import unquote


GLB_MAGIC = b"glTF"
GLB_JSON_CHUNK = 0x4E4F534A
GLB_BIN_CHUNK = 0x004E4942
SUPPORTED_MODEL_EXTENSIONS = {".glb", ".gltf", ".fbx", ".blend"}
LOD_PATTERN = re.compile(r"(?:^|[_\-.\s])LOD([0-9]+)(?:$|[_\-.\s])", re.IGNORECASE)
COLLISION_PATTERN = re.compile(
    r"(?:^|[_\-.\s])(COLLIDER|COLLISION|UCX|UCP|USP|UBX)(?:$|[_\-.\s0-9])",
    re.IGNORECASE,
)
UNKNOWN_PATTERN = re.compile(r"\b(UNKNOWN|PENDING|NOT YET|UNCLEAR)\b", re.IGNORECASE)


class AssetAuditError(Exception):
    """A deterministic, user-facing asset inspection failure."""


def load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AssetAuditError(f"Could not read JSON '{path.name}': {exc}") from exc


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames is None:
                return [], []
            return list(reader.fieldnames), [dict(row) for row in reader]
    except (OSError, UnicodeError, csv.Error) as exc:
        raise AssetAuditError(f"Could not read CSV '{path.name}': {exc}") from exc


def normalize_relative(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.resolve().as_posix()


def safe_int(value: Any) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else None


def triangle_count(mode: int, element_count: int | None) -> int | None:
    """Return triangles for a glTF primitive mode, or None when not triangular."""
    if element_count is None:
        return None
    if mode == 4:  # TRIANGLES
        return element_count // 3
    if mode in (5, 6):  # TRIANGLE_STRIP / TRIANGLE_FAN
        return max(element_count - 2, 0)
    return None


def classify_limit(value: float, rule: dict[str, Any]) -> str:
    target = rule.get("target_max")
    fail_above = rule.get("fail_above")
    if isinstance(fail_above, (int, float)) and value > float(fail_above):
        return "FAIL"
    if isinstance(target, (int, float)) and value > float(target):
        return "WARN"
    return "PASS"


def parse_image_dimensions(data: bytes, mime_type: str = "", suffix: str = "") -> tuple[int, int, str] | None:
    mime = mime_type.lower()
    extension = suffix.lower()
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        width, height = struct.unpack(">II", data[16:24])
        return width, height, "PNG"
    if (mime == "image/jpeg" or extension in {".jpg", ".jpeg"} or data.startswith(b"\xff\xd8")) and len(data) >= 4:
        offset = 2
        while offset + 9 <= len(data):
            if data[offset] != 0xFF:
                offset += 1
                continue
            while offset < len(data) and data[offset] == 0xFF:
                offset += 1
            if offset >= len(data):
                break
            marker = data[offset]
            offset += 1
            if marker in {0xD8, 0xD9}:
                continue
            if offset + 2 > len(data):
                break
            segment_length = struct.unpack(">H", data[offset : offset + 2])[0]
            if segment_length < 2 or offset + segment_length > len(data):
                break
            if marker in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}:
                height, width = struct.unpack(">HH", data[offset + 3 : offset + 7])
                return width, height, "JPEG"
            offset += segment_length
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP" and len(data) >= 30:
        chunk = data[12:16]
        if chunk == b"VP8X":
            width = 1 + int.from_bytes(data[24:27], "little")
            height = 1 + int.from_bytes(data[27:30], "little")
            return width, height, "WEBP"
        if chunk == b"VP8 " and len(data) >= 30 and data[23:26] == b"\x9d\x01\x2a":
            width = struct.unpack("<H", data[26:28])[0] & 0x3FFF
            height = struct.unpack("<H", data[28:30])[0] & 0x3FFF
            return width, height, "WEBP"
        if chunk == b"VP8L" and len(data) >= 25 and data[20] == 0x2F:
            bits = int.from_bytes(data[21:25], "little")
            return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1, "WEBP"
    if data.startswith(b"\xabKTX 20\xbb\r\n\x1a\n") and len(data) >= 36:
        width, height = struct.unpack("<II", data[20:28])
        return width, height, "KTX2"
    return None


def _read_prefix(path: Path, limit: int = 262_144) -> bytes:
    with path.open("rb") as handle:
        return handle.read(limit)


def _data_uri_details(uri: str) -> tuple[bytes, int | None, str]:
    header, separator, payload = uri.partition(",")
    if not separator:
        return b"", None, ""
    mime = header[5:].split(";", 1)[0] if header.startswith("data:") else ""
    if ";base64" in header:
        clean = "".join(payload.split())
        padding = len(clean) - len(clean.rstrip("="))
        byte_size = max((len(clean) * 3) // 4 - padding, 0)
        prefix_chars = clean[: min(len(clean), 349_528)]
        prefix_chars += "=" * ((4 - len(prefix_chars) % 4) % 4)
        try:
            return base64.b64decode(prefix_chars, validate=False)[:262_144], byte_size, mime
        except (ValueError, base64.binascii.Error):
            return b"", byte_size, mime
    decoded = unquote(payload).encode("latin-1", errors="replace")
    return decoded[:262_144], len(decoded), mime


def _accessor_count(accessors: list[Any], index: Any) -> int | None:
    if not isinstance(index, int) or index < 0 or index >= len(accessors):
        return None
    accessor = accessors[index]
    return safe_int(accessor.get("count")) if isinstance(accessor, dict) else None


def _extract_lod_level(name: str) -> int | None:
    match = LOD_PATTERN.search(name)
    return int(match.group(1)) if match else None


def _inspect_document(
    document: dict[str, Any],
    asset_path: Path,
    project_root: Path,
    binary_chunks: list[dict[str, int]],
) -> tuple[dict[str, Any], list[str]]:
    warnings: list[str] = []
    scenes = document.get("scenes", [])
    nodes = document.get("nodes", [])
    meshes = document.get("meshes", [])
    accessors = document.get("accessors", [])
    buffer_views = document.get("bufferViews", [])
    materials = document.get("materials", [])
    textures = document.get("textures", [])
    images = document.get("images", [])
    skins = document.get("skins", [])
    animations = document.get("animations", [])
    for collection_name, collection in (
        ("scenes", scenes), ("nodes", nodes), ("meshes", meshes),
        ("accessors", accessors), ("bufferViews", buffer_views),
        ("materials", materials), ("textures", textures), ("images", images),
        ("skins", skins), ("animations", animations),
    ):
        if not isinstance(collection, list):
            raise AssetAuditError(f"glTF field '{collection_name}' must be an array.")

    node_names = [str(node.get("name", "")) for node in nodes if isinstance(node, dict)]
    mesh_names = [str(mesh.get("name", "")) for mesh in meshes if isinstance(mesh, dict)]
    names_by_mesh: dict[int, list[str]] = {index: [mesh_names[index]] for index in range(len(mesh_names))}
    for node in nodes:
        if not isinstance(node, dict) or not isinstance(node.get("mesh"), int):
            continue
        mesh_index = node["mesh"]
        if mesh_index in names_by_mesh:
            names_by_mesh[mesh_index].append(str(node.get("name", "")))

    primitive_count = 0
    vertex_count = 0
    index_count = 0
    known_triangles = 0
    unknown_triangle_primitives = 0
    mesh_details: list[dict[str, Any]] = []
    lod_triangles: dict[str, int] = {}
    detected_lod_levels: set[int] = set()
    for mesh_index, mesh in enumerate(meshes):
        if not isinstance(mesh, dict):
            warnings.append(f"Mesh {mesh_index} is malformed.")
            continue
        primitives = mesh.get("primitives", [])
        if not isinstance(primitives, list):
            warnings.append(f"Mesh {mesh_index} has malformed primitives.")
            continue
        mesh_triangles = 0
        mesh_complete = True
        for primitive in primitives:
            primitive_count += 1
            if not isinstance(primitive, dict):
                unknown_triangle_primitives += 1
                mesh_complete = False
                continue
            attributes = primitive.get("attributes", {})
            position_count = _accessor_count(accessors, attributes.get("POSITION")) if isinstance(attributes, dict) else None
            indices_count = _accessor_count(accessors, primitive.get("indices"))
            if position_count is not None:
                vertex_count += position_count
            if indices_count is not None:
                index_count += indices_count
            element_count = indices_count if indices_count is not None else position_count
            mode = primitive.get("mode", 4)
            primitive_triangles = triangle_count(mode, element_count) if isinstance(mode, int) else None
            if primitive_triangles is None:
                unknown_triangle_primitives += 1
                mesh_complete = False
            else:
                known_triangles += primitive_triangles
                mesh_triangles += primitive_triangles
                if mode == 4 and element_count is not None and element_count % 3:
                    warnings.append(f"Mesh {mesh_index} triangle primitive has {element_count} elements; remainder was ignored.")
        candidate_levels = {_extract_lod_level(name) for name in names_by_mesh.get(mesh_index, []) if name}
        candidate_levels.discard(None)
        lod_level = next(iter(candidate_levels)) if len(candidate_levels) == 1 else None
        if lod_level is not None:
            detected_lod_levels.add(lod_level)
            lod_key = f"LOD{lod_level}"
            lod_triangles[lod_key] = lod_triangles.get(lod_key, 0) + mesh_triangles
        mesh_details.append({
            "name": str(mesh.get("name", "")),
            "primitive_count": len(primitives),
            "triangles": mesh_triangles if mesh_complete else None,
            "lod_level": lod_level,
        })

    named_lod_levels = sorted({
        level for name in node_names + mesh_names if (level := _extract_lod_level(name)) is not None
    })
    detected_lod_levels.update(named_lod_levels)
    if len(detected_lod_levels) >= 2:
        lod_status = "PRESENT"
    elif len(detected_lod_levels) == 1:
        lod_status = "UNKNOWN"
        warnings.append("Only one LOD-labelled level was found; a complete LOD chain was not assumed.")
    else:
        lod_status = "NOT DETECTED"

    collision_names = sorted(name for name in node_names + mesh_names if COLLISION_PATTERN.search(name))
    collision_status = "DETECTED" if collision_names else "NOT DETECTED"

    texture_slot_names = {
        "baseColorTexture": "base_color",
        "metallicRoughnessTexture": "metallic_roughness",
        "normalTexture": "normal",
        "occlusionTexture": "occlusion",
        "emissiveTexture": "emissive",
    }
    material_details: list[dict[str, Any]] = []
    for index, material in enumerate(materials):
        if not isinstance(material, dict):
            material_details.append({"name": f"material_{index}", "texture_slots": []})
            continue
        slots: list[dict[str, Any]] = []
        pbr = material.get("pbrMetallicRoughness", {})
        candidates = dict(material)
        if isinstance(pbr, dict):
            candidates.update(pbr)
        for gltf_key, readable_name in texture_slot_names.items():
            value = candidates.get(gltf_key)
            if isinstance(value, dict) and isinstance(value.get("index"), int):
                slots.append({"slot": readable_name, "texture_index": value["index"]})
        material_details.append({"name": str(material.get("name", f"material_{index}")), "texture_slots": slots})

    image_details: list[dict[str, Any]] = []
    approximate_texture_bytes = 0
    largest_dimension = 0
    for index, image in enumerate(images):
        detail: dict[str, Any] = {
            "index": index,
            "name": f"image_{index}",
            "mime_type": "UNKNOWN",
            "storage": "UNKNOWN",
            "byte_size": None,
            "width": None,
            "height": None,
            "format": "UNKNOWN",
            "approximate_uncompressed_rgba8_bytes": None,
        }
        if not isinstance(image, dict):
            warnings.append(f"Image {index} is malformed.")
            image_details.append(detail)
            continue
        detail["name"] = str(image.get("name", f"image_{index}"))
        mime = str(image.get("mimeType", ""))
        detail["mime_type"] = mime or "UNKNOWN"
        prefix = b""
        suffix = ""
        uri = image.get("uri")
        if isinstance(uri, str) and uri.startswith("data:"):
            prefix, byte_size, uri_mime = _data_uri_details(uri)
            detail["storage"] = "DATA_URI"
            detail["byte_size"] = byte_size
            if not mime and uri_mime:
                mime = uri_mime
                detail["mime_type"] = mime
        elif isinstance(uri, str):
            detail["storage"] = "EXTERNAL"
            if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*://", uri):
                warnings.append(f"Image {index} uses a remote URI and was not read.")
            else:
                image_path = (asset_path.parent / unquote(uri)).resolve()
                suffix = image_path.suffix
                try:
                    image_path.relative_to(project_root.resolve())
                    if image_path.is_file():
                        detail["byte_size"] = image_path.stat().st_size
                        prefix = _read_prefix(image_path)
                    else:
                        warnings.append(f"External image '{uri}' is missing.")
                except ValueError:
                    warnings.append(f"External image '{uri}' resolves outside the project and was not read.")
        elif isinstance(image.get("bufferView"), int):
            detail["storage"] = "BUFFER_VIEW"
            view_index = image["bufferView"]
            if 0 <= view_index < len(buffer_views) and isinstance(buffer_views[view_index], dict):
                view = buffer_views[view_index]
                byte_length = safe_int(view.get("byteLength"))
                byte_offset = safe_int(view.get("byteOffset")) or 0
                buffer_index = safe_int(view.get("buffer")) or 0
                detail["byte_size"] = byte_length
                if buffer_index == 0 and binary_chunks and byte_length is not None:
                    chunk = binary_chunks[0]
                    if byte_offset + byte_length <= chunk["length"]:
                        with asset_path.open("rb") as handle:
                            handle.seek(chunk["offset"] + byte_offset)
                            prefix = handle.read(min(byte_length, 262_144))
                    else:
                        warnings.append(f"Image {index} bufferView exceeds the GLB binary chunk.")
                else:
                    warnings.append(f"Image {index} bufferView data is not locally readable.")
            else:
                warnings.append(f"Image {index} references an invalid bufferView.")
        dimensions = parse_image_dimensions(prefix, mime, suffix)
        if dimensions is not None:
            width, height, detected_format = dimensions
            detail.update({"width": width, "height": height, "format": detected_format})
            rgba8_bytes = width * height * 4
            detail["approximate_uncompressed_rgba8_bytes"] = rgba8_bytes
            approximate_texture_bytes += rgba8_bytes
            largest_dimension = max(largest_dimension, width, height)
        else:
            warnings.append(f"Image {index} dimensions could not be determined from its header.")
        image_details.append(detail)

    joint_count = sum(len(skin.get("joints", [])) for skin in skins if isinstance(skin, dict) and isinstance(skin.get("joints", []), list))
    animation_names = [str(animation.get("name", f"animation_{index}")) for index, animation in enumerate(animations) if isinstance(animation, dict)]
    metrics = {
        "scene_count": len(scenes),
        "node_count": len(nodes),
        "mesh_count": len(meshes),
        "primitive_count": primitive_count,
        "vertex_count": vertex_count,
        "index_count": index_count,
        "triangle_estimate": known_triangles,
        "triangle_estimate_complete": unknown_triangle_primitives == 0,
        "unknown_triangle_primitives": unknown_triangle_primitives,
        "mesh_details": mesh_details,
        "material_count": len(materials),
        "materials": material_details,
        "texture_count": len(textures),
        "image_count": len(images),
        "images": image_details,
        "largest_texture_dimension": largest_dimension or None,
        "approximate_uncompressed_texture_bytes": approximate_texture_bytes,
        "skin_count": len(skins),
        "joint_reference_count": joint_count,
        "animation_count": len(animations),
        "animation_names": animation_names,
        "lod_status": lod_status,
        "lod_levels_detected": sorted(detected_lod_levels),
        "lod_triangles": dict(sorted(lod_triangles.items())),
        "glb_collision": collision_status,
        "collision_names": collision_names,
    }
    return metrics, warnings


def inspect_glb(asset_path: Path, project_root: Path) -> tuple[dict[str, Any], list[str]]:
    file_size = asset_path.stat().st_size
    with asset_path.open("rb") as handle:
        header = handle.read(12)
        if header.startswith(b"version https://git-lfs.github.com/spec/v1"):
            raise AssetAuditError("GLB is an unmaterialized Git LFS pointer.")
        if len(header) != 12:
            raise AssetAuditError("GLB header is truncated.")
        magic, version, declared_length = struct.unpack("<4sII", header)
        if magic != GLB_MAGIC:
            raise AssetAuditError("Invalid GLB magic; expected 'glTF'.")
        if version != 2:
            raise AssetAuditError(f"Unsupported GLB version {version}; expected 2.")
        if declared_length != file_size:
            raise AssetAuditError(f"GLB declared length {declared_length} does not match file size {file_size}.")
        json_bytes: bytes | None = None
        binary_chunks: list[dict[str, int]] = []
        cursor = 12
        while cursor < declared_length:
            chunk_header = handle.read(8)
            if len(chunk_header) != 8:
                raise AssetAuditError("GLB chunk header is truncated.")
            chunk_length, chunk_type = struct.unpack("<II", chunk_header)
            cursor += 8
            if cursor + chunk_length > declared_length:
                raise AssetAuditError("GLB chunk extends beyond the declared file length.")
            if chunk_type == GLB_JSON_CHUNK and json_bytes is None:
                json_bytes = handle.read(chunk_length)
            elif chunk_type == GLB_BIN_CHUNK:
                binary_chunks.append({"offset": cursor, "length": chunk_length})
                handle.seek(chunk_length, 1)
            else:
                handle.seek(chunk_length, 1)
            cursor += chunk_length
        if json_bytes is None:
            raise AssetAuditError("GLB has no JSON chunk.")
    try:
        document = json.loads(json_bytes.decode("utf-8").rstrip(" \t\r\n\0"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise AssetAuditError(f"GLB JSON chunk is invalid: {exc}") from exc
    if not isinstance(document, dict) or str(document.get("asset", {}).get("version", "")) != "2.0":
        raise AssetAuditError("GLB JSON does not declare glTF asset version 2.0.")
    return _inspect_document(document, asset_path, project_root, binary_chunks)


def inspect_gltf(asset_path: Path, project_root: Path) -> tuple[dict[str, Any], list[str]]:
    document = load_json(asset_path)
    if not isinstance(document, dict) or str(document.get("asset", {}).get("version", "")) != "2.0":
        raise AssetAuditError("glTF JSON does not declare asset version 2.0.")
    return _inspect_document(document, asset_path, project_root, [])


def match_asset_ledger(relative_path: str, rows: list[dict[str, str]]) -> dict[str, Any]:
    normalized = relative_path.replace("\\", "/").casefold()
    basename = Path(relative_path).name.casefold()
    exact: list[dict[str, str]] = []
    fallback: list[dict[str, str]] = []
    for row in rows:
        export_path = str(row.get("export_glb", "")).replace("\\", "/").strip().casefold()
        original = Path(str(row.get("original_filename", "")).strip()).name.casefold()
        if export_path == normalized:
            exact.append(row)
        elif original and original == basename:
            fallback.append(row)
    matches = exact if exact else fallback
    status = "FOUND" if len(matches) == 1 else "MISSING" if not matches else "AMBIGUOUS"
    return {
        "status": status,
        "match_count": len(matches),
        "entry": dict(matches[0]) if len(matches) == 1 else None,
    }


def match_license_ledger(asset_entry: dict[str, str] | None, rows: list[dict[str, str]]) -> dict[str, Any]:
    asset_id = str((asset_entry or {}).get("asset_id", "")).strip()
    matches = [row for row in rows if asset_id and str(row.get("asset_id", "")).strip() == asset_id]
    status = "FOUND" if len(matches) == 1 else "MISSING" if not matches else "AMBIGUOUS"
    entry = dict(matches[0]) if len(matches) == 1 else None
    ai_value = str((entry or {}).get("AI_processing_allowed", "") or (asset_entry or {}).get("AI_processing_allowed", "")).strip()
    ai_status = ai_value if ai_value and not UNKNOWN_PATTERN.search(ai_value) else "UNKNOWN"
    shipping_blocked = status != "FOUND"
    if entry is not None:
        for field in ("license", "commercial_ok", "license_snapshot"):
            value = str(entry.get(field, "")).strip()
            if not value or UNKNOWN_PATTERN.search(value):
                shipping_blocked = True
    return {
        "status": status,
        "match_count": len(matches),
        "entry": entry,
        "AI_PROCESSING_ALLOWED": ai_status,
        "shipping_status": "BLOCK SHIPPING" if shipping_blocked else "METADATA COMPLETE",
    }


def run_git(project_root: Path, arguments: list[str]) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            ["git", "-C", str(project_root), *arguments],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
        )
        return completed.returncode, (completed.stdout + completed.stderr).strip()
    except (OSError, subprocess.SubprocessError):
        return -1, ""


def interpret_lfs_status(policy_value: str, lfs_listing: str, git_tracked: bool) -> dict[str, Any]:
    policy_applies = policy_value.strip().casefold() == "lfs"
    lfs_tracked = bool(lfs_listing.strip())
    return {
        "policy_applies": policy_applies,
        "git_tracked": git_tracked,
        "lfs_tracked": lfs_tracked,
        "status": "YES" if lfs_tracked else "NO",
    }


def get_lfs_status(project_root: Path, relative_path: str) -> dict[str, Any]:
    attr_code, attr_output = run_git(project_root, ["check-attr", "filter", "--", relative_path])
    policy_value = attr_output.rsplit(":", 1)[-1].strip() if attr_code == 0 and ":" in attr_output else ""
    tracked_code, _ = run_git(project_root, ["ls-files", "--error-unmatch", "--", relative_path])
    lfs_code, lfs_output = run_git(project_root, ["lfs", "ls-files", "--name-only"])
    normalized_target = relative_path.replace("\\", "/").casefold()
    matching_lines = [
        line for line in lfs_output.splitlines()
        if line.strip().replace("\\", "/").casefold() == normalized_target
    ] if lfs_code == 0 else []
    result = interpret_lfs_status(policy_value, "\n".join(matching_lines), tracked_code == 0)
    result["available"] = attr_code == 0 and lfs_code == 0
    return result


def resolve_category(
    explicit_category: str | None,
    ledger_entry: dict[str, str] | None,
    categories: dict[str, Any],
) -> tuple[str, str, str | None]:
    if explicit_category:
        normalized = explicit_category.strip().upper()
        if normalized not in categories:
            raise AssetAuditError(f"Unknown explicit category '{explicit_category}'.")
        return normalized, "CLI", None
    ledger_value = str((ledger_entry or {}).get("category", "")).strip()
    normalized = ledger_value.upper()
    if normalized in categories:
        return normalized, "ASSET_LEDGER", None
    if ledger_value:
        return "UNKNOWN", "ASSET_LEDGER_UNMAPPED", f"Ledger category '{ledger_value}' is not a configured intake category; CATEGORY remains UNKNOWN."
    return "UNKNOWN", "FALLBACK", "No explicit or recognized ledger category was available; CATEGORY is UNKNOWN."


def _budget_check(name: str, value: float, rule: dict[str, Any], display_value: Any = None) -> dict[str, Any]:
    status = classify_limit(value, rule)
    return {
        "metric": name,
        "value": value if display_value is None else display_value,
        "target_max": rule.get("target_max"),
        "fail_above": rule.get("fail_above"),
        "status": status,
    }


def apply_budgets(category: str, file_mib: float, metrics: dict[str, Any], budgets: dict[str, Any]) -> list[dict[str, Any]]:
    category_budget = budgets["categories"].get(category, {})
    checks: list[dict[str, Any]] = []
    if "disk_mib" in category_budget:
        checks.append(_budget_check("disk_mib", file_mib, category_budget["disk_mib"], round(file_mib, 3)))
    triangles = metrics.get("triangle_estimate")
    if isinstance(triangles, int) and metrics.get("triangle_estimate_complete") and "lod0_triangles" in category_budget:
        checks.append(_budget_check("lod0_triangles", triangles, category_budget["lod0_triangles"]))
    for lod_name, metric_name in (("LOD1", "lod1_triangles"), ("LOD2", "lod2_triangles")):
        value = metrics.get("lod_triangles", {}).get(lod_name)
        if isinstance(value, int) and metric_name in category_budget:
            checks.append(_budget_check(metric_name, value, category_budget[metric_name]))
    materials = metrics.get("material_count")
    if isinstance(materials, int) and "materials" in category_budget:
        checks.append(_budget_check("materials", materials, category_budget["materials"]))
    texture_dimension = metrics.get("largest_texture_dimension")
    if isinstance(texture_dimension, int) and "texture_dimension" in category_budget:
        checks.append(_budget_check("texture_dimension", texture_dimension, category_budget["texture_dimension"]))
    return checks


def audit_asset(
    asset_path: Path,
    project_root: Path,
    budgets: dict[str, Any],
    asset_rows: list[dict[str, str]],
    license_rows: list[dict[str, str]],
    explicit_category: str | None = None,
    duplicate_basenames: set[str] | None = None,
    lfs_probe: Callable[[Path, str], dict[str, Any]] = get_lfs_status,
) -> dict[str, Any]:
    relative_path = normalize_relative(asset_path, project_root)
    warnings: list[str] = []
    failures: list[str] = []
    notes: list[str] = []
    file_size = asset_path.stat().st_size if asset_path.is_file() else 0
    file_mib = file_size / (1024 * 1024)
    extension = asset_path.suffix.lower()

    ledger = match_asset_ledger(relative_path, asset_rows)
    ledger_entry = ledger.get("entry")
    license_status = match_license_ledger(ledger_entry, license_rows)
    try:
        category, category_source, category_warning = resolve_category(explicit_category, ledger_entry, budgets["categories"])
    except AssetAuditError as exc:
        category, category_source, category_warning = "UNKNOWN", "INVALID_CLI", str(exc)
        failures.append(str(exc))
    if category_warning:
        warnings.append(category_warning)

    metrics: dict[str, Any] = {
        "scene_count": None,
        "node_count": None,
        "mesh_count": None,
        "primitive_count": None,
        "vertex_count": None,
        "index_count": None,
        "triangle_estimate": None,
        "triangle_estimate_complete": False,
        "material_count": None,
        "texture_count": None,
        "image_count": None,
        "images": [],
        "largest_texture_dimension": None,
        "approximate_uncompressed_texture_bytes": None,
        "skin_count": None,
        "joint_reference_count": None,
        "animation_count": None,
        "animation_names": [],
        "lod_status": "UNKNOWN",
        "lod_levels_detected": [],
        "lod_triangles": {},
        "glb_collision": "UNKNOWN",
        "collision_names": [],
    }
    if not asset_path.is_file():
        failures.append("Asset file does not exist.")
    else:
        try:
            if extension == ".glb":
                metrics, parse_warnings = inspect_glb(asset_path, project_root)
                warnings.extend(parse_warnings)
            elif extension == ".gltf":
                metrics, parse_warnings = inspect_gltf(asset_path, project_root)
                warnings.extend(parse_warnings)
            else:
                warnings.append(f"Static metadata inspection for '{extension}' is limited to file, LFS, ledger, and path checks.")
        except (AssetAuditError, OSError) as exc:
            failures.append(f"Model inspection failed: {exc}")

    lfs = lfs_probe(project_root, relative_path)
    required_lfs = extension in set(budgets["general"].get("lfs_required_extensions", []))
    if required_lfs and not lfs.get("available", True):
        warnings.append("Git LFS status could not be determined.")
    elif required_lfs and not lfs.get("lfs_tracked"):
        failures.append("Production binary is not tracked through Git LFS as required by policy.")
    elif required_lfs and not lfs.get("policy_applies"):
        failures.append("Production binary does not match a Git LFS attribute policy.")

    if ledger["status"] == "MISSING":
        warnings.append("Asset ledger entry is missing.")
    elif ledger["status"] == "AMBIGUOUS":
        warnings.append("Asset ledger match is ambiguous.")
    if license_status["status"] == "MISSING":
        warnings.append("License ledger entry is missing; BLOCK SHIPPING until metadata is resolved.")
    elif license_status["status"] == "AMBIGUOUS":
        warnings.append("License ledger match is ambiguous; BLOCK SHIPPING until resolved.")
    elif license_status["shipping_status"] == "BLOCK SHIPPING":
        warnings.append("License metadata is unresolved; BLOCK SHIPPING. No legal conclusion is inferred.")
    if license_status["AI_PROCESSING_ALLOWED"] == "UNKNOWN":
        warnings.append("AI_PROCESSING_ALLOWED is UNKNOWN; do not upload to external AI services.")

    path_parts = Path(relative_path).parts
    if any(" " in part for part in path_parts):
        warnings.append("Production path contains spaces.")
    if len(relative_path) > int(budgets["general"].get("path_length_warning", 180)):
        warnings.append(f"Production path is {len(relative_path)} characters long.")
    if asset_path.stem.casefold() in {name.casefold() for name in budgets["general"].get("generic_filenames", [])}:
        warnings.append(f"Generic production filename '{asset_path.name}' should be made specific before approval.")
    if duplicate_basenames and asset_path.name.casefold() in duplicate_basenames:
        warnings.append(f"Duplicate production filename '{asset_path.name}' exists in the model inventory.")

    if metrics.get("triangle_estimate") is not None and not metrics.get("triangle_estimate_complete"):
        warnings.append("Triangle estimate is incomplete because one or more primitive modes/accessors were unsupported or malformed.")
    category_budget = budgets["categories"].get(category, {})
    lod_expected = category_budget.get("lod_expected")
    if metrics.get("lod_status") == "NOT DETECTED":
        metrics["lod_status"] = "MISSING" if lod_expected is True else "UNKNOWN"
        if lod_expected is True:
            warnings.append(f"LOD chain is missing for repeated/complex category {category}.")
    if metrics.get("glb_collision") == "NOT DETECTED":
        notes.append("No collision marker was detected inside the model; verify separate Godot collision before approval.")

    budget_checks = apply_budgets(category, file_mib, metrics, budgets)
    for check in budget_checks:
        if check["status"] == "WARN":
            warnings.append(
                f"Budget warning: {check['metric']}={check['value']} exceeds testing target {check['target_max']}."
            )
        elif check["status"] == "FAIL":
            failures.append(
                f"Budget failure: {check['metric']}={check['value']} exceeds testing fail threshold {check['fail_above']}."
            )

    warnings = sorted(set(warnings))
    failures = sorted(set(failures))
    notes = sorted(set(notes))
    final_result = "FAIL" if failures else "PASS WITH WARNINGS" if warnings else "PASS"
    return {
        "asset": relative_path,
        "category": category,
        "category_source": category_source,
        "file": {
            "type": extension.lstrip(".").upper() or "UNKNOWN",
            "bytes": file_size,
            "mib": round(file_mib, 3),
        },
        "metrics": metrics,
        "budget_checks": budget_checks,
        "lfs": lfs,
        "asset_ledger": ledger,
        "license": license_status,
        "warnings": warnings,
        "failures": failures,
        "notes": notes,
        "final_result": final_result,
    }


def discover_assets(project_root: Path, budgets: dict[str, Any]) -> list[Path]:
    assets_root = project_root / "assets"
    extensions = set(budgets["general"].get("model_extensions", SUPPORTED_MODEL_EXTENSIONS))
    if not assets_root.is_dir():
        return []
    return sorted(
        (path for path in assets_root.rglob("*") if path.is_file() and path.suffix.lower() in extensions),
        key=lambda path: normalize_relative(path, project_root).casefold(),
    )


def run_project_audit(
    project_root: Path,
    budgets_path: Path,
    asset_paths: Iterable[Path],
    explicit_category: str | None = None,
    lfs_probe: Callable[[Path, str], dict[str, Any]] = get_lfs_status,
) -> dict[str, Any]:
    budgets = load_json(budgets_path)
    _, asset_rows = read_csv(project_root / "docs" / "ASSET_LEDGER.csv")
    _, license_rows = read_csv(project_root / "docs" / "LICENSE_LEDGER.csv")
    paths = list(asset_paths)
    names = Counter(path.name.casefold() for path in paths)
    duplicates = {name for name, count in names.items() if count > 1}
    results = [
        audit_asset(path, project_root, budgets, asset_rows, license_rows, explicit_category, duplicates, lfs_probe)
        for path in paths
    ]
    counts = {
        "PASS": sum(result["final_result"] == "PASS" for result in results),
        "PASS WITH WARNINGS": sum(result["final_result"] == "PASS WITH WARNINGS" for result in results),
        "FAIL": sum(result["final_result"] == "FAIL" for result in results),
        "TOTAL": len(results),
    }
    return {
        "schema_version": 1,
        "budget_status": budgets.get("status", "UNKNOWN"),
        "project_context": budgets.get("project_context", {}),
        "summary": counts,
        "assets": results,
    }


def _display(value: Any) -> str:
    return "UNKNOWN" if value is None else str(value)


def render_text(report: dict[str, Any]) -> str:
    lines = [
        "PRIMALIS ASSET AUDIT",
        "=" * 60,
        "Budget status: [TESTING]",
        "Static intake results are planning signals, not universal rules.",
        "An asset passing static budget does not guarantee runtime performance.",
        "Actual Godot gameplay profiling remains authoritative.",
        "",
    ]
    context = report.get("project_context", {})
    lines.extend([
        f"Development GPU: {context.get('development_gpu', 'UNKNOWN')}",
        f"Primary resolution: {context.get('primary_resolution', 'UNKNOWN')}",
        f"Gameplay target: ~{context.get('normal_fps_target', 'UNKNOWN')} FPS where practical; {context.get('heavy_gameplay_minimum_fps', 'UNKNOWN')} FPS heavy minimum",
        "",
    ])
    for result in report.get("assets", []):
        metrics = result["metrics"]
        lines.extend([
            "-" * 60,
            f"Asset: {result['asset']}",
            f"Category: {result['category']} ({result['category_source']})",
            f"Disk size: {result['file']['bytes']} bytes ({result['file']['mib']:.3f} MiB)",
            f"Type: {result['file']['type']}",
            f"Scenes / nodes / meshes / primitives: {_display(metrics.get('scene_count'))} / {_display(metrics.get('node_count'))} / {_display(metrics.get('mesh_count'))} / {_display(metrics.get('primitive_count'))}",
            f"Vertices / indices: {_display(metrics.get('vertex_count'))} / {_display(metrics.get('index_count'))}",
            f"Triangle estimate: {_display(metrics.get('triangle_estimate'))} (complete: {metrics.get('triangle_estimate_complete', False)})",
            f"Materials: {_display(metrics.get('material_count'))}",
            f"Textures / images: {_display(metrics.get('texture_count'))} / {_display(metrics.get('image_count'))}",
            f"Largest texture: {_display(metrics.get('largest_texture_dimension'))} px",
            f"Approximate uncompressed texture memory (RGBA8 baseline): {((metrics.get('approximate_uncompressed_texture_bytes') or 0) / (1024 * 1024)):.3f} MiB",
            f"Skins / joint references / animations: {_display(metrics.get('skin_count'))} / {_display(metrics.get('joint_reference_count'))} / {_display(metrics.get('animation_count'))}",
            f"Animation names: {', '.join(metrics.get('animation_names', [])) or '(none)'}",
            f"LOD status: {metrics.get('lod_status', 'UNKNOWN')} (levels: {metrics.get('lod_levels_detected', [])})",
            f"GLB collision: {metrics.get('glb_collision', 'UNKNOWN')}",
            f"Git LFS tracked: {result['lfs'].get('status', 'UNKNOWN')} (policy: {result['lfs'].get('policy_applies', False)}, Git tracked: {result['lfs'].get('git_tracked', False)})",
            f"Asset ledger: {result['asset_ledger']['status']}",
            f"License entry: {result['license']['status']}",
            f"License: {((result['license'].get('entry') or {}).get('license') or 'UNKNOWN')}",
            f"AI_PROCESSING_ALLOWED: {result['license']['AI_PROCESSING_ALLOWED']}",
            f"Shipping metadata: {result['license']['shipping_status']}",
            "",
            "Budget checks:",
        ])
        if result["budget_checks"]:
            for check in result["budget_checks"]:
                lines.append(
                    f"  [{check['status']}] {check['metric']}: {check['value']} (target <= {check['target_max']}, fail > {_display(check['fail_above'])})"
                )
        else:
            lines.append("  [WARN] No category-specific numeric checks; explicit categorization recommended.")
        if metrics.get("materials"):
            lines.append("Materials and PBR slots:")
            for material in metrics["materials"]:
                slots = ", ".join(slot["slot"] for slot in material.get("texture_slots", [])) or "none"
                lines.append(f"  {material['name']}: {slots}")
        if metrics.get("images"):
            lines.append("Images:")
            for image in metrics["images"]:
                dimensions = f"{image['width']}x{image['height']}" if image.get("width") and image.get("height") else "UNKNOWN"
                lines.append(
                    f"  {image['name']}: {dimensions}, {image['format']}, {image['storage']}, {_display(image['byte_size'])} bytes"
                )
        lines.append(f"FINAL: {result['final_result']}")
        lines.append("FAILURES:")
        lines.extend([f"  - {message}" for message in result["failures"]] or ["  (none)"])
        lines.append("WARNINGS:")
        lines.extend([f"  - {message}" for message in result["warnings"]] or ["  (none)"])
        lines.append("NOTES:")
        lines.extend([f"  - {message}" for message in result["notes"]] or ["  (none)"])
        lines.append("")
    summary = report["summary"]
    lines.extend([
        "=" * 60,
        "PROJECT SUMMARY",
        f"PASS: {summary['PASS']}",
        f"PASS WITH WARNINGS: {summary['PASS WITH WARNINGS']}",
        f"FAIL: {summary['FAIL']}",
        f"TOTAL: {summary['TOTAL']}",
    ])
    return "\n".join(lines) + "\n"


def write_reports(report: dict[str, Any], text_path: Path, json_path: Path) -> None:
    text_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.parent.mkdir(parents=True, exist_ok=True)
    text_path.write_text(render_text(report), encoding="utf-8", newline="\n")
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def parse_arguments(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read-only PRIMALIS production asset intake audit.")
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--budgets", type=Path, required=True)
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--asset", type=Path)
    target.add_argument("--all", action="store_true")
    parser.add_argument("--category")
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--output-text", type=Path)
    parser.add_argument("--output-json", type=Path)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = parse_arguments(argv or sys.argv[1:])
    project_root = args.project_root.resolve()
    budgets_path = args.budgets.resolve()
    try:
        budgets = load_json(budgets_path)
        if args.asset:
            asset_path = args.asset if args.asset.is_absolute() else project_root / args.asset
            asset_paths = [asset_path.resolve()]
        else:
            asset_paths = discover_assets(project_root, budgets)
        report = run_project_audit(project_root, budgets_path, asset_paths, args.category)
        text_path = args.output_text or project_root / "captures" / "audit" / "latest_asset_audit.txt"
        json_path = args.output_json or project_root / "captures" / "audit" / "latest_asset_audit.json"
        write_reports(report, text_path, json_path)
    except AssetAuditError as exc:
        print(f"ASSET AUDIT ERROR: {exc}", file=sys.stderr)
        return 2

    summary = report["summary"]
    if args.summary:
        print(
            "ASSET PERFORMANCE SUMMARY: "
            f"PASS={summary['PASS']} WARN={summary['PASS WITH WARNINGS']} FAIL={summary['FAIL']} TOTAL={summary['TOTAL']}"
        )
        print("ASSET PERFORMANCE JSON: " + json.dumps(summary, sort_keys=True))
        print(f"Detailed report: {normalize_relative(text_path, project_root)}")
    else:
        print(render_text(report), end="")
        print(f"Detailed text report: {normalize_relative(text_path, project_root)}")
        print(f"Machine-readable report: {normalize_relative(json_path, project_root)}")
    return 2 if summary["FAIL"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
