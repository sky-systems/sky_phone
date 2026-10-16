"""Reimport native exports in a fresh Blender process and check their contents."""
import hashlib
import importlib
import json
import math
from pathlib import Path
import bpy

HERE = Path(__file__).resolve().parent
STREAM = HERE.parents[1] / "sky_phone" / "stream"
addon = next(a.module for a in bpy.context.preferences.addons if "sollumz" in a.module)
p = importlib.import_module(addon + ".sollumz_properties")
expected = json.loads((HERE / "export-report.json").read_text())
results = []
for name, specification in expected["models"].items():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    path = STREAM / ("sky_phone_cell_" + name + ".ydr")
    assert path.read_bytes()[:4] == b"RSC7"
    assert bpy.ops.sollumz.import_assets(directory=str(STREAM), files=[{"name": path.name}],
        use_custom_settings=True, textures_mode="PACK") == {"FINISHED"}
    root = bpy.data.objects[path.stem]
    assert root.sollum_type == p.SollumType.DRAWABLE
    models = [obj for obj in root.children if obj.sollum_type == p.SollumType.DRAWABLE_MODEL]
    counts = {}
    textures = set()
    for level in (p.LODLevel.HIGH, p.LODLevel.MEDIUM, p.LODLevel.LOW, p.LODLevel.VERYLOW):
        count = 0
        for obj in models:
            mesh = obj.sz_lods.get_lod(level).mesh
            if mesh is None:
                continue
            mesh.calc_loop_triangles()
            count += len(mesh.loop_triangles)
            assert mesh.uv_layers.get("UVMap 0") and mesh.color_attributes.get("Color 1")
            assert all(math.isfinite(component) for vertex in mesh.vertices for component in vertex.co)
            for material in mesh.materials:
                for node in material.node_tree.nodes:
                    if node.type != "TEX_IMAGE" or not node.is_sollumz:
                        continue
                    assert node.image and node.texture_properties.embedded and node.image.packed_file
                    assert node.image.packed_file.data[:4] == b"DDS "
                    textures.add(node.image.name)
        counts[level.name] = count
        assert count == specification["triangles"][level.name], (name, level.name, count)
    composite = next(child for child in root.children if child.sollum_type == p.SollumType.BOUND_COMPOSITE)
    assert len(composite.children) == specification["collisionBoxes"]
    for bound in composite.children:
        assert bound.composite_flags1.map_weapon and bound.composite_flags1.map_dynamic
        assert bound.composite_flags2.projectile and bound.composite_flags2.test_weapon
        assert bound.composite_flags2.explosion and bound.composite_flags2.ped
    results.append({"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "triangles": counts, "textures": sorted(textures), "collisionBoxes": len(composite.children)})
assert (STREAM / "sky_phone_cell_towers.ytyp").read_bytes()[:4] == b"RSC7"
assert bpy.ops.sollumz.import_assets(directory=str(STREAM), files=[{"name": "sky_phone_cell_towers.ytyp"}],
    use_custom_settings=True) == {"FINISHED"}
archetypes = bpy.context.scene.ytyps[-1].archetypes
assert len(archetypes) == 4
assert all(arch.physics_dictionary == arch.asset_name and arch.physics_dictionary for arch in archetypes)
(HERE / "native-validation.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
print("CELL_TOWERS_NATIVE_REIMPORT_PASSED", len(results), flush=True)
