"""Role-specific silhouettes, outside the three deck mounts and crew seats."""
from mathutils import Vector


def beam(b, start, end, width, color):
    """Square beam in Godot coordinates, used for braces and crane booms."""
    direction = Vector(end) - Vector(start)
    first = direction.normalized().cross(Vector((1, 0, 0)))
    if first.length < .01:
        first = direction.normalized().cross(Vector((0, 1, 0)))
    first.normalize()
    second = direction.normalized().cross(first)
    rings = []
    for center in (Vector(start), Vector(end)):
        rings.append([tuple((p.x, -p.z, p.y)) for p in
                      [center + first*a*width/2 + second*c*width/2
                       for a, c in ((-1, -1), (1, -1), (1, 1), (-1, 1))]])
    b.loft(rings, color)


def add_bodywork(b, kind):
    if kind == "cargo":
        # Tall, open slatted crate body: recognizable even without paint.
        for side in (-1, 1):
            for z in (-1.73, 0, 1.73):
                b.box((side*1.56, 2.10, z), (.15, 1.66, .15), "trim")
            for y in (1.68, 2.13, 2.58):
                b.box((side*1.57, y, 0), (.13, .27, 3.55), "paint_light")
        for y in (1.68, 2.13, 2.58):
            b.box((0, y, -1.78), (3.22, .27, .13), "paint")
        b.box((0, 1.94, 1.79), (3.22, .93, .14), "paint")
        for x in (-1.1, 1.1):
            b.box((x, 1.94, 1.88), (.12, 1.0, .06), "trim")
    elif kind == "repair":
        # Asymmetric service cabinet and an outboard workshop lifting arm.
        b.box((-1.70, 2.05, .15), (.53, 1.38, 1.56), "paint")
        b.box((-1.70, 2.78, .15), (.61, .12, 1.67), "steel")
        for y in (1.64, 1.96, 2.28):
            b.box((-1.99, y, .15), (.06, .22, 1.34), "paint_light")
            b.box((-2.03, y, .15), (.04, .04, .40), "trim")
        b.box((1.63, 2.40, -.20), (.22, 2.05, .26), "paint")
        beam(b, (1.63, 3.40, -.20), (1.63, 3.72, 1.48), .22, "paint_light")
        beam(b, (1.63, 2.72, -.20), (1.63, 3.58, .98), .10, "steel")
        b.box((1.63, 3.20, 1.48), (.055, .96, .055), "dark")
        b.box((1.63, 2.74, 1.42), (.14, .10, .20), "steel")
    elif kind == "weapon":
        # Low stepped ammunition lockers, deliberately below the other bodies.
        for side in (-1, 1):
            b.box((side*1.57, 1.82, .20), (.43, .82, 2.84), "paint")
            b.box((side*1.57, 2.27, .20), (.51, .12, 2.95), "trim")
            for z in (-.77, .20, 1.17):
                b.box((side*1.81, 1.87, z), (.08, .46, .70), "bed")
                b.box((side*1.87, 1.87, z), (.05, .10, .20), "accent")
        b.box((0, 1.77, 1.77), (3.15, .70, .32), "paint")
    elif kind == "anti_tank":
        # Heavy sloped armor tub, open roof and firing gap at the front.
        for side in (-1, 1):
            rings = []
            for y, x in ((1.38, 1.52), (3.02, 1.72)):
                rings.append([(side*xx, -z, y) for xx, z in
                              ((x-.12, -1.83), (x+.12, -1.83),
                               (x+.12, 1.78), (x-.12, 1.78))])
            b.loft(rings, "paint")
            b.box((side*1.72, 3.06, -.02), (.31, .12, 3.73), "paint_light")
            for z in (-1.12, .12, 1.32):
                beam(b, (side*1.68, 1.55, z), (side*1.88, 2.95, z), .11, "steel")
            b.box((side*1.13, 2.25, 1.84), (1.08, 1.58, .24), "paint")
        b.box((0, 2.04, -1.85), (3.32, 1.26, .24), "paint")
    elif kind == "anti_air":
        # Open platform with a raised rear radar mast and rectangular antenna.
        b.box((0, 2.38, -1.88), (.24, 2.08, .24), "steel")
        beam(b, (-.70, 1.40, -1.88), (0, 2.85, -1.88), .10, "trim")
        beam(b, (.70, 1.40, -1.88), (0, 2.85, -1.88), .10, "trim")
        b.box((0, 3.50, -1.88), (1.88, .78, .16), "paint")
        for x in (-.70, -.35, 0, .35, .70):
            b.box((x, 3.50, -1.78), (.065, .65, .06), "paint_light")
        b.box((0, 3.50, -1.74), (1.80, .065, .06), "steel")
        for side in (-1, 1):
            for z in (-.50, 1.65):
                b.box((side*1.61, 1.89, z), (.10, .90, .10), "steel")
            b.box((side*1.61, 2.34, .58), (.10, .10, 2.25), "paint_light")


def add_chassis_detail(b):
    """Suspension, wiring, latches and rear lamps baked into the deck batch."""
    for side in (-1, 1):
        x = side*1.29
        for z in (-1.55, 1.55):
            # Visible leaf stack and its axle clamps inside each wheel.
            for layer in range(3):
                b.box((x, .78+layer*.055, z), (.16, .04, .90-layer*.17), 'steel')
            for dz in (-.22, .22):
                b.box((x, .87, z+dz), (.21, .24, .055), 'trim')
            beam(b, (side*1.45, .82, z-.12), (side*1.38, 1.26, z+.24), .085, 'paint_light')
            b.box((side*1.80, 1.38, z-.73), (.62, .52, .055), 'rubber')
        for z in (-1.30, -.42, .46, 1.34):
            b.box((side*1.61, 1.56, z), (.035, .17, .12), 'steel')
            b.box((side*1.64, 1.56, z), (.025, .07, .055), 'accent')
        # Rear lamp housings and a contrasting lens, matching the pickup.
        b.box((side*1.30, 1.26, -1.89), (.30, .27, .13), 'trim')
        b.box((side*1.30, 1.29, -1.965), (.23, .14, .035), 'red')
        b.box((side*1.30, 1.17, -1.965), (.23, .06, .035), 'white')
        b.box((side*1.57, 1.51, 1.66), (.045, .09, .17), 'amber')
    for z in (-1.55, 1.55):
        b.box((0, .84, z), (3.16, .15, .16), 'steel')
        for x in (-.67, .67):
            beam(b, (x, .90, z), (x, 1.05, z*.35), .07, 'trim')
    b.box((0, 1.15, -1.87), (.65, .22, .035), 'dark')
    for x in (-.22, -.11, 0, .11, .22):
        b.box((x, 1.15, -1.897), (.055, .08, .018), 'white')
