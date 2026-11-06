# Ikon item ox_inventory dari ydr yang sudah diekspor ke XML (cw.ps1 export <file.ydr> <folder>).
# blender -b --factory-startup --python render_icon_ydr.py -- <file.ydr.xml> <out.png> [ukuran]
# Tekstur dicari di <folder xml>/<nama ydr>/<DiffuseSampler>.dds (folder hasil export CodeWalker).
import bpy, sys, os
import xml.etree.ElementTree as ET
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
src, dst = argv[:2]
size = int(argv[2]) if len(argv) > 2 else 256
texdir = os.path.join(os.path.dirname(src), os.path.basename(src).split('.')[0])

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
root = ET.parse(src).getroot()

# shader -> material Blender (tekstur DiffuseSampler kalau ada)
mats = []
for si, sh in enumerate(root.find('ShaderGroup/Shaders')):
    m = bpy.data.materials.new('sh%d' % si)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = 0.6
    for p in sh.find('Parameters'):
        if p.get('name') == 'DiffuseSampler' and p.find('Name') is not None:
            f = os.path.join(texdir, p.find('Name').text + '.dds')
            if os.path.exists(f):
                tex = m.node_tree.nodes.new('ShaderNodeTexImage')
                tex.image = bpy.data.images.load(f)
                m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    mats.append(m)

SIZES = {'Position': 3, 'Normal': 3, 'Colour0': 4, 'Colour1': 4, 'Tangent': 4, 'BlendWeights': 4, 'BlendIndices': 4,
         'TexCoord0': 2, 'TexCoord1': 2, 'TexCoord2': 2, 'TexCoord3': 2}
for gi, g in enumerate(root.iter('Geometries')):
    for geo in g:
        vb = geo.find('VertexBuffer')
        layout = [e.tag for e in vb.find('Layout')]
        data = (vb.find('Data2') if vb.find('Data2') is not None else vb.find('Data')).text.strip().splitlines()
        pi, ti = layout.index('Position'), layout.index('TexCoord0') if 'TexCoord0' in layout else None
        verts, uvs = [], []
        for ln in data:
            parts = ln.strip().split('   ')
            verts.append(tuple(map(float, parts[pi].split())))
            if ti is not None:
                u, v = map(float, parts[ti].split()); uvs.append((u, 1 - v))
        idx = list(map(int, geo.find('IndexBuffer/Data').text.split()))
        faces = [tuple(idx[k:k + 3]) for k in range(0, len(idx), 3)]
        me = bpy.data.meshes.new('g'); me.from_pydata(verts, [], faces)
        if uvs:
            uvl = me.uv_layers.new()
            for loop in me.loops: uvl.data[loop.index].uv = uvs[loop.vertex_index]
        me.materials.append(mats[int(geo.find('ShaderIndex').get('value'))])
        for p in me.polygons: p.use_smooth = True
        sc.collection.objects.link(bpy.data.objects.new('g', me))
    break  # hanya DrawableModelsHigh

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
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
c = (mn + mx) / 2; r = (mx - mn).length / 2
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'; cam.data.ortho_scale = r * 1.6
cam.location = c + Vector((0, -r * 3, r * 2.6))   # GTA: Z atas, kamera dari -Y (depan)
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (0.6, 0.3, 0.4)
sc.render.filepath = dst
bpy.ops.render.render(write_still=True)
