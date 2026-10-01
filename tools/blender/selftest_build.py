"""Baut eine Testdatei mit absichtlich eingebauten Fehlern, um pet_audit.py/pet_views.py zu pruefen.

    python tools/blender/selftest_build.py <ziel.blend>

Sammlung TestPet_Broken enthaelt bekannte Fehler, TestPet_Clean ist die fehlerfreie Kontrolle.
Das sind KEINE Spiel-Pets, nur Pruefkoerper fuer die Werkzeuge.
"""

import os
import sys

import bpy  # muss vor bmesh/mathutils geladen werden (bpy-Modul)
import bmesh

target = (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])[0]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def coll(name):
    c = bpy.data.collections.new(name)
    sc.collection.children.link(c)
    return c


def mesh_obj(name, col, build, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    col.objects.link(o)
    for p in me.polygons:
        p.use_smooth = True
    return o


def parent_keep(child, parent):
    bpy.context.view_layer.update()  # sonst ist matrix_world neuer Objekte noch die Einheitsmatrix
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def sphere(r, z=0.0):
    def b(bm):
        bm.loops.layers.uv.new("UVMap")
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=r, calc_uvs=True)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, z))
    return b


def cone(r, d):
    def b(bm):
        bm.loops.layers.uv.new("UVMap")
        bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=r, radius2=0.0, depth=d, calc_uvs=True)
    return b


def mat(name, color, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.5
    if image:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def loop_action(obj, name, z_vals):
    for f, z in z_vals:
        obj.location.z = z
        obj.keyframe_insert("location", index=2, frame=f)
    obj.animation_data.action.name = name


fur = mat("M_Fur", (0.9, 0.6, 0.3))
eye = mat("M_Eye", (0.02, 0.02, 0.03))

# ------------------------------------------------ fehlerhaftes Pet
cb = coll("TestPet_Broken")
missing = bpy.data.images.new("T_Fur_Missing", 8, 8)
missing.source = "FILE"
missing.filepath = "//textures/fur_missing.png"
body = mesh_obj("Broken_Body", cb, sphere(0.5, 0.5))
body.data.materials.append(mat("M_Fur_Tex", (1, 1, 1), missing))
bm = bmesh.new(); bm.from_mesh(body.data)
bm.verts.new((0.0, 0.0, 1.4))                      # loser Vertex
bm.to_mesh(body.data); bm.free()

head = mesh_obj("Broken_Head", cb, sphere(0.35), loc=(0, -0.2, 1.05))
head.scale = (1.2, 1.2, 1.2)                        # Skalierung nicht angewendet
head.data.materials.append(fur)
head.data.materials.append(None)                    # leerer Slot
bm = bmesh.new(); bm.from_mesh(head.data)
bmesh.ops.reverse_faces(bm, faces=list(bm.faces)[:3])  # einzelne gekippte Flaechen
bm.to_mesh(head.data); bm.free()

ear_l = mesh_obj("Broken_Ear_L", cb, cone(0.12, 0.3), loc=(-0.22, -0.2, 1.45))
bm = bmesh.new(); bm.from_mesh(ear_l.data)
bmesh.ops.reverse_faces(bm, faces=bm.faces)         # Normalen nach innen
bm.to_mesh(ear_l.data); bm.free()
ear_l.data.materials.append(fur)

ear_r = mesh_obj("Broken_Ear_R", cb, cone(0.12, 0.3), loc=(0.22, -0.2, 1.45))
bm = bmesh.new(); bm.from_mesh(ear_r.data)
geo = bmesh.ops.duplicate(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces))  # doppelte Flaechen
bm.to_mesh(ear_r.data); bm.free()
ear_r.data.materials.append(fur)


def tail(bm):
    bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.08, radius2=0.08, depth=0.4, calc_uvs=True)
    top = [f for f in bm.faces if f.calc_center_median().z > 0.19]
    bmesh.ops.delete(bm, geom=top, context="FACES_ONLY")  # Loch


tl = mesh_obj("Broken_Tail", cb, tail, loc=(0, 0.55, 0.5))
tl.rotation_euler = (1.2, 0, 0)
tl.data.materials.append(fur)

paw = mesh_obj("Broken_Paw_L", cb, sphere(0.12), loc=(-0.25, -0.15, 0.08))
paw.scale = (-1, 1, 1)                              # negative Skalierung
paw.data.materials.append(fur)

eye_float = mesh_obj("Broken_Eye_Floating", cb, sphere(0.06), loc=(0.15, -1.2, 1.15))  # schwebt
eye_float.data.materials.append(eye)
for o in (head, ear_l, ear_r, tl, paw, eye_float):
    parent_keep(o, body)
loop_action(body, "Broken_Idle_Loop", [(1, 0.0), (60, 0.08), (120, 0.03)])  # Sprung am Loop-Ende

# ------------------------------------------------ fehlerfreie Kontrolle
cc = coll("TestPet_Clean")
cbody = mesh_obj("Clean_Body", cc, sphere(0.5, 0.5), loc=(3, 0, 0))
cbody.data.materials.append(fur)
chead = mesh_obj("Clean_Head", cc, sphere(0.42), loc=(3, -0.2, 1.05))
chead.data.materials.append(fur)
for x in (-0.15, 0.15):
    e = mesh_obj(f"Clean_Eye_{'L' if x < 0 else 'R'}", cc, sphere(0.07), loc=(3 + x, -0.58, 1.12))
    e.data.materials.append(eye)
    parent_keep(e, chead)
parent_keep(chead, cbody)
loop_action(cbody, "Clean_Idle_Loop", [(1, 0.0), (60, 0.08), (120, 0.0)])

os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=target)
print("[selftest] gespeichert:", target)
