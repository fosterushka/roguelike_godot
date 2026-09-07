"""Build the authored low-poly infantry library used by the Godot soldier rig.

The source geometry is deliberately small: each person is seven articulated
pieces, with shared limbs and a shared palette material.  Z is up in Blender;
Godot receives the same axis convention through the GLB exporter.
"""
from pathlib import Path
import sys
import math

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/people"
GAME_OUT = ROOT / "assets/actors/military_people.glb"
sys.path.insert(0, str(Path(__file__).parent))
from pickup_geometry import MeshBuilder, PALETTE


RIG = {
    "BODY": ("body", None, (0.0, 1.08, 0.0), (0.0, 0.0, 0.0)),
    "HEAD": ("head", None, (0.0, 1.68, 0.015), (0.0, 0.0, 0.0)),
    "LEG_L": ("leg", -1.0, (-0.17, 0.74, 0.0), (0.0, 0.0, 0.0)),
    "LEG_R": ("leg", 1.0, (0.17, 0.74, 0.0), (0.0, 0.0, 0.0)),
    "ARM_L": ("arm", -1.0, (-0.39, 1.4, 0.0), (0.0, 0.0, -0.10)),
    "ARM_R": ("arm", 1.0, (0.39, 1.4, 0.0), (0.0, 0.0, 0.10)),
    "WEAPON": ("weapon", 1.0, (-0.46, 1.23, 0.24), (0.0, 0.0, -0.08)),
}


def palette_material():
    image = bpy.data.images.new("people_palette.png", 32, 32)
    for index, hex_color in enumerate(PALETTE.values()):
        color = tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,)
        row, column = divmod(index, 4)
        for y in range(row * 8, row * 8 + 8):
            for x in range(column * 8, column * 8 + 8):
                image.pixels[(y * 32 + x) * 4:(y * 32 + x + 1) * 4] = color
    image.filepath_raw = str(OUT / "palette.png")
    image.file_format = "PNG"
    image.save()
    image.pack()
    image.filepath = "//palette.png"
    material = bpy.data.materials.new("MilitaryPeoplePalette")
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.88
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Closest"
    material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    return material


def mesh(name, build, material):
    builder = MeshBuilder()
    build(builder)
    # MeshBuilder's authored coordinates follow Godot (Y-up) so they can be
    # checked beside the combat rig.  Blender is Z-up; convert once at export.
    builder.vertices = [(x, -z, y) for x, y, z in builder.vertices]
    return builder.finish(name, material)


def tailored(builder, center, levels, color):
    """Eight-sided tailored volumes, instead of rectangular placeholder anatomy."""
    cx, cy, cz = center
    rings=[]
    for y, width, depth in levels:
        bevel=min(width,depth)*.22
        outline=[(-width/2+bevel,-depth/2),(width/2-bevel,-depth/2),(width/2,-depth/2+bevel),(width/2,depth/2-bevel),(width/2-bevel,depth/2),(-width/2+bevel,depth/2),(-width/2,depth/2-bevel),(-width/2,-depth/2+bevel)]
        rings.append([(cx+x,cy+y,cz+z) for x,z in outline])
    builder.loft(rings,color)


