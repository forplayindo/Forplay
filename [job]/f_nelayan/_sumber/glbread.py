import struct,json
def load(path):
    d=open(path,'rb').read()
    jl,_=struct.unpack('<II',d[12:20]); j=json.loads(d[20:20+jl])
    off=20+jl; bl,_=struct.unpack('<II',d[off:off+8]); bin_=d[off+8:off+8+bl]
    return j,bin_
def acc(j,b,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    fmt={5126:'f',5123:'H',5125:'I',5121:'B'}[a['componentType']]
    sz=struct.calcsize(fmt); stride=bv.get('byteStride',sz*n)
    base=bv.get('byteOffset',0)+a.get('byteOffset',0)
    out=[]
    for k in range(a['count']):
        v=struct.unpack_from('<'+fmt*n,b,base+k*stride); out.append(v if n>1 else v[0])
    return out
def matmul(a,b):  # column-major 4x4
    r=[0]*16
    for c in range(4):
        for rr in range(4):
            r[c*4+rr]=sum(a[k*4+rr]*b[c*4+k] for k in range(4))
    return r
def nodemat(n):
    if 'matrix' in n: return n['matrix']
    t=n.get('translation',[0,0,0]); q=n.get('rotation',[0,0,0,1]); s=n.get('scale',[1,1,1])
    x,y,z,w=q
    R=[1-2*(y*y+z*z),2*(x*y+z*w),2*(x*z-y*w),0, 2*(x*y-z*w),1-2*(x*x+z*z),2*(y*z+x*w),0, 2*(x*z+y*w),2*(y*z-x*w),1-2*(x*x+y*y),0, 0,0,0,1]
    for c in range(3):
        for r_ in range(3): R[c*4+r_]*=s[c]
    R[12],R[13],R[14]=t; return R
def xf(m,p,w=1):
    return tuple(m[0*4+r]*p[0]+m[1*4+r]*p[1]+m[2*4+r]*p[2]+m[12+r]*w for r in range(3))
def walk(j,b):
    """yield (nodename, material, positions_world, normals_world, uvs, indices)"""
    I=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
    def rec(ni,parent):
        n=j['nodes'][ni]; m=matmul(parent,nodemat(n))
        if 'mesh' in n:
            for p in j['meshes'][n['mesh']]['primitives']:
                pos=[xf(m,v) for v in acc(j,b,p['attributes']['POSITION'])]
                nor=[xf(m,v,0) for v in acc(j,b,p['attributes']['NORMAL'])]
                uv=acc(j,b,p['attributes']['TEXCOORD_0'])
                idx=acc(j,b,p['indices']) if p.get('indices') is not None else list(range(len(pos)))
                yield n.get('name'),p.get('material'),pos,nor,uv,idx
        for c in n.get('children',[]): yield from rec(c,m)
    for r in j['scenes'][j.get('scene',0)]['nodes']: yield from rec(r,I)
