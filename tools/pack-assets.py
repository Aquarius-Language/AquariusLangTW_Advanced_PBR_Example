"""Pack outputs from bake.cpp; NumPy and Pillow are only needed when rebaking."""
import argparse,gzip,json,hashlib,shutil
from pathlib import Path
import numpy as np
from PIL import Image
from importlib.util import spec_from_file_location, module_from_spec
spec=spec_from_file_location('pack_mesh',Path(__file__).with_name('pack-mesh.py'));mesh_packer=module_from_spec(spec);spec.loader.exec_module(mesh_packer)
p=argparse.ArgumentParser();p.add_argument('raw',type=Path);p.add_argument('project',type=Path);p.add_argument('--source',type=Path,default=Path('C:/GitClonedProjects/PBR'));args=p.parse_args()
destination=args.project/'assets'/'baked';destination.mkdir(parents=True,exist_ok=True)
manifest={}
for name in ['albedo','normal','metallic','roughness','environment','irradiance','brdf']:
    source=args.raw/(name+'.raw');data=source.read_bytes()
    if name in ['environment','irradiance','brdf']:
        assert np.isfinite(np.frombuffer(data,dtype='<f2')).all(),name
    (destination/(name+'.gz')).write_bytes(gzip.compress(data,compresslevel=6,mtime=0))
    manifest[name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
    print(name,len(data),flush=True)
vertices=json.loads((args.raw/'mesh.json').read_text());(destination/'mesh.json').write_text(json.dumps(vertices,separators=(',',':')),encoding='utf-8')
(destination/'mesh.aqmesh').write_bytes(mesh_packer.pack_mesh(vertices))
tangents=np.fromfile(args.raw/'tangents.f32',dtype='<f4').reshape(-1,4);width=1024;height=(len(tangents)+width-1)//width
packed=np.zeros((height*width,4),dtype='<f2');packed[:len(tangents)]=tangents
(destination/'tangents.gz').write_bytes(gzip.compress(packed.tobytes(),compresslevel=6,mtime=0))
manifest['mesh']={'vertices':len(vertices),'triangles':len(vertices)//3,'min':np.array(vertices)[:,:3].min(axis=0).tolist(),'max':np.array(vertices)[:,:3].max(axis=0).tolist(),'tangentWidth':width,'tangentHeight':height}
(destination/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
original=args.project/'assets'/'original';original.mkdir(parents=True,exist_ok=True)
for name in ['meshes','textures']:shutil.copytree(args.source/'data'/name,original/name,dirs_exist_ok=True)
shutil.copy2(args.source/'data'/'environment.hdr',original/'environment.hdr')
shutil.copy2(args.source/'COPYING.txt',args.project/'PBR-LICENSE.txt')
for name in ['reference','reference-lit']:
    linear=np.fromfile(args.raw/(name+'.f32'),dtype='<f4').reshape(1024,1024,4)[::-1]
    rgb=np.rint(np.clip(np.maximum(linear[:,:,:3],0)**(1/2.2),0,1)*255).astype('uint8')
    Image.fromarray(rgb).save(args.project/(name+'.png'))
print(json.dumps(manifest['mesh']),flush=True)
