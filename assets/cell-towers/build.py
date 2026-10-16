"""Convert the owner's three Meshy GLBs into four native, articulated GTA props.

Run with Blender + Sollumz 2.9 native export. See README.md for inputs/options.
"""
import argparse
import hashlib
import importlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
STREAM = HERE.parents[1] / "sky_phone" / "stream"
SCALE = 0.63
SHIFT = Vector((-0.055, -1.72, 1.30))
HINGE = Vector((-0.515, 0.27, 0.0))
DOOR_OFFSET = SHIFT + HINGE * SCALE
PREFIX = "sky_phone_cell_"
addon = next(a.module for a in bpy.context.preferences.addons if "sollumz" in a.module)
p = importlib.import_module(addon + ".sollumz_properties")
COLLISION_FLAGS = next(preset["data"] for preset in json.loads(
    (Path(p.__file__).parent / "ybn/gta5/presets/flag_presets.json").read_text()
)["presets"] if preset["name"] == "General (Default)")
empty = importlib.import_module(addon + ".tools.blenderhelper").create_empty_object
convert = importlib.import_module(addon + ".tools.drawablehelper").convert_obj_to_model
shader = importlib.import_module(addon + ".ydr.shader_materials").create_shader
bound_box = importlib.import_module(addon + ".tools.boundhelper").create_bound_box
collision = importlib.import_module(addon + ".ybn.collision_materials")


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def decimate(obj, triangles):
    activate(obj)
    mod = obj.modifiers.new("Meshy topology reduction", "DECIMATE")
    mod.ratio = min(1.0, triangles / len(obj.data.polygons))
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for face in obj.data.polygons:
        face.use_smooth = True


def cut(obj, predicate):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if predicate(v.co)], context="VERTS")
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()


