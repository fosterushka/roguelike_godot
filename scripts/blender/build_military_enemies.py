"""Original compact military enemy set. Z-up, front -Y, one shared palette."""
import bpy
import bmesh
import math
import os
import shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets/models/enemies")
ACTORS = os.path.join(ROOT, "assets/actors")
PALETTE = {
    "paint": (0.349, 0.404, 0.267, 1), "light": (0.455, 0.502, 0.353, 1),
    "shadow": (0.224, 0.267, 0.192, 1), "rubber": (0.075, 0.09, 0.07, 1),
    "steel": (0.384, 0.412, 0.314, 1), "glass": (0.11, 0.19, 0.18, 1),
    "amber": (0.83, 0.50, 0.18, 1), "red": (0.66, 0.22, 0.13, 1),
    "cream": (0.78, 0.76, 0.57, 1), "dark": (0.05, 0.09, 0.06, 1),
}

def material():
    m = bpy.data.materials.new("MilitaryEnemyPalette")
    m.diffuse_color = PALETTE["paint"]
    m.use_nodes = True
    tree=m.node_tree; bsdf=tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = .82
    texture=tree.nodes.new("ShaderNodeTexImage"); texture.image=bpy.data.images["enemy_palette"]
    tree.links.new(texture.outputs["Color"],bsdf.inputs["Base Color"])
    return m

MAT = None

def group(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    return obj

def finish(obj, color):
    obj.data.materials.append(MAT)
    # Every OBJ face gets a palette atlas cell, so OBJ/MTL previews retain authored colors.
    uv = obj.data.uv_layers.new(name="PaletteUV") if not obj.data.uv_layers else obj.data.uv_layers.active
    uv.name = "PaletteUV"
    names = list(PALETTE)
    cell = names.index(color)
    point = ((cell % 4 + .5) / 4, (cell // 4 + .5) / 4)
    for polygon in obj.data.polygons:
        for loop in polygon.loop_indices: uv.data[loop].uv = point
    col = obj.data.color_attributes.new("Palette", 'BYTE_COLOR', 'CORNER')
    for item in col.data: item.color = PALETTE[color]
    obj["palette_color"] = color
    return obj

def cube(parent, name, loc, size, color="paint", bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    obj = bpy.context.object; obj.name = name; obj.parent = parent
    obj.dimensions = size; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("HardChamfer", 'BEVEL'); mod.width = bevel; mod.segments = 1
        bpy.context.view_layer.objects.active = obj; bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, color)

def cyl(parent, name, loc, radius, depth, color="steel", rot=(math.pi/2,0,0), vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object; obj.name = name; obj.parent = parent
    return finish(obj, color)

def wedge(parent, name, loc, size, color="paint"):
    x,y,z = (v*.5 for v in size)
    verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z*.48),(x,y,z*.48),(-x,y,z)]
    faces=[(0,1,2,3),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0),(4,7,6,5)]
    mesh=bpy.data.meshes.new(name+"Mesh"); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj); obj.parent=parent; obj.location=loc
    return finish(obj,color)

def wheel(parent, name, x, y, z, r=.42, width=.22):
    return cyl(parent, name, (x,y,z), r, width, "rubber", (0,math.pi/2,0), 12)

def strut(parent, name, a, b, thick=.07, color="steel"):
    ax,ay,az=a; bx,by,bz=b; dx,dy,dz=bx-ax,by-ay,bz-az
    length=math.sqrt(dx*dx+dy*dy+dz*dz); mid=((ax+bx)/2,(ay+by)/2,(az+bz)/2)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=thick, depth=length, location=mid)
    obj=bpy.context.object; obj.name=name; obj.parent=parent
    obj.rotation_mode='QUATERNION'; obj.rotation_quaternion=(mathutils.Vector((0,0,1)).rotation_difference(mathutils.Vector((dx,dy,dz))))
    obj.rotation_mode='XYZ'; return finish(obj,color)

def add_wheels(parent, points, r=.42):
    for n,(x,y,z) in enumerate(points): wheel(parent, "Wheel_%02d"%n, x,y,z,r)

def bike():
    p=group("bike"); add_wheels(p,[(-.38,-.78,.38),(-.38,.78,.38)],.34)
    cube(p,"Frame",(-.38,0,.67),(.22,1.55,.16),"steel")
    wedge(p,"FuelTank",(-.38,-.12,.82),(.46,.68,.45),"paint")
    cube(p,"Engine",(-.38,.22,.53),(.34,.36,.32),"dark")
    cube(p,"Seat",(-.38,.42,.86),(.38,.54,.16),"shadow")
    strut(p,"Fork",(-.38,-.1,.72),(-.38,-.78,.56),.055); strut(p,"Fork2",(-.20,-.1,.72),(-.20,-.78,.56),.055)
    cube(p,"Handlebar",(-.38,-.55,1.05),(.86,.08,.08),"steel")
    cube(p,"Headlamp",(-.38,-.83,.84),(.32,.07,.22),"cream")
    cube(p,"RearRack",(-.38,.76,.83),(.58,.35,.08),"steel")
    return p