def limb_meshes(material):
    def leg(builder):
        tailored(builder,(0,0,0),[(-.46,.14,.16),(-.28,.18,.18),(-.13,.205,.21),(.015,.19,.21)],"paint_shadow")
        builder.box((0, -0.25, .112), (.19, .16, .055), "trim")
        tailored(builder,(0,0,.035),[(-.55,.22,.32),(-.46,.21,.31),(-.39,.17,.22)],"rubber")
        for y in (-.43,-.46,-.49): builder.box((0,y,.185),(.15,.015,.015),"steel")
        builder.box((0, -0.555, .018), (.235, .045, .34), "dark")
        builder.box((0, -0.025, .0), (.205, .08, .205), "paint_light")
    def arm(builder):
        tailored(builder,(0,0,0),[(-.44,.125,.14),(-.27,.15,.17),(-.17,.17,.18),(.015,.185,.19)],"paint")
        builder.box((0, -0.12, .095), (.175, .15, .035), "paint_light")
        tailored(builder,(0,-.47,0),[(-.07,.11,.13),(.05,.135,.15)],"trim")
        builder.box((0,-.25,-.091),(.16,.11,.045),"trim")
        builder.box((0, -0.03, .0), (.19, .07, .19), "paint_light")
    def head(builder):
        tailored(builder,(0,0,0),[(-.165,.19,.23),(-.11,.28,.28),(.07,.31,.30),(.17,.28,.27)],"accent")
        builder.box((0,-.066,.177),(.07,.09,.055),"accent")
        builder.box((0,-.127,.152),(.15,.013,.016),"paint_shadow")
        for side in (-1,1):
            builder.box((side*.166,.016,0),(.048,.15,.12),"trim")
            builder.box((side*.167,-.098,.067),(.022,.17,.035),"paint_shadow")
        builder.box((0, -.035, .182), (.25, .10, .026), "glass")
        for side in (-1, 1):
            builder.box((side * .075, -.035, .202), (.10, .075, .022), "glass_light")
        builder.box((0, -.035, .195), (.035, .09, .032), "trim")
        builder.box((0, -.18, -.02), (.13, .05, .13), "accent")
        rings = []
        for y, radius in ((.09, .215), (.23, .205), (.29, .14)):
            rings.append([(math.cos(index * math.tau / 8) * radius, y, math.sin(index * math.tau / 8) * radius) for index in range(8)])
        builder.loft(rings, "paint", "paint_light")
        builder.box((0, .09, .20), (.38, .065, .075), "paint_shadow")
    return mesh("MilitarySharedLeg", leg, material), mesh("MilitarySharedArm", arm, material), mesh("MilitarySharedHead", head, material)


def torso_mesh(kind, material):
    def build(builder):
        color = "paint" if kind in ("rifleman", "ak", "bazooka") else "paint_shadow"
        tailored(builder,(0,0,0),[(-.35,.45,.30),(-.18,.49,.33),(.20,.56,.35),(.35,.42,.29)],color)
        tailored(builder,(0,.13,.183),[(-.22,.36,.065),(.13,.40,.07),(.21,.28,.055)],"trim")
        for side in (-1,1):
            builder.box((side*.19,.11,.191),(.055,.43,.036),"accent")
        builder.box((0,-.345,.175),(.075,.053,.028),"steel")
        builder.box((0, -.19, .19), (.48, .40, .075), "trim")
        builder.box((0, -.42, .02), (.58, .06, .34), "paint_light")
        builder.box((0, .24, -.20), (.44, .22, .10), "bed")
        builder.box((0, -.24, .245), (.43, .07, .045), "paint_light")
        for x in (-.14,0,.14):
            builder.box((x,.035,.28),(.12,.031,.025),"paint_light")
            builder.box((x,-.067,.278),(.025,.04,.019),"steel")
        for side in (-1, 0, 1):
            builder.box((side * .14, -.06, .245), (.115, .16, .055), "bed")
        builder.box((-.31, .06, .08), (.11, .28, .17), "steel")
        builder.box((-.31, .19, .19), (.12, .045, .06), "accent")
        for side in (-1, 1):
            builder.box((side * .32, .20, .0), (.12, .24, .24), "paint_light")
        if kind == "ak":
            builder.box((0, -.41, .22), (.34, .12, .05), "accent")
            builder.box((.31, .08, .01), (.11, .42, .16), "steel")
        elif kind == "bazooka":
            builder.box((0, .30, .20), (.42, .18, .10), "steel")
            builder.box((-.31, .0, .05), (.09, .48, .17), "trim")
        elif kind == "bomber":
            builder.box((0, -.42, .22), (.43, .08, .10), "red")
            for side in (-1, 1): builder.box((side * .19, -.46, .22), (.08, .08, .12), "amber")
        else:
            builder.box((0, -.40, .22), (.40, .09, .06), "paint_light")
    return mesh("Military%sBody" % kind.capitalize(), build, material)


