"""Purpose-specific readable mechanics for the mounted equipment library.

Geometry is baked into the existing BASE/MOVING batches and uses the pickup
palette. No per-bolt scene objects, material slots or runtime scripts are added.
"""
import math

SIDES = (-1, 1)
RIFLES = {'turret', 'akTurret', 'assaultRifle'}
ELECTRONICS = {'radar', 'counterDroneJammer', 'mineHacker'}


def detail(kind, base, moving, box, tube, beam):
    b = moving if moving.faces else base
    if kind in RIFLES:
        # Receiver, gas tube, stock and shield distinguish the three weapons.
        box(b, (0, .60, .24), (.26, .25, .72), 'paint_shadow')
        tube(b, (0, .73, .86), .027, .74, 'steel', (0, 0, 1), 8)
        box(b, (0, .60, -.45), (.20, .26, .37), 'bed')
        for z in (.48, .61, .74, .87):
            box(b, (0, .67, z), (.25, .045, .045), 'steel')
        if kind == 'turret':
            for side in SIDES:
                box(b, (side*.30, .80, .38), (.24, .40, .07), 'paint')
                tube(b, (side*.21, .58, -.01), .052, .045, 'accent', (1, 0, 0), 8)
        elif kind == 'akTurret':
            for y, z in ((.38, .16), (.25, .23), (.12, .32)):
                box(b, (.12, y, z), (.10, .16, .20), 'bed')
        else:
            tube(b, (0, .87, .12), .065, .31, 'trim', (0, 0, 1), 10)
            tube(b, (0, .87, .28), .047, .015, 'glass_light', (0, 0, 1), 10)
    elif kind == 'anti_tank_station':
        for side in SIDES:
            box(b, (side*.30, .62, .53), (.16, .23, .95), 'paint')
            tube(b, (side*.19, .50, .73), .056, .86, 'steel', (0, 0, 1), 10)
            box(b, (side*.40, .74, .30), (.23, .62, .12), 'paint_light')
        box(b, (0, .58, 1.85), (.30, .20, .23), 'trim')
        box(b, (0, .58, 1.97), (.16, .11, .012), 'dark')
    elif kind == 'bazooka':
        for z in (-.17, .35, .92):
            tube(b, (0, .68, z), .245, .055, 'paint_light', (0, 0, 1), 12)
        box(b, (-.29, 1.05, .40), (.065, .22, .055), 'steel')
        box(b, (-.29, 1.17, .40), (.18, .04, .055), 'steel')
        box(b, (.24, .43, .13), (.13, .27, .14), 'bed')
    elif kind == 'anti_air_station':
        for side in SIDES:
            tube(b, (side*.38, .90, .88), .10, .53, 'paint_shadow', (0, .22, 1), 10)
            for z in (.58, .76, .94):
                tube(b, (side*.38, .83+z*.22, z), .113, .045, 'steel', (0, .22, 1), 10)
            beam(b, (side*.25, .59, -.03), (side*.38, 1.02, .76), .035, 'steel')
        for x in (-.28, -.14, 0, .14, .28):
            box(b, (x, 1.42, -.33), (.025, .27, .025), 'steel')
    elif kind == 'minigun':
        for z in (.65, 1.10, 1.40):
            tube(b, (0, .58, z), .19, .08, 'steel', (0, 0, 1), 12)
        tube(b, (.31, .48, -.09), .18, .38, 'paint_shadow', (0, 0, 1), 12)
        for index in range(7):
            box(b, (-.30+index*.055, .32, .04), (.043, .09, .16), 'accent')
    elif kind == 'grenadeLauncher':
        tube(b, (.02, .39, .24), .28, .28, 'paint', (1, 0, 0), 12)
        for index in range(8):
            angle = index*math.tau/8
            tube(b, (.18, .39+math.sin(angle)*.18, .24+math.cos(angle)*.18), .032, .025, 'accent', (1, 0, 0), 6)
        tube(b, (0, .84, .18), .04, .26, 'trim', (0, 0, 1), 8)
    elif kind == 'flamethrower':
        for side in SIDES:
            for y in (.33, .68):
                tube(b, (side*.24, y, -.30), .143, .045, 'steel', segments=10)
            beam(b, (side*.24, .29, -.30), (side*.18, .36, .30), .028, 'rubber')
        tube(b, (0, .58, 1.43), .14, .22, 'paint_shadow', (0, 0, 1), 10)
        box(b, (0, .44, 1.51), (.07, .07, .20), 'accent')
    elif kind == 'railgun':
        for z in (.52, .72, .92, 1.12, 1.32, 1.52):
            box(b, (0, .58, z), (.42, .24, .055), 'paint_shadow')
            for side in SIDES:
                box(b, (side*.23, .58, z), (.045, .15, .08), 'glass_light')
        box(b, (0, .58, -.37), (.36, .38, .27), 'steel')
    elif kind == 'missileRack':
        for side in SIDES:
            box(b, (side*.39, .63, .19), (.075, .56, .95), 'paint')
            box(b, (side*.41, .63, -.32), (.08, .61, .11), 'steel')
        box(b, (0, .94, .19), (.82, .065, .96), 'paint_light')
    elif kind in ELECTRONICS:
        for side in SIDES:
            for y in (.22, .30, .38, .46):
                box(base, (side*.33, y, -.06), (.026, .032, .27), 'trim')
        if kind == 'counterDroneJammer':
            for side in SIDES:
                box(base, (side*.24, 1.18, 0), (.13, .49, .11), 'paint_light')
        elif kind == 'mineHacker':
            tube(base, (.28, .58, .23), .12, .055, 'steel', (0, 0, 1), 10)
            tube(base, (.28, .58, .265), .09, .012, 'glass_light', (0, 0, 1), 10)
    elif kind == 'fuel_pump':
        tube(base, (.27, .86, .20), .10, .035, 'steel', (0, 0, 1), 12)
        tube(base, (.27, .86, .224), .075, .012, 'white', (0, 0, 1), 12)
        beam(base, (.27, .86, .24), (.31, .90, .24), .012, 'trim')
    elif kind == 'salvage_arm':
        for at in ((0, 1.1, -.23), (0, .99, .58)):
            tube(base, at, .13, .24, 'steel', (1, 0, 0), 12)
        beam(base, (.13, .37, -.04), (.13, .91, -.20), .05, 'paint_shadow')
        beam(base, (.13, .81, -.17), (.13, 1.05, -.22), .03, 'steel')
    elif kind in {'repair_station', 'workshop'}:
        for side in SIDES:
            box(base, (side*.38, .34, .33), (.04, .44, .04), 'steel')
        if kind == 'workshop':
            box(base, (.22, .85, -.21), (.26, .18, .25), 'paint_shadow')
            tube(base, (.22, .95, -.21), .10, .05, 'steel', (1, 0, 0), 10)
    elif kind in {'armor', 'armor_panels'}:
        for z in (-.22, 0, .22):
            for x in (-.22, .22):
                box(base, (x, .53, z+.06), (.27, .25, .055), 'paint_light')
    elif kind == 'bumper':
        tube(base, (0, .35, .13), .13, .70, 'trim', (1, 0, 0), 12)
        for x in (-.28, .28):
            tube(base, (x, .35, .13), .18, .05, 'steel', (1, 0, 0), 12)
    elif kind == 'reinforced_hitch':
        for side in SIDES:
            beam(base, (side*.27, .25, -.24), (side*.09, .25, .22), .043, 'accent')
    elif kind in {'cargo_rack', 'ammo_feed', 'treasury'}:
        for side in SIDES:
            box(base, (side*.39, .48, 0), (.04, .07, .24), 'steel')
        if kind == 'ammo_feed':
            for x in (-.24, -.12, 0, .12, .24):
                tube(base, (x, .80, .1), .04, .26, 'accent', (0, 0, 1), 8)
                tube(base, (x, .80, .25), .04, .08, 'steel', (0, 0, 1), 8, 0)
