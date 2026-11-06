# Ikon item ox_inventory dari glb (latar transparan).
# blender -b --factory-startup --python render_icon.py -- <in.glb> <out.png> [ukuran]
import bpy, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
src, dst = argv[:2]
size = int(argv[2]) if len(argv) > 2 else 256

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = size
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'Standard'

world = bpy.data.worlds.new('w'); sc.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8

mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
for o in sc.objects:
    if o.type == 'MESH':
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
c = (mn + mx) / 2; r = (mx - mn).length / 2

cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'; cam.data.ortho_scale = r * 1.6
cam.location = c + Vector((0, -r * 3, r * 2.6))
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam

sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (0.6, 0.3, 0.4)

sc.render.filepath = dst
bpy.ops.render.render(write_still=True)
