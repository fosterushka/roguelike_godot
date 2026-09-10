"""Authored military enemy set. Z-up, front -Y, one shared palette.

Body seams, wheel hardware and role-specific equipment follow player pickup
construction. Decorative geometry is merged into existing animation pivots.
"""
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

def disc(parent, name, loc, radius, color="steel", rot=(math.pi/2,0,0), vertices=8):
    """One visible cap; use for rims and recessed lenses, not solid cylinders."""
    points=[(math.cos(i*math.tau/vertices)*radius,math.sin(i*math.tau/vertices)*radius,0) for i in range(vertices)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(points,[],[tuple(range(vertices))]);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.parent=parent;obj.location=loc;obj.rotation_euler=rot
    return finish(obj,color)


def wedge(parent, name, loc, size, color="paint"):
    x,y,z = (v*.5 for v in size)
    verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z*.48),(x,y,z*.48),(-x,y,z)]
    faces=[(0,1,2,3),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0),(4,7,6,5)]
    mesh=bpy.data.meshes.new(name+"Mesh"); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj); obj.parent=parent; obj.location=loc
    return finish(obj,color)

def wheel(parent, name, x, y, z, r=.42, width=.22):
    tire = cyl(parent, name, (x,y,z), r, width, "rubber", (0,math.pi/2,0), 16)
    parts = []
    for side in (-1, 1):
        face = x + side * (width * .5 + .006)
        parts.append(cyl(parent, "WheelRim", (face,y,z), r*.59, .025, "steel", (0,math.pi/2,0), 12))
        parts.append(cyl(parent, "WheelHub", (face+side*.02,y,z), r*.23, .045, "shadow", (0,math.pi/2,0), 8))
        for step in range(6):
            angle = step * math.tau / 6
            parts.append(cyl(parent, "Lug", (face+side*.025,y+math.sin(angle)*r*.39,z+math.cos(angle)*r*.39), r*.047,.025,"cream",(0,math.pi/2,0),6))
    for step in range(16):
        angle = step * math.tau / 16
        tread = cube(parent,"Tread",(x,y+math.sin(angle)*r,z+math.cos(angle)*r),(width*1.04,r*.19,r*.075),"shadow")
        tread.rotation_euler.x = -angle
        parts.append(tread)
    join_into(tire, parts)
    return tire

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
    # Seated rider, baked into the shared body draw call.
    cube(p,"RiderPelvis",(-.38,.36,1.04),(.42,.32,.27),"shadow",.035)
    torso=cube(p,"RiderVest",(-.38,.16,1.40),(.48,.32,.58),"shadow",.04)
    torso.rotation_euler.x=-.22
    cube(p,"RiderPouches",(-.38,-.025,1.35),(.42,.12,.22),"paint")
    cyl(p,"RiderHelmet",(-.38,.025,1.84),.235,.26,"paint",(0,0,0),10)
    cube(p,"RiderVisor",(-.38,-.18,1.82),(.34,.09,.12),"glass",.02)
    for side in [-1,1]:
        x=-.38+side*.27
        strut(p,"RiderThigh",(x,.34,1.02),(x,-.08,.74),.12,"paint")
        strut(p,"RiderCalf",(x,-.08,.74),(x,.26,.40),.09,"paint")
        cube(p,"RiderBoot",(x,.17,.35),(.19,.36,.16),"rubber")
        strut(p,"RiderUpperArm",(x,.10,1.60),(x,-.20,1.29),.085,"paint")
        strut(p,"RiderForearm",(x,-.20,1.29),(x,-.54,1.09),.075,"paint")
        cube(p,"RiderGlove",(x,-.55,1.08),(.15,.15,.13),"rubber")
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
    cab_vertices=[(-.775,-1.7,.40),(.775,-1.7,.40),(.775,-.425,.40),(-.775,-.425,.40),(-.775,-1.25,1.48),(.775,-1.25,1.48),(.775,-.425,1.48),(-.775,-.425,1.48)]
    data=bpy.data.meshes.new("CabMesh");data.from_pydata(cab_vertices,[],[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]);data.update()
    cab=bpy.data.objects.new("Cab",data);bpy.context.collection.objects.link(cab);cab.parent=p;finish(cab,"paint")
    cube(p,"Hood",(0,-1.5,.73),(1.52,.50,.27),"paint",.03)
    for side in (-1,1):
        points=[(side*.055,-1.7+(.94-.40)*.45/1.08-.013,.94),(side*.66,-1.7+(.94-.40)*.45/1.08-.013,.94),(side*.66,-1.7+(1.35-.40)*.45/1.08-.013,1.35),(side*.055,-1.7+(1.35-.40)*.45/1.08-.013,1.35)]
        data=bpy.data.meshes.new("WindshieldPane");data.from_pydata(points,[],[(0,1,2,3) if side > 0 else (3,2,1,0)]);data.update()
        pane=bpy.data.objects.new("WindshieldPane",data);bpy.context.collection.objects.link(pane);pane.parent=p;finish(pane,"glass")
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