def weapon_mesh(kind, material):
    def rifle(builder):
        builder.box((0, -.28, .03), (.10, .78, .10), "trim")
        builder.box((0, -.03, .03), (.18, .22, .15), "steel")
        builder.box((0, -.63, .03), (.052, .28, .052), "dark")
        builder.box((0, -.48, .03), (.12, .045, .13), "paint_light")
        builder.box((0, -.12, -.09), (.09, .25, .12), "bed")
        builder.box((0, -.38, .105), (.035, .17, .035), "accent")
        builder.box((0, .10, -.08), (.08, .25, .18), "bed")
    def ak(builder):
        rifle(builder)
        builder.box((0, -.45, .03), (.13, .28, .11), "paint_light")
        builder.box((0, .10, -.08), (.12, .28, .18), "accent")
    def bazooka(builder):
        rings = []
        for y, radius in ((-.55, .145), (.33, .145)):
            rings.append([(math.cos(index * math.tau / 10) * radius, y, math.sin(index * math.tau / 10) * radius) for index in range(10)])
        builder.loft(rings, "steel", "trim")
        builder.box((0, -.08, -.16), (.18, .23, .12), "paint")
        builder.box((0, .30, .0), (.29, .09, .29), "trim")
        builder.box((0, -.52, .0), (.32, .07, .32), "dark")
    def bomb(builder):
        builder.box((0, -.08, .0), (.42, .34, .25), "red")
        builder.box((0, -.08, .16), (.11, .12, .10), "amber")
        builder.box((0, .15, .0), (.10, .15, .10), "trim")
    funcs = {"rifleman": rifle, "ak": ak, "bazooka": bazooka, "bomber": bomb}
    return mesh("Military%sWeapon" % kind.capitalize(), funcs[kind], material)


def add_part(parent, object_name, part_mesh, key, kind, weapon_position=None):
    role, side, position, rotation = RIG[key]
    if key == "WEAPON" and kind == "bomber":
        position = (0.0, 1.13, 0.30)
    obj = bpy.data.objects.new(object_name, part_mesh)
    parent.users_collection[0].objects.link(obj)
    obj.parent = parent
    # The same fixed basis change makes the standalone GLB stand upright while
    # its exported local mesh remains identical to the Godot rig coordinates.
    axis = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    obj.location = (position[0], -position[2], position[1])
    obj.rotation_euler = (axis @ Euler(rotation).to_matrix() @ axis.inverted()).to_euler()
    obj["rig_role"] = role
    obj["rig_kind"] = kind
    if side is not None: obj["rig_side"] = side
    return obj


def add_model(collection, kind, shared, material):
    root = bpy.data.objects.new("MODEL_" + kind.upper(), None)
    collection.objects.link(root)
    body = torso_mesh(kind, material)
    weapon = weapon_mesh(kind, material)
    parts = {"BODY": body, "HEAD": shared[2], "LEG_L": shared[0], "LEG_R": shared[0], "ARM_L": shared[1], "ARM_R": shared[1], "WEAPON": weapon}
    for key, part_mesh in parts.items():
        add_part(root, "%s_%s" % (kind.upper(), key), part_mesh, key, kind)
    return root


CREW_ROLES = ("mechanic", "shooter", "loader", "looter", "fuel", "anti_tank", "anti_air", "civilian")


