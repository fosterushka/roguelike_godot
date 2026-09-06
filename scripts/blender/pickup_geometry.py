"""Original military utility pickup. Z-up, front -Y; no imported mesh data."""
import math

import bmesh
import bpy
from mathutils import Vector


# A single 4x4 palette shared by every face, listed from bottom left.
PALETTE = {
    "paint": "596744", "paint_light": "74805a", "paint_shadow": "394431",
    "trim": "282f26", "rubber": "22251f", "tread": "363a2d",
    "glass": "273b39", "glass_light": "576559", "steel": "626950",
    "lamp": "f1d6a0", "red": "bb5946", "amber": "d3954e",
    "bed": "41482f", "accent": "a29467", "dark": "18231b", "white": "d3d6bc",
}
BODY_WIDTH_SCALE = 1.18


class MeshBuilder:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.colors = []

    def polygon(self, points, color, outward=None):
        if outward is not None:
            normal = (Vector(points[1])-Vector(points[0])).cross(Vector(points[2])-Vector(points[0]))
            if normal.dot(Vector(outward)) < 0:
                points = list(reversed(points))
        start = len(self.vertices)
        self.vertices.extend(points)
        self.faces.append(tuple(range(start, start + len(points))))
        self.colors.append(color)

    def solid(self, points, faces, color, face_colors=None):
        start = len(self.vertices)
        self.vertices.extend(points)
        for index, face in enumerate(faces):
            self.faces.append(tuple(start + value for value in face))
            self.colors.append(face_colors.get(index, color) if face_colors else color)

    def box(self, center, size, color):
        x, y, z = center
        a, b, c = (value / 2 for value in size)
        points = [(x-a, y-b, z-c), (x+a, y-b, z-c), (x+a, y+b, z-c), (x-a, y+b, z-c),
                  (x-a, y-b, z+c), (x+a, y-b, z+c), (x+a, y+b, z+c), (x-a, y+b, z+c)]
        self.solid(points, [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
                            (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], color)

    def loft(self, rings, color, cap_color=None):
        count = len(rings[0])
        points = [point for ring in rings for point in ring]
        faces = [tuple(reversed(range(count)))]
        for ring in range(len(rings)-1):
            for i in range(count):
                j = (i+1) % count
                faces.append((ring*count+i, ring*count+j, (ring+1)*count+j, (ring+1)*count+i))
        faces.append(tuple(range((len(rings)-1)*count, len(rings)*count)))
        self.solid(points, faces, color, {len(faces)-1: cap_color or color})

    def side_profile(self, side, profile, color):
        """A thin continuous side panel with wheel openings in its lower outline."""
        rings = [[(side*x, y, z) for y, z in profile] for x in (1.015, 1.115)]
        self.loft(rings, color)

    def finish(self, name, material):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.materials.append(material)
        uv = mesh.uv_layers.new(name="PaletteUV")
        names = list(PALETTE)
        for polygon, color in zip(mesh.polygons, self.colors):
            cell = names.index(color)
            point = ((cell % 4 + .5)/4, (cell // 4 + .5)/4)
            for loop in polygon.loop_indices:
                uv.data[loop].uv = point
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        return mesh


def rectangle_ring(half_width, front, rear, z, bevel=.10, front_z=None):
    """Counterclockwise chamfered outline, optionally sloped toward the front."""
    front_z = z if front_z is None else front_z
    return [(-half_width+bevel, front, front_z), (half_width-bevel, front, front_z),
            (half_width, front+bevel, front_z), (half_width, rear-bevel, z),
            (half_width-bevel, rear, z), (-half_width+bevel, rear, z),
            (-half_width, rear-bevel, z), (-half_width, front+bevel, front_z)]


def cabin(builder):
    builder.loft([
        rectangle_ring(1.03, -1.32, .72, 1.14, .08),
        rectangle_ring(1.04, -1.22, .72, 1.60, .08),
        rectangle_ring(.88, -.64, .55, 2.43, .08),
    ], "paint", "paint_light")
    builder.loft([
        rectangle_ring(.90, -.68, .59, 2.43, .09),
        rectangle_ring(.87, -.65, .56, 2.49, .08),
    ], "paint_light")

    def front_y(z):
        return -1.22 + (z-1.60)/.83*.58 - .008

    # Two inset panes leave a geometric central windshield pillar.
    for side in (-1, 1):
        low, high = 1.84, 2.23
        builder.polygon([(side*.075, front_y(low), low), (side*.82, front_y(low), low),
                         (side*.73, front_y(high), high), (side*.075, front_y(high), high)], "glass", (0, -1, 0))
        side_window = [(-.84, 1.84), (.42, 1.84), (.35, 2.22), (-.55, 2.22)]
        builder.polygon([(side*(1.04-(z-1.6)/.83*.16+.008), y, z)
                         for y, z in side_window], "glass", (side, 0, 0))
        builder.polygon([(side*1.046, -.99, 1.24), (side*1.046, .57, 1.24),
                         (side*1.048, .57, 1.57), (side*1.048, -1.06, 1.57)], "paint_shadow", (side, 0, 0))
        builder.box((side*1.086, .42, 1.62), (.07, .22, .055), "steel")
        builder.box((side*1.17, -.97, 1.77), (.26, .055, .055), "trim")
        builder.box((side*1.32, -.97, 1.87), (.095, .23, .20), "trim")
        builder.polygon([(side*1.371, -1.05, 1.80), (side*1.371, -.89, 1.80),
                         (side*1.371, -.89, 1.94), (side*1.371, -1.05, 1.94)], "glass_light", (side, 0, 0))
    builder.polygon([(-.66, .688, 1.81), (.66, .688, 1.81),
                     (.63, .588, 2.29), (-.63, .588, 2.29)], "glass", (0, 1, 0))


def cargo_bed(builder):
    # An actual open bed. Floor strips leave room for the inner wheel housings.
    builder.box((0, 1.85, 1.10), (1.47, 2.25, .10), "bed")
    for side in (-1, 1):
        for y, length in ((.96, .42), (2.86, .24)):
            builder.box((side*.875, y, 1.10), (.28, length, .10), "bed")
        builder.loft([
            rectangle_ring(.23, 1.19, 2.77, 1.08, .12),
            rectangle_ring(.20, 1.37, 2.59, 1.47, .12),
        ], "bed")
        # Translate just the housing geometry from the center to the bed side.
        for i in range(len(builder.vertices)-16, len(builder.vertices)):
            x, y, z = builder.vertices[i]
            builder.vertices[i] = (x+side*.91, y, z)
        builder.box((side*1.085, 1.88, 1.73), (.14, 2.44, .07), "steel")
    builder.box((0, .76, 1.41), (2.04, .11, .61), "paint")
    builder.box((0, 3.035, 1.41), (2.10, .13, .61), "paint")
    for x in (-.58, -.29, 0, .29, .58):
        builder.box((x, 1.88, 1.165), (.027, 2.10, .028), "paint_shadow")
    builder.polygon([(-.81, 3.105, 1.19), (.81, 3.105, 1.19),
                     (.81, 3.105, 1.61), (-.81, 3.105, 1.61)], "paint_shadow", (0, 1, 0))
    builder.box((0, 3.12, 1.56), (.30, .035, .058), "steel")
    for side in (-1, 1):
        builder.box((side*.94, 3.115, 1.43), (.14, .035, .31), "red")
        builder.box((side*.94, 3.137, 1.35), (.11, .012, .075), "white")


def wheel_arch(builder, side, center_y):
    points = []
    for radius in (.785, .855):
        for index in range(7):
            angle = index*math.pi/6
            points.append((side*1.14, center_y+radius*math.cos(angle), .69+radius*math.sin(angle)))
    faces = [(i, i+1, i+8, i+7) for i in range(6)]
    if side > 0:
        faces = [tuple(reversed(face)) for face in faces]
    builder.solid(points, faces, "trim")


def military_equipment(builder):
    # A steel brush guard stands clear of the grille. No subdivided tubes.
    for side in (-1, 1):
        builder.box((side*.60, -3.245, 1.12), (.095, .11, .72), "trim")
        for offset in (-.13, .13):
            builder.box((side*.81+offset, -3.17, 1.25), (.038, .045, .30), "trim")
        # Flat tow eyes with real holes are eight triangles each.
        outer = [(side*.78-.08, -3.245, .68), (side*.78+.08, -3.245, .68),
                 (side*.78+.08, -3.245, .86), (side*.78-.08, -3.245, .86)]
        inner = [(side*.78-.04, -3.25, .72), (side*.78+.04, -3.25, .72),
                 (side*.78+.04, -3.25, .82), (side*.78-.04, -3.25, .82)]
        for index in range(4):
            nxt = (index+1) % 4
            builder.polygon([outer[index], outer[nxt], inner[nxt], inner[index]], "accent", (0, -1, 0))
    builder.box((0, -3.245, 1.46), (2.30, .11, .095), "trim")

    # Hood louvers use flush palette-colored faces instead of deep cutouts.
    for index in range(5):
        y = -1.93+index*.075
        z = 1.55+(y+2.96)/(2.96-1.26)*.06+.004
        builder.polygon([(-.34, y, z), (.34, y, z), (.34, y+.025, z+.0009),
                         (-.34, y+.025, z+.0009)], "paint_shadow", (0, 0, 1))

    # Rack behind the cab protects the rear window but leaves the bed open.
    for side in (-1, 1):
        builder.box((side*1.01, .87, 2.02), (.10, .10, .84), "trim")
    builder.box((0, .87, 2.44), (2.12, .10, .10), "trim")

    builder.polygon([(math.cos(i*math.pi/4)*.37, -.08+math.sin(i*math.pi/4)*.37, 2.496)
                     for i in range(8)], "paint_shadow", (0, 0, 1))
    builder.box((0, -.08, 2.525), (.22, .045, .048), "steel")

    # One compact jerrycan, confined to the front corner of the cargo bed.
    builder.box((.79, 1.12, 1.215), (.36, .38, .13), "steel")
    start = len(builder.vertices)
    builder.loft([rectangle_ring(.14, 1.01, 1.37, 1.28, .04),
                  rectangle_ring(.14, 1.01, 1.37, 1.94, .04)], "accent")
    for index in range(start, len(builder.vertices)):
        x, y, z = builder.vertices[index]
        builder.vertices[index] = (x+.79, y, z)
    builder.box((.79, 1.19, 1.99), (.18, .065, .09), "trim")
    builder.polygon([(.64, 1.005, 1.43), (.94, 1.005, 1.43),
                     (.94, 1.005, 1.49), (.64, 1.005, 1.49)], "trim", (0, -1, 0))


def body_mesh(material):
    builder = MeshBuilder()
    builder.box((0, 0, .70), (1.60, 5.74, .25), "trim")
    builder.loft([
        rectangle_ring(1.04, -3.0, -1.23, .94, .14),
        rectangle_ring(1.01, -2.96, -1.26, 1.61, .12, front_z=1.55),
    ], "paint", "paint_light")
    # Continuous side panels trace both wheel openings instead of blocking them.
    profile = [(-3.0, 1.54), (-2.38, 1.65), (-1.30, 1.65), (-1.25, 1.16),
               (.72, 1.16), (.76, 1.72), (3.04, 1.72), (3.04, .85),
               (2.79, .85), (2.70, 1.10), (2.42, 1.40), (1.98, 1.53),
               (1.54, 1.40), (1.26, 1.10), (1.17, .85),
               (-1.17, .85), (-1.26, 1.10), (-1.54, 1.40), (-1.98, 1.53),
               (-2.42, 1.40), (-2.70, 1.10), (-2.79, .85), (-3.0, .85)]
    for side in (-1, 1):
        builder.side_profile(side, profile, "paint")
        builder.box((side*1.16, -.02, .81), (.23, 1.76, .10), "trim")
        for center in (-1.98, 1.98):
            wheel_arch(builder, side, center)
    cabin(builder)
    cargo_bed(builder)
    builder.box((0, -3.105, .79), (2.42, .25, .23), "trim")
    builder.box((0, 3.19, .83), (2.36, .23, .20), "trim")
    builder.box((0, -3.015, 1.20), (1.22, .034, .29), "dark")
    for x in (-.48, -.24, 0, .24, .48):
        builder.box((x, -3.041, 1.20), (.043, .018, .23), "steel")
    for side in (-1, 1):
        builder.box((side*.81, -3.005, 1.22), (.34, .052, .255), "trim")
        builder.polygon([(side*.81+math.cos(i*math.pi/4)*.105, -3.037,
                          1.24+math.sin(i*math.pi/4)*.105) for i in range(8)], "lamp", (0, -1, 0))
        builder.box((side*.975, -3.038, 1.15), (.06, .017, .12), "amber")
    # Flush hood seams and a simple front emblem, not dense ornamental hardware.
    builder.box((0, -3.061, 1.20), (.13, .025, .095), "accent")
    military_equipment(builder)
    builder.vertices = [(x*BODY_WIDTH_SCALE, y, z) for x, y, z in builder.vertices]
    return builder.finish("PickupBodyMesh", material)


def wheel_mesh(material):
    builder = MeshBuilder()
    count = 12
    points = []
    # A low-poly tire with broad shoulders; only 60 vertices for its main shell.
    rings = [(-.32, .53), (-.28, .65), (0, .705), (.28, .65), (.32, .53)]
    for x, radius in rings:
        for index in range(count):
            angle = 2*math.pi*index/count
            points.append((x, math.cos(angle)*radius, math.sin(angle)*radius))
    faces, shades = [], {}
    for ring in range(len(rings)-1):
        for i in range(count):
            j = (i+1) % count
            faces.append((ring*count+i, ring*count+j, (ring+1)*count+j, (ring+1)*count+i))
            shades[len(faces)-1] = "tread" if ring in (1, 2) and i % 2 else "rubber"
    faces.extend([tuple(reversed(range(count))), tuple(range(4*count, 5*count))])
    builder.solid(points, faces, "rubber", shades)
    # Both outer faces are detailed, so one linked mesh serves left and right.
    for side in (-1, 1):
        rings = []
        rim_sides = 8
        for x, radius in ((side*.326, .40), (side*.348, .32)):
            rings.append([(x, math.cos(i*2*math.pi/rim_sides)*radius, math.sin(i*2*math.pi/rim_sides)*radius)
                          for i in range(rim_sides)])
        builder.loft(rings, "steel")
        builder.polygon([(side*.351, math.cos(i*2*math.pi/rim_sides)*.135,
                          math.sin(i*2*math.pi/rim_sides)*.135) for i in range(rim_sides)], "accent", (side, 0, 0))
        for i in range(6):
            angle = i*2*math.pi/6
            y, z = math.cos(angle)*.235, math.sin(angle)*.235
            builder.polygon([(side*.354, y-.035, z-.035), (side*.354, y+.035, z-.035),
                             (side*.354, y+.035, z+.035), (side*.354, y-.035, z+.035)], "trim", (side, 0, 0))
    return builder.finish("PickupSharedWheelMesh", material)


def create_meshes(material):
    return {
        "body": body_mesh(material), "wheel": wheel_mesh(material),
        "wheel_centers": [
            {"name": "FRONT_LEFT", "center": (-1.22*BODY_WIDTH_SCALE, -1.98, .71)},
            {"name": "FRONT_RIGHT", "center": (1.22*BODY_WIDTH_SCALE, -1.98, .71)},
            {"name": "REAR_LEFT", "center": (-1.22*BODY_WIDTH_SCALE, 1.98, .71)},
            {"name": "REAR_RIGHT", "center": (1.22*BODY_WIDTH_SCALE, 1.98, .71)},
        ],
    }