def vehicle_details(parent):
    """Purposeful silhouette details at native modelling scale, before batching."""
    name = parent.name
    if name in ("drone", "kamikaze"):
        for x in (-.32,.32):
            strut(parent,"LandingLeg",(x,.22,-.08),(x,-.30,-.38),.025)
            strut(parent,"LandingSki",(x,-.46,-.39),(x,.48,-.39),.025)
        for y in (-.22,-.08,.06,.20): cube(parent,"CoolingVent",(0,y,.182),(.38,.032,.014),"dark")
        cyl(parent,"SensorGimbal",(0,-.54,-.26),.14,.16,"steel",(0,0,0),12)
        cyl(parent,"Lens",(0,-.635,-.27),.083,.026,"glass",vertices=12)
        for rotor in [o for o in parent.children if o.name.startswith("Rotor_")]:
            hub=cyl(parent,"Motor",tuple(rotor.location),.085,.13,"steel",(0,0,0),10)
            join_into(rotor,[hub])
        return
    if name == "bike":
        for side in (-1,1):
            x=-.38+side*.23
            strut(parent,"FrameRail",(x,-.53,.54),(x,.58,.52),.04)
            cyl(parent,"Exhaust",(x,.49,.46),.07,.82,"steel")
            cube(parent,"SaddleBag",(x+side*.12,.59,.77),(.21,.43,.36),"paint",.045)
            cube(parent,"BagStrap",(x+side*.235,.59,.78),(.025,.07,.35),"cream")
            cyl(parent,"EngineCover",(x,.12,.53),.18,.05,"steel",(0,math.pi/2,0),12)
        for z in (.44,.49,.54,.59): cube(parent,"CoolingFin",(-.38,.13,z),(.47,.29,.017),"steel")
        return
    sizes={"jammerTruck":(.77,-1.72,1.50,1.1),"minelayer":(.77,-1.72,1.50,1.1)}
    if name not in sizes: return
    half, front, back, height = sizes[name]
    for side in (-1,1):
        x=half*side
        cube(parent,"RockerRail",(x,0,.46),(.09,back-front-.28,.12),"steel",.015)
        cube(parent,"AccessPanel",(x+side*.018,.03,height),(.035,.63,.39),"shadow",.012)
        cube(parent,"DoorSkin",(x+side*.04,.03,height),(.022,.56,.31),"paint",.008)
        cube(parent,"Handle",(x+side*.068,.22,height+.05),(.043,.13,.03),"cream")
        for y in (-.24,.26):
            for z in (height-.13,height+.13): cyl(parent,"PanelBolt",(x+side*.063,y,z),.02,.015,"steel",(0,math.pi/2,0),6)
        cube(parent,"FootStep",(side*(half+.08),.04,.53),(.22,.66,.055),"shadow")
        cube(parent,"TailLamp",(side*half*.77,back+.06,.76),(.13,.045,.12),"red")
        strut(parent,"TowEye",(side*half*.55,front-.08,.43),(side*half*.55,front-.08,.63),.04)
    for x in (-.34,-.20,-.06,.08,.22,.36):
        cube(parent,"GrilleSlat",(x,front-.027,.76),(.037,.038,.20),"steel")
    for y in (.60,.72,.84): cube(parent,"EngineLouvre",(0,y,height+.47),(.64,.04,.025),"dark")
    if name in ("jammerTruck","minelayer"):
        for side in (-1,1):
            cube(parent,"CabSideGlass",(side*.79,-.90,1.15),(.026,.50,.31),"glass")
            strut(parent,"MirrorArm",(side*.79,-1.47,1.1),(side*1.0,-1.43,1.22),.022)
            cube(parent,"WingMirror",(side*1.02,-1.43,1.25),(.055,.18,.20),"steel",.014)
        cube(parent,"RoofHatch",(0,-.97,1.47),(.67,.62,.075),"shadow",.035)
        cube(parent,"FrontBumper",(0,front-.14,.5),(1.8,.16,.18),"steel",.025)


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
    if parent.name.startswith("wreck_"):
        leader = children[0]
        join_into(leader, children[1:])
        leader.name = "Body"
        return
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
    # Move origins only. Geometry stays integrated with the chassis while runtime
    # damage hitboxes and removable component animations retain their anchors.
    import json
    with open(os.path.join(ROOT, 'data/leviathan_geometry.json')) as file:
        geometry = json.load(file)
    with open(os.path.join(ROOT, 'data/enemy_vehicle_styles.json')) as file:
        scale = json.load(file)['models']['boss']['scale']
    anchors = {'Component_' + kind[0].upper() + kind[1:]:
               tuple(value * scale for value in item['anchor'])
               for kind, item in geometry['components'].items()}
    from mathutils import Vector
    for name, location in anchors.items():
        child = next(item for item in parent.children if item.name == name)
        old_world = child.matrix_world.copy()
        child.location = Vector(location)
        bpy.context.view_layer.update()
        offset = child.matrix_world.inverted() @ old_world
        child.data.transform(offset)


