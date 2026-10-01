"""Mehrfachansichten + Kontaktbogen fuer Pet-Dateien – komplett in Blender, speichert keine .blend.

Aufruf:
    blender -b --factory-startup --python tools/blender/pet_views.py -- <dateien...> --out <ordner>
    python tools/blender/pet_views.py <dateien...> --out <ordner>        (bpy-Modul)

Pro Pet-Gruppe entsteht <out>/<datei>/<gruppe>/sheet.png (3 Zeilen × 6 Spalten) plus Einzelbilder.
Die Beleuchtung haengt nur von der Bounding-Box ab, damit Vorher- und Nachher-Bilder
unter identischen Bedingungen entstehen. Der Hintergrund aendert nur, was die Kamera sieht,
nicht das Licht auf dem Pet.

Zeile 1 – Material, heller Hintergrund: FRONT, RIGHT, BACK, 3Q, 3Q_BACK, TOP
Zeile 2 – Material, dunkler Hintergrund: FRONT, 3Q, CLOSE, SMALL (96 px), Silhouette 3Q, Silhouette FRONT
Zeile 3 – Clay/Normalen: CLAY FRONT, CLAY RIGHT, CLAY 3Q, NORMALS 3Q, NORMALS 3Q_BACK, NORMALS TOP
          (NORMALS: grau = korrekt, rot = Rueckseite sichtbar → gekippte Normale oder offene Flaeche)
"""

import argparse
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pet_audit import load_file, world_bbox  # noqa: E402

RIG = "AUDIT_RIG"
BG_LIGHT = (0.80, 0.82, 0.85)
BG_DARK = (0.035, 0.038, 0.045)
AMBIENT = 0.30
SMALL_PX = 96

