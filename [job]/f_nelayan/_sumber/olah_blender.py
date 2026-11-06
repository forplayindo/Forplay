# Olah glb mentah (AI, ratusan ribu segitiga) jadi glb ringan untuk GTA.
# blender -b -P olah_blender.py -- <folder_materi> <folder_build> [nama_file.glb ...]
# Benang jaring -> voxel remesh (lubang tertutup) + decimate + UV tile; tampil lewat tekstur jaring alpha (cutout).
# Bagian padat (ikan, peti, pelampung, tali) -> decimate per material sesuai jatah segitiga.
import bpy, bmesh, sys, os, math
import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = set(argv[2:])
os.makedirs(OUT, exist_ok=True)

# file -> (model, jatah segitiga total, buang tutup bawah kulit jaring, ukuran 1 tile tekstur jaring (m), jatah peti)
PROPS = {
    'jaring ditangan.glb': ('f_nelayan_jaring_tangan', 2500, False, 0.12, 0),
    'jaring dilempar.glb': ('f_nelayan_jaring_lempar', 3000, True,  0.36, 0),
    'jaring dilaut.glb':   ('f_nelayan_jaring_laut',   2500, False, 0.40, 0),
    'jaring isi ikan.glb': ('f_nelayan_jaring_ikan',   9000, False, 0.20, 0),
    'ikan di peti.glb':    ('f_nelayan_peti_ikan',     5000, False, None, 2500),
    'tumpukan peti.glb':   ('f_nelayan_peti_tumpuk',   9000, False, None, 5000),
}
NET_SHARE = 0.35       # porsi jatah untuk permukaan jaring
EYE_TRIS = 200         # mata ikan cukup titik kecil
CRATE_VOXEL = 0.004    # per peti; lubang ventilasi masih terbuka
EMPTY_CRATE = ('ikan di peti.glb', 'crate_blue_hdpe', 'f_nelayan_peti_kosong')

def is_net(name):
    n = name.lower()
    return 'nylon' in n or n.startswith('net')

def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def select_only(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]

FISH_SILVER = (0.672, 0.723, 0.761)
FISH_BACK = (0.044, 0.072, 0.107)

def bsdf_of(mat):
    if mat and mat.node_tree:
        return next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)

def set_flat_colour(mat, rgb):
    b = bsdf_of(mat)
    if not b:
        return
    for l in list(b.inputs['Base Color'].links):
        mat.node_tree.links.remove(l)
    b.inputs['Base Color'].default_value = (*rgb, 1.0)

def split_vertex_colour(obj):
    """Ikan AI: warna dasar putih x vertex color. Shader GTA tidak memakai vertex color sebagai warna,
    jadi muka gelap dipindah ke material punggung, sisanya perak."""
    me = obj.data
    if not me.color_attributes:
        return
    ca = me.color_attributes[0]
    col = np.empty(len(ca.data) * 4, np.float32)
    ca.data.foreach_get('color', col)
    lum = col.reshape(-1, 4)[:, :3] @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    if ca.domain == 'POINT':
        vi = np.empty(len(me.loops), np.int32)
        me.loops.foreach_get('vertex_index', vi)
        lum = lum[vi]
    npoly = len(me.polygons)
    start = np.empty(npoly, np.int32); me.polygons.foreach_get('loop_start', start)
    total = np.empty(npoly, np.int32); me.polygons.foreach_get('loop_total', total)
    face = np.add.reduceat(lum, start) / total
    mi = np.empty(npoly, np.int32); me.polygons.foreach_get('material_index', mi)
    for idx, mat in enumerate(list(me.materials)):
        b = bsdf_of(mat)
        if not b or 'fish' not in mat.name.lower() or 'eye' in mat.name.lower():
            continue
        # importer menyambung vertex color ke Base Color (nilai default socket jadi tidak berarti)
        if not b.inputs['Base Color'].is_linked and min(b.inputs['Base Color'].default_value[:3]) < 0.95:
            continue
        sel = mi == idx
        if not sel.any():
            continue
        thr = float(face[sel].mean())
        set_flat_colour(mat, FISH_SILVER)
        back = mat.copy(); back.name = mat.name + '_punggung'
        set_flat_colour(back, FISH_BACK)
        me.materials.append(back)
        mi[sel & (face < thr)] = len(me.materials) - 1
        print('vertex colour split %s: thr %.3f, punggung %d / %d muka' % (mat.name, thr, int((sel & (face < thr)).sum()), int(sel.sum())))
    me.polygons.foreach_set('material_index', mi)

