"""Blender 5.2 + Sollumz: deterministic, editable phone and native GTA V props.

blender --background --python build_sky_phone_prop.py
Dimensions: Apple iPhone 18 Pro Max specifications. Camera/details: supplied reference.
No external geometry or paid generation service is required.
"""
from pathlib import Path
import math, json, re, struct, colorsys
import bpy, bmesh
import numpy as np
from mathutils import Vector
from bl_ext.repo_sollumz_org.sollumz.sollumz_properties import ArchetypeType, LODLevel, SollumType
from bl_ext.repo_sollumz_org.sollumz.tools.drawablehelper import convert_obj_to_drawable
from bl_ext.repo_sollumz_org.sollumz.tools.blenderhelper import create_empty_object
from bl_ext.repo_sollumz_org.sollumz.tools.boundhelper import create_bound_box
from bl_ext.repo_sollumz_org.sollumz.ybn.collision_materials import create_collision_material_from_index
from bl_ext.repo_sollumz_org.sollumz.ydr.shader_materials import create_shader

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
STREAM = REPO / 'sky_phone/stream/phone_prop'
TEX = ROOT / 'source/textures'
XML = ROOT / 'source/xml'
for p in (STREAM, TEX, XML, ROOT / 'previews'): p.mkdir(parents=True, exist_ok=True)
W, H, D = .078, .1634, .00875
SCREEN_W, SCREEN_H, SCREEN_Y = .0736, .1589, -.00449
DUI_Y = -.0055  # Overlay clears the outer glass; keep shared/phone_prop.lua aligned.
PARTS = []

def select(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

def dds(name, color, grain=0.0, rainbow=False, normal=False):
    size=512 if (name.endswith('_ceramic') or name.endswith('_alloy')) else 128
    rng=np.random.default_rng(18)
    noise=rng.normal(0,grain,(size,size,1))
    rgb=np.broadcast_to(np.array(color,dtype=float),(size,size,3)).copy()+noise
    if rainbow:
        for y in range(size):
            for x in range(size):
                rgb[y,x]=np.array(colorsys.hsv_to_rgb((math.atan2(y-64,x-64)/math.tau)%1,.72,.85))*255+noise[y,x]
    if normal:
        rgb=np.concatenate((128+rng.normal(0,2,(size,size,2)),np.full((size,size,1),255)),axis=2)
    rgb=np.clip(rgb,0,255).astype(np.uint8)
    path=TEX/(name+'.dds')
    # Uncompressed BGRA8 with complete mip chain; no lossy color banding.
    header=struct.pack('<7I',124,0x2100f,size,size,size*4,0,int(math.log2(size))+1)+bytes(44)
    header+=struct.pack('<8I',32,0x41,0,32,0xff0000,0xff00,0xff,0xff000000)
    header+=struct.pack('<5I',0x401008,0,0,0,0)
    payload=bytearray(b'DDS '+header)
    while True:
        rgba=np.concatenate((rgb[:,:,::-1],np.full((*rgb.shape[:2],1),255,dtype=np.uint8)),axis=2)
        payload.extend(rgba.tobytes())
        if len(rgb)==1: break
        n=len(rgb)//2
        rgb=rgb.reshape(n,2,n,2,3).mean(axis=(1,3)).astype(np.uint8)
    path.write_bytes(payload)
    image=bpy.data.images.load(str(path),check_existing=True)
    image.name=name
    image.pack()
    return image

def material(name,color,roughness,metallic=0,grain=0,rainbow=False):
    mat=create_shader('normal_spec.sps')
    mat.name='sky_phone_prop' if name=='black' else 'sky_phone_prop_'+name
    mat['preview_roughness']=roughness
    mat['preview_metallic']=metallic
    specs=[('DiffuseSampler',dds(mat.name,color,grain,rainbow)),
           ('BumpSampler',dds('sky_phone_prop_micro_normal',(128,128,255),normal=True)),
           ('SpecSampler',dds('sky_phone_prop_spec_'+name,(int((1-roughness)*210),)*3))]
    for key,img in specs:
        node=mat.node_tree.nodes.get(key)
        if node is None: raise RuntimeError('Missing shader sampler '+key)
        node.image=img
        node.texture_properties.embedded=True
        if key!='DiffuseSampler': img.colorspace_settings.name='Non-Color'
    for key,value in [('bumpiness',.12),('specularIntensityMult',.8 if metallic else .3),('specularFalloffMult',(1-roughness)*256)]:
        node=mat.node_tree.nodes.get(key)
        if node: node.outputs[0].default_value=value
    bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value=roughness
    bsdf.inputs['Metallic'].default_value=metallic
    return mat

def finish(name,verts,faces,mat):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh);bm.free()
    uv=mesh.uv_layers.new(name='UVMap 0')
    for loop in mesh.loops:
        v=mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=(v.x/W+.5,v.z/H+.5)
    col=mesh.color_attributes.new(name='Color 1',type='BYTE_COLOR',domain='CORNER')
    for c in col.data:c.color=(1,1,1,1)
    for p in mesh.polygons:p.use_smooth=len(p.vertices)==4
    PARTS.append(obj)
    return obj