def buggy():
    p=group("buggy"); add_wheels(p,[(-.82,-.88,.38),(.82,-.88,.38),(-.82,.86,.38),(.82,.86,.38)],.42)
    wedge(p,"ArmoredNose",(0,-.8,.68),(1.55,.72,.55),"paint")
    cube(p,"Hull",(0,.12,.7),(1.55,1.36,.44),"paint",.06)
    for x in (-.63,.63):
        strut(p,"RollCage",(x,-.16,.86),(x,.57,1.5),.07,"steel"); strut(p,"RollBar",(x,.57,1.5),(x,.84,.88),.07,"steel")
    cube(p,"Turret",(0,.34,1.18),(.62,.58,.28),"dark")
    cyl(p,"WeaponPitch",(0,-.2,1.22),.09,.95,"steel",(math.pi/2,0,0),8)
    cube(p,"AmmoBox",(.58,.56,.98),(.26,.38,.30),"amber")
    cube(p,"Bumper",(0,-1.18,.48),(1.72,.12,.18),"steel")
    return p

def drone(name="drone", kamikaze=False):
    p=group(name); cube(p,"Fuselage",(0,0,0),(.72,1.18,.34),"paint",.08)
    wedge(p,"Nose",(0,-.78,0),(.50,.55,.30),"light")
    cube(p,"Sensor",(0,-.72,.1),(.36,.08,.16),"glass")
    for i,(x,y) in enumerate(((-.78,-.42),(.78,-.42),(-.78,.45),(.78,.45))):
        cube(p,"Arm%02d"%i,(x*.52,y,0),(.75,.08,.08),"steel")
        cyl(p,"Rotor_%02d"%i,(x,y,.08),.32,.035,"dark",(0,0,0),8)
    if kamikaze:
        cyl(p,"Warhead",(0,-.22,-.15),.30,.64,"red",(math.pi/2,0,0),10)
        cube(p,"Warning",(0,.36,.2),(.38,.25,.08),"amber")
    else:
        cyl(p,"Gun",(0,-.83,-.08),.08,.72,"steel",(math.pi/2,0,0),8)
        cube(p,"Battery",(0,.4,-.05),(.52,.28,.22),"dark")
    return p

def truck(name, feature):
    p=group(name); add_wheels(p,[(-.84,-1.35,.43),(.84,-1.35,.43),(-.84,1.36,.43),(.84,1.36,.43)],.46)
    wedge(p,"Cab",(0,-1.05,.9),(1.55,1.25,1.15),"paint"); cube(p,"Windshield",(0,-1.63,1.1),(1.1,.07,.42),"glass")
    cube(p,"Chassis",(0,.52,.62),(1.56,2.15,.36),"steel")
    cube(p,"RearBody",(0,.72,1.0),(1.48,1.7,.92),"paint",.05)
    cube(p,"Grille",(0,-1.7,.72),(1.05,.06,.25),"dark")
    for x in (-.62,.62): cube(p,"Lamp",(x,-1.74,.82),(.18,.04,.15),"cream")
    if feature=="jammer":
        cyl(p,"JammerHead",(0,.72,1.72),.48,.25,"steel",(0,0,0),10)
        for i in range(4): strut(p,"Antenna%02d"%i,(0,.72,1.84),((i-1.5)*.22,.72,2.48),.035,"cream")
        cyl(p,"JammerScan",(0,.72,1.58),.68,.04,"amber",(0,0,0),12)
    elif feature=="mine":
        cube(p,"MineBay",(0,1.15,1.42),(1.18,.66,.42),"dark")
        for x in (-.42,0,.42): cyl(p,"MineRack",(x,1.55,.83),.18,.30,"amber",(0,0,0),8)
        cyl(p,"WeaponPitch",(0,-.35,1.28),.08,.85,"steel",(math.pi/2,0,0),8)
    return p

def crawler():
    p=group("repairCrawler")
    for x in (-1.12,1.12):
        cube(p,"Track_%s"%x,(x,0,.4),(.48,2.9,.62),"rubber",.07)
        for y in (-.95,0,.95): wheel(p,"RoadWheel",x,y,.37,.26,.18)
    wedge(p,"CrawlerHull",(0,-.15,.88),(2.25,2.8,1.05),"paint")
    cube(p,"Workshop",(0,.54,1.32),(1.72,1.25,.72),"light")
    cyl(p,"RepairArm",(.92,-.36,1.45),.10,1.65,"steel",(0,math.pi/3,0),8)
    cube(p,"ToolHead",(1.58,-.72,1.28),(.30,.32,.27),"amber")
    cube(p,"RearCrane",(-.55,1.12,1.82),(.11,.11,.95),"steel")
    return p

