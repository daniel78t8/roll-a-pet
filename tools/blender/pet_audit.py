"""Bestandsaufnahme fuer Pet-Dateien – laeuft komplett in Blender und speichert NICHTS.

Aufruf (Blender-Programm):
    blender -b --factory-startup --python tools/blender/pet_audit.py -- <dateien...> --out <ordner>
Aufruf (Blender als Python-Modul, siehe setup_bpy.sh):
    python tools/blender/pet_audit.py <dateien...> --out <ordner>

Unterstuetzt .blend, .fbx, .obj, .glb/.gltf. Die Originaldateien werden nur gelesen
und niemals gespeichert. Pro Datei entstehen <out>/<name>/audit.json und audit.md,
dazu <out>/summary.md ueber alle Dateien.
"""

import argparse
import json
import math
import os
import sys
from collections import Counter, defaultdict

import bpy  # muss vor bmesh/mathutils geladen werden (bpy-Modul)
import bmesh
import numpy as np
from mathutils import Vector

# Toleranzen (Blender-Einheiten bzw. Bruchteile)
DUP_DIST = 1e-5
AREA_EPS = 1e-10
UV_GRID = 256
LOOP_TOL = 1e-3
FLOAT_GAP = 0.002  # Mindestabstand der Bounding-Boxen, ab dem ein Teil als "schwebend" gilt

LOOP_HINTS = ("loop", "idle", "walk", "run", "fly", "hover", "swim", "breath", "cycle")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("files", nargs="+")
    p.add_argument("--out", required=True)
    return p.parse_args(argv)


# ---------------------------------------------------------------- Laden

