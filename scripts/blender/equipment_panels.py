"""Small authored corner chamfers matching the player's lofted body panels."""
PANEL_CHAMFER = .025
MIN_PANEL_SIDE = .065


def panel(builder, center, size, color):
    x, y, z = center
    w, d, h = (value*.5 for value in size)
    if min(size) < MIN_PANEL_SIDE:
        builder.box(center, size, color)
        return
    edge = min(PANEL_CHAMFER, min(size)*.12)
    rings = []
    for height, inset in ((z-h, edge), (z-h+edge, 0), (z+h-edge, 0), (z+h, edge)):
        a, b = w-inset, d-inset
        c = min(edge, a*.4, b*.4)
        rings.append([(x+u,y+v,height) for u,v in
                      ((-a+c,-b),(a-c,-b),(a,-b+c),(a,b-c),
                       (a-c,b),(-a+c,b),(-a,b-c),(-a,-b+c))])
    builder.loft(rings, color)