def dds_rgba(path, pixels):
    height, width = pixels.shape[:2]
    levels = []
    level = pixels.astype(np.uint8)
    while True:
        levels.append(level.tobytes())
        h, w = level.shape[:2]
        if h == w == 1:
            break
        level = np.rint(level.astype(np.float32).reshape(h // 2, 2, w // 2, 2, 4).mean((1, 3))).astype(np.uint8)
    header = [124, 0x2100F, height, width, width * 4, 0, len(levels)] + [0] * 11
    header += [32, 0x41, 0, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000]
    header += [0x401008, 0, 0, 0, 0]
    path.write_bytes(b"DDS " + struct.pack("<31I", *header) + b"".join(levels))


def bake_maps(source, obj, name):
    # Meshy uses a dense UV atlas. Collapsing its triangles invalidates the
    # original atlas interpolation; reproject the original surface onto a new
    # low-poly UV layout instead of stretching that atlas over the decimation.
    activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    material = bpy.data.materials.new(name + ".bake")
    material.use_nodes = True
    obj.data.materials.clear()
    obj.data.materials.append(material)
    target = material.node_tree.nodes.new("ShaderNodeTexImage")
    material.node_tree.nodes.active = target
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = .003
    scene.render.bake.max_ray_distance = .025
    scene.render.bake.margin = 8
    scene.render.bake.use_clear = True
    activate(obj)
    source.select_set(True)
    images = []
    for kind in ("DIFFUSE", "NORMAL"):
        image = bpy.data.images.new(name + "." + kind.lower(), 2048, 2048, alpha=False)
        if kind == "NORMAL":
            image.colorspace_settings.name = "Non-Color"
        target.image = image
        bpy.ops.object.bake(type=kind, pass_filter={"COLOR"} if kind == "DIFFUSE" else set())
        images.append(image)
    bpy.data.objects.remove(source, do_unlink=True)
    return images


def game_material(obj, name, texconv, images):
    diffuse, normal = images
    material = shader("normal_spec.sps")
    material.name = name
    texture_dir = HERE / "textures"
    raw_dir = HERE / "build" / "textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    raw_dir.mkdir(parents=True, exist_ok=True)
    for suffix, image, sampler in (("d", diffuse, "DiffuseSampler"), ("n", normal, "BumpSampler")):
        image.scale(2048, 2048)
        pixels = np.empty(2048 * 2048 * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels = pixels.reshape(2048, 2048, 4)
        pixels[:, :, 3] = 1
        raw = raw_dir / f"{name}_{suffix}.dds"
        # DDS origin is top-left; Blender exposes rows from the bottom.
        dds_rgba(raw, np.clip(pixels[::-1] * 255, 0, 255).astype(np.uint8))
        result = subprocess.run([str(texconv), "-nologo", "-y", "-dx9", "-f", "BC3_UNORM" if suffix == "n" else "BC1_UNORM", "-o", str(texture_dir), str(raw)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        converted = bpy.data.images.load(str(texture_dir / raw.name), check_existing=True)
        if suffix == "n":
            converted.colorspace_settings.name = "Non-Color"
        node = material.node_tree.nodes[sampler]
        node.image = converted
        node.texture_properties.embedded = True
    material.node_tree.nodes["SpecSampler"].image = material.node_tree.nodes["DiffuseSampler"].image
    material.node_tree.nodes["SpecSampler"].texture_properties.embedded = True
    material.node_tree.nodes["specularIntensityMult"].set_float(.12)
    material.node_tree.nodes["specularFalloffMult"].set_float(32)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    obj.data.uv_layers.active.name = "UVMap 0"
    colours = obj.data.color_attributes.new(name="Color 1", type="BYTE_COLOR", domain="CORNER")
    colours.data.foreach_set("color", np.ones(len(colours.data) * 4, dtype=np.float32))
    return material


def add_collision(root, boxes, material_name="METAL_SOLID_MEDIUM"):
    composite = empty(p.SollumType.BOUND_COMPOSITE, root.name + ".collision")
    composite.parent = root
    composite.hide_render = True
    material = collision.create_collision_material_from_index(next(i for i, m in enumerate(collision.collisionmats) if m.name == material_name))
    for centre, size, rotation in boxes:
        box = bound_box()
        box.parent = composite
        box.location = centre
        box.dimensions = size
        box.rotation_euler = rotation
        box.data.materials.append(material)
        box.hide_render = True
        for group, values in COLLISION_FLAGS.items():
            for flag, enabled in values.items():
                setattr(getattr(box, group), flag, enabled)


def distant_cabinet(name):
    """At distance the cabinet occupies only a few pixels; use its solid case."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -1.43, 1.30))
    obj = bpy.context.object
    obj.dimensions = (.76, .36, 1.20)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    triangulate = obj.modifiers.new("Native triangles", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj.data.uv_layers.active.name = "UVMap 0"
    colours = obj.data.color_attributes.new(name="Color 1", type="BYTE_COLOR", domain="CORNER")
    colours.data.foreach_set("color", np.ones(len(colours.data) * 4, dtype=np.float32))
    texture = HERE / "textures" / (PREFIX + name + "_far.dds")
    shade = (62, 59, 55, 255) if name == "panel_broken" else (120, 122, 122, 255)
    dds_rgba(texture, np.array([[shade]], dtype=np.uint8))
    material = shader("default.sps")
    material.name = PREFIX + name + "_far"
    node = material.node_tree.nodes["DiffuseSampler"]
    node.image = bpy.data.images.load(str(texture), check_existing=True)
    node.texture_properties.embedded = True
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def export_model(obj, name, ytyp, counts, boxes):
    root = empty(p.SollumType.DRAWABLE, PREFIX + name)
    obj.name = root.name + ".mesh"
    convert(obj)
    obj.parent = root
    report = {"HIGH": len(obj.data.polygons)}
    for level, count in zip((p.LODLevel.MEDIUM, p.LODLevel.LOW, p.LODLevel.VERYLOW), counts):
        if name.startswith("panel") and level in (p.LODLevel.LOW, p.LODLevel.VERYLOW):
            duplicate = distant_cabinet(name)
        else:
            duplicate = obj.copy()
            duplicate.data = obj.data.copy()
            bpy.context.collection.objects.link(duplicate)
            decimate(duplicate, count)
        obj.sz_lods.get_lod(level).mesh = duplicate.data
        report[level.name] = len(duplicate.data.polygons)
        bpy.data.objects.remove(duplicate, do_unlink=True)
    obj.sz_lods.active_lod_level = p.LODLevel.HIGH
    distances = (70, 140, 260, 500) if name == "tower" else (20, 45, 90, 150)
    props = root.drawable_properties
    props.lod_dist_high, props.lod_dist_med, props.lod_dist_low, props.lod_dist_vlow = distances
    add_collision(root, boxes)
    arch = ytyp.new_archetype(p.ArchetypeType.BASE)
    arch.name = root.name
    arch.asset = root
    arch.asset_type = p.AssetType.DRAWABLE
    arch.asset_name = root.name
    arch.texture_dictionary = root.name
    arch.drawable_dictionary = ""
    arch.physics_dictionary = root.name
    arch.clip_dictionary = ""
    arch.flags.total = "0"
    arch.lod_dist = distances[-1]
    arch.hd_texture_dist = distances[0]
    return root, {"triangles": report, "dimensions": list(obj.dimensions), "collisionBoxes": len(boxes)}


def render_preview(roots):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.world.color = (.3, .3, .3)
    scene.view_settings.view_transform = "Standard"
    camera = bpy.data.objects.new("Review camera", bpy.data.cameras.new("Review camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    for label, loc, energy, size in (("Key", (-5, -7, 10), 2500, 8), ("Fill", (5, -3, 4), 500, 4)):
        light = bpy.data.objects.new(label, bpy.data.lights.new(label, "AREA"))
        scene.collection.objects.link(light)
        light.location = loc
        light.rotation_euler = (Vector((0, 0, 5)) - light.location).to_track_quat("-Z", "Y").to_euler()
        light.data.energy, light.data.size = energy, size
    door, panel, broken = roots["door"], roots["panel"], roots["panel_broken"]
    door.location = DOOR_OFFSET
    def visible(root, enabled):
        for child in root.children:
            if child.sollum_type == p.SollumType.DRAWABLE_MODEL:
                child.hide_render = not enabled
    previews = HERE / "previews"
    previews.mkdir(exist_ok=True)
    for state in ("closed", "open", "damaged", "tower"):
        visible(panel, state != "damaged")
        visible(broken, state == "damaged")
        door.rotation_euler.z = 0 if state in ("closed", "tower") else math.radians(-110)
        centre = Vector((0, -.7, 8)) if state == "tower" else Vector((-.15, -1.65, 1.3))
        camera.data.ortho_scale = 20 if state == "tower" else 1.8
        camera.location = centre + Vector((8, -24, 3) if state == "tower" else (1.0, -4, 1))
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(previews / (state + ".png"))
        bpy.ops.render.render(write_still=True)
    door.location = (0, 0, 0)
    door.rotation_euler.z = 0
    visible(broken, True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inputs", required=True, type=Path)
    parser.add_argument("--texconv", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.ytyps.clear()
    ytyp = scene.ytyps.add()
    ytyp.name = "sky_phone_cell_towers"
    scene.ytyp_index = 0
    roots, report = {}, {"inputs": {}, "doorOffset": list(DOOR_OFFSET), "cabinetOffset": [0, -1.55, 1.30], "models": {}}
    for source_name, name, budget in (("tower_textured", "tower", 40000), ("intact", "panel", 24000), ("damaged", "panel_broken", 24000)):
        path = args.inputs / (source_name + ".glb")
        report["inputs"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        print("IMPORT", name, flush=True)
        bpy.ops.import_scene.gltf(filepath=str(path))
        obj = next(o for o in bpy.context.selected_objects if o.type == "MESH")
        activate(obj)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if name == "tower":
            cut(obj, lambda v: v.x < -.16 and -.80 < v.z < -.54)
        original = obj.copy()
        original.data = obj.data.copy()
        bpy.context.collection.objects.link(original)
        # glTF duplicates vertices at UV/normal seams. Weld those positions
        # before collapsing; reducing disconnected seam triangles tears them.
        activate(obj)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=.00001)
        bpy.ops.object.mode_set(mode="OBJECT")
        if obj.data.attributes.get("sharp_edge"):
            obj.data.attributes.remove(obj.data.attributes["sharp_edge"])
        # Reduce before splitting to keep the working authoring scene manageable.
        decimate(obj, budget + (5000 if name == "panel" else 0))
        images = bake_maps(original, obj, PREFIX + name)
        game_material(obj, PREFIX + name, args.texconv, images)
        if name != "tower":
            if name == "panel":
                door = obj.copy()
                door.data = obj.data.copy()
                bpy.context.collection.objects.link(door)
                cut(door, lambda v: v.x >= -.535)
                for vertex in door.data.vertices:
                    relative = vertex.co - HINGE
                    # Fit the generated door's width to its cabinet opening.
                    vertex.co = Vector((-relative.y * 1.32, relative.x, relative.z)) * SCALE
                roots["door"], report["models"]["door"] = export_model(door, "door", ytyp, (1400, 500, 120), [((.37, -.045, 0), (.75, .07, 1.05), (0, 0, 0))])
            cut(obj, lambda v: v.x < -.535)
            for vertex in obj.data.vertices:
                vertex.co = vertex.co * SCALE + SHIFT
            boxes = [((0, -1.50, 1.30), (.61, .12, .91), (0, 0, 0))]
            counts = (7000, 1800, 300)
        else:
            low = min(v.co.z for v in obj.data.vertices)
            high = max(v.co.z for v in obj.data.vertices)
            scale = 16 / (high - low)
            for vertex in obj.data.vertices:
                vertex.co = Vector((vertex.co.x * scale, vertex.co.y * scale, (vertex.co.z - low) * scale))
            boxes = [((0, 0, .24), (3.65, 3.65, .48), (0, 0, 0)), ((0, 0, 13.2), (2.6, 2.6, 2.5), (0, 0, 0))]
            for x in (-1, 1):
                for y in (-1, 1):
                    start, end = Vector((x * 1.25, y * 1.25, .5)), Vector((x * .42, y * .42, 12))
                    direction = end - start
                    boxes.append((tuple((start + end) * .5), (.16, .16, direction.length), direction.to_track_quat("Z", "Y").to_euler()))
            # Cabinet case belongs to the invulnerable tower; only its inner
            # opening belongs to the damageable panel collision.
            boxes += [((x, -1.43, 1.3), (.07, .36, 1.08), (0, 0, 0)) for x in (-.37, .34)]
            boxes += [((-.015, -1.43, z), (.78, .36, .07), (0, 0, 0)) for z in (.77, 1.84)]
            boxes.append(((-.015, -1.27, 1.3), (.78, .06, 1.1), (0, 0, 0)))
            counts = (12000, 3500, 700)
        roots[name], report["models"][name] = export_model(obj, name, ytyp, counts, boxes)
        print("READY", name, report["models"][name], flush=True)
    STREAM.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for root in roots.values():
        root.select_set(True)
    bpy.context.view_layer.objects.active = roots["tower"]
    result = bpy.ops.sollumz.export_assets(directory=str(STREAM), direct_export=True, use_custom_settings=True,
        target_formats={"NATIVE"}, target_versions={"GEN8"}, limit_to_selected=True, exclude_skeleton=True,
        apply_transforms=False, export_ytyps=True, export_ytyps_include="ALL", export_ymaps=False, export_ytds=False)
    assert result == {"FINISHED"}, result
    for name in [root.name + ".ydr" for root in roots.values()] + ["sky_phone_cell_towers.ytyp"]:
        path = STREAM / name
        assert path.read_bytes()[:4] == b"RSC7", name
    (HERE / "export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for image in bpy.data.images:
        if image.filepath.endswith(".dds"):
            image.pack()
            image.filepath = "//textures/" + Path(image.filepath).name
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "cell_towers.blend"), compress=True)
    render_preview(roots)
    print("CELL_TOWERS_EXPORT_OK", flush=True)


if __name__ == "__main__":
    main()