def rounded(name,w,h,d,r,loc,mat,steps=12,bevel=.00025):
    # Rings retain a large corner radius while giving the metal edge a small roll.
    b=min(bevel,d*.4,r*.25)
    rings=[(-d/2,b),(-d/2+b,0),(d/2-b,0),(d/2,b)]
    verts=[]
    for depth,inset in rings:
        ww,hh,rr=w/2-inset,h/2-inset,r-inset
        for cx,cz,start in [(ww-rr,hh-rr,0),(-ww+rr,hh-rr,90),(-ww+rr,-hh+rr,180),(ww-rr,-hh+rr,270)]:
            for j in range(steps+1):
                a=math.radians(start+j*90/steps)
                verts.append((loc[0]+cx+rr*math.cos(a),loc[1]+depth,loc[2]+cz+rr*math.sin(a)))
    n=4*(steps+1)
    faces=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
    for k in range(3):
        for i in range(n): faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
    return finish(name,verts,faces,mat)

def cylinder(name,r,depth,loc,mat,n=64):
    verts=[]
    for y,rr in [(-depth/2,r*.94),(-depth/2+min(depth*.2,.00018),r),(depth/2-min(depth*.2,.00018),r),(depth/2,r*.94)]:
        for i in range(n):
            a=i*math.tau/n
            verts.append((loc[0]+rr*math.cos(a),loc[1]+y,loc[2]+rr*math.sin(a)))
    faces=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
    for k in range(3):
        for i in range(n):faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
    return finish(name,verts,faces,mat)