def realize_and_split():
    """Semua mesh (termasuk instance GPU) -> 1 objek per material, transform sudah diterapkan."""
    deps = bpy.context.evaluated_depsgraph_get()
    coll = bpy.context.scene.collection
    made = []
    for inst in deps.object_instances:
        ob = inst.object
        if ob.type != 'MESH':
            continue
        mw = inst.matrix_world.copy()
        me = bpy.data.meshes.new_from_object(ob, preserve_all_data_layers=True, depsgraph=deps)
        me.transform(mw)
        o = bpy.data.objects.new('p', me)
        coll.objects.link(o)
        made.append(o)
    for o in list(bpy.data.objects):
        if o not in made:
            bpy.data.objects.remove(o, do_unlink=True)
    select_only(made)
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    split_vertex_colour(obj)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.mesh.separate(type='MATERIAL')
    bpy.ops.object.mode_set(mode='OBJECT')
    parts = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.polygons)]
    for o in parts:
        o.name = o.data.materials[0].name if o.data.materials else 'tanpa_material'
    return parts

def apply_mod(o, kind, **kw):
    select_only([o])
    m = o.modifiers.new('m', kind)
    for k, v in kw.items():
        setattr(m, k, v)
    bpy.ops.object.modifier_apply(modifier=m.name)

def decimate_to(o, target):
    t = tris(o)
    if t > target:
        apply_mod(o, 'DECIMATE', decimate_type='COLLAPSE', ratio=max(target / t, 0.0005), use_collapse_triangulate=True)

def net_hull(o, open_bottom):
    """Benang jaring (ratusan ribu segitiga, banyak lubang) -> kulit convex hull yang mengikuti bentuknya.
    Jaring lempar (kubah): tutup bawah hull dibuang supaya tetap terbuka."""
    me = o.data
    bm = bmesh.new()
    for v in me.vertices:
        bm.verts.new(v.co)
    res = bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    junk = list({g for g in res['geom_interior'] + res['geom_unused'] if isinstance(g, bmesh.types.BMVert)})
    bmesh.ops.delete(bm, geom=junk, context='VERTS')
    if open_bottom:
        bm.normal_update()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.6], context='FACES')
    bm.to_mesh(me)
    bm.free()
    me.update()

