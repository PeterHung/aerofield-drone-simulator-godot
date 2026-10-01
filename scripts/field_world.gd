class_name FieldWorld
extends Node3D
## Procedural native 3D scene. Training state is exclusively in FlightSimulator.
const Data = preload("res://scripts/training_data.gd")
var simulator: FlightSimulator
var camera: Camera3D
var drone: Node3D
var rotors: Array[Node3D] = []
var field: Node3D
var route: Node3D
var target: Node3D
var windsock: Node3D
var camera_mode = "observer"
var show_route = true
var last_signature = ""
var last_level = ""
var font: FontVariation
var material_cache: Dictionary = {}

func _ready() -> void:
	font = FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansTC.ttf")
	font.variation_opentype = {2003265652:550.0}
	var environment_node = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("c7e0eb")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5e7eb")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	add_child(environment_node)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color("fff1d4")
	sun.light_energy = 0.85
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 48
	camera.far = 450
	camera.near = 0.08
	camera.current = true
	add_child(camera)
	create_environment()
	field = Node3D.new()
	add_child(field)
	route = Node3D.new()
	add_child(route)
	target = Node3D.new()
	add_child(target)
	create_drone()
	rebuild_field()
	update_view(1)

func material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var key = color.to_html()+str(unshaded)
	if material_cache.has(key):
		return material_cache[key]
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_cache[key] = result
	return result

func mesh(parent: Node3D, shape: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, unshaded: bool = false) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color,unshaded)
	instance.position = pos
	parent.add_child(instance)
	return instance

