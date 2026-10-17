"""Hard-surface cabinet parts. Detail is geometry, not a blurred baked atlas."""
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector


# Shared colour/specular swatches keep the four drawables to one cabinet shader.
PALETTE = (
    (174, 185, 187, 55, 100),  # powder-coated enclosure
    (22, 27, 30, 40, 90),     # gasket / polymer
    (150, 163, 170, 185, 195), # plated metal
    (221, 224, 218, 50, 100),  # breaker housings
    (29, 85, 157, 55, 90),    # neutral conductors
    (231, 179, 35, 55, 95),   # warning / earth stripe
    (50, 110, 63, 50, 80),    # earth conductors
    (119, 72, 43, 60, 95),    # phase insulation
    (160, 45, 32, 65, 100),   # isolator / status lens
    (90, 103, 110, 100, 145),  # backplate
    (33, 30, 27, 18, 25),     # charred housing
    (159, 97, 49, 175, 170),  # exposed copper
    (8, 11, 13, 25, 65),     # screw slots / print
    (192, 198, 198, 65, 110), # edge trim
    (64, 72, 76, 60, 100),   # dark conduit
    (78, 142, 78, 65, 100),  # indicator lens (not emissive)
)


def material(build):
    textures = {}
    for suffix in ("d", "n", "s"):
        pixels = np.empty((256, 256, 4), dtype=np.uint8)
        for index, (r, g, b, specular, gloss) in enumerate(PALETTE):
            value = (r, g, b, 255) if suffix == "d" else (128, 128, 255, 255) if suffix == "n" else (specular, specular, specular, gloss)
            row, column = divmod(index, 4)
            pixels[row * 64:(row + 1) * 64, column * 64:(column + 1) * 64] = value
        path = build.HERE / "textures" / (build.PREFIX + "cabinet_" + suffix + ".dds")
        build.dds_rgba(path, pixels[::-1])
        image = bpy.data.images.load(str(path), check_existing=False)
        if suffix != "d":
            image.colorspace_settings.name = "Non-Color"
        textures[suffix] = image
    mat = build.shader("normal_spec.sps")
    mat.name = build.PREFIX + "cabinet"
    for suffix, sampler in (("d", "DiffuseSampler"), ("n", "BumpSampler"), ("s", "SpecSampler")):
        node = mat.node_tree.nodes[sampler]
        node.image = textures[suffix]
        node.texture_properties.embedded = True
    mat.node_tree.nodes["specularIntensityMult"].set_float(1)
    mat.node_tree.nodes["specularFalloffMult"].set_float(95)
    mat.node_tree.nodes["specularFresnel"].set_float(.35)
    return mat