def bake_object_transforms(models):
    # Keep object locations as Godot pivots, while baking axes/scales into mesh data.
    for parent in models:
        for item in parent.children:
            bpy.ops.object.select_all(action='DESELECT')
            item.select_set(True)
            bpy.context.view_layer.objects.active = item
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

def recalculate_normals(models):
    for parent in models:
        for item in parent.children:
            bm = bmesh.new()
            bm.from_mesh(item.data)
            # Isolated UV caps/decals have an authored visible side. A planar
            # island has no volume from which Blender can infer "outside".
            solid_faces = [face for face in bm.faces if not all(edge.is_boundary for edge in face.edges)]
            if solid_faces:
                bmesh.ops.recalc_face_normals(bm, faces=solid_faces)
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
    bpy.context.preferences.filepaths.save_version = 0
    os.makedirs(OUT,exist_ok=True); os.makedirs(ACTORS,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    write_palette(); MAT=material()
    models=[bike(),buggy(),drone(),drone("kamikaze",True),raider(),truck("jammerTruck","jammer"),crawler(),truck("minelayer","mine"),boss()]
    models += [wreck("wreck_bike","bike",(.9,2.1,.5)),wreck("wreck_buggy","buggy",(2.1,2.25,.7)),wreck("wreck_jammerTruck","jammerTruck",(2.3,3.25,.8)),wreck("wreck_repairCrawler","repairCrawler",(2.65,3.45,.85)),wreck("wreck_minelayer","minelayer",(2.3,3.0,.75))]
    scales = {"bike": 1.12, "buggy": 1.60, "drone": 1.60, "kamikaze": 1.60, "raider": 2.20, "jammerTruck": 1.72, "repairCrawler": 2.45, "minelayer": 1.72, "boss": 2.10, "wreck_bike": 1.12, "wreck_buggy": 1.60, "wreck_jammerTruck": 1.72, "wreck_repairCrawler": 2.45, "wreck_minelayer": 1.72}
    for item in models:
        if item.name not in ("buggy", "raider", "repairCrawler", "boss"):
            vehicle_details(item)
        optimize(item)
        bake_scale(item, scales[item.name])
    bpy.context.view_layer.update()
    bake_object_transforms(models)
    align_boss_components(next(item for item in models if item.name == "boss"))
    for item in models: ground_model(item)
    recalculate_normals(models)
    for item in models: export_obj(item)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(ACTORS,"military_enemies.glb"), export_format='GLB', use_selection=True, export_materials='EXPORT', export_normals=True, export_tangents=False, export_apply=True)
    layout_source_file(models)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"military_enemies.blend"))

def install_bodywork():
    import importlib.util
    path = os.path.join(os.path.dirname(__file__), "enemy_vehicle_bodywork.py")
    spec = importlib.util.spec_from_file_location("enemy_vehicle_bodywork", path)
    bodywork = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bodywork)
    bodywork.install(globals())
    originals = {"bike": bike, "jammerTruck": lambda: truck("wreck_source", "jammer"), "minelayer": lambda: truck("wreck_source", "mine")}
    globals().update(buggy=bodywork.buggy, raider=bodywork.raider, crawler=bodywork.crawler, boss=bodywork.boss,
                     wreck=lambda name, source, size: bodywork.wreck(name, source, size, originals))

if __name__=='__main__':
    import mathutils
    install_bodywork()
    main()
