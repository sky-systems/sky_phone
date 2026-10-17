"""Reimport native exports in a fresh Blender process and check their contents."""
import hashlib
import importlib
import json
import math
from pathlib import Path
import struct
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from pymateria.gta5 import gen8

HERE = Path(__file__).resolve().parent
STREAM = HERE.parents[1] / "sky_phone" / "stream"
addon = next(a.module for a in bpy.context.preferences.addons if "sollumz" in a.module)
p = importlib.import_module(addon + ".sollumz_properties")
expected = json.loads((HERE / "export-report.json").read_text())
results = []


def check_lattice_surface(models, lattice_meshes):
    """Compare the exported collision with the visible lattice on all four sides."""
    surfaces = []
    for objects, visual in ((models, True), (lattice_meshes, False)):
        vertices, faces = [], []
        for obj in objects:
            mesh = obj.sz_lods.get_lod(p.LODLevel.HIGH).mesh if visual else obj.data
            base = len(vertices)
            vertices.extend(obj.matrix_world @ vertex.co for vertex in mesh.vertices)
            for face in mesh.polygons:
                if visual:
                    material = mesh.materials[face.material_index]
                    if material.node_tree.nodes["DiffuseSampler"].sollumz_texture_name != "sky_phone_cell_tower_d":
                        continue
                faces.append([base + index for index in face.vertices])
        surfaces.append(BVHTree.FromPolygons(vertices, faces))
    reference, lattice = surfaces
    rays = hits = missed = extra = 0
    errors = []
    for axis, side in ((1, -1), (0, 1), (1, 1), (0, -1)):
        direction = Vector((0, 0, 0))
        direction[axis] = -side
        for z in np.arange(.72, 12.15, .055):
            for across in np.arange(-1.3, 1.3, .045):
                origin = Vector((0, 0, float(z)))
                origin[axis], origin[1 - axis] = side * 1.65, float(across)
                expected_hit, _, _, expected_distance = reference.ray_cast(origin, direction, 1.30)
                actual_hit, _, _, actual_distance = lattice.ray_cast(origin, direction, 1.30)
                rays += 1
                if expected_hit is not None:
                    hits += 1
                    if actual_hit is None:
                        missed += 1
                    else:
                        errors.append(abs(actual_distance - expected_distance))
                elif actual_hit is not None:
                    extra += 1
    coverage = 1 - missed / hits
    clear_gaps = 1 - extra / (rays - hits)
    distance_95 = float(np.quantile(errors, .95))
    assert coverage > .95 and clear_gaps > .98 and distance_95 < .05, (coverage, clear_gaps, distance_95)
    return {"rays": rays, "visualHits": hits, "surfaceCoverage": coverage,
        "clearGaps": clear_gaps, "distanceError95Metres": distance_95}


