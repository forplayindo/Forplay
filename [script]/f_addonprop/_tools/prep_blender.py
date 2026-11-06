# Blender (headless): kurangi polygon glb + ekspor tekstur ke DDS + render preview.
# blender -b --factory-startup --python prep_blender.py -- <in.glb> <out.glb> <out_dir> <prefix> <noodle_cap> <container_cap> <other_cap>
import bpy, sys, os, struct, math
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
src, dst, outdir, prefix = argv[:4]
cap_noodle, cap_cont, cap_other = map(int, argv[4:7])
VOXEL = float(argv[7]) if len(argv) > 7 else 0
os.makedirs(outdir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']

NOODLE = {'mie', 'mie_goreng'}
CONTAINER = {'piring', 'dinding_luar', 'dinding_dalam', 'kaki_mangkok'}

def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)

def setup_render(tag):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'TEXTURE'
    sc.render.resolution_x, sc.render.resolution_y = 900, 600
    sc.render.film_transparent = False
    for m in bpy.data.materials:
        if m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == 'BSDF_PRINCIPLED':
                    m.diffuse_color = n.inputs['Base Color'].default_value
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    c = (mn + mx) / 2; r = (mx - mn).length / 2
    cam = bpy.data.objects.get('PrevCam')
    if not cam:
        cam = bpy.data.objects.new('PrevCam', bpy.data.cameras.new('PrevCam'))
        sc.collection.objects.link(cam)
    cam.location = c + Vector((0, -r * 1.9, r * 1.5))
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(outdir, '%s_%s.png' % (prefix, tag))
    bpy.ops.render.render(write_still=True)

setup_render('sebelum')

total = 0
for o in meshes:
    t = tris(o)
    cap = cap_noodle if o.name in NOODLE else cap_cont if o.name in CONTAINER else cap_other
    if o.name in NOODLE and VOXEL > 0:
        # untaian mie = ribuan tabung tipis; collapse langsung jadi serpihan -> gabung dulu jadi 1 permukaan
        rm = o.modifiers.new('rm', 'REMESH')
        rm.mode = 'VOXEL'; rm.voxel_size = VOXEL; rm.use_smooth_shade = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=rm.name)
        print('REMESH', o.name, t, '->', tris(o))
        t = tris(o)
    if t > cap:
        mod = o.modifiers.new('dec', 'DECIMATE')
        if o.name in CONTAINER:
            # collapse merusak lekukan piring -> makanan tembus; planar hanya membuang bidang datar
            mod.decimate_type = 'DISSOLVE'
            mod.angle_limit = math.radians(1.5)
        else:
            mod.decimate_type = 'COLLAPSE'
            mod.ratio = cap / t
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    print('MESH %-18s %7d -> %6d' % (o.name, t, tris(o)))
    total += tris(o)
print('TOTAL', total)

setup_render('sesudah')

# tekstur -> DDS A8R8G8B8 + mipmap, nama = <prefix>_<material>.dds, lebar maks 1024 (pow2)
def pow2(n):
    return 1 << max(2, int(round(math.log2(n))))

def write_dds(path, img):
    w, h = img.size
    tw = min(1024, pow2(w)); th = max(4, pow2(h * tw / w))
    im = img.copy(); im.scale(tw, th)
    px = np.array(im.pixels[:], dtype=np.float32).reshape(th, tw, 4)[::-1]  # Blender: baris bawah dulu
    levels = [px]
    while levels[-1].shape[0] > 1 or levels[-1].shape[1] > 1:
        a = levels[-1]
        if a.shape[0] > 1: a = (a[0::2] + a[1::2]) / 2
        if a.shape[1] > 1: a = (a[:, 0::2] + a[:, 1::2]) / 2
        levels.append(a)
    data = b''.join((np.clip(l, 0, 1) * 255 + 0.5).astype(np.uint8)[..., [2, 1, 0, 3]].tobytes() for l in levels)
    hdr = struct.pack('<4s7I', b'DDS ', 124, 0x2100F, th, tw, tw * 4, 0, len(levels)) + b'\0' * 44
    hdr += struct.pack('<2I4s5I', 32, 0x41, b'\0\0\0\0', 32, 0xFF0000, 0xFF00, 0xFF, 0xFF000000)
    hdr += struct.pack('<5I', 0x401008, 0, 0, 0, 0)
    open(path, 'wb').write(hdr + data)
    print('DDS', os.path.basename(path), tw, th, 'mips', len(levels))

for m in bpy.data.materials:
    if not m.node_tree: continue
    for n in m.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image:
            write_dds(os.path.join(outdir, '%s_%s.dds' % (prefix, m.name)), n.image)
            break

bpy.data.objects.remove(bpy.data.objects['PrevCam'])
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_apply=True, export_yup=True)
