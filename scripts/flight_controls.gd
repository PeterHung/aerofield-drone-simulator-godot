class_name FlightControls
extends RefCounted
## Every focus/pause/reconnection boundary requires neutral controls.
const Data = preload("res://scripts/training_data.gd")
var needs_neutral = true
var device = -1
var previous_buttons: Dictionary = {}
var left_stick = Vector2.ZERO
var right_stick = Vector2.ZERO
var status = "鍵盤可用 · 可連接遊戲手把"

func reset() -> void:
	needs_neutral = true
	left_stick = Vector2.ZERO
	right_stick = Vector2.ZERO

static func stick_axis(value: float) -> float:
	if not is_finite(value) or absf(value) <= 0.16:
		return 0.0
	return signf(value)*pow((minf(1,absf(value))-0.16)/0.84,1.35)

static func key_axis(positive: Array, negative: Array) -> float:
	var pos = false
	var neg = false
	for key in positive:
		pos = pos or Input.is_physical_key_pressed(key)
	for key in negative:
		neg = neg or Input.is_physical_key_pressed(key)
	return float(pos)-float(neg)

func poll(blocked: bool = false) -> Dictionary:
	var pads = Input.get_connected_joypads()
	var supported = []
	for pad in pads:
		if Input.is_joy_known(pad):
			supported.append(pad)
	var next_device = device if device in supported else (-1 if supported.is_empty() else supported[0])
	var disconnected = device != -1 and next_device != device
	if next_device != device:
		device = next_device
		previous_buttons.clear()
		reset()
	var input = {"forward":key_axis([KEY_UP],[KEY_DOWN]),"right":key_axis([KEY_RIGHT],[KEY_LEFT]),
		"throttle":key_axis([KEY_W],[KEY_S]),"yaw":key_axis([KEY_E,KEY_D],[KEY_Q,KEY_A])}
	var buttons = {}
	var pad_axes = Data.zero_input()
	if device != -1:
		pad_axes = {"yaw":stick_axis(Input.get_joy_axis(device,JOY_AXIS_LEFT_X)),
			"throttle":-stick_axis(Input.get_joy_axis(device,JOY_AXIS_LEFT_Y)),
			"right":stick_axis(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X)),
			"forward":-stick_axis(Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))}
		for button in [JOY_BUTTON_A,JOY_BUTTON_X,JOY_BUTTON_START,JOY_BUTTON_LEFT_SHOULDER]:
			buttons[button] = Input.is_joy_button_pressed(device,button)
	var precision = Input.is_physical_key_pressed(KEY_SHIFT) or buttons.get(JOY_BUTTON_LEFT_SHOULDER,false)
	for key in input:
		var touch = 0.0
		match key:
			"yaw": touch = left_stick.x
			"throttle": touch = -left_stick.y
			"right": touch = right_stick.x
			"forward": touch = -right_stick.y
		input[key] = clampf(input[key]+pad_axes[key]+touch,-1,1)
	var neutral = not precision and not Input.is_physical_key_pressed(KEY_ENTER) and not Input.is_physical_key_pressed(KEY_SPACE) and not Input.is_physical_key_pressed(KEY_P) and not Input.is_physical_key_pressed(KEY_R)
	for value in input.values():
		neutral = neutral and is_zero_approx(value)
	for value in buttons.values():
		neutral = neutral and not value
	if blocked:
		needs_neutral = true
	elif neutral:
		needs_neutral = false
	var enabled = not blocked and not needs_neutral
	var result = {"input":input if enabled else Data.zero_input(),"primary":false,"pause":false,
		"emergency":false,"disconnected":disconnected,"precision":precision and enabled}
	if enabled:
		result.primary = buttons.get(JOY_BUTTON_A,false) and not previous_buttons.get(JOY_BUTTON_A,false)
		result.pause = buttons.get(JOY_BUTTON_START,false) and not previous_buttons.get(JOY_BUTTON_START,false)
		result.emergency = buttons.get(JOY_BUTTON_X,false) and not previous_buttons.get(JOY_BUTTON_X,false)
		if precision:
			for key in result.input:
				result.input[key] *= 0.35
	previous_buttons = buttons
	status = "手把已連接 · "+Input.get_joy_name(device) if device != -1 else ("手把沒有標準映射 · 請用鍵盤" if not pads.is_empty() else "鍵盤可用 · 可連接遊戲手把")
	if needs_neutral:
		status = "請放開按鍵並將搖桿置中"
	return result