for name, specification in expected["models"].items():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    path = STREAM / ("sky_phone_cell_" + name + ".ydr")
    assert path.read_bytes()[:4] == b"RSC7"
    native = gen8.Drawable.import_rsc(path).result
    native_textures = {str(texture.name): texture for texture in native.shader_group.texture_dictionary.textures.values()}
    assert bpy.ops.sollumz.import_assets(directory=str(STREAM), files=[{"name": path.name}],
        use_custom_settings=True, textures_mode="PACK") == {"FINISHED"}
    root = bpy.data.objects[path.stem]
    assert root.sollum_type == p.SollumType.DRAWABLE
    models = [obj for obj in root.children if obj.sollum_type == p.SollumType.DRAWABLE_MODEL]
    counts = {}
    textures = {}
    vertices = {}
    high_min = [math.inf] * 3
    high_max = [-math.inf] * 3
    for level in (p.LODLevel.HIGH, p.LODLevel.MEDIUM, p.LODLevel.LOW, p.LODLevel.VERYLOW):
        count = 0
        vertex_count = 0
        for obj in models:
            mesh = obj.sz_lods.get_lod(level).mesh
            if mesh is None:
                continue
            mesh.calc_loop_triangles()
            count += len(mesh.loop_triangles)
            vertex_count += len(mesh.vertices)
            assert mesh.uv_layers.get("UVMap 0") and mesh.color_attributes.get("Color 1")
            assert all(math.isfinite(component) for vertex in mesh.vertices for component in vertex.co)
            if level == p.LODLevel.HIGH:
                for vertex in mesh.vertices:
                    for axis in range(3):
                        high_min[axis] = min(high_min[axis], vertex.co[axis])
                        high_max[axis] = max(high_max[axis], vertex.co[axis])
            for material in mesh.materials:
                for node in material.node_tree.nodes:
                    if node.type != "TEX_IMAGE" or not node.is_sollumz:
                        continue
                    assert node.image and node.texture_properties.embedded and node.image.packed_file
                    data = node.image.packed_file.data
                    assert data[:4] == b"DDS "
                    height, width = struct.unpack_from("<II", data, 12)
                    mip_count = struct.unpack_from("<I", data, 28)[0]
                    texture_name = node.sollumz_texture_name
                    texture_format = data[84:88].decode("ascii").strip("\0") or "RGBA8"
                    full_mips = int(math.log2(max(width, height))) + 1
                    # szio's GEN8 importer strips compressed DDS levels below
                    # one 4x4 block. Check native levels separately and compare
                    # every retained compressed block with the authored DDS.
                    expected_mips = max(1, full_mips - 2) if texture_format in ("DXT1", "DXT5") else full_mips
                    assert mip_count == expected_mips, (name, texture_name, mip_count)
                    native_texture = native_textures[texture_name]
                    assert (native_texture.width, native_texture.height) == (width, height)
                    assert expected_mips <= len(native_texture.mips) <= full_mips
                    source = (HERE / "textures" / (texture_name + ".dds")).read_bytes()
                    assert struct.unpack_from("<I", source, 28)[0] == full_mips
                    assert data[128:] == source[128:len(data)], texture_name
                    texture = {"width": width, "height": height, "nativeMipLevels": len(native_texture.mips),
                        "reimportMipLevels": mip_count, "format": texture_format, "reimportDdsBytes": len(data)}
                    assert texture_name not in textures or textures[texture_name] == texture
                    textures[texture_name] = texture
        counts[level.name] = count
        vertices[level.name] = vertex_count
        assert count == specification["triangles"][level.name], (name, level.name, count)
    composite = next(child for child in root.children if child.sollum_type == p.SollumType.BOUND_COMPOSITE)
    boxes = [child for child in composite.children if child.sollum_type == p.SollumType.BOUND_BOX]
    assert len(boxes) == specification["collisionBoxes"]
    lattice_meshes = [child for child in composite.children_recursive if child.sollum_type == p.SollumType.BOUND_GEOMETRY]
    collision_triangles = sum(len(obj.data.polygons) for obj in lattice_meshes)
    assert collision_triangles == specification.get("collisionTriangles", 0), (name, collision_triangles, specification.get("collisionTriangles", 0))
    for bound in composite.children:
        assert bound.composite_flags1.map_weapon and bound.composite_flags1.map_dynamic
        assert bound.composite_flags2.projectile and bound.composite_flags2.test_weapon
        assert bound.composite_flags2.explosion and bound.composite_flags2.ped
    surface_check = None
    if name == "tower":
        assert 0 < collision_triangles <= 6000
        bpy.context.view_layer.update()
        surface_check = check_lattice_surface(models, lattice_meshes)
        assert abs(high_max[2] - high_min[2] - 16.0) < .001
        assert textures["sky_phone_cell_tower_d"]["width"] == 4096
        assert textures["sky_phone_cell_tower_n"]["width"] == 4096
        assert textures["sky_phone_cell_tower_s"]["width"] == 2048
    distances = root.drawable_properties
    results.append({"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "fileBytes": path.stat().st_size, "triangles": counts, "vertices": vertices,
        "highBounds": {"min": high_min, "max": high_max},
        "lodDistances": [distances.lod_dist_high, distances.lod_dist_med, distances.lod_dist_low, distances.lod_dist_vlow],
        "textures": textures, "collisionBoxes": len(boxes), "collisionTriangles": collision_triangles,
        "collisionSurfaceCheck": surface_check})
assert (STREAM / "sky_phone_cell_towers.ytyp").read_bytes()[:4] == b"RSC7"
assert bpy.ops.sollumz.import_assets(directory=str(STREAM), files=[{"name": "sky_phone_cell_towers.ytyp"}],
    use_custom_settings=True) == {"FINISHED"}
archetypes = bpy.context.scene.ytyps[-1].archetypes
assert len(archetypes) == 4
assert all(arch.physics_dictionary == arch.asset_name and arch.physics_dictionary for arch in archetypes)
for archetype in archetypes:
    result = next(item for item in results if item["file"] == archetype.asset_name + ".ydr")
    result["archetypeBounds"] = {"min": list(archetype.bb_min), "max": list(archetype.bb_max)}
    assert all(archetype.bb_min[axis] <= result["highBounds"]["min"][axis] + .001
        and archetype.bb_max[axis] >= result["highBounds"]["max"][axis] - .001
        for axis in range(3)), (archetype.name, result["archetypeBounds"], result["highBounds"])
(HERE / "native-validation.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
print("CELL_TOWERS_NATIVE_REIMPORT_PASSED", len(results), flush=True)