def body_geometry(mats):
    body,back,trim=mats
    rounded('Unibody alloy chassis',W,H,D,.009,(0,0,0),body,20,.00065)
    rounded('Front polished metal lip',W-.0008,H-.0008,.00045,.0088,(0,-D/2+.00002,0),trim,20,.00013)
    rounded('Ceramic front glass',W-.0015,H-.0015,.0003,.0087,(0,-D/2-.00015,0),GLASS,20,.0001)
    rounded('Blank OLED UV 0-1',SCREEN_W,SCREEN_H,.00008,.0081,(0,SCREEN_Y,0),BLACK,20,.00001)
    # Blank display has its own material and a complete UV rectangle, ready for DUI.
    oled=PARTS[-1]
    for loop in oled.data.loops:
        p=oled.data.vertices[loop.vertex_index].co
        oled.data.uv_layers.active.data[loop.index].uv=(p.x/SCREEN_W+.5,p.z/SCREEN_H+.5)
    rounded('Dynamic Island',.0162,.0055,.0001,.0027,(0,-.00461,.0732),GLASS,12,.00002)
    cylinder('Front camera sapphire',.0013,.00004,(.0049,-.00469,.0732),LENS,40)
    rounded('Rear ceramic inlay seam',W-.0031,.112,.00035,.009,(0,.00433,-.0238),DARK,18,.0001)
    rounded('Rear satin ceramic',W-.0036,.1115,.00038,.0088,(0,.00455,-.0238),back,18,.00015)
    rounded('Camera plateau rolled shoulder',W-.0025,.044,.0028,.0085,(0,.0052,.0584),body,20,.0007)
    rounded('Camera plateau satin face',W-.004,.0425,.00035,.008,(0,.00668,.0584),back,18,.00012)
    for i,(x,z) in enumerate([(.023,.067),(.023,.047),(.005,.057)]):
        cylinder(f'Camera {i+1} anodized rim',.0091,.0025,(x,.0079,z),trim)
        cylinder(f'Camera {i+1} black gasket',.0083,.0022,(x,.0086,z),DARK)
        cylinder(f'Camera {i+1} sapphire cover',.0075,.00035,(x,.0098,z),GLASS)
        cylinder(f'Camera {i+1} optical coating',.0057,.00011,(x,.0100,z),LENS)
        cylinder(f'Camera {i+1} iris',.0033,.00008,(x,.01008,z),DARK,48)
        cylinder(f'Camera {i+1} aperture',.0018,.00005,(x,.01014,z),GLASS,32)
        cylinder(f'Camera {i+1} reflection',.0007,.00002,(x-.0013,.01018,z+.0016),COATING,24)
    cylinder('True Tone flash bezel',.0035,.0004,(-.027,.007,.068),trim,48)
    cylinder('Frosted flash lens',.003,.00045,(-.027,.0073,.068),FLASH,48)
    cylinder('Flash core',.0015,.0001,(-.027,.00757,.068),WHITE,32)
    cylinder('LiDAR',.0035,.0003,(-.027,.007,.047),DARK,48)
    cylinder('Rear microphone',.0005,.00025,(-.027,.007,.057),DARK,20)
    # Side keys, pressure sensor, insulating antenna breaks and bottom port.
    for name,x,z,length in [('Action',-W/2,.049,.0065),('Volume up',-W/2,.028,.010),('Volume down',-W/2,.012,.010),('Power',W/2,.034,.017),('Camera control',W/2,-.030,.014)]:
        o=rounded(name,.003,length,.0007,.0013,(0,0,0),trim,8,.00015)
        for v in o.data.vertices:
            xx,yy,zz=v.co;v.co=(x+yy,xx,z+zz)
    for side in [-1,1]:
        for z in [-.061,.061]:
            o=rounded('Antenna insulator',.0074,.0007,.00015,.00025,(0,0,0),INSULATOR,5,.00002)
            for v in o.data.vertices:
                xx,yy,zz=v.co;v.co=(side*(W/2+.00002)+yy,xx,z+zz)
    def bottom(name,w,h,x,mat):
        o=rounded(name,w,h,.00012,min(w,h)*.46,(0,0,0),mat,7,.00002)
        for v in o.data.vertices:
            xx,yy,zz=v.co;v.co=(x+xx,zz,-H/2-.00004+yy)
    bottom('USB C machined surround',.0101,.0035,0,trim)
    bottom('USB C recessed opening',.0088,.0026,0,DARK)
    bottom('USB C center tongue',.0066,.0007,0,COATING)
    for side in [-1,1]:
        for i in range(5): bottom('Speaker perforation',.0013,.0017,side*(.013+i*.0024),DARK)
        bottom('Pentalobe fastener',.0010,.0010,side*.008,COATING)
    # GTA iFruit: fruit bowl, two fruit lobes and curved leaf/banana.
    # Separate flush metal inlays retain the logo's negative-space divisions.
    def inlay(name, points):
        obj=finish('iFruit '+name,[(-(u-24)*.00056,.00479,-(v-24)*.00056-.015) for u,v in points],
                   [tuple(range(len(points)))],trim)
        bm=bmesh.new();bm.from_mesh(obj.data)
        for face in bm.faces:
            if face.normal.y < 0: face.normal_flip()
        bm.to_mesh(obj.data);bm.free()
    bowl=[(5.5,25.0),(42.5,25.0)]
    bowl += [(24+18.5*math.cos(i*math.pi/64),25+17.5*math.sin(i*math.pi/64)) for i in range(1,65)]
    inlay('bowl inlay',bowl)
    left=[(8.8,23.4)]
    left += [(17.18+8.38*math.cos(math.pi+i*math.pi/48),23.4+8.38*math.sin(math.pi+i*math.pi/48)) for i in range(1,49)]
    inlay('left fruit inlay',left)
    right=[(39.2,23.4)]
    right += [(30.82+8.38*math.cos(i*2.18/40),23.4-8.38*math.sin(i*2.18/40)) for i in range(1,41)]
    right += [(25.5,18.2),(26.25,20.0),(26.8,21.8),(26.9,23.4)]
    inlay('right fruit inlay',right)
    def cubic(a,b,c,d,steps=24):
        return [tuple((1-t)**3*a[k]+3*(1-t)**2*t*b[k]+3*(1-t)*t*t*c[k]+t**3*d[k] for k in range(2))
                for t in [i/steps for i in range(steps+1)]]
    leaf=cubic((16.1,13.7),(19.0,6.5),(29.5,2.5),(37.1,6.8))
    leaf += [(37.1,8.85)]
    leaf += cubic((37.1,8.85),(30.8,9.4),(26.0,12.0),(23.0,16.1))
    leaf += cubic((23.0,16.1),(20.8,14.3),(18.8,13.9),(16.1,13.7))
    inlay('leaf inlay',leaf)