def boss():
    p=group("boss")
    for side in (-1,1):
        cube(p,"Component_%sDrive"%("Left" if side<0 else "Right"),(side*2.25,0,.62),(1.08,4.2,1.18),"rubber",.10)
        for y in (-1.38,0,1.38): wheel(p,"BossRoadWheel",side*2.25,y,.52,.43,.28)
    wedge(p,"BossHull",(0,-.22,1.42),(4.05,4.5,1.9),"paint")
    cube(p,"Component_Core",(0,.15,2.25),(1.55,1.5,.95),"amber",.08)
    cube(p,"Component_MissilePod",(-1.2,-.82,2.25),(1.05,1.25,.60),"steel")
    cube(p,"Component_GunPod",(1.2,-.82,2.2),(1.05,1.25,.60),"steel")
    for x in (-1.2,1.2):
        for y in (-1.18,-.82): cyl(p,"PodTube",(x,y,2.22),.12,.75,"dark",(math.pi/2,0,0),8)
    cyl(p,"MainCannon",(0,-2.38,1.84),.16,1.85,"steel",(math.pi/2,0,0),10)
    cube(p,"CommandTurret",(0,.7,2.45),(1.28,1.1,.48),"light")
    return p

def raider():
    p=group("raider")
    # A rolling desert fort: wider than a buggy but clearly below Leviathan scale.
    add_wheels(p,[(-1.35,-1.38,.48),(1.35,-1.38,.48),(-1.35,1.25,.48),(1.35,1.25,.48)],.52)
    wedge(p,"FortHull",(0,-.15,1.02),(2.65,3.5,1.32),"paint")
    cube(p,"FortCab",(0,.42,1.72),(2.05,1.42,.78),"light",.07)
    cube(p,"FortWindshield",(0,-.34,1.78),(1.48,.06,.31),"glass")
    cube(p,"RocketRack",(-.75,-.88,2.02),(.76,.92,.46),"steel")
    for y in (-1.12,-.82,-.52): cyl(p,"FortRocket",(-.75,y,2.04),.10,.62,"amber",(math.pi/2,0,0),8)
    cyl(p,"FortCannon",(.72,-1.92,1.65),.13,1.45,"steel",(math.pi/2,0,0),10)
    cube(p,"FortBumper",(0,-1.98,.62),(2.84,.14,.24),"steel")
    return p

def wreck(name, source, size):
    p=group(name); x,y,z=size
    wedge(p,"WreckHull",(0,0,.24),(x,y,.48),"shadow")
    cube(p,"WreckFrame",(.12,-.08,.52),(x*.72,y*.62,.13),"steel")
    cube(p,"WreckFirebox",(-.18,.18,.58),(x*.34,y*.28,.2),"dark")
    if source != "bike":
        for sx,sy in ((-.35,-.32),(.35,.32)): wheel(p,"WreckWheel",sx*x,sy*y,.2,min(x,y)*.13,.16)
    return p

def write_palette():
    image=bpy.data.images.new("enemy_palette",4,4)
    pixels=[]
    keys=list(PALETTE)
    for index in range(16): pixels.extend(PALETTE[keys[index % len(keys)]])
    image.pixels= pixels; image.file_format='PNG'
    palette_path = os.path.join(OUT,"palette.png")
    image.filepath_raw=palette_path; image.save()
    shutil.copyfile(palette_path, os.path.join(ACTORS,"military_enemies_palette.png"))

def join_into(target, sources):
    sources = [item for item in sources if item != target]
    if not sources: return
    bpy.ops.object.select_all(action='DESELECT')
    target.select_set(True)
    for item in sources: item.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()

def optimize(parent):
    """One palette-UV body mesh; retain only animated or removable pivots."""
    children = list(parent.children)
    if parent.name == "boss":
        left = next(item for item in children if item.name == "Component_LeftDrive")
        right = next(item for item in children if item.name == "Component_RightDrive")
        missile = next(item for item in children if item.name == "Component_MissilePod")
        gun = next(item for item in children if item.name == "Component_GunPod")
        for item in children:
            if item.name.startswith("BossRoadWheel"):
                join_into(left if item.location.x < 0 else right, [item])
            elif item.name.startswith("PodTube"):
                join_into(missile if item.location.x < 0 else gun, [item])
    static = [item for item in list(parent.children) if not item.name.startswith(("Wheel_", "Rotor_", "JammerHead", "JammerScan", "WeaponPitch", "Component_"))]
    if static:
        leader = static[0]
        join_into(leader, static[1:])
        leader.name = "Body"

