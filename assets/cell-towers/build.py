"""Build the Meshy mast and clean cabinet as four native, articulated GTA props.

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
convert_bound_geometry = importlib.import_module(addon + ".tools.boundhelper").convert_obj_to_geometry
collision = importlib.import_module(addon + ".ybn.collision_materials")


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def decimate(obj, triangles, preserve_uv=False, preserve_tip=False):
    activate(obj)
    mod = obj.modifiers.new("Meshy topology reduction", "DECIMATE")
    mod.ratio = min(1.0, triangles / len(obj.data.polygons))
    mod.use_collapse_triangulate = True
    if preserve_uv or preserve_tip:
        # A zero weight prevents an edge collapse at an atlas boundary. Keep
        # those vertices so the original maps remain usable on the near mesh.
        unlocked = np.ones(len(obj.data.vertices), dtype=bool)
        if preserve_uv:
            indices = np.empty(len(obj.data.loops), dtype=np.int32)
            obj.data.loops.foreach_get("vertex_index", indices)
            uv = np.empty(len(obj.data.loops) * 2, dtype=np.float32)
            obj.data.uv_layers.active.data.foreach_get("uv", uv)
            uv = uv.reshape(-1, 2)
            low = np.full((len(obj.data.vertices), 2), np.inf)
            high = np.full((len(obj.data.vertices), 2), -np.inf)
            np.minimum.at(low, indices, uv)
            np.maximum.at(high, indices, uv)
            unlocked &= np.max(high - low, axis=1) < .000001
        if preserve_tip:
            positions = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
            obj.data.vertices.foreach_get("co", positions)
            heights = positions.reshape(-1, 3)[:, 2]
            unlocked &= heights < heights.max() - .05
        interior = np.flatnonzero(unlocked).tolist()
        group = obj.vertex_groups.new(name="Preserve atlas and antenna tip")
        group.add(interior, 1.0, "REPLACE")
        mod.vertex_group = group.name
        mod.vertex_group_factor = 1.0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if preserve_uv or preserve_tip:
        obj.vertex_groups.clear()
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for face in obj.data.polygons:
        face.use_smooth = True


def transfer_normals(source, obj):
    activate(obj)
    transfer = obj.modifiers.new("Original surface normals", "DATA_TRANSFER")
    transfer.object = source
    transfer.use_loop_data = True
    transfer.data_types_loops = {"CUSTOM_NORMAL"}
    transfer.loop_mapping = "POLYINTERP_NEAREST"
    bpy.ops.object.modifier_apply(modifier=transfer.name)


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


def bake_maps(source, obj, name, preserve_uv=False):
    activate(obj)
    if not preserve_uv:
        # The more heavily reduced cabinet parts use their own atlas.
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
    scene.render.bake.use_cage = False
    scene.render.bake.cage_extrusion = .002 if preserve_uv else .003
    scene.render.bake.max_ray_distance = .015 if preserve_uv else .025
    scene.render.bake.margin = 12 if preserve_uv else 8
    scene.render.bake.use_clear = True
    activate(obj)
    source.select_set(True)
    images = []
    for kind in ("DIFFUSE", "NORMAL"):
        size = 4096 if preserve_uv else 2048
        image = bpy.data.images.new(name + "." + kind.lower(), size, size, alpha=False)
        if kind == "NORMAL":
            image.colorspace_settings.name = "Non-Color"
        target.image = image
        bpy.ops.object.bake(type=kind, pass_filter={"COLOR"} if kind == "DIFFUSE" else set())
        images.append(image)
    if preserve_uv:
        # Project all original maps onto the reduced surface. Keeping the UV
        # islands alone does not correct interpolation after edge collapses.
        nodes = source.data.materials[0].node_tree.nodes
        bsdf = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
        split = bsdf.inputs["Metallic"].links[0].from_node
        orm = split.inputs[0].links[0].from_node
        emission = nodes.new("ShaderNodeEmission")
        output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL")
        links = source.data.materials[0].node_tree.links
        links.new(orm.outputs["Color"], emission.inputs["Color"])
        links.new(emission.outputs[0], output.inputs["Surface"])
        image = bpy.data.images.new(name + ".metallic_roughness", 2048, 2048, alpha=False)
        image.colorspace_settings.name = "Non-Color"
        target.image = image
        bpy.ops.object.bake(type="EMIT")
        images.append(image)
    bpy.data.objects.remove(source, do_unlink=True)
    return images


def game_material(obj, name, texconv, images):
    diffuse, normal = images[:2]
    material = shader("normal_spec.sps")
    material.name = name
    texture_dir = HERE / "textures"
    raw_dir = HERE / "build" / "textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    raw_dir.mkdir(parents=True, exist_ok=True)
    maps = [("d", diffuse, "DiffuseSampler"), ("n", normal, "BumpSampler")]
    if len(images) == 3:
        orm = images[2]
        width, height = orm.size
        pixels = np.empty(width * height * 4, dtype=np.float32)
        orm.pixels.foreach_get(pixels)
        pixels = pixels.reshape(height, width, 4)
        metallic = pixels[:, :, 2].copy()
        roughness = pixels[:, :, 1].copy()
        # GTA's legacy specular workflow stores highlight strength in RGB
        # and gloss in alpha, rather than glTF's metallic/roughness channels.
        pixels[:, :, :3] = (.08 + .7 * metallic)[:, :, None]
        pixels[:, :, 3] = 1 - roughness
        specular = bpy.data.images.new(name + ".specular", width, height, alpha=True)
        specular.colorspace_settings.name = "Non-Color"
        specular.pixels.foreach_set(pixels.ravel())
        maps.append(("s", specular, "SpecSampler"))
    for suffix, image, sampler in maps:
        width, height = image.size
        pixels = np.empty(width * height * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels = pixels.reshape(height, width, 4)
        if suffix != "s":
            pixels[:, :, 3] = 1
        if len(images) == 3 and suffix == "n":
            # glTF uses +Y tangent normals; GTA/Sollumz uses -Y.
            pixels[:, :, 1] = 1 - pixels[:, :, 1]
        raw = raw_dir / f"{name}_{suffix}.dds"
        # DDS origin is top-left; Blender exposes rows from the bottom.
        dds_rgba(raw, np.clip(pixels[::-1] * 255, 0, 255).astype(np.uint8))
        result = subprocess.run([str(texconv), "-nologo", "-y", "-dx9", "-f", "BC1_UNORM" if suffix == "d" else "BC3_UNORM", "-o", str(texture_dir), str(raw)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        converted = bpy.data.images.load(str(texture_dir / raw.name), check_existing=True)
        if suffix != "d":
            converted.colorspace_settings.name = "Non-Color"
        node = material.node_tree.nodes[sampler]
        node.image = converted
        node.texture_properties.embedded = True
    if len(images) == 3:
        material.node_tree.nodes["specularIntensityMult"].set_float(1)
        material.node_tree.nodes["specularFalloffMult"].set_float(180)
        material.node_tree.nodes["specularFresnel"].set_float(.5)
    else:
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


def add_collision(root, boxes, material_name="METAL_SOLID_MEDIUM", composite=None):
    if composite is None:
        composite = empty(p.SollumType.BOUND_COMPOSITE, root.name + ".collision")
        composite.parent = root
        composite.hide_render = True
    material = collision.create_collision_material_from_index(next(i for i, m in enumerate(collision.collisionmats) if m.name == material_name))
    created = []
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
        created.append(box)
    return created


def add_lattice_collision(root, source):
    """Follow the Meshy braces, including their irregular ends and open gaps."""
    composite = next(child for child in root.children if child.sollum_type == p.SollumType.BOUND_COMPOSITE)
    obj = bpy.data.objects.new(root.name + ".lattice_collision", source.data.copy())
    bpy.context.collection.objects.link(obj)
    cut(obj, lambda vertex: vertex.z < .60 or vertex.z > 12.4)
    decimate(obj, 6000)
    obj.data.materials.clear()
    material_index = next(i for i, material in enumerate(collision.collisionmats) if material.name == "METAL_SOLID_MEDIUM")
    obj.data.materials.append(collision.create_collision_material_from_index(material_index))
    for face in obj.data.polygons:
        face.material_index = 0
    for layer in list(obj.data.uv_layers):
        obj.data.uv_layers.remove(layer)
    for attribute in list(obj.data.color_attributes):
        obj.data.color_attributes.remove(attribute)
    convert_bound_geometry(obj, "General (Default)")
    obj.parent = composite
    obj.hide_render = True
    return len(obj.data.polygons)


def export_model(obj, name, ytyp, counts, boxes, lods=None):
    # Vertex edits must invalidate Blender's cached bounds before the YTYP
    # exporter reads object.bound_box.
    obj.data.update()
    root = empty(p.SollumType.DRAWABLE, PREFIX + name)
    obj.name = root.name + ".mesh"
    convert(obj)
    obj.parent = root
    report = {"HIGH": len(obj.data.polygons)}
    for index, (level, count) in enumerate(zip((p.LODLevel.MEDIUM, p.LODLevel.LOW, p.LODLevel.VERYLOW), counts)):
        if lods is not None:
            duplicate = lods[index]
        else:
            duplicate = obj.copy()
            duplicate.data = obj.data.copy()
            bpy.context.collection.objects.link(duplicate)
            decimate(duplicate, count, preserve_tip=name == "tower")
            if name == "tower":
                transfer_normals(obj, duplicate)
        obj.sz_lods.get_lod(level).mesh = duplicate.data
        report[level.name] = len(duplicate.data.polygons)
        bpy.data.objects.remove(duplicate, do_unlink=True)
    obj.sz_lods.active_lod_level = p.LODLevel.HIGH
    distances = (35, 100, 230, 500) if name == "tower" else (20, 45, 90, 150)
    props = root.drawable_properties
    props.lod_dist_high, props.lod_dist_med, props.lod_dist_low, props.lod_dist_vlow = distances
    add_collision(root, boxes)
    arch = next((archetype for archetype in ytyp.archetypes if archetype.name == root.name), None)
    if arch is None:
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
    return root, {"triangles": report, "dimensions": list(obj.dimensions), "collisionBoxes": len(boxes),
        "collisionTriangles": 0}


def render_preview(roots, states=("closed", "open", "damaged", "tower", "side")):
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
    for state in states:
        visible(panel, state != "damaged")
        visible(broken, state == "damaged")
        door.rotation_euler.z = 0 if state in ("closed", "tower", "side") else math.radians(-110)
        if state == "tower":
            centre, view = Vector((0, -.7, 8)), Vector((8, -24, 3))
        elif state == "side":
            centre, view = Vector((-1.48, -.045, 2.44)), Vector((-4, -.8, .7))
        else:
            centre, view = Vector((-.15, -1.65, 1.3)), Vector((1.0, -4, 1))
        camera.data.ortho_scale = 20 if state == "tower" else 1.8
        camera.location = centre + view
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(previews / (state + ".png"))
        bpy.ops.render.render(write_still=True)
    door.location = (0, 0, 0)
    door.rotation_euler.z = 0
    visible(broken, True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inputs", type=Path)
    parser.add_argument("--texconv", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--tower-only", action="store_true", help="Rebuild the mast and refit the cabinet assemblies.")
    mode.add_argument("--collision-only", action="store_true", help="Rebuild lattice collision from the saved mast; preserve all visual assets.")
    mode.add_argument("--cabinet-only", action="store_true", help="Rebuild clean cabinet parts while preserving the mast's geometry and textures.")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    if not args.collision_only and not args.cabinet_only and (args.inputs is None or args.texconv is None):
        parser.error("--inputs and --texconv are required when rebuilding visual assets")
    if args.collision_only or args.cabinet_only:
        bpy.ops.wm.open_mainfile(filepath=str(HERE / "cell_towers.blend"))
        roots = {name: bpy.data.objects[PREFIX + name] for name in ("tower", "door", "panel", "panel_broken")}
        report = json.loads((HERE / "export-report.json").read_text())
        ytyp = bpy.context.scene.ytyps[0]
    elif args.tower_only:
        bpy.ops.wm.open_mainfile(filepath=str(HERE / "cell_towers.blend"))
        root = bpy.data.objects[PREFIX + "tower"]
        meshes = set()
        for obj in root.children_recursive:
            if obj.sollum_type == p.SollumType.DRAWABLE_MODEL:
                for level in (p.LODLevel.HIGH, p.LODLevel.MEDIUM, p.LODLevel.LOW, p.LODLevel.VERYLOW):
                    meshes.add(obj.sz_lods.get_lod(level).mesh)
        for obj in list(root.children_recursive) + [root]:
            bpy.data.objects.remove(obj, do_unlink=True)
        for mesh in meshes:
            bpy.data.meshes.remove(mesh)
        bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
        ytyp = bpy.context.scene.ytyps[0]
        roots = {name: bpy.data.objects[PREFIX + name] for name in ("door", "panel", "panel_broken")}
        report = json.loads((HERE / "export-report.json").read_text())
    else:
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)
        scene = bpy.context.scene
        scene.ytyps.clear()
        ytyp = scene.ytyps.add()
        ytyp.name = "sky_phone_cell_towers"
        scene.ytyp_index = 0
        roots, report = {}, {"inputs": {}, "doorOffset": list(DOOR_OFFSET), "cabinetOffset": [0, -1.55, 1.30], "models": {}}
    if not (args.collision_only or args.cabinet_only):
        path = args.inputs / "tower_textured.glb"
        report["inputs"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        print("IMPORT tower", flush=True)
        bpy.ops.import_scene.gltf(filepath=str(path))
        obj = next(o for o in bpy.context.selected_objects if o.type == "MESH")
        activate(obj)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
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
        decimate(obj, 300000, preserve_uv=True)
        transfer_normals(original, obj)
        images = bake_maps(original, obj, PREFIX + "tower", preserve_uv=True)
        game_material(obj, PREFIX + "tower", args.texconv, images)
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
        # The fixed casing is invulnerable; only the interior collider accepts damage.
        boxes += [((x, -1.43, 1.3), (.07, .36, 1.08), (0, 0, 0)) for x in (-.37, .34)]
        boxes += [((-.015, -1.43, z), (.78, .36, .07), (0, 0, 0)) for z in (.77, 1.84)]
        boxes.append(((-.015, -1.27, 1.3), (.78, .06, 1.1), (0, 0, 0)))
        roots["tower"], report["models"]["tower"] = export_model(obj, "tower", ytyp, (80000, 20000, 5000), boxes)
    if not args.collision_only:
        sys.path.insert(0, str(HERE))
        import cabinet
        cabinet.install(sys.modules[__name__], roots, report, ytyp)
    root = roots["tower"]
    for obj in list(root.children_recursive):
        if obj.sollum_type in (p.SollumType.BOUND_GEOMETRY, p.SollumType.BOUND_GEOMETRYBVH, p.SollumType.BOUND_POLY_TRIANGLE):
            bpy.data.objects.remove(obj, do_unlink=True)
    model = bpy.data.objects[PREFIX + "tower.mesh"]
    model.sz_lods.active_lod_level = p.LODLevel.HIGH
    report["models"]["tower"]["collisionTriangles"] = add_lattice_collision(root, model)
    print("LATTICE_COLLISION", report["models"]["tower"]["collisionTriangles"], flush=True)
    STREAM.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    export_roots = [roots["tower"]] if args.collision_only else roots.values()
    for root in export_roots:
        root.select_set(True)
    bpy.context.view_layer.objects.active = roots["tower"]
    bpy.context.view_layer.update()
    result = bpy.ops.sollumz.export_assets(directory=str(STREAM), direct_export=True, use_custom_settings=True,
        target_formats={"NATIVE"}, target_versions={"GEN8"}, limit_to_selected=True, exclude_skeleton=True,
        apply_transforms=False, export_ytyps=False, export_ymaps=False, export_ytds=False)
    assert result == {"FINISHED"}, result
    # YDR export temporarily switches LOD meshes. Update their restored High
    # bounds before exporting the archetypes in a separate operator call.
    bpy.context.view_layer.update()
    result = bpy.ops.sollumz.export_ytyp_io(directory=str(STREAM), direct_export=True, use_custom_settings=True,
        target_formats={"NATIVE"}, target_versions={"GEN8"}, apply_transforms=False, export_ytyps_include="ALL")
    assert result == {"FINISHED"}, result
    for name in [root.name + ".ydr" for root in roots.values()] + ["sky_phone_cell_towers.ytyp"]:
        path = STREAM / name
        assert path.read_bytes()[:4] == b"RSC7", name
    (HERE / "export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for image in bpy.data.images:
        if image.filepath.endswith(".dds"):
            filename = Path(bpy.path.abspath(image.filepath)).name
            image.pack()
            image.filepath = "//textures/" + filename
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "cell_towers.blend"), compress=True)
    if not args.collision_only:
        render_preview(roots)
    print("CELL_TOWERS_EXPORT_OK", flush=True)


if __name__ == "__main__":
    main()