def join_parts():
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    select(obj)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    tri=obj.modifiers.new('GTA triangulation','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    return obj

def decimate(obj,ratio):
    copy=obj.copy();copy.data=obj.data.copy();bpy.context.collection.objects.link(copy)
    select(copy)
    mod=copy.modifiers.new('Distance simplification','DECIMATE');mod.ratio=ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mesh=copy.data;bpy.data.objects.remove(copy,do_unlink=True)
    return mesh

def export(root):
    select(root)
    common=dict(direct_export=True,use_custom_settings=True,target_versions={'GEN8'},limit_to_selected=True,apply_transforms=False,exclude_skeleton=False,mesh_domain='FACE_CORNER')
    for folder,fmt in [(STREAM,'NATIVE'),(XML,'CWXML')]:
        result=bpy.ops.sollumz.export_assets(directory=str(folder),target_formats={fmt},**common)
        assert result=={'FINISHED'},(root.name,result)
    assert (STREAM/(root.name+'.ydr')).read_bytes()[:4]==b'RSC7'

def point(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

def render(roots,models):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True
    scene.render.resolution_x=1600;scene.render.resolution_y=1400;scene.render.resolution_percentage=100
    scene.world.color=(.16,.16,.16)
    scene.view_settings.view_transform='AgX'
    bpy.ops.object.camera_add(location=(.20,.34,.16));camera=bpy.context.object
    camera.name='Studio camera';camera.data.type='ORTHO';camera.data.ortho_scale=.23
    point(camera,(0,0,0));scene.camera=camera
    for loc,energy,size in [((.06,.18,.24),2.0,.19),((-.15,.08,.03),1.4,.12),((.08,-.10,.14),2.4,.15)]:
        bpy.ops.object.light_add(type='AREA',location=loc)
        light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=size;point(light,(0,0,0))
    original_materials = {}
    previews = {}
    for model in models:
        original_materials[model.name] = list(model.data.materials)
        for i, game_mat in enumerate(model.data.materials):
            if game_mat.name not in previews:
                preview = bpy.data.materials.new(game_mat.name + '_studio')
                preview.use_nodes = True
                bsdf = preview.node_tree.nodes.get('Principled BSDF')
                bsdf.inputs['Roughness'].default_value = game_mat.get('preview_roughness', .4)
                bsdf.inputs['Metallic'].default_value = game_mat.get('preview_metallic', 0)
                tex = preview.node_tree.nodes.new('ShaderNodeTexImage')
                tex.image = game_mat.node_tree.nodes.get('DiffuseSampler').image
                preview.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
                if 'sapphire' in game_mat.name or 'optical' in game_mat.name:
                    bsdf.inputs['Coat Weight'].default_value = .6
                    bsdf.inputs['Coat Roughness'].default_value = .07
                previews[game_mat.name] = preview
            model.data.materials[i] = previews[game_mat.name]
    for model in models:model.hide_render=True
    hero=models[-1];hero.hide_render=False
    for label,loc in [('back',(.14,.31,.12)),('front',(.11,-.35,.10)),('detail',(.12,.20,.13))]:
        camera.location=loc;point(camera,(0,0,.004 if label!='detail' else .052))
        camera.data.ortho_scale=.21 if label!='detail' else .096
        scene.render.filepath=str(ROOT/'previews'/('burgundy_'+label+'.png'));bpy.ops.render.render(write_still=True)
    hero.hide_render=True
    copies=[]
    for i,m in enumerate(models[:15]):
        o=m.copy();o.data=m.data;o.parent=None;bpy.context.collection.objects.link(o)
        o.location=((i%5-2)*.092,0,(1-i//5)*.181);o.hide_render=False;copies.append(o)
    camera.location=(.13,1.5,.23);point(camera,(0,0,0));camera.data.ortho_scale=.60
    scene.render.resolution_x=1800;scene.render.resolution_y=1800
    scene.render.filepath=str(ROOT/'previews'/'all_frame_colors.png');bpy.ops.render.render(write_still=True)
    for o in copies:bpy.data.objects.remove(o,do_unlink=True)
    hero.hide_render=False
    camera.location=(.14,.31,.12);point(camera,(0,0,0));camera.data.ortho_scale=.21

    for model in models:
        for i, mat in enumerate(original_materials[model.name]):model.data.materials[i]=mat

def main():
    global GLASS,BLACK,DARK,LENS,COATING,FLASH,WHITE,INSULATOR
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    GLASS=material('sapphire',(9,12,17),.10,.12)
    BLACK=material('blank_display',(2,3,5),.22)
    DARK=material('graphite',(12,14,18),.37,.15)
    LENS=material('optical_blue',(15,23,37),.12,.4)
    COATING=material('coating',(55,76,90),.22,.75)
    FLASH=material('flash',(189,186,174),.5,0,1)
    WHITE=material('flash_core',(232,230,215),.4)
    INSULATOR=material('insulator',(73,69,73),.6)
    source=(REPO/'frontend/src/config/appearance.ts').read_text(encoding='utf-8')
    colors=dict(re.findall(r"(\w+): '(#[0-9a-f]{6})'",source))
    colors['rgb']='#bbbbbb';colors['burgundy']='#713442'
    roots=[];models=[];report={'branding':'iFruit','dimensions_m':[W,D,H],'screen':{'width':SCREEN_W,'height':SCREEN_H,'y':DUI_Y,'radius':.0081},'variants':{}}
    base=None;base_mats=None
    for name,color in colors.items():
        rgb=tuple(int(color[i:i+2],16) for i in (1,3,5))
        mats=[material(name+'_alloy',rgb,.3,.78,1.0,name=='rgb'),material(name+'_ceramic',tuple(int(c*.80) for c in rgb),.43,.12,1.5,name=='rgb'),material(name+'_polished',tuple(min(255,int(c*1.12+8)) for c in rgb),.2,.85,.3,name=='rgb')]
        if base is None:
            body_geometry(mats);model=join_parts();base=model.data.copy();base_mats=mats
        else:
            model=bpy.data.objects.new(name,base.copy());bpy.context.collection.objects.link(model)
            for i,mat in enumerate(model.data.materials):
                if mat in base_mats:model.data.materials[i]=mats[base_mats.index(mat)]
        name='sky_phone_prop' if name=='black' else 'sky_phone_prop_'+name
        model.name=name+'.model'
        lods=[model.data]+[decimate(model,r) for r in [.42,.14,.035]]
        root=convert_obj_to_drawable(model);root.name=name
        for level,mesh in zip([LODLevel.HIGH,LODLevel.MEDIUM,LODLevel.LOW,LODLevel.VERYLOW],lods):model.sz_lods.get_lod(level).mesh=mesh
        model.sz_lods.active_lod_level=LODLevel.HIGH
        props=root.drawable_properties
        props.lod_dist_high=5;props.lod_dist_med=12;props.lod_dist_low=25;props.lod_dist_vlow=45
        bound=create_empty_object(SollumType.BOUND_COMPOSITE);bound.name=name+'.collision';bound.parent=root
        box=create_bound_box();box.parent=bound;box.dimensions=(W,D,H)
        box.data.materials.append(create_collision_material_from_index(1))
        for flags in [box.composite_flags1,box.composite_flags2]:
            flags.map_dynamic=True;flags.object=True;flags.ped=True;flags.test_script=True
        box.hide_render=True;box.hide_set(True)
        root['screen_uv']='U left to right, V bottom to top; front -Y, top +Z'
        root['rear_brand']='iFruit'
        root['design_reference']='User supplied front/back image; small unseen details are approximations'
        export(root);roots.append(root);models.append(model)
        report['variants'][name]={'color':color,'triangles':[len(mesh.polygons) for mesh in lods],'bytes':(STREAM/(name+'.ydr')).stat().st_size}
        print('PHONE EXPORTED',name,report['variants'][name],flush=True)
    scene=bpy.context.scene
    while len(scene.ytyps):scene.ytyps.remove(len(scene.ytyps)-1)
    ytyp=scene.ytyps.add();ytyp.name='sky_phone_prop'
    for root in roots:
        a=ytyp.new_archetype(ArchetypeType.BASE);a.name=root.name;a.asset=root;a.asset_name=root.name
        a.lod_dist=45;a.hd_texture_dist=8;a.texture_dictionary=root.name;a.physics_dictionary=root.name
        a.flags.flag9=True;a.flags.flag23=True;a.flags.flag24=True
    scene.ytyp_index=0
    for folder,fmt in [(STREAM,'NATIVE'),(XML,'CWXML')]:
        assert bpy.ops.sollumz.export_ytyp_io(directory=str(folder),target_formats={fmt},direct_export=True,use_custom_settings=True,target_versions={'GEN8'},apply_transforms=False,export_ytyps_include='ALL')=={'FINISHED'}
    (ROOT/'source/build_report.json').write_text(json.dumps(report,indent=2))
    render(roots,models)
    for model in models:model.hide_set(True)
    models[-1].hide_set(False);select(roots[-1])
    for img in bpy.data.images:
        if img.source == 'FILE' and img.name.startswith('sky_phone_prop_'):
            img.filepath = '//source/textures/' + Path(img.filepath).name
    scene.render.filepath = '//previews/burgundy_back.png'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'sky_phone_prop.blend'),compress=True)
    print('PHONE BUILD COMPLETE',flush=True)

if __name__=='__main__':main()