def bake_scale(parent, amount):
    for item in parent.children:
        item.location *= amount
        item.scale *= amount

def align_boss_components(parent):
    anchors = {"Component_MissilePod": (0.0, 1.584, 8.316), "Component_GunPod": (1.98, -1.716, 7.26), "Component_LeftDrive": (-4.686, 0.462, 2.97), "Component_RightDrive": (4.686, 0.462, 2.97), "Component_Core": (0.0, -0.264, 5.874)}
    def child(name): return next(item for item in parent.children if item.name == name)
    for name, location in anchors.items(): child(name).location = location
    missile = child("Component_MissilePod")
    gun = child("Component_GunPod")
    strut(parent, "MissileSupportA", (0.0, 0.0, 3.4), (0.0, 1.584, 8.05), .13, "steel")
    strut(parent, "MissileSupportB", (-.72, .10, 3.25), (0.0, 1.584, 7.82), .11, "steel")
    strut(parent, "GunSupport", (1.05, -.55, 3.25), (1.98, -1.716, 7.02), .12, "steel")
    join_into(missile, [child("MissileSupportA"), child("MissileSupportB")])
    join_into(gun, [child("GunSupport")])

def bake_object_transforms(models):
    # Keep object locations as Godot pivots, while baking axes/scales into mesh data.
    for parent in models:
        for item in parent.children:
            bpy.ops.object.select_all(action='DESELECT')
            item.select_set(True)
            bpy.context.view_layer.objects.active = item
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

def extend_boss_drives(parent):
    for name in ("Component_LeftDrive", "Component_RightDrive"):
        drive = next(item for item in parent.children if item.name == name)
        lowest = min(vertex.co.z for vertex in drive.data.vertices)
        if lowest < 0.0:
            factor = 2.97 / -lowest
            for vertex in drive.data.vertices: vertex.co.z *= factor
            drive.data.update()

def recalculate_normals(models):
    for parent in models:
        for item in parent.children:
            bm = bmesh.new()
            bm.from_mesh(item.data)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(item.data)
            bm.free()
            item.data.update()

def ground_model(parent):
    if parent.name in ("drone", "kamikaze"): return
    lowest = min((item.matrix_world @ vertex.co).z for item in parent.children for vertex in item.data.vertices)
    if lowest < 0.0:
        for item in parent.children: item.location.z -= lowest

def layout_source_file(models):
    for index, parent in enumerate(models):
        parent.location = ((index % 5) * 20.0, (index // 5) * 20.0, 0.0)

def export_obj(parent):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [parent]+list(parent.children): obj.select_set(True)
    bpy.context.view_layer.objects.active=parent
    bpy.ops.wm.obj_export(filepath=os.path.join(OUT,parent.name+".obj"), export_selected_objects=True, export_materials=True)

def main():
    global MAT
    os.makedirs(OUT,exist_ok=True); os.makedirs(ACTORS,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    write_palette(); MAT=material()
    models=[bike(),buggy(),drone(),drone("kamikaze",True),raider(),truck("jammerTruck","jammer"),crawler(),truck("minelayer","mine"),boss()]
    models += [wreck("wreck_bike","bike",(.9,2.1,.5)),wreck("wreck_buggy","buggy",(2.1,2.25,.7)),wreck("wreck_jammerTruck","jammerTruck",(2.3,3.25,.8)),wreck("wreck_repairCrawler","repairCrawler",(2.65,3.45,.85)),wreck("wreck_minelayer","minelayer",(2.3,3.0,.75))]
    scales = {"bike": 1.12, "buggy": 1.60, "drone": 1.60, "kamikaze": 1.60, "raider": 2.20, "jammerTruck": 1.72, "repairCrawler": 2.45, "minelayer": 1.72, "boss": 2.10, "wreck_bike": 1.12, "wreck_buggy": 1.60, "wreck_jammerTruck": 1.72, "wreck_repairCrawler": 2.45, "wreck_minelayer": 1.72}
    for item in models:
        optimize(item)
        bake_scale(item, scales[item.name])
    align_boss_components(next(item for item in models if item.name == "boss"))
    bake_object_transforms(models)
    extend_boss_drives(next(item for item in models if item.name == "boss"))
    for item in models: ground_model(item)
    recalculate_normals(models)
    for item in models: export_obj(item)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(ACTORS,"military_enemies.glb"), export_format='GLB', use_selection=True, export_materials='EXPORT', export_normals=True, export_tangents=False, export_apply=True)
    layout_source_file(models)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"military_enemies.blend"))

if __name__=='__main__':
    import mathutils
    main()