def add_crew_assets(collection, material, shared):
    roots=[]
    seated=bpy.data.objects.new("MODEL_SEATED",None); collection.objects.link(seated); roots.append(seated)
    def part(name, build, position, uniform=False):
        data=mesh("Seated"+name,build,material)
        obj=bpy.data.objects.new(name,data); collection.objects.link(obj); obj.parent=seated
        obj.location=(position[0],-position[2],position[1]); obj["seat_role_uniform"]=uniform
        return obj
    def volume(size, color):
        return lambda b: tailored(b,(0,0,0),[(-size[1]/2,size[0]*.91,size[2]*.91),(size[1]*.30,size[0],size[2]),(size[1]/2,size[0]*.87,size[2]*.86)],color)
    part("Pelvis",volume((.38,.20,.30),"paint"),(0,.42,0),True)
    part("Torso",volume((.48,.64,.30),"paint"),(0,.83,-.03),True)
    # The head is the same authored helmet, goggles and face used on infantry.
    head=bpy.data.objects.new("Head",shared[2]); collection.objects.link(head); head.parent=seated; head.location=(0,-.01,1.29); head.scale=(.90,.90,.90)
    part("VestPlate",lambda b: tailored(b,(0,0,0),[(-.2,.31,.06),(.11,.41,.07),(.2,.28,.055)],"trim"),(0,.88,.14))
    part("VestPouches",lambda b: [b.box((x,0,0),(.105,.14,.08),"bed") for x in (-.14,0,.14)],(0,.76,.21))
    part("PickupBenchCushion",volume((.62,.14,.58),"bed"),(0,.25,0))
    for side in (-1,1):
        suffix="" if side<0 else "Right"
        part("PickupBenchLeg"+suffix,volume((.08,.34,.10),"trim"),(side*.22,.07,0))
        part("Thigh"+suffix,volume((.17,.18,.52),"paint"),(side*.16,.39,.27),True)
        part("Shin"+suffix,volume((.16,.40,.17),"paint_shadow"),(side*.16,.20,.49))
        part("Boot"+suffix,volume((.20,.13,.30),"rubber"),(side*.16,.06,.57))
        part("Kneepad"+suffix,volume((.17,.10,.055),"trim"),(side*.16,.40,.548))
        part("UpperArm"+suffix,volume((.16,.43,.17),"paint"),(side*.31,.81,.03),True)
        part("Forearm"+suffix,volume((.14,.15,.40),"paint"),(side*.31,.57,.25),True)
        part("Hand"+suffix,volume((.135,.13,.14),"trim"),(side*.31,.56,.48))
    for role in CREW_ROLES:
        kit=bpy.data.objects.new("MODEL_CREW_"+role.upper(),None); collection.objects.link(kit); roots.append(kit)
        def build(b):
            # All accessories use torso-local coordinates so walking follows the body.
            if role=="civilian":
                tailored(b,(0,.24,.19),[(-.11,.43,.07),(.05,.46,.09),(.13,.29,.07)],"accent")
                b.box((0,-.27,-.24),(.29,.29,.18),"bed")
            elif role=="mechanic":
                for x in (-.22,-.11,.0):
                    b.box((x,-.35,.26),(.06,.21,.06),"steel")
                    b.box((x,-.24,.26),(.09,.075,.045),"steel")
                b.box((.32,-.17,.0),(.17,.32,.22),"bed")
                b.box((.34,-.1,.125),(.08,.03,.026),"amber")
            elif role=="shooter":
                for x in (-.25,-.08,.09,.26): b.box((x,-.12,.285),(.12,.22,.10),"paint_shadow")
                b.box((0,.0,-.245),(.37,.45,.19),"paint")
            elif role=="loader":
                b.box((0,0,-.28),(.42,.48,.23),"steel")
                for y in (-.16,0,.16): b.box((0,y,-.411),(.39,.03,.021),"accent")
                for x in (-.2,-.1,0,.1,.2): b.box((x,.17,.27),(.055,.19,.065),"amber")
            elif role=="looter":
                tailored(b,(0,0,-.32),[(-.36,.37,.25),(.2,.46,.30),(.36,.33,.25)],"accent")
                for x in (-.14,.14): b.box((x,0,-.481),(.045,.65,.027),"trim")
                b.box((.32,-.19,0),(.16,.28,.23),"bed")
            elif role=="fuel":
                b.box((0,-.02,-.31),(.39,.53,.25),"paint_shadow")
                b.box((0,.29,-.31),(.24,.06,.17),"steel")
                for x in (-.105,.105): b.box((x,.00,-.45),(.026,.39,.023),"amber")
                b.box((.135,.267,-.31),(.065,.06,.09),"dark")
            elif role=="anti_tank":
                for x in (-.2,.2):
                    rings=[[(x+math.cos(i*math.tau/10)*r,y,-.28+math.sin(i*math.tau/10)*r) for i in range(10)] for y,r in ((-.43,.082),(.30,.082),(.46,.018))]
                    b.loft(rings,"paint_light","amber")
                b.box((0,-.18,-.30),(.53,.10,.15),"trim")
            elif role=="anti_air":
                b.box((0,-.03,-.30),(.45,.55,.23),"steel")
                b.box((0,.05,-.43),(.25,.18,.025),"glass_light")
                for x in (-.17,.17): b.box((x,.48,-.30),(.025,.57,.025),"trim")
                b.box((.31,.01,.08),(.14,.28,.20),"amber")
        data=mesh("CrewKit_"+role,build,material)
        obj=bpy.data.objects.new("Kit",data);collection.objects.link(obj);obj.parent=kit
    return roots