class Parts:
    def __init__(self, build, mat, level, transform=Matrix.Identity(4)):
        self.build, self.material, self.level = build, mat, level
        self.transform = transform
        self.objects = []
        self.segments = (24, 16, 8, 6)[level]

    def finish_part(self, obj, colour, bevel=0):
        self.build.activate(obj)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if bevel and self.level < 3:
            modifier = obj.modifiers.new("Manufactured edge radius", "BEVEL")
            modifier.width, modifier.segments = bevel, (3, 2, 1)[self.level]
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        weighted = obj.modifiers.new("Flat panels and rounded edges", "WEIGHTED_NORMAL")
        weighted.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=weighted.name)
        uv = obj.data.uv_layers.active or obj.data.uv_layers.new()
        uv.name = "UVMap 0"
        u, v = (colour % 4 + .5) / 4, (colour // 4 + .5) / 4
        for polygon in obj.data.polygons:
            axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
            axes = [i for i in range(3) if i != axis]
            for loop in polygon.loop_indices:
                co = obj.data.vertices[obj.data.loops[loop].vertex_index].co
                uv.data[loop].uv = (u + co[axes[0]] * .012, v + co[axes[1]] * .012)
        obj.data.materials.clear()
        obj.data.materials.append(self.material)
        obj.matrix_world = self.transform
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        self.objects.append(obj)
        return obj

    def box(self, centre, size, colour=0, bevel=.004):
        bpy.ops.mesh.primitive_cube_add(size=1, location=centre)
        obj = bpy.context.object
        obj.dimensions = size
        return self.finish_part(obj, colour, bevel)

    def cylinder(self, centre, radius, depth, colour=2, direction=(0, 0, 1)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=self.segments, radius=radius, depth=depth, location=centre)
        obj = bpy.context.object
        obj.rotation_euler = Vector(direction).to_track_quat("Z", "Y").to_euler()
        return self.finish_part(obj, colour, min(.002, radius * .14))

    def wire(self, points, radius, colour):
        curve = bpy.data.curves.new("Routed conductor", "CURVE")
        curve.dimensions = "3D"
        curve.resolution_u = 4
        curve.bevel_depth = radius
        curve.bevel_resolution = 2 if self.level == 0 else 1
        spline = curve.splines.new("BEZIER")
        spline.bezier_points.add(len(points) - 1)
        for vertex, point in zip(spline.bezier_points, points):
            vertex.co = point
            vertex.handle_left_type = vertex.handle_right_type = "AUTO"
        obj = bpy.data.objects.new("Routed conductor", curve)
        bpy.context.collection.objects.link(obj)
        self.build.activate(obj)
        bpy.ops.object.convert(target="MESH")
        self.finish_part(bpy.context.object, colour)

    def polygon(self, points, colour):
        mesh = bpy.data.meshes.new("Cut graphic")
        mesh.from_pydata(points, [], [list(range(len(points)))])
        obj = bpy.data.objects.new("Cut graphic", mesh)
        bpy.context.collection.objects.link(obj)
        self.finish_part(obj, colour)

    def screw(self, x, y, z):
        if self.level > 1:
            return
        self.cylinder((x, y, z), .008, .005, direction=(0, -1, 0))
        self.box((x, y - .003, z), (.011, .001, .002), 12, 0)

    def warning(self, x, y, z, width):
        for factor, colour, depth in ((1, 12, 0), (.82, 5, -.0007)):
            w = width * factor
            self.polygon([(x-w/2, y+depth, z-w*.30), (x+w/2, y+depth, z-w*.30), (x, y+depth, z+w*.56)], colour)
        self.polygon([(x+.03*width,y-.0015,z+.37*width), (x-.17*width,y-.0015,z-.02*width),
            (x-.025*width,y-.0015,z-.02*width), (x-.10*width,y-.0015,z-.23*width),
            (x+.20*width,y-.0015,z+.11*width), (x+.035*width,y-.0015,z+.11*width)],12)

    def join(self, name):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in self.objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = self.objects[0]
        if len(self.objects) > 1:
            bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = name
        triangulate = obj.modifiers.new("Native triangles", "TRIANGULATE")
        triangulate.keep_custom_normals = True
        bpy.ops.object.modifier_apply(modifier=triangulate.name)
        obj.data.validate(clean_customdata=False)
        colours = obj.data.color_attributes.new(name="Color 1", type="BYTE_COLOR", domain="CORNER")
        colours.data.foreach_set("color", np.ones(len(colours.data)*4, dtype=np.float32))
        return obj


def enclosure(parts, width=.78, height=1.10, depth=.36):
    w, h, d = width/2, height/2, depth/2
    parts.box((0, d-.018, 0), (width-.10, .036, height-.10), 0, .004)
    for x in (-w+.025, w-.025):
        parts.box((x, 0, 0), (.05, depth, height-.10), 0, .004)
    for z in (-h+.025, h-.025):
        parts.box((0, 0, z), (width, depth, .05), 0, .007)
    # Raised lip and the continuous rubber seal remain attached to the housing.
    for x in (-w+.048, w-.048):
        parts.box((x, -d-.003, 0), (.014, .018, height-.072), 1, .003)
    for z in (-h+.048, h-.048):
        parts.box((0, -d-.003, z), (width-.082, .018, .014), 1, .003)
    for x in (-w+.075, w-.075):
        for z in (-h+.075, h-.075):
            parts.screw(x, -d-.003, z)
    if parts.level < 3:
        for x in (-.225, -.075, .075, .225):
            parts.cylinder((x, .015, -h-.027), .033, .05, 13)
            parts.cylinder((x, .015, -h-.075), .021, .07, 1)


def door(parts, width=.724, height=1.036, front=-.185):
    # This is a real flat, 24 mm thick steel leaf, with a separate inner lining.
    parts.box((0, front-.012, 0), (width, .024, height), 0, .007)
    if parts.level == 3:
        return
    parts.box((0, front+.006, 0), (width-.075, .012, height-.075), 13, .004)
    for z in (-height*.32, height*.32):
        parts.cylinder((-width/2-.009, front+.015, z), .014, .105, 2)
        parts.box((-width/2+.014, front+.005, z), (.048, .017, .088), 2, .003)
    # Recessed quarter-turn latch and a separate handle, on the opening edge.
    parts.box((width/2-.067, front-.030, 0), (.049, .014, .164), 1, .015)
    parts.box((width/2-.067, front-.047, .015), (.022, .025, .108), 2, .008)
    parts.cylinder((width/2-.067, front-.040, -.057), .010, .008, 2, (0,-1,0))
    parts.box((width/2-.067, front-.045, -.057), (.002, .001, .011), 12, 0)
    parts.warning(0, front-.025, height*.17, min(width*.30,.26))
    if parts.level < 2:
        for x in (-width*.24, width*.24):
            for index in range(5):
                z = -height*.35 + index*.016
                parts.box((x,front-.025,z), (width*.22,.002,.005),1,.001)
                parts.box((x,front-.028,z+.004), (width*.23,.008,.004),0,.001)
        for z in (-height*.40,height*.40):
            parts.screw(-width/2+.022, front-.027, z)


def interior(parts, damaged):
    parts.box((0,.114,0),(.65,.025,.96),9,.004)
    if parts.level == 3:
        parts.box((0,-.06,.05),(.56,.14,.66),10 if damaged else 3,.005)
        return
    for z in (-.29,.035,.32):
        parts.box((0,.075,z),(.60,.025,.045),2,.002)
    for row, z in enumerate((.29,-.02)):
        for index in range(6):
            x=-.235+index*.092
            burnt = damaged and (row == 0 or index in (2,3))
            colour = 10 if burnt else 3
            parts.box((x,-.012,z),(.079,.15,.184),colour,.006)
            parts.box((x,-.096,z-.010),(.054,.020,.092),1,.003)
            if not (damaged and index in (2,4)):
                parts.box((x,-.116,z+(.018 if not damaged else -.027)),(.038,.027,.023),8 if index==0 else 1,.004)
            if parts.level < 2:
                for end in (-1,1):
                    parts.screw(x,-.092,z+end*.070)
                parts.box((x,-.105,z-.058),(.016,.002,.008),10 if burnt else 15,0)
                colour_wire=(7,4,6)[index%3]
                for end in (-1,1):
                    start=z+end*.10
                    endz=z+end*.135
                    points=[(x,.015,start),(x,-.01,endz),(x+.022,.045,endz+end*.025)]
                    if burnt:
                        points[-1]=(x+.04,-.09,endz-.045)
                    parts.wire(points,.006,10 if burnt else colour_wire)
                    if burnt:
                        parts.cylinder(points[-1],.003,.025,11)
    for index in range(10):
        x=-.24+index*.053
        parts.box((x,-.005,-.31),(.044,.12,.085),10 if damaged else (4 if index<4 else 6 if index>7 else 3),.003)
        if parts.level < 2:
            parts.screw(x,-.07,-.31)
    if parts.level < 2:
        for x in (-.29,.29):
            parts.wire([(x,.08,-.46),(x,-.005,-.38),(x,-.005,.38),(x*.8,.05,.46)],.012,10 if damaged else 14)
        if damaged:
            # Broken covers and loose copper are distinct geometry in the damaged state.
            for x,z in ((-.16,.39),(.04,.30),(.17,-.03)):
                parts.polygon([(x-.024,-.095,z-.034),(x+.026,-.095,z-.023),(x+.012,-.095,z+.026)],12)
                parts.wire([(x,-.10,z),(x+.055,-.20,z-.085),(x+.02,-.23,z-.13)],.004,11)


def remove_side_enclosure(mesh):
    """Remove only the protruding box, preserving neighbouring mast corner normals."""
    positions = np.array([vertex.co[:] for vertex in mesh.vertices], dtype=np.float32)
    remove = ((positions[:, 0] < -1.28) & (np.abs(positions[:, 1]) < .61)
        & (positions[:, 2] > 1.73) & (positions[:, 2] < 3.36))
    polygons = [face for face in mesh.polygons if not any(remove[index] for index in face.vertices)]
    loops = np.array([index for face in polygons for index in face.loop_indices], dtype=np.int32)
    used, indices = np.unique([mesh.loops[index].vertex_index for index in loops], return_inverse=True)
    result = bpy.data.meshes.new(mesh.name + ".clean_enclosure")
    assert all(face.loop_total == 3 for face in polygons)
    result.from_pydata(positions[used].tolist(), [], indices.reshape(-1, 3).tolist())
    for mat in mesh.materials:
        result.materials.append(mat)
    for target, source in zip(result.polygons, polygons):
        target.material_index, target.use_smooth = source.material_index, source.use_smooth
    for layer in mesh.uv_layers:
        values = np.empty(len(mesh.loops) * 2, dtype=np.float32)
        layer.data.foreach_get("uv", values)
        result.uv_layers.new(name=layer.name).data.foreach_set("uv", values.reshape(-1, 2)[loops].ravel())
    for attribute in mesh.color_attributes:
        values = np.empty(len(attribute.data) * 4, dtype=np.float32)
        attribute.data.foreach_get("color", values)
        target = result.color_attributes.new(name=attribute.name, type=attribute.data_type, domain=attribute.domain)
        target.data.foreach_set("color", values.reshape(-1, 4)[loops].ravel())
    normals = np.empty(len(mesh.loops) * 3, dtype=np.float32)
    mesh.corner_normals.foreach_get("vector", normals)
    result.normals_split_custom_set(normals.reshape(-1, 3)[loops].tolist())
    return result


def install(build, roots, report, ytyp):
    mat = material(build)
    levels = (build.p.LODLevel.HIGH, build.p.LODLevel.MEDIUM, build.p.LODLevel.LOW, build.p.LODLevel.VERYLOW)
    tower = roots["tower"]
    for obj in list(tower.children):
        if obj.name.startswith(build.PREFIX + "tower.cabinets"):
            bpy.data.objects.remove(obj, do_unlink=True)
    mast = bpy.data.objects[build.PREFIX + "tower.mesh"]
    for level in levels:
        slot = mast.sz_lods.get_lod(level)
        slot.mesh = remove_side_enclosure(slot.mesh)
    composite = next(obj for obj in tower.children if obj.sollum_type == build.p.SollumType.BOUND_COMPOSITE)
    side_name = build.PREFIX + "tower.side_enclosure_collision"
    for obj in list(composite.children):
        if obj.name == side_name:
            bpy.data.objects.remove(obj, do_unlink=True)
    side = build.add_collision(tower, [((-1.48, -.045, 2.44), (.50, 1.02, 1.42), (0, 0, 0))], composite=composite)[0]
    side.name = side_name
    report["models"]["tower"]["collisionBoxes"] = sum(obj.sollum_type == build.p.SollumType.BOUND_BOX for obj in composite.children)
    geometry = {name: [] for name in ("case", "door", "panel", "panel_broken")}
    centre = Vector((-.015, -1.43, 1.30))
    for level in range(4):
        parts = Parts(build, mat, level, Matrix.Translation(centre))
        enclosure(parts)
        # The original side enclosure keeps its position and silhouette, with
        # new clean sheet-metal surfaces instead of the low-density atlas patch.
        parts.transform = Matrix.Translation((-1.48, -.045, 2.44)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")
        enclosure(parts, 1.02, 1.42, .47)
        door(parts, .98, 1.37, -.24)
        geometry["case"].append(parts.join(build.PREFIX + "tower.cabinets"))
        parts = Parts(build, mat, level, Matrix.Translation(centre - build.DOOR_OFFSET))
        door(parts)
        geometry["door"].append(parts.join(build.PREFIX + "door.clean"))
        for name, damaged in (("panel", False), ("panel_broken", True)):
            parts = Parts(build, mat, level, Matrix.Translation(centre))
            interior(parts, damaged)
            geometry[name].append(parts.join(build.PREFIX + name + ".clean"))
    case = geometry.pop("case")
    build.convert(case[0])
    case[0].parent = tower
    for level, obj in zip(levels[1:], case[1:]):
        case[0].sz_lods.get_lod(level).mesh = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
    for name, lods in geometry.items():
        if name in roots:
            for obj in list(roots[name].children_recursive) + [roots[name]]:
                bpy.data.objects.remove(obj, do_unlink=True)
        boxes = ([((.37, -.045, 0), (.75, .07, 1.05), (0, 0, 0))] if name == "door"
            else [((0, -1.50, 1.30), (.61, .12, .91), (0, 0, 0))])
        roots[name], report["models"][name] = build.export_model(lods[0], name, ytyp, (0, 0, 0), boxes, lods=lods[1:])
    models = [obj for obj in tower.children if obj.sollum_type == build.p.SollumType.DRAWABLE_MODEL]
    report["models"]["tower"]["triangles"] = {
        level.name: sum(len(obj.sz_lods.get_lod(level).mesh.polygons) for obj in models) for level in levels
    }
    report["cabinetAuthoring"] = "Procedural sheet metal, geometric hardware and warning symbols; shared 256px colour/specular swatches."