def double_side(o):
    """cutout = satu sisi; salin muka terbalik supaya jaring terlihat dari dalam/belakang juga."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    faces = list(bm.faces)
    dup = bmesh.ops.duplicate(bm, geom=faces)
    bmesh.ops.reverse_faces(bm, faces=[g for g in dup['geom'] if isinstance(g, bmesh.types.BMFace)])
    bm.to_mesh(o.data)
    bm.free()

def uv_tile(o, tile):
    select_only([o])
    if not o.data.uv_layers:
        o.data.uv_layers.new()
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    me = o.data
    uv = me.uv_layers.active.data
    a3 = auv = 0.0
    for p in me.polygons:
        a3 += p.area
        pts = [uv[li].uv for li in p.loop_indices]
        s = 0.0
        for i in range(len(pts)):
            x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % len(pts)]
            s += x0 * y1 - x1 * y0
        auv += abs(s) / 2
    k = math.sqrt(a3 / auv) / tile if auv > 0 else 1.0   # 1 satuan UV = 1 tile tekstur
    for l in uv:
        l.uv = (l.uv[0] * k, l.uv[1] * k)

def smooth(o):
    select_only([o])
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    except Exception:
        bpy.ops.object.shade_smooth()

def ensure_uv(o):
    if not o.data.uv_layers:
        o.data.uv_layers.new()

def export(objs, path):
    select_only(objs)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT')

def net_image(color, name, size=128, cells=4, line=3):
    """Tekstur jaring belah ketupat yang bisa di-tile; disimpan juga sebagai .rgba (sRGB) untuk builder."""
    color = [12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055 for c in color]  # linear -> sRGB
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    per = size / cells
    d1 = np.abs(((x + y) % per) - per / 2)
    d2 = np.abs(((x - y) % per) - per / 2)
    edge = per / 2 - line / 2
    a = ((d1 >= edge) | (d2 >= edge)).astype(np.float32)
    knot = ((d1 >= edge - 1) & (d2 >= edge - 1)).astype(np.float32)
    shade = 0.85 + 0.15 * knot
    rgba = np.zeros((size, size, 4), np.float32)
    for c in range(3):
        rgba[..., c] = color[c] * shade
    rgba[..., 3] = a
    img = bpy.data.images.new(name, size, size, alpha=True)
    img.pixels = rgba[::-1].ravel()
    raw = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    raw.tofile(os.path.join(OUT, name + '.rgba'))
    return img

def preview_material_net(mat, img):
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
    try:
        mat.surface_render_method = 'DITHERED'
    except Exception:
        mat.blend_method = 'CLIP'

def render(path, objs):
    sc = bpy.context.scene
    for e in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE', 'BLENDER_WORKBENCH'):
        try:
            sc.render.engine = e
            break
        except Exception:
            pass
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o not in objs
    for m in bpy.data.materials:  # pratinjau saja: logam polos tampak hitam tanpa pantulan lingkungan
        if m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == 'BSDF_PRINCIPLED':
                    n.inputs['Metallic'].default_value = 0.0
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.film_transparent = False
    if not sc.world:
        sc.world = bpy.data.worlds.new('w')
    sc.world.color = (0.55, 0.6, 0.65)
    mn = [min((o.matrix_world @ v.co)[k] for o in objs for v in o.data.vertices) for k in range(3)]
    mx = [max((o.matrix_world @ v.co)[k] for o in objs for v in o.data.vertices) for k in range(3)]
    c = [(mn[k] + mx[k]) / 2 for k in range(3)]
    r = max(math.dist(mn, mx) / 2, 0.05)
    for o in [o for o in bpy.data.objects if o.type in ('CAMERA', 'LIGHT')]:
        bpy.data.objects.remove(o, do_unlink=True)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    d = r * 2.6
    cam.location = (c[0] + d * 0.62, c[1] - d * 0.62, c[2] + d * 0.5)
    direction = np.array(c) - np.array(cam.location)
    from mathutils import Vector
    cam.rotation_euler = Vector(direction).to_track_quat('-Z', 'Y').to_euler()
    cam.data.clip_end = d * 10
    sc.camera = cam
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(sun)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

report = []
for fname, (model, budget, open_bottom, tile, crate_tris) in PROPS.items():
    if ONLY and fname not in ONLY:
        continue
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, fname))
    parts = realize_and_split()
    render(os.path.join(OUT, model + '_asli.png'), parts)
    before = sum(tris(o) for o in parts)
    nets = [o for o in parts if is_net(o.name)]
    eyes = [o for o in parts if 'eye' in o.name.lower()]
    solids = [o for o in parts if o not in nets and o not in eyes]
    net_budget = int(budget * NET_SHARE) if nets else 0
    eye_budget = EYE_TRIS if eyes else 0
    solid_budget = budget - net_budget - eye_budget
    for o in eyes:
        decimate_to(o, EYE_TRIS // len(eyes))
    st = sum(tris(o) for o in solids) or 1
    for o in solids:
        if 'crate' in o.name.lower():
            # peti AI = banyak potongan terpisah -> collapse merusak. Satukan dulu (voxel) baru decimate.
            apply_mod(o, 'REMESH', mode='VOXEL', voxel_size=CRATE_VOXEL, adaptivity=0.0)
            decimate_to(o, crate_tris)
        else:
            decimate_to(o, max(60, int(solid_budget * tris(o) / st)))
        smooth(o)
    for o in nets:
        net_hull(o, open_bottom)
        decimate_to(o, max(150, net_budget // len(nets) // 2))
        uv_tile(o, tile)
        smooth(o)
        double_side(o)
    for o in parts:
        ensure_uv(o)
    export(parts, os.path.join(OUT, model + '.glb'))
    if fname == EMPTY_CRATE[0]:
        crate = [o for o in parts if o.name == EMPTY_CRATE[1]]
        export(crate, os.path.join(OUT, EMPTY_CRATE[2] + '.glb'))
        render(os.path.join(OUT, EMPTY_CRATE[2] + '_hasil.png'), crate)
        report.append('%s: crate only, %d tris' % (EMPTY_CRATE[2], tris(crate[0])))
    for o in nets:
        mat = o.data.materials[0]
        col = mat.diffuse_color[:3]
        try:
            bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            col = bsdf.inputs['Base Color'].default_value[:3]
        except Exception:
            pass
        preview_material_net(mat, net_image(col, 'jaring_' + mat.name))
    render(os.path.join(OUT, model + '_hasil.png'), parts)
    after = sum(tris(o) for o in parts)
    report.append('%s: %d -> %d tris | %s' % (model, before, after, ', '.join('%s=%d' % (o.name, tris(o)) for o in parts)))

print('\n=== HASIL ===')
for r in report:
    print(r)