func box(parent: Node3D, dimensions: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = dimensions
	return mesh(parent,shape,color,pos)

func cylinder(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3, top: float = -1) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = 24
	return mesh(parent,shape,color,pos)

func line(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color, unshaded: bool = false) -> void:
	if a.distance_to(b) < 0.001:
		return
	var shape = CylinderMesh.new()
	shape.top_radius = width/2
	shape.bottom_radius = width/2
	shape.height = a.distance_to(b)
	shape.radial_segments = 6
	var item = mesh(parent,shape,color,(a+b)/2,unshaded)
	item.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func ring(parent: Node3D, p: Vector3, radius: float, width: float, color: Color) -> void:
	var shape = TorusMesh.new()
	shape.inner_radius = radius-width/2
	shape.outer_radius = radius+width/2
	shape.rings = 72
	shape.ring_segments = 8
	mesh(parent,shape,color,p)

func label3d(parent: Node3D, text: String, p: Vector3, color: Color, font_size: int = 48) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font = font
	label.font_size = font_size
	label.pixel_size = 0.018
	label.modulate = color
	label.outline_size = 5
	label.outline_modulate = Color(0.1,0.19,0.16,0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = p
	parent.add_child(label)
	return label

func create_environment() -> void:
	box(self,Vector3(400,0.4,360),Color("617843"),Vector3(0,-0.22,70))
	for i in range(24):
		box(self,Vector3(9,0.013,88),Color("75874e") if i%2==0 else Color("6e8148"),Vector3(-103.5+i*9,-0.011,38))
	box(self,Vector3(220,0.08,6),Color("a8a38a"),Vector3(0,0,-5))
	box(self,Vector3(220,0.09,0.15),Color("ded9c9"),Vector3(0,0.05,-2))
	var seeded = RandomNumberGenerator.new()
	seeded.seed = 48261
	for i in range(64):
		var x = -137.0+i*4.4
		var z = 73.0+seeded.randf_range(0,15)
		create_tree(Vector3(x,0,z),seeded.randf_range(0.85,1.5),seeded)
	for i in range(10):
		create_tree(Vector3(-120+seeded.randf_range(-8,8),0,7+i*5),1.2,seeded)
	for side in [-1,1]:
		for i in range(19):
			box(self,Vector3(0.12,1.1,0.12),Color("e0ddd0"),Vector3(side*115,0.55,i*4))
		box(self,Vector3(0.1,0.09,72),Color("d6d6c7"),Vector3(side*115,0.7,36))
	box(self,Vector3(15,5.5,10),Color("d6dad2"),Vector3(48,2.75,64))
	box(self,Vector3(16,0.45,11),Color("3d5557"),Vector3(48,5.65,64))
	box(self,Vector3(9,4.3,0.1),Color("52696a"),Vector3(48,2.2,58.94))
	label3d(self,"AEROFIELD",Vector3(48,4.9,58.5),Color("f0eee2"),25)
	for i in range(4):
		box(self,Vector3(4,1.9,2),Color("e5dfcd"),Vector3(-38-i*5,0.95,61))
		box(self,Vector3(4.3,0.15,2.3),Color("3e5559"),Vector3(-38-i*5,1.95,61))
	windsock = Node3D.new()
	windsock.position = Vector3(-26,0,36)
	add_child(windsock)
	cylinder(windsock,0.065,6,Color("d3dad7"),Vector3(0,3,0))
	var cloth = Node3D.new()
	cloth.name = "Cloth"
	cloth.position = Vector3(0,5.7,0)
	windsock.add_child(cloth)
	for i in range(5):
		var piece = cylinder(cloth,0.3-i*0.038,0.38,Color("e9793e") if i%2==0 else Color("f5e9d0"),Vector3(-0.2-i*0.35,0,0),0.27-i*0.038)
		piece.rotation.z = PI/2

func create_tree(pos: Vector3, scale_factor: float, seeded: RandomNumberGenerator) -> void:
	var tree = Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE*scale_factor
	add_child(tree)
	cylinder(tree,0.17,2.8,Color("69543c"),Vector3(0,1.4,0))
	for i in range(3):
		var shape = SphereMesh.new()
		shape.radius = 1.4-i*0.12
		shape.height = 2.3
		shape.radial_segments = 12
		shape.rings = 6
		mesh(tree,shape,Color("496c43") if i%2==0 else Color("577b49"),Vector3(seeded.randf_range(-0.6,0.6),2.4+i*0.6,seeded.randf_range(-0.4,0.4)))

func rebuild_field() -> void:
	clear(field)
	var g = Data.geometry(simulator.config.level)
	for side in ["left","right"]:
		for radius in [g.inner_radius,g.radius,g.outer_radius]:
			ring(field,Data.scene_position(g[side])+Vector3.UP*0.04,radius,0.1,Color("e1e9ce"))
	ring(field,Data.scene_position(Data.HOME)+Vector3.UP*0.035,1.5,0.1,Color("f3ecd8"))
	var home_label = label3d(field,"H",Data.scene_position(Data.HOME)+Vector3.UP*0.07,Color("ffffff"),56)
	home_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	home_label.rotation_degrees.x = -90
	for key in g.points:
		var p = Data.scene_position(g.points[key])
		cylinder(field,0.22,0.55,Color("ea803f"),p+Vector3.UP*0.275,0.02)
		cylinder(field,0.14,0.12,Color("f9e7cd"),p+Vector3.UP*0.33,0.1)
		label3d(field,key,p+Vector3.UP*0.95,Color("f6f0d8"),23)
	var corners = [Vector3(-g.half_length,0.035,Data.HOME.z),Vector3(-g.half_length,0.035,Data.HOME.z+g.depth),
		Vector3(g.half_length,0.035,Data.HOME.z+g.depth),Vector3(g.half_length,0.035,Data.HOME.z)]
	for i in range(4):
		line(field,corners[i],corners[(i+1)%4],0.08,Color("c8d5ba"))
	line(field,Vector3(-g.half_length,0.04,0),Vector3(g.half_length,0.04,0),0.14,Color("ed793f"))
	label3d(field,"飛手安全線",Vector3(0,0.6,-1),Color("f9e7cf"),28)
	last_level = simulator.config.level
	last_signature = ""

func create_drone() -> void:
	drone = Node3D.new()
	add_child(drone)
	box(drone,Vector3(0.8,0.24,0.9),Color("e8e6d8"),Vector3(0,0.4,0))
	box(drone,Vector3(0.5,0.12,0.56),Color("263d43"),Vector3(0,0.59,-0.08))
	box(drone,Vector3(0.6,0.19,0.15),Color("ed793f"),Vector3(0,0.43,0.46))
	for x in [-1,1]:
		for z in [-1,1]:
			line(drone,Vector3(x*0.24,0.43,z*0.26),Vector3(x*1.05,0.43,z*0.92),0.13,Color("263d43"))
			cylinder(drone,0.16,0.22,Color("e97a3e") if z==1 else Color("304b50"),Vector3(x*1.05,0.5,z*0.92))
			var rotor = Node3D.new()
			rotor.position = Vector3(x*1.05,0.65,z*0.92)
			drone.add_child(rotor)
			box(rotor,Vector3(0.95,0.025,0.08),Color("263b40"),Vector3.ZERO)
			box(rotor,Vector3(0.08,0.025,0.95),Color("344c50"),Vector3.ZERO)
			rotors.append(rotor)
	for x in [-0.6,0.6]:
		line(drone,Vector3(x,0.1,-0.525),Vector3(x,0.1,0.525),0.07,Color("263d43"))
		for z in [-0.35,0.35]:
			line(drone,Vector3(x,0.1,z),Vector3(x*0.65,0.4,z),0.045,Color("263d43"))
	var lens = cylinder(drone,0.105,0.16,Color("172b32"),Vector3(0,0.26,0.47))
	lens.rotation.x = PI/2
	var shadow_shape = CylinderMesh.new()
	shadow_shape.top_radius = 1.2
	shadow_shape.bottom_radius = 1.2
	shadow_shape.height = 0.006
	var shadow = mesh(self,shadow_shape,Color("6d7e50"),Data.scene_position(Data.HOME)+Vector3.UP*0.012)
	shadow.name = "DroneShadow"

func clear(node: Node3D) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func rebuild_route() -> void:
	clear(route)
	clear(target)
	if not show_route or simulator.config.mode != "guided":
		return
	var route_steps = simulator.steps
	if route_steps.is_empty() and simulator.module().code not in ["A","G"]:
		route_steps = Data.build_steps(simulator.module().code,simulator.config.level,simulator.config.wind_from)
	var first = maxi(0,simulator.step_index-1)
	for i in range(first,route_steps.size()):
		var item = route_steps[i]
		var a = Data.scene_position(item.get("from",Data.HOME))+Vector3.UP*0.12
		var b = Data.scene_position(item.p)+Vector3.UP*0.12
		line(route,a,b,0.04,Color("ecaa68"),true)
	var item = simulator.current_step()
	if not item.is_empty():
		var p = Data.scene_position(item.p)
		ring(target,p+Vector3.UP*0.06,item.radius,0.065,Color("ff783e"))
		line(target,Vector3(p.x,0.08,p.z),p+Vector3.UP*0.1,0.025,Color("f7b772"),true)
		label3d(target,"目標 %.1f m" % item.p.y,p+Vector3.UP*1.3,Color("fff5db"),23)

func update_view(dt: float) -> void:
	if simulator == null or drone == null:
		return
	if last_level != simulator.config.level:
		rebuild_field()
	var signature = "%s:%d:%d:%s:%s:%s" % [simulator.module().code,simulator.step_index,simulator.steps.size(),simulator.phase,show_route,simulator.config.mode]
	if signature != last_signature:
		last_signature = signature
		rebuild_route()
	var f = simulator.flight
	var p = Data.scene_position(f.p)
	drone.position = p
	drone.rotation = Vector3(f.pitch,-deg_to_rad(f.yaw),-f.roll)
	drone.visible = camera_mode != "fpv"
	for i in range(rotors.size()):
		if f.armed and not simulator.paused and simulator.phase in ["active","declaration","awaitingEnd"]:
			rotors[i].rotation.y += dt*34*(1 if i%2==0 else -1)
	var shadow = get_node("DroneShadow") as MeshInstance3D
	shadow.position = Vector3(p.x,0.012,p.z)
	shadow.scale = Vector3.ONE*maxf(0.28,1-f.p.y/35)
	if windsock != null:
		windsock.rotation.y = PI if simulator.config.wind_from == 90 else 0
		windsock.get_node("Cloth").rotation.z = sin(Time.get_ticks_msec()*0.002)*0.06
	var forward = Vector3(-sin(deg_to_rad(f.yaw)),0,cos(deg_to_rad(f.yaw)))
	var camera_pos: Vector3
	var focus: Vector3
	match camera_mode:
		"follow":
			camera_pos = p-forward*9+Vector3.UP*4
			focus = p+Vector3.UP*0.4
		"fpv":
			camera_pos = p+forward*0.65+Vector3.UP*0.42
			focus = camera_pos+forward*10+Vector3(0,-sin(f.pitch)*10,0)
		"top":
			camera_pos = Vector3(0,Data.LEVELS[simulator.config.level].length*0.78,15)
			focus = Vector3(0,0,15.1)
		_:
			camera_pos = Vector3(0,9.5,-23)
			focus = Vector3(p.x*0.32,maxf(2.2,p.y*0.65),14+p.z*0.18)
	var blend = 1.0 if camera_mode in ["fpv","top"] else minf(1,dt*4)
	camera.position = camera.position.lerp(camera_pos,blend)
	camera.look_at(focus,Vector3.UP)
