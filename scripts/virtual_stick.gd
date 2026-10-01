class_name VirtualStick
extends Control
signal moved(value: Vector2)
var value = Vector2.ZERO
var pointer = -2
var caption = ""

func _ready() -> void:
	custom_minimum_size = Vector2(132,150)
	mouse_filter = Control.MOUSE_FILTER_STOP

func release() -> void:
	pointer = -2
	value = Vector2.ZERO
	moved.emit(value)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and pointer == -2:
			pointer = event.index
			move_pointer(event.position)
		elif not event.pressed and event.index == pointer:
			release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == pointer:
		move_pointer(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and pointer == -2:
			pointer = -1
			move_pointer(event.position)
		elif not event.pressed and pointer == -1:
			release()
		accept_event()
	elif event is InputEventMouseMotion and pointer == -1:
		move_pointer(event.position)
		accept_event()

func move_pointer(pos: Vector2) -> void:
	value = ((pos-Vector2(size.x/2,65))/48).limit_length()
	moved.emit(value)
	queue_redraw()

func _draw() -> void:
	var center = Vector2(size.x/2,65)
	draw_circle(center,58,Color(0.08,0.16,0.19,0.72))
	draw_arc(center,48,0,TAU,64,Color(0.8,0.9,0.88,0.4),1.5,true)
	draw_line(center-Vector2(40,0),center+Vector2(40,0),Color(1,1,1,0.15))
	draw_line(center-Vector2(0,40),center+Vector2(0,40),Color(1,1,1,0.15))
	draw_circle(center+value*48,18,Color("ed793f"))
	draw_string(get_theme_default_font(),Vector2(8,140),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x-16,13,Color("e7efeb"))
