class_name FieldMinimap
extends Control
const Data = preload("res://scripts/training_data.gd")
var simulator: FlightSimulator
var show_route = true

func _ready() -> void:
	custom_minimum_size = Vector2(220,172)
	mouse_filter = MOUSE_FILTER_IGNORE

func point(p: Vector3) -> Vector2:
	var g = Data.geometry(simulator.config.level)
	var scale_px = minf((size.x-30)/(g.half_length*2+8),(size.y-44)/(g.depth+12))
	return Vector2(size.x/2+p.x*scale_px,size.y-20-p.z*scale_px)

func _draw() -> void:
	if simulator == null:
		return
	var g = Data.geometry(simulator.config.level)
	draw_style_box(box(),Rect2(Vector2.ZERO,size))
	draw_string(get_theme_default_font(),Vector2(12,21),"考場俯視圖",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("bdd0c8"))
	var scale_px = absf(point(Vector3(1,0,0)).x-point(Vector3.ZERO).x)
	for side in ["left","right"]:
		for radius in [g.inner_radius,g.radius,g.outer_radius]:
			draw_arc(point(g[side]),radius*scale_px,0,TAU,48,Color(0.7,0.85,0.7,0.45),1,true)
	draw_arc(point(Data.HOME),1.5*scale_px,0,TAU,24,Color("e7f1d7"),1.5,true)
	draw_line(point(Vector3(-g.half_length,0,0)),point(Vector3(g.half_length,0,0)),Color("ed793f"),2,true)
	if show_route and simulator.config.mode == "guided":
		var route = simulator.steps
		for i in range(1,route.size()):
			draw_line(point(route[i-1].p),point(route[i].p),Color(1,0.65,0.35,0.6),1.2,true)
		var target = simulator.current_step()
		if not target.is_empty():
			draw_circle(point(target.p),4,Color("ed793f"))
	var pos = point(simulator.flight.p)
	var a = deg_to_rad(simulator.flight.yaw)
	var heading = Vector2(sin(a),-cos(a))
	var right = Vector2(cos(a),sin(a))
	draw_colored_polygon(PackedVector2Array([pos+heading*7,pos-heading*4-right*4,pos-heading*4+right*4]),Color("ffffff"))

func box() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.075,0.15,0.18,0.88)
	style.set_corner_radius_all(8)
	style.border_color = Color(1,1,1,0.14)
	style.set_border_width_all(1)
	return style