# Name: (Azimut°, Elevation°) – Azimut 0 = Blick von vorn (-Y), 90 = von rechts (+X)
VIEWS = {
    "FRONT": (0, 0), "RIGHT": (90, 0), "BACK": (180, 0), "TOP": (0, 89.9),
    "3Q": (35, 18), "3Q_BACK": (215, 18), "CLOSE": (25, 12),
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    p = argparse.ArgumentParser()
    p.add_argument("files", nargs="+")
    p.add_argument("--out", required=True)
    p.add_argument("--engine", default="CYCLES", choices=["CYCLES", "BLENDER_EEVEE"])
    p.add_argument("--res", type=int, default=512)
    p.add_argument("--samples", type=int, default=24)
    p.add_argument("--group", default="auto", choices=["auto", "scene", "collection"])
    return p.parse_args(argv)


# ---------------------------------------------------------------- Gruppen

def renderable(o):
    return o.type in {"MESH", "CURVE", "SURFACE", "META", "FONT", "CURVES", "POINTCLOUD", "VOLUME"}


def find_groups(mode, imported):
    sc = bpy.context.scene
    objs = [o for o in sc.objects if renderable(o) and not o.hide_render]
    if mode == "scene" or (mode == "auto" and imported):
        return {"scene": objs}
    groups = {}
    for col in sc.collection.children:
        members = [o for o in col.all_objects if renderable(o) and not o.hide_render]
        if members:
            groups[col.name] = members
    if mode == "collection" or len(groups) >= 2:
        loose = [o for o in sc.collection.objects if renderable(o) and not o.hide_render]
        if loose:
            groups["_ohne_Sammlung"] = loose
        return groups
    return {"scene": objs}


# ---------------------------------------------------------------- Rig

def ensure_rig():
    sc = bpy.context.scene
    col = bpy.data.collections.get(RIG) or bpy.data.collections.new(RIG)
    if col.name not in sc.collection.children:
        sc.collection.children.link(col)
    cam = bpy.data.objects.get("AUDIT_Cam")
    if cam is None:
        cam = bpy.data.objects.new("AUDIT_Cam", bpy.data.cameras.new("AUDIT_Cam"))
        col.objects.link(cam)
    lights = {}
    for name, size in (("AUDIT_Key", 1.0), ("AUDIT_Fill", 2.0), ("AUDIT_Rim", 0.6)):
        o = bpy.data.objects.get(name)
        if o is None:
            ld = bpy.data.lights.new(name, "AREA")
            o = bpy.data.objects.new(name, ld)
            col.objects.link(o)
        o.data.size = size
        lights[name] = o
    sc.camera = cam

    # Welt: konstantes Umgebungslicht, Kamera sieht separate Hintergrundfarbe
    w = bpy.data.worlds.get("AUDIT_World") or bpy.data.worlds.new("AUDIT_World")
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    lp = nt.nodes.new("ShaderNodeLightPath")
    amb = nt.nodes.new("ShaderNodeBackground")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.name = "BG"
    mix = nt.nodes.new("ShaderNodeMixShader")
    amb.inputs["Color"].default_value = (AMBIENT, AMBIENT, AMBIENT, 1)
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(amb.outputs[0], mix.inputs[1])
    nt.links.new(bg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    sc.world = w

    # Normalen-Pruefmaterial: Vorderseite grau-blau, Rueckseite rot
    m = bpy.data.materials.get("AUDIT_Normals") or bpy.data.materials.new("AUDIT_Normals")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    front = nt.nodes.new("ShaderNodeBsdfDiffuse")
    back = nt.nodes.new("ShaderNodeEmission")
    mix = nt.nodes.new("ShaderNodeMixShader")
    front.inputs["Color"].default_value = (0.16, 0.18, 0.22, 1)
    back.inputs["Color"].default_value = (1, 0.02, 0.02, 1)
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(front.outputs[0], mix.inputs[1])
    nt.links.new(back.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], o.inputs["Surface"])
    return cam, lights


def place(obj, center, az, el, dist):
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    obj.location = center + d * dist
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (center - obj.location).to_track_quat("-Z", "Y")


def light_rig(lights, center, radius):
    # Fest relativ zum Pet (nicht zur Kamera) – vergleichbar ueber alle Ansichten und Versionen
    for name, az, el, power, size in (("AUDIT_Key", -40, 45, 900, 1.2),
                                      ("AUDIT_Fill", 60, 15, 300, 2.5),
                                      ("AUDIT_Rim", 160, 35, 500, 0.8)):
        o = lights[name]
        place(o, center, az, el, radius * 4)
        o.data.size = size * radius
        o.data.energy = power * radius * radius


# ---------------------------------------------------------------- Render

def configure(engine, res, samples):
    sc = bpy.context.scene
    r = sc.render
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = False
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGB"
    sc.view_settings.look = "None"
    r.use_stamp = True
    for f in ("date", "time", "render_time", "frame", "frame_range", "memory", "hostname", "camera",
              "lens", "scene", "marker", "filename", "sequencer_strip"):
        setattr(r, f"use_stamp_{f}", False)
    r.use_stamp_note = True
    r.stamp_font_size = max(12, res // 32)
    r.stamp_foreground = (1, 1, 1, 1)
    r.stamp_background = (0, 0, 0, 0.85)
    if engine == "CYCLES":
        sc.cycles.device = "CPU"
        sc.cycles.samples = samples
        sc.cycles.use_denoising = bool(getattr(bpy.app.build_options, "openimagedenoise", False))
        sc.cycles.max_bounces = 6
        sc.cycles.transmission_bounces = 6


def shoot(path, label, engine, res, workbench=None, override=None, bg=BG_LIGHT, cam_res=None):
    sc = bpy.context.scene
    r = sc.render
    r.engine = "BLENDER_WORKBENCH" if workbench else engine
    # AgX fuer Material-Ansichten (Spitzlichter), Standard fuer technische Pruefbilder
    sc.view_settings.view_transform = "Standard" if (workbench or override) else "AgX"
    r.resolution_x = r.resolution_y = cam_res or res
    r.stamp_note_text = label
    r.use_stamp = cam_res is None
    sc.view_layers[0].material_override = override
    sc.world.node_tree.nodes["BG"].inputs["Color"].default_value = (*bg, 1)
    if workbench:
        sh = sc.display.shading
        sh.light, sh.color_type = workbench["light"], "SINGLE"
        sh.single_color = workbench["color"]
        sh.show_cavity = workbench.get("cavity", False)
        sh.cavity_type = "BOTH"
        sc.world.color = workbench["bg"]
        sc.display.render_aa = "8"
    r.filepath = path
    bpy.ops.render.render(write_still=True)
    sc.view_layers[0].material_override = None
    return path


def load_px(path, size):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    a = a.reshape(h, w, 4)
    if (w, h) != (size, size):  # Nearest-Neighbour: zeigt die echte Kleinansicht
        ys = (np.arange(size) * h / size).astype(int)
        xs = (np.arange(size) * w / size).astype(int)
        a = a[ys][:, xs]
    return a


def compose(rows, path, cell):
    H, W = len(rows) * cell, max(len(r) for r in rows) * cell
    sheet = np.ones((H, W, 4), dtype=np.float32)
    for ri, row in enumerate(rows):
        y0 = H - (ri + 1) * cell  # Blender-Pixel beginnen unten links
        for ci, p in enumerate(row):
            sheet[y0:y0 + cell, ci * cell:(ci + 1) * cell] = load_px(p, cell)
    img = bpy.data.images.new("AUDIT_Sheet", W, H, alpha=False)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def render_group(name, members, out, a):
    sc = bpy.context.scene
    cam, lights = ensure_rig()
    keep = set(members) | set(bpy.data.collections[RIG].objects)
    hidden = []
    for o in sc.objects:
        if o not in keep and not o.hide_render and (renderable(o) or o.type == "LIGHT"):
            o.hide_render = True
            hidden.append(o)
    bb = world_bbox(members)
    if bb is None:
        for o in hidden:
            o.hide_render = False
        return None
    mn, mx = bb
    center, size = (mn + mx) / 2, mx - mn
    radius = max(size.length / 2, 1e-3)
    light_rig(lights, center, radius)
    cam.data.type = "ORTHO"
    cam.data.clip_start, cam.data.clip_end = radius * 0.01, radius * 20

    d = os.path.join(out, bpy.path.clean_name(name))
    os.makedirs(d, exist_ok=True)
    P = lambda n: os.path.join(d, n + ".png")

    def aim(view, close=False):
        az, el = VIEWS[view]
        if close:  # obere 45 % der Box (Kopfbereich bei den meisten Pets)
            c = Vector((center.x, center.y, mn.z + size.z * 0.78))
            place(cam, c, az, el, radius * 6)
            cam.data.ortho_scale = max(size.x, size.y, size.z) * 0.6
        else:
            place(cam, center, az, el, radius * 6)
            cam.data.ortho_scale = radius * 2.15

    wb_clay = {"light": "STUDIO", "color": (0.8, 0.78, 0.75), "cavity": True, "bg": (0.35, 0.36, 0.38)}
    wb_sil = {"light": "FLAT", "color": (0, 0, 0), "bg": (1, 1, 1)}
    norm = bpy.data.materials["AUDIT_Normals"]
    E = a.engine
    row1, row2, row3 = [], [], []
    for v in ("FRONT", "RIGHT", "BACK", "3Q", "3Q_BACK", "TOP"):
        aim(v)
        row1.append(shoot(P(f"mat_light_{v}"), f"{name} - {v}", E, a.res))
    for v in ("FRONT", "3Q"):
        aim(v)
        row2.append(shoot(P(f"mat_dark_{v}"), f"{v} dunkel", E, a.res, bg=BG_DARK))
    aim("CLOSE", close=True)
    row2.append(shoot(P("mat_dark_CLOSE"), "Nah (oberer Bereich)", E, a.res, bg=BG_DARK))
    aim("3Q")
    row2.append(shoot(P("mat_small_3Q"), "", E, a.res, cam_res=SMALL_PX))
    row2.append(shoot(P("sil_3Q"), "Silhouette 3Q", E, a.res, workbench=wb_sil))
    aim("FRONT")
    row2.append(shoot(P("sil_FRONT"), "Silhouette FRONT", E, a.res, workbench=wb_sil))
    for v in ("FRONT", "RIGHT", "3Q"):
        aim(v)
        row3.append(shoot(P(f"clay_{v}"), f"Clay {v}", E, a.res, workbench=wb_clay))
    for v in ("3Q", "3Q_BACK", "TOP"):
        aim(v)
        row3.append(shoot(P(f"normals_{v}"), f"Normalen {v} (rot=Rueckseite)", E, a.res, override=norm))
    sheet = os.path.join(d, "sheet.png")
    compose([row1, row2, row3], sheet, a.res)
    for o in hidden:
        o.hide_render = False
    return sheet


def main():
    a = parse_args()
    for f in a.files:
        f = os.path.abspath(f)
        load_file(f)
        configure(a.engine, a.res, a.samples)
        imported = not f.lower().endswith(".blend")
        out = os.path.join(a.out, os.path.splitext(os.path.basename(f))[0])
        for gname, members in find_groups(a.group, imported).items():
            s = render_group(gname, members, out, a)
            print(f"[views] {f} · {gname}: {s}")


if __name__ == "__main__":
    main()
