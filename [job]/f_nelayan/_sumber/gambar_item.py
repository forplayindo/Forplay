# Gambar item inventory dari model 3D (latar transparan, 256x256).
# blender -b --factory-startup -P gambar_item.py -- <file.glb> <out.png> [sudut_derajat]
import bpy, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
src, out = argv[0], argv[1]
yaw = math.radians(float(argv[2]) if len(argv) > 2 else 35.0)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
meshes = [o for o in sc.objects if o.type == 'MESH']

for m in bpy.data.materials:  # logam polos tampak hitam tanpa pantulan lingkungan
    if m.node_tree:
        for n in m.node_tree.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                n.inputs['Metallic'].default_value = 0.0

deps = bpy.context.evaluated_depsgraph_get()
pts = []
for inst in deps.object_instances:
    if inst.object.type == 'MESH':
        mw = inst.matrix_world.copy()
        me = inst.object.data
        step = max(1, len(me.vertices) // 4000)
        pts += [mw @ me.vertices[i].co for i in range(0, len(me.vertices), step)]
mn = Vector([min(p[k] for p in pts) for k in range(3)])
mx = Vector([max(p[k] for p in pts) for k in range(3)])
c = (mn + mx) / 2
r = (mx - mn).length / 2

for e in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE', 'BLENDER_WORKBENCH'):
    try:
        sc.render.engine = e
        break
    except Exception:
        pass
sc.render.resolution_x = sc.render.resolution_y = 256
sc.render.film_transparent = True
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
sc.world = bpy.data.worlds.new('w')
sc.world.color = (0.8, 0.8, 0.8)

cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = r * 2.15
d = r * 4
cam.location = c + Vector((math.sin(yaw) * d, -math.cos(yaw) * d, d * 0.45))
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.clip_end = d * 10
sc.camera = cam
for rot, energy in (((math.radians(45), 0, math.radians(30)), 4.0), ((math.radians(60), 0, math.radians(200)), 1.5)):
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = energy
    sun.rotation_euler = rot
    sc.collection.objects.link(sun)
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