def add_preview(scene):
    stage = bpy.data.collections.new("PRESENTATION_ONLY")
    scene.collection.children.link(stage)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.object
    for owner in list(floor.users_collection): owner.objects.unlink(floor)
    stage.objects.link(floor)
    floor_mat = bpy.data.materials.new("PreviewGround")
    floor_mat.diffuse_color = (.07, .09, .08, 1)
    floor.data.materials.append(floor_mat)
    bpy.ops.object.light_add(type="AREA", location=(4, -6, 7))
    light = bpy.context.object
    for owner in list(light.users_collection): owner.objects.unlink(light)
    stage.objects.link(light)
    light.data.energy, light.data.shape, light.data.size = 1100, "DISK", 5
    light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(7, -11, 6))
    camera = bpy.context.object
    for owner in list(camera.users_collection): owner.objects.unlink(camera)
    stage.objects.link(camera)
    camera.data.type, camera.data.ortho_scale = "ORTHO", 6.5
    camera.rotation_euler = (Vector((0, 0, 1.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera


def export_model(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children: child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.obj_export(filepath=str(path), export_selected_objects=True, export_materials=True,
        export_uv=True, export_normals=True, export_triangulated_mesh=True,
        forward_axis="NEGATIVE_Z", up_axis="Y")


def main():
    bpy.context.preferences.filepaths.save_version = 0
    OUT.mkdir(parents=True, exist_ok=True)
    GAME_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections): bpy.data.collections.remove(collection)
    scene = bpy.context.scene
    scene["asset_origin"] = "authored_from_scratch"
    scene["asset_style"] = "optimized_military_lowpoly_infantry"
    collection = bpy.data.collections.new("MILITARY_PEOPLE")
    scene.collection.children.link(collection)
    material = palette_material()
    shared = limb_meshes(material)
    roots = [add_model(collection, kind, shared, material) for kind in ("rifleman", "ak", "bazooka", "bomber")]
    crew_roots = add_crew_assets(collection, material, shared)
    for crew_root in crew_roots: crew_root.hide_render = True
    for index, root in enumerate(roots): root.location.x = (index - 1.5) * 1.45
    add_preview(scene)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 560
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT / "preview.png")
    bpy.ops.render.render(write_still=True)
    for root in roots: root.location.x = 0.0
    for root in roots: export_model(root, OUT / (root.name.removeprefix("MODEL_").lower() + ".obj"))
    bpy.ops.object.select_all(action="DESELECT")
    for crew_root in crew_roots: crew_root.hide_render = False
    for root in roots + crew_roots:
        root.select_set(True)
        for child in root.children: child.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(GAME_OUT), export_format="GLB", use_selection=True,
        export_materials="EXPORT", export_normals=True, export_texcoords=True, export_apply=True)
    for index, root in enumerate(roots): root.location.x = (index - 1.5) * 1.45
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "military_people.blend"))
    print("MILITARY_PEOPLE_EXPORT_OK", GAME_OUT)


if __name__ == "__main__":
    main()