def load_file(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        raise ValueError(f"Nicht unterstuetztes Format: {ext}")


# ---------------------------------------------------------------- Hilfen

def r(v, n=4):
    if isinstance(v, (list, tuple, Vector)):
        return [round(float(x), n) for x in v]
    return round(float(v), n)


def world_bbox(objs):
    pts = []
    for o in objs:
        if o.type == "MESH" and len(o.data.vertices):
            pts.extend(o.matrix_world @ Vector(c) for c in o.bound_box)
    if not pts:
        return None
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def bbox_gap(a, b):
    """Groesster Achsabstand zwischen zwei AABBs (<= 0 heisst: beruehren/ueberlappen)."""
    return max(max(a[0][i] - b[1][i], b[0][i] - a[1][i]) for i in range(3))


def action_fcurves(act):
    fcs = []
    if hasattr(act, "layers") and len(act.layers):
        for layer in act.layers:
            for strip in layer.strips:
                for cb in getattr(strip, "channelbags", []):
                    fcs.extend(cb.fcurves)
    elif hasattr(act, "fcurves"):  # Blender < 4.4
        fcs.extend(act.fcurves)
    return fcs


# ---------------------------------------------------------------- Geometrie

def islands(bm):
    parent = list(range(len(bm.verts)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for e in bm.edges:
        a, b = find(e.verts[0].index), find(e.verts[1].index)
        if a != b:
            parent[a] = b
    groups = defaultdict(list)
    for v in bm.verts:
        groups[find(v.index)].append(v)
    return list(groups.values())


def anisotropy(p, u):
    """Verhaeltnis der Singulaerwerte der Abbildung 3D-Dreieck → UV (1 = winkeltreu)."""
    e1, e2 = p[1] - p[0], p[2] - p[0]
    n = e1.cross(e2)
    if n.length < 1e-12:
        return None
    x = e1.normalized()
    y = n.cross(x).normalized()
    P = np.array([[e1.dot(x), e2.dot(x)], [e1.dot(y), e2.dot(y)]])
    Q = np.array([[u[1].x - u[0].x, u[2].x - u[0].x], [u[1].y - u[0].y, u[2].y - u[0].y]])
    s = np.linalg.svd(Q @ np.linalg.inv(P), compute_uv=False)
    return float(s[0] / s[1]) if s[1] > 1e-12 else float("inf")


def uv_stats(bm, uv_layer, faces_3d_area):
    tris_uv = []
    zero_uv = 0
    out_of_range = 0
    distorted = 0
    density_outliers = 0
    total_uv = 0.0
    face_uv_area = []
    for f in bm.faces:
        uvs = [l[uv_layer].uv.copy() for l in f.loops]
        cos = [l.vert.co for l in f.loops]
        if any(u.x < -1e-4 or u.x > 1.0001 or u.y < -1e-4 or u.y > 1.0001 for u in uvs):
            out_of_range += 1
        a = 0.0
        worst = 1.0
        for i in range(1, len(uvs) - 1):
            t = (uvs[0], uvs[i], uvs[i + 1])
            tris_uv.append(t)
            a += abs((t[1] - t[0]).cross(t[2] - t[0])) * 0.5
            an = anisotropy((cos[0], cos[i], cos[i + 1]), t)
            if an is not None:
                worst = max(worst, an)
        face_uv_area.append(a)
        total_uv += a
        if a < AREA_EPS:
            zero_uv += 1
        elif worst > 2.0:
            distorted += 1
    total_3d = sum(faces_3d_area) or 1.0
    if total_uv > 0:
        # Texeldichte-Abweichung: oft gewollt (z. B. mehr Aufloesung fuer das Gesicht) → nur Info
        for a3, au in zip(faces_3d_area, face_uv_area):
            if a3 < AREA_EPS:
                continue
            ratio = (au / total_uv) / (a3 / total_3d)
            if ratio < 0.5 or ratio > 2.0:
                density_outliers += 1

    # Ueberlappung per Rasterung im 0..1-Bereich (gespiegelte Inseln sind oft Absicht)
    grid = np.zeros((UV_GRID, UV_GRID), dtype=np.uint16)
    for t in tris_uv:
        xs = [p.x * UV_GRID for p in t]
        ys = [p.y * UV_GRID for p in t]
        x0, x1 = max(int(min(xs)), 0), min(int(max(xs)) + 1, UV_GRID)
        y0, y1 = max(int(min(ys)), 0), min(int(max(ys)) + 1, UV_GRID)
        if x0 >= x1 or y0 >= y1:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = zip(xs, ys)
        d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(d) < 1e-12:
            continue
        w1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / d
        w2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / d
        inside = (w1 >= 0) & (w2 >= 0) & (w1 + w2 <= 1)
        grid[y0:y1, x0:x1] += inside.astype(np.uint16)
    covered = int((grid > 0).sum())
    overlapped = int((grid > 1).sum())
    n = max(len(bm.faces), 1)
    return {
        "faces_zero_uv_area": zero_uv,
        "faces_outside_0_1_pct": r(100 * out_of_range / n, 1),
        "uv_coverage_pct": r(100 * covered / UV_GRID ** 2, 1),
        "uv_overlap_pct_of_covered": r(100 * overlapped / covered, 1) if covered else 0.0,
        "faces_distorted_pct": r(100 * distorted / n, 1),
        "texel_density_outliers_pct": r(100 * density_outliers / n, 1),
    }


def audit_mesh(obj):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()

    face_areas = [f.calc_area() for f in bm.faces]
    pos_key = lambda v: (round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5))
    face_keys = Counter(frozenset(pos_key(v) for v in f.verts) for f in bm.faces)

    info = {
        "verts": len(bm.verts),
        "faces": len(bm.faces),
        "tris": sum(len(f.verts) - 2 for f in bm.faces),
        "ngons": sum(1 for f in bm.faces if len(f.verts) > 4),
        "loose_verts": sum(1 for v in bm.verts if not v.link_edges),
        "loose_edges": sum(1 for e in bm.edges if not e.link_faces),
        "boundary_edges": sum(1 for e in bm.edges if e.is_boundary),
        "nonmanifold_edges_gt2_faces": sum(1 for e in bm.edges if len(e.link_faces) > 2),
        "inconsistent_winding_edges": sum(
            1 for e in bm.edges
            if len(e.link_loops) == 2 and e.link_loops[0].vert == e.link_loops[1].vert),
        "degenerate_faces": sum(1 for a in face_areas if a < AREA_EPS),
        "duplicate_verts": len(bmesh.ops.find_doubles(bm, verts=bm.verts, dist=DUP_DIST)["targetmap"]),
        "duplicate_faces": sum(c - 1 for c in face_keys.values() if c > 1),
        "smooth_faces_pct": r(100 * sum(1 for f in bm.faces if f.smooth) / max(len(bm.faces), 1), 1),
        "shape_keys": [k.name for k in me.shape_keys.key_blocks] if me.shape_keys else [],
        "vertex_groups": len(obj.vertex_groups),
        "uv_layers": [l.name for l in me.uv_layers],
        "color_attributes": [a.name for a in me.color_attributes],
    }

    # Inseln (lose Teile), geschlossen?, Volumen-Vorzeichen (negativ = Normalen nach innen)
    isl_report = []
    for verts in islands(bm):
        vset = set(verts)
        faces = {f for v in verts for f in v.link_faces}
        edges = {e for v in verts for e in v.link_edges}
        closed = bool(faces) and not any(e.is_boundary or not e.link_faces for e in edges)
        vol = 0.0
        for f in faces:
            co = [l.vert.co for l in f.loops]
            for i in range(1, len(co) - 1):
                vol += co[0].dot(co[i].cross(co[i + 1])) / 6.0
        mn = Vector((min(v.co.x for v in vset), min(v.co.y for v in vset), min(v.co.z for v in vset)))
        mx = Vector((max(v.co.x for v in vset), max(v.co.y for v in vset), max(v.co.z for v in vset)))
        isl_report.append({
            "verts": len(vset), "faces": len(faces), "closed": closed,
            "signed_volume": r(vol, 6),
            "inside_out": closed and vol < 0,
            "bbox_local": [r(mn), r(mx)],
        })
    info["islands"] = len(isl_report)
    info["islands_inside_out"] = sum(1 for i in isl_report if i["inside_out"])
    info["islands_open"] = sum(1 for i in isl_report if not i["closed"])
    info["island_details"] = isl_report[:50]

    # Material-Slots und Nutzung
    used = Counter(f.material_index for f in bm.faces)
    slots = []
    for i, s in enumerate(obj.material_slots):
        slots.append({
            "index": i,
            "material": s.material.name if s.material else None,
            "link": s.link,
            "faces": used.get(i, 0),
        })
    info["material_slots"] = slots
    info["faces_on_missing_slot"] = sum(c for i, c in used.items() if i >= len(obj.material_slots))

    info["uv"] = {}
    for layer in bm.loops.layers.uv.values():
        info["uv"][layer.name] = uv_stats(bm, layer, face_areas)
    bm.free()
    return info


# ---------------------------------------------------------------- Materialien/Bilder

def socket_val(node, name):
    s = node.inputs.get(name)
    if s is None or s.is_linked:
        return "linked" if s is not None else None
    v = s.default_value
    try:
        return r(list(v), 3)
    except TypeError:
        return r(v, 3)


def audit_material(mat):
    d = {"name": mat.name, "users": mat.users,
         "surface_render_method": getattr(mat, "surface_render_method", None),
         "blend_method": getattr(mat, "blend_method", None),
         "use_backface_culling": mat.use_backface_culling,
         "diffuse_color": r(list(mat.diffuse_color), 3),
         "images": [], "principled": [], "node_types": []}
    if mat.node_tree:
        d["node_types"] = sorted(Counter(n.bl_idname for n in mat.node_tree.nodes).items())
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                d["images"].append(n.image.name if n.image else None)
            elif n.type == "BSDF_PRINCIPLED":
                d["principled"].append({k: socket_val(n, k) for k in (
                    "Base Color", "Metallic", "Roughness", "Alpha", "Transmission Weight",
                    "Emission Color", "Emission Strength", "Coat Weight", "Sheen Weight",
                    "Subsurface Weight", "Normal")})
    return d


def audit_image(img):
    path = bpy.path.abspath(img.filepath) if img.filepath else ""
    packed = img.packed_file is not None
    exists = packed or (bool(path) and os.path.exists(path)) or img.source in ("GENERATED", "VIEWER")
    return {
        "name": img.name, "source": img.source, "filepath": img.filepath, "abs": path,
        "packed": packed, "exists": exists, "size": list(img.size) if exists else None,
        "colorspace": img.colorspace_settings.name, "alpha_mode": img.alpha_mode,
        "users": img.users,
    }


# ---------------------------------------------------------------- Animation

def audit_action(act):
    fcs = action_fcurves(act)
    start, end = act.frame_range
    jumps, kinks = [], []
    looks_loop = any(h in act.name.lower() for h in LOOP_HINTS) or any(
        m.type == "CYCLES" for fc in fcs for m in fc.modifiers)
    for fc in fcs:
        a, b = fc.evaluate(start), fc.evaluate(end)
        if abs(a - b) > LOOP_TOL:
            jumps.append({"path": fc.data_path, "index": fc.array_index, "start": r(a), "end": r(b)})
        else:
            s0 = fc.evaluate(start + 0.5) - a
            s1 = b - fc.evaluate(end - 0.5)
            if abs(s0 - s1) > LOOP_TOL * 5:
                kinks.append({"path": fc.data_path, "index": fc.array_index,
                              "slope_start": r(s0), "slope_end": r(s1)})
    return {
        "name": act.name, "users": act.users, "frame_range": r([start, end], 2),
        "manual_range": act.use_frame_range, "cyclic_flag": getattr(act, "use_cyclic", None),
        "fcurves": len(fcs),
        "keyframes": sum(len(fc.keyframe_points) for fc in fcs),
        "looks_like_loop": looks_loop,
        "loop_value_jumps": jumps if looks_loop else [],
        "loop_slope_kinks": kinks if looks_loop else [],
        "nonloop_end_differs": len(jumps) if not looks_loop else None,
    }


# ---------------------------------------------------------------- Objekte

def audit_object(o):
    mw = o.matrix_world
    det = mw.to_3x3().determinant()
    d = {
        "name": o.name, "type": o.type, "data": o.data.name if o.data else None,
        "parent": o.parent.name if o.parent else None, "parent_type": o.parent_type if o.parent else None,
        "parent_bone": o.parent_bone or None,
        "children": [c.name for c in o.children],
        "collections": [c.name for c in o.users_collection],
        "location": r(o.location), "rotation_mode": o.rotation_mode,
        "rotation_euler_deg": r([math.degrees(a) for a in o.rotation_euler], 2),
        "scale": r(o.scale),
        "world_det": r(det, 5),
        "hide_render": o.hide_render, "hide_viewport": o.hide_viewport,
        "modifiers": [(m.name, m.type) for m in o.modifiers],
        "constraints": [(c.name, c.type) for c in o.constraints],
        "action": o.animation_data.action.name if o.animation_data and o.animation_data.action else None,
        "nla_tracks": [t.name for t in o.animation_data.nla_tracks] if o.animation_data else [],
        "drivers": len(o.animation_data.drivers) if o.animation_data else 0,
        "flags": [],
    }
    s = o.scale
    if det < 0:
        d["flags"].append("NEGATIVE_SCALE (Normalen erscheinen gespiegelt)")
    if any(abs(x - 1) > 1e-4 for x in s):
        d["flags"].append("SCALE_NOT_APPLIED")
        if max(abs(x) for x in s) - min(abs(x) for x in s) > 1e-4:
            d["flags"].append("NON_UNIFORM_SCALE")
    if o.type == "MESH":
        d["mesh"] = audit_mesh(o)
        m = d["mesh"]
        for key, label in (("islands_inside_out", "NORMALS_INSIDE_OUT"),
                           ("inconsistent_winding_edges", "INCONSISTENT_NORMALS"),
                           ("duplicate_faces", "DUPLICATE_FACES"),
                           ("duplicate_verts", "DUPLICATE_VERTS"),
                           ("loose_verts", "LOOSE_VERTS"), ("loose_edges", "LOOSE_EDGES"),
                           ("degenerate_faces", "DEGENERATE_FACES"),
                           ("nonmanifold_edges_gt2_faces", "NONMANIFOLD_EDGES"),
                           ("faces_on_missing_slot", "FACES_WITHOUT_MATERIAL_SLOT")):
            if m[key]:
                d["flags"].append(f"{label}={m[key]}")
        if m["boundary_edges"]:
            d["flags"].append(f"OPEN_BOUNDARY_EDGES={m['boundary_edges']} (Loch oder gewollt offen?)")
        if not o.material_slots or any(sl["material"] is None for sl in m["material_slots"]):
            d["flags"].append("EMPTY_OR_MISSING_MATERIAL_SLOT")
        if any(sl["faces"] == 0 for sl in m["material_slots"]):
            d["flags"].append("UNUSED_MATERIAL_SLOT")
        if not m["uv_layers"]:
            d["flags"].append("NO_UV")
        for name, u in m["uv"].items():
            if u["faces_zero_uv_area"]:
                d["flags"].append(f"UV[{name}]_ZERO_AREA_FACES={u['faces_zero_uv_area']}")
            if u["faces_distorted_pct"] > 5:
                d["flags"].append(f"UV[{name}]_DISTORTED={u['faces_distorted_pct']}% der Flaechen")
            if u["uv_overlap_pct_of_covered"] > 5:
                d["flags"].append(f"UV[{name}]_OVERLAP={u['uv_overlap_pct_of_covered']}% (gespiegelt = ok?)")
    if o.type == "ARMATURE":
        arm = o.data
        d["bones"] = [{"name": b.name, "parent": b.parent.name if b.parent else None,
                       "deform": b.use_deform, "length": r(b.length)} for b in arm.bones]
    return d


def pet_groups():
    """Pro Pet eine Gruppe: oberste Sammlungen, falls mindestens zwei Meshes enthalten, sonst die Szene."""
    sc = bpy.context.scene
    groups = {}
    for col in sc.collection.children:
        members = [o for o in col.all_objects if o.type == "MESH"]
        if members:
            groups[col.name] = members
    loose = [o for o in sc.collection.objects if o.type == "MESH"]
    if len(groups) >= 2:
        if loose:
            groups["_ohne_Sammlung"] = loose
        return groups
    return {"scene": [o for o in sc.objects if o.type == "MESH"]}


def floating_parts(mesh_objs):
    """Bounding-Box-Heuristik: Inseln, deren Box keine andere Box beruehrt."""
    boxes = []
    for o in mesh_objs:
        if o.hide_render:
            continue
        mw = o.matrix_world
        for i, isl in enumerate(audit_cache[o.name]["mesh"]["island_details"]):
            mn, mx = (Vector(v) for v in isl["bbox_local"])
            corners = [mw @ Vector((x, y, z)) for x in (mn.x, mx.x) for y in (mn.y, mx.y) for z in (mn.z, mx.z)]
            wmn = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
            wmx = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
            boxes.append((f"{o.name}#island{i}", (wmn, wmx)))
    if len(boxes) < 2:
        return []
    out = []
    for name, b in boxes:
        gaps = [bbox_gap(b, ob) for n2, ob in boxes if n2 != name]
        g = min(gaps)
        if g > FLOAT_GAP:
            out.append({"part": name, "min_gap": r(g, 4)})
    return out


audit_cache = {}


def collection_tree(col, depth=0):
    lines = [("  " * depth) + f"- {col.name} ({len(col.objects)} Objekte)"]
    for c in col.children:
        lines.extend(collection_tree(c, depth + 1))
    return lines


def audit_scene(path):
    audit_cache.clear()
    sc = bpy.context.scene
    objs = list(sc.objects)
    report = {
        "file": path,
        "blender_version_file": list(bpy.data.version) if bpy.data.is_saved else None,
        "blender_version_running": bpy.app.version_string,
        "scene": {
            "name": sc.name, "unit_system": sc.unit_settings.system,
            "unit_scale": sc.unit_settings.scale_length,
            "fps": sc.render.fps / sc.render.fps_base,
            "frame_range": [sc.frame_start, sc.frame_end], "engine": sc.render.engine,
        },
        "collections": collection_tree(sc.collection),
        "counts": dict(Counter(o.type for o in objs)),
        "objects": [], "materials": [], "images": [], "actions": [], "node_groups": [],
    }
    for o in objs:
        d = audit_object(o)
        audit_cache[o.name] = d
        report["objects"].append(d)
    mesh_objs = [o for o in objs if o.type == "MESH"]
    report["groups"] = []
    for gname, members in pet_groups().items():
        g = {"name": gname, "mesh_objects": [o.name for o in members],
             "tris": sum(audit_cache[o.name]["mesh"]["tris"] for o in members)}
        bb = world_bbox([o for o in members if not o.hide_render])
        if bb:
            mn, mx = bb
            bottom = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
            g["world_bbox"] = {"min": r(mn), "max": r(mx), "size": r(mx - mn)}
            mset = set(members)
            g["roots"] = [{
                "name": o.name, "type": o.type,
                "offset_from_bottom_center": r(o.matrix_world.translation - bottom),
            } for o in objs if o.parent is None and (o in mset or any(c in mset for c in o.children_recursive))]
        g["floating_parts_heuristic"] = floating_parts(members)
        report["groups"].append(g)
    report["materials"] = [audit_material(m) for m in bpy.data.materials]
    report["images"] = [audit_image(i) for i in bpy.data.images if i.type == "IMAGE"]
    report["actions"] = [audit_action(a) for a in bpy.data.actions]
    report["node_groups"] = [(g.name, g.bl_idname, g.users) for g in bpy.data.node_groups]
    report["missing_images"] = [i["name"] for i in report["images"] if not i["exists"]]
    report["unused_materials"] = [m.name for m in bpy.data.materials if m.users == 0]
    report["mesh_totals"] = {
        "tris": sum(audit_cache[o.name]["mesh"]["tris"] for o in mesh_objs),
        "objects": len(mesh_objs),
    }
    return report


# ---------------------------------------------------------------- Ausgabe

def to_markdown(rep):
    L = [f"# Bestandsaufnahme: `{os.path.basename(rep['file'])}`", ""]
    s = rep["scene"]
    L += [f"- Datei-Version: {rep['blender_version_file']} · geprueft mit Blender {rep['blender_version_running']}",
          f"- Einheiten: {s['unit_system']} × {s['unit_scale']} · {s['fps']} fps · Frames {s['frame_range']}",
          f"- Objekte: {rep['counts']} · Dreiecke gesamt: {rep['mesh_totals']['tris']}"]
    L += ["", "## Sammlungen", *rep["collections"], "", "## Pet-Gruppen", ""]
    for g in rep["groups"]:
        L.append(f"### {g['name']} – {len(g['mesh_objects'])} Mesh-Objekte, {g['tris']} Dreiecke")
        if "world_bbox" in g:
            L.append(f"- Groesse (Welt, X×Y×Z): {g['world_bbox']['size']} · Boden bei Z={g['world_bbox']['min'][2]}")
            for ro in g["roots"]:
                L.append(f"- Wurzel `{ro['name']}` ({ro['type']}): Ursprung relativ zur Boden-Mitte {ro['offset_from_bottom_center']}")
        if g["floating_parts_heuristic"]:
            L.append("- Moeglicherweise schwebende Teile (Bounding-Box-Heuristik, visuell pruefen):")
            L += [f"  - {f['part']}: Abstand {f['min_gap']}" for f in g["floating_parts_heuristic"]]
        L.append("")
    L += ["## Befunde pro Objekt", ""]
    L.append("| Objekt | Typ | Eltern | Tris | Inseln | Befunde |")
    L.append("|---|---|---|---:|---:|---|")
    for o in rep["objects"]:
        m = o.get("mesh", {})
        L.append(f"| {o['name']} | {o['type']} | {o['parent'] or '–'} | {m.get('tris', '')} | "
                 f"{m.get('islands', '')} | {'<br>'.join(o['flags']) or 'ok'} |")
    L += ["", "## Materialien", "", "| Material | Nutzer | Render-Methode | Bilder | Principled-Werte |", "|---|---:|---|---|---|"]
    for m in rep["materials"]:
        pv = "; ".join(", ".join(f"{k}={v}" for k, v in p.items() if v is not None) for p in m["principled"])
        L.append(f"| {m['name']} | {m['users']} | {m['surface_render_method']} | {', '.join(map(str, m['images'])) or '–'} | {pv or '–'} |")
    L += ["", "## Bilder", "", "| Bild | Gepackt | Vorhanden | Groesse | Farbraum | Pfad |", "|---|---|---|---|---|---|"]
    for i in rep["images"]:
        L.append(f"| {i['name']} | {i['packed']} | {'ja' if i['exists'] else '**FEHLT**'} | {i['size']} | {i['colorspace']} | `{i['filepath']}` |")
    L += ["", "## Animationen", ""]
    if not rep["actions"]:
        L.append("Keine Actions vorhanden.")
    for a in rep["actions"]:
        L.append(f"- **{a['name']}** Frames {a['frame_range']}, {a['fcurves']} Kurven, {a['keyframes']} Keys, "
                 f"Loop-Kandidat: {a['looks_like_loop']}, Wertspruenge am Loop: {len(a['loop_value_jumps'])}, "
                 f"Knicke am Loop: {len(a['loop_slope_kinks'])}")
        for j in a["loop_value_jumps"][:10]:
            L.append(f"  - Sprung {j['path']}[{j['index']}]: {j['start']} → {j['end']}")
    if rep["missing_images"]:
        L += ["", f"**Fehlende Bilddateien:** {', '.join(rep['missing_images'])}"]
    if rep["unused_materials"]:
        L += ["", f"Unbenutzte Materialien: {', '.join(rep['unused_materials'])}"]
    return "\n".join(L) + "\n"


def main():
    args = parse_args()
    os.makedirs(args.out, exist_ok=True)
    summary = ["# Zusammenfassung Bestandsaufnahme", "",
               "| Datei | Mesh-Objekte | Tris | Objekte mit Befund | Fehlende Bilder | Actions |",
               "|---|---:|---:|---:|---:|---:|"]
    for f in args.files:
        f = os.path.abspath(f)
        name = os.path.splitext(os.path.basename(f))[0]
        dst = os.path.join(args.out, name)
        os.makedirs(dst, exist_ok=True)
        try:
            load_file(f)
            rep = audit_scene(f)
        except Exception as e:  # eine kaputte Datei darf den Lauf nicht abbrechen
            msg = " ".join(str(e).split()).replace("|", "/")
            summary.append(f"| {name} | FEHLER: {msg} | | | | |")
            print(f"[audit] {f}: FEHLER {e}")
            continue
        with open(os.path.join(dst, "audit.json"), "w", encoding="utf-8") as fh:
            json.dump(rep, fh, indent=1, ensure_ascii=False, default=str)
        with open(os.path.join(dst, "audit.md"), "w", encoding="utf-8") as fh:
            fh.write(to_markdown(rep))
        flagged = sum(1 for o in rep["objects"] if o["flags"])
        summary.append(f"| {name} | {rep['mesh_totals']['objects']} | {rep['mesh_totals']['tris']} | "
                       f"{flagged} | {len(rep['missing_images'])} | {len(rep['actions'])} |")
        print(f"[audit] {f}: ok -> {dst}")
    with open(os.path.join(args.out, "summary.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(summary) + "\n")


if __name__ == "__main__":
    main()
