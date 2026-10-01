extends Control
const Data = preload("res://scripts/training_data.gd")
const Sim = preload("res://scripts/simulator.gd")
const Controls = preload("res://scripts/flight_controls.gd")
const World = preload("res://scripts/field_world.gd")
const Minimap = preload("res://scripts/minimap.gd")
const Stick = preload("res://scripts/virtual_stick.gd")
const Audio = preload("res://scripts/training_audio.gd")
const INK = Color("263b40")
const MUTED = Color("748681")
const ORANGE = Color("ea773d")
const NAVY = Color("233b42")
var sim = Sim.new()
var controls = Controls.new()
var world: FieldWorld
var audio: TrainingAudio
var map: FieldMinimap
var header: HBoxContainer
var sidebar: PanelContainer
var footer: PanelContainer
var field_view: SubViewport
var main_margin: MarginContainer
var field_card: PanelContainer
var mode_option: OptionButton
var level_option: OptionButton
var assist_option: OptionButton
var wind_option: OptionButton
var module_buttons: Array[Button] = []
var title: Label
var english: Label
var prompt: Label
var detail: Label
var hint: Label
var progress_label: Label
var control_status: Label
var time_label: Label
var stats: Array[Label] = []
var module_progress: ProgressBar
var primary_button: Button
var pause_button: Button
var repeat_button: Button
var skip_button: Button
var emergency_button: Button
var camera_buttons: Array[Button] = []
var route_button: CheckButton
var map_button: CheckButton
var paused_overlay: PanelContainer
var paused_label: Label
var field_prompt: Label
var left_stick: VirtualStick
var right_stick: VirtualStick
var results_dialog: AcceptDialog
var results_text: RichTextLabel
var audio_dialog: AcceptDialog
var sound_checks: Array[CheckButton] = []
var sound_status: Label
var export_dialog: FileDialog
var reset_dialog: ConfirmationDialog
var help_dialog: AcceptDialog
var fullscreen_field = false
var previous_window_mode = DisplayServer.WINDOW_MODE_WINDOWED
var focused = true
var ui_age = 0.0
var last_voice = ""
var last_results = ""
var popup_count = 0
var auto_save_enabled = true

func _ready() -> void:
	name = "Aerofield"
	theme = create_theme()
	build_ui()
	audio = Audio.new()
	add_child(audio)
	Input.joy_connection_changed.connect(_joy_changed)
	resized.connect(_resize_ui)
	_resize_ui()
	refresh_ui()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("AEROFIELD · Godot 無人機飛行訓練")

func create_theme() -> Theme:
	var result = Theme.new()
	var font = FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansTC.ttf")
	font.variation_opentype = {2003265652:480.0} # OpenType 'wght' tag.
	result.default_font = font
	result.default_font_size = 14
	result.set_color("font_color","Label",INK)
	result.set_color("font_color","Button",INK)
	for property in ["font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		result.set_color(property,"Button",INK)
	result.set_color("font_disabled_color","Button",Color("a7b2ae"))
	for type_name in ["CheckButton","OptionButton"]:
		for property in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
			result.set_color(property,type_name,INK)
		result.set_color("font_disabled_color",type_name,Color("9eaca2"))
	result.set_stylebox("normal","Button",style(Color("ffffff"),Color("dce4df"),7,12))
	result.set_stylebox("hover","Button",style(Color("f7efe6"),Color("e4b18e"),7,12))
	result.set_stylebox("pressed","Button",style(Color("f8e5d5"),ORANGE,7,12))
	result.set_stylebox("disabled","Button",style(Color("f0f3ef"),Color("e1e6df"),7,12))
	result.set_stylebox("focus","Button",style(Color(0,0,0,0),ORANGE,7,0))
	result.set_stylebox("panel","PopupMenu",style(Color("ffffff"),Color("dce4df"),8,10))
	result.set_color("font_color","PopupMenu",INK)
	result.set_stylebox("panel","AcceptDialog",style(Color("f6f7f3"),Color("b3c3bb"),10,18))
	result.set_stylebox("panel","Window",style(Color("f6f7f3"),Color("b3c3bb"),10,18))
	return result

func style(background: Color, border: Color = Color(0,0,0,0), radius: int = 10, padding: int = 16) -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(1 if border.a > 0 else 0)
	result.set_corner_radius_all(radius)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result

func label(parent: Node, text: String, font_size: int = 14, color: Color = INK) -> Label:
	var item = Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	parent.add_child(item)
	return item

func button(parent: Node, text: String, action: Callable, accent: bool = false) -> Button:
	var item = Button.new()
	item.text = text
	item.focus_mode = Control.FOCUS_NONE
	item.custom_minimum_size.y = 38
	if accent:
		item.add_theme_stylebox_override("normal",style(ORANGE,ORANGE,7,13))
		item.add_theme_stylebox_override("hover",style(Color("f38a52"),Color("f38a52"),7,13))
		item.add_theme_stylebox_override("pressed",style(Color("d76630"),Color("d76630"),7,13))
		item.add_theme_color_override("font_color",Color.WHITE)
		item.add_theme_color_override("font_hover_color",Color.WHITE)
		item.add_theme_color_override("font_pressed_color",Color.WHITE)
	parent.add_child(item)
	item.pressed.connect(action)
	return item

func option(parent: Node, caption: String, items: Array) -> OptionButton:
	label(parent,caption,12,MUTED)
	var item = OptionButton.new()
	item.custom_minimum_size.y = 36
	item.size_flags_horizontal = SIZE_EXPAND_FILL
	for text in items:
		item.add_item(text)
	item.get_popup().about_to_popup.connect(_popup_opened)
	item.get_popup().popup_hide.connect(_popup_closed)
	parent.add_child(item)
	return item

func check(parent: Node, text: String, action: Callable) -> CheckButton:
	var item = CheckButton.new()
	item.text = text
	item.focus_mode = FOCUS_NONE
	item.toggled.connect(action)
	parent.add_child(item)
	return item

func build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color("f3f5f0")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	main_margin = MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge in ["left","top","right","bottom"]:
		main_margin.add_theme_constant_override("margin_"+edge,20)
	add_child(main_margin)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation",16)
	main_margin.add_child(root)
	header = HBoxContainer.new()
	header.custom_minimum_size.y = 56
	header.add_theme_constant_override("separation",16)
	root.add_child(header)
	var logo = PanelContainer.new()
	logo.add_theme_stylebox_override("panel",style(NAVY,Color(0,0,0,0),10,10))
	header.add_child(logo)
	label(logo," A ",25,ORANGE)
	var brand = VBoxContainer.new()
	brand.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(brand)
	label(brand,"AEROFIELD",25,INK)
	label(brand,"無人機飛行訓練工作站   /   GODOT EDITION",11,MUTED)
	time_label = label(header,"剩餘 30:00",13,MUTED)
	button(header,"訓練紀錄",_show_results)
	button(header,"聲音",_show_audio)
	button(header,"操作說明",_show_help)
	var content = HBoxContainer.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",18)
	root.add_child(content)
	sidebar = PanelContainer.new()
	sidebar.custom_minimum_size.x = 286
	sidebar.add_theme_stylebox_override("panel",style(Color.WHITE,Color("e0e6de"),12,18))
	content.add_child(sidebar)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation",8)
	scroll.add_child(left)
	label(left,"訓練科目",18)
	label(left,"循序練習，建立每次飛行的節奏。",11,MUTED)
	var gap = Control.new()
	gap.custom_minimum_size.y = 6
	left.add_child(gap)
	for i in range(7):
		var item = Data.MODULES[i]
		var b = button(left,"%s   %s" % [item.code,item.title],_choose.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 46
		b.add_theme_font_size_override("font_size",13)
		module_buttons.append(b)
	left.add_child(HSeparator.new())
	label(left,"訓練設定",15)
	mode_option = option(left,"練習方式",["導引練習","獨立練習 · 依序七科"])
	level_option = option(left,"考場級別",["I 級  ·  80 × 20 m","II 級  ·  120 × 30 m","III 級  ·  160 × 40 m"])
	assist_option = option(left,"飛行模式",["定位模式 · 自動煞停","姿態模式 · 保留風漂"])
	wind_option = option(left,"來風方向",["左側來風 · 270°","右側來風 · 90°"])
	mode_option.item_selected.connect(_setting_changed)
	level_option.item_selected.connect(_setting_changed)
	assist_option.item_selected.connect(_setting_changed)
	wind_option.item_selected.connect(_setting_changed)
	button(left,"開始新訓練",_request_reset)
	var disclaimer = label(left,"S 表示練習完成。\n容差為模擬設定，成績供練習參考。",11,MUTED)
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var right = VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",12)
	content.add_child(right)
	field_card = PanelContainer.new()
	field_card.size_flags_vertical = SIZE_EXPAND_FILL
	field_card.add_theme_stylebox_override("panel",style(Color("d2e1d7"),Color("d4ded6"),12,0))
	right.add_child(field_card)
	var layer = Control.new()
	layer.custom_minimum_size = Vector2(560,310)
	field_card.add_child(layer)
	var viewport_container = SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	viewport_container.mouse_filter = MOUSE_FILTER_IGNORE
	layer.add_child(viewport_container)
	field_view = SubViewport.new()
	field_view.size = Vector2i(1000,540)
	field_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	field_view.msaa_3d = Viewport.MSAA_2X
	viewport_container.add_child(field_view)
	world = World.new()
	world.simulator = sim
	field_view.add_child(world)
	var overlay = MarginContainer.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge in ["left","top","right","bottom"]:
		overlay.add_theme_constant_override("margin_"+edge,14)
	overlay.mouse_filter = MOUSE_FILTER_PASS
	layer.add_child(overlay)
	var overlay_column = VBoxContainer.new()
	overlay_column.mouse_filter = MOUSE_FILTER_PASS
	overlay_column.add_theme_constant_override("separation",10)
	overlay.add_child(overlay_column)
	var scene_top = HBoxContainer.new()
	scene_top.add_theme_constant_override("separation",8)
	overlay_column.add_child(scene_top)
	var pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel",style(NAVY,Color(0,0,0,0),6,8))
	scene_top.add_child(pill)
	label(pill,"LIVE  /  即時考場",11,Color("f1f4e9"))
	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	scene_top.add_child(spacer)
	for entry in [["目視","observer"],["跟隨","follow"],["FPV","fpv"],["俯視","top"]]:
		var b = button(scene_top,entry[0],_camera.bind(entry[1]))
		b.custom_minimum_size.y = 32
		b.add_theme_font_size_override("font_size",12)
		camera_buttons.append(b)
	button(scene_top,"全螢幕",_toggle_field)
	var middle = HBoxContainer.new()
	middle.size_flags_vertical = SIZE_EXPAND_FILL
	middle.mouse_filter = MOUSE_FILTER_IGNORE
	overlay_column.add_child(middle)
	var empty = Control.new()
	empty.mouse_filter = MOUSE_FILTER_IGNORE
	empty.size_flags_horizontal = SIZE_EXPAND_FILL
	middle.add_child(empty)
	map = Minimap.new()
	map.simulator = sim
	map.size_flags_vertical = SIZE_SHRINK_BEGIN
	middle.add_child(map)
	var sticks_row = HBoxContainer.new()
	sticks_row.mouse_filter = MOUSE_FILTER_IGNORE
	overlay_column.add_child(sticks_row)
	left_stick = Stick.new()
	left_stick.caption = "高度 / 轉向"
	left_stick.visible = false
	left_stick.moved.connect(func(value): controls.left_stick = value)
	sticks_row.add_child(left_stick)
	var stick_spacer = Control.new()
	stick_spacer.mouse_filter = MOUSE_FILTER_IGNORE
	stick_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	sticks_row.add_child(stick_spacer)
	right_stick = Stick.new()
	right_stick.caption = "前後 / 平移"
	right_stick.visible = false
	right_stick.moved.connect(func(value): controls.right_stick = value)
	sticks_row.add_child(right_stick)
	field_prompt = label(overlay_column,"",14,Color("fff7e6"))
	field_prompt.visible = false
	field_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var telemetry = PanelContainer.new()
	telemetry.add_theme_stylebox_override("panel",style(Color(0.09,0.18,0.2,0.94),Color(1,1,1,0.1),8,12))
	overlay_column.add_child(telemetry)
	var telem_row = HBoxContainer.new()
	telem_row.add_theme_constant_override("separation",15)
	telemetry.add_child(telem_row)
	for caption in ["高度  m","水平速度  m/s","航向  °","電量  %","訓練時間"]:
		var cell = VBoxContainer.new()
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
		telem_row.add_child(cell)
		label(cell,caption,10,Color("a9c1b7"))
		stats.append(label(cell,"0.0",23,Color("f3f6e8")))
	pause_button = button(telem_row,"暫停  P",_toggle_pause)
	paused_overlay = PanelContainer.new()
	paused_overlay.set_anchors_and_offsets_preset(PRESET_CENTER)
	paused_overlay.position = Vector2(-140,-55)
	paused_overlay.custom_minimum_size = Vector2(280,110)
	paused_overlay.add_theme_stylebox_override("panel",style(Color(0.09,0.17,0.19,0.95),Color("ed793f"),12,20))
	paused_overlay.visible = false
	layer.add_child(paused_overlay)
	var paused_column = VBoxContainer.new()
	paused_overlay.add_child(paused_column)
	paused_label = label(paused_column,"訓練已暫停",20,Color.WHITE)
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(paused_column,"放開按鍵後，按 P 或繼續按鈕",11,Color("bbcfc2"))
	button(paused_column,"繼續訓練",_toggle_pause,true)
	footer = PanelContainer.new()
	footer.add_theme_stylebox_override("panel",style(Color.WHITE,Color("e0e6de"),12,18))
	right.add_child(footer)
	var footer_col = VBoxContainer.new()
	footer_col.add_theme_constant_override("separation",7)
	footer.add_child(footer_col)
	var heading = HBoxContainer.new()
	footer_col.add_child(heading)
	title = label(heading,"",20)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	english = label(heading,"",10,MUTED)
	prompt = label(footer_col,"",15,INK)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail = label(footer_col,"",12,MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint = label(footer_col,"",12,Color("be6233"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var progress_row = HBoxContainer.new()
	footer_col.add_child(progress_row)
	progress_label = label(progress_row,"",11,MUTED)
	module_progress = ProgressBar.new()
	module_progress.size_flags_horizontal = SIZE_EXPAND_FILL
	module_progress.custom_minimum_size.y = 7
	module_progress.show_percentage = false
	module_progress.add_theme_stylebox_override("background",style(Color("eef2e9"),Color(0,0,0,0),3,0))
	module_progress.add_theme_stylebox_override("fill",style(ORANGE,Color(0,0,0,0),3,0))
	progress_row.add_child(module_progress)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	footer_col.add_child(actions)
	primary_button = button(actions,"開始科目  Enter",_primary,true)
	emergency_button = button(actions,"緊急返航  R",_emergency)
	repeat_button = button(actions,"重練",_repeat)
	skip_button = button(actions,"略過",_skip)
	var action_spacer = Control.new()
	action_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	route_button = check(actions,"航線",_route_changed)
	route_button.button_pressed = true
	map_button = check(actions,"俯視圖",func(value): map.visible = value)
	map_button.button_pressed = true
	check(actions,"搖桿",_sticks_changed)
	control_status = label(right,"鍵盤可用 · ↑↓←→ 移動  /  W S 高度  /  Q E 轉向  /  Shift 微調",11,MUTED)
	build_dialogs()

func build_dialogs() -> void:
	results_dialog = AcceptDialog.new()
	results_dialog.title = "AEROFIELD · 訓練紀錄"
	results_dialog.min_size = Vector2i(740,480)
	add_child(results_dialog)
	var col = VBoxContainer.new()
	results_dialog.add_child(col)
	results_text = RichTextLabel.new()
	results_text.bbcode_enabled = true
	results_text.custom_minimum_size = Vector2(700,360)
	results_text.size_flags_vertical = SIZE_EXPAND_FILL
	results_text.add_theme_color_override("default_color",INK)
	col.add_child(results_text)
	button(col,"匯出 JSON 訓練紀錄",_export)
	watch_dialog(results_dialog)
	audio_dialog = AcceptDialog.new()
	audio_dialog.title = "聲音設定"
	audio_dialog.min_size = Vector2i(460,300)
	add_child(audio_dialog)
	var sound_col = VBoxContainer.new()
	sound_col.add_theme_constant_override("separation",12)
	audio_dialog.add_child(sound_col)
	sound_checks.append(check(sound_col,"中文語音提示",_voice_toggled))
	sound_checks.append(check(sound_col,"飛行與操作音效",func(value): audio.effects_enabled = value; audio.beep()))
	sound_checks.append(check(sound_col,"背景音樂",func(value): audio.music_enabled = value))
	sound_status = label(sound_col,"",12,MUTED)
	button(sound_col,"全部關閉",_mute)
	watch_dialog(audio_dialog)
	help_dialog = AcceptDialog.new()
	help_dialog.title = "操作說明"
	help_dialog.min_size = Vector2i(670,470)
	add_child(help_dialog)
	var help_text = label(help_dialog,"Enter：開始／口令確認／檢查確認／下一科\nSpace：啟動馬達　　P：暫停／繼續　　Esc：退出考場全螢幕\nW／S：上升／下降　　Q／E（A／D）：機頭左轉／右轉\n↑／↓：依機頭方向前進／後退　　←／→：左右平移\nShift（按住）：35% 慢速微調　　R：F 科緊急口令／口誦確認\n\n標準手把：左搖桿高度與轉向，右搖桿移動。\nA／×：確認　X／□：緊急口令　Start：暫停　LB／L1：微調\n重新連接、返回視窗或關閉對話框後，先放開按鍵並置中。\n\n左觸控搖桿控制高度與轉向，右搖桿控制移動。\n開始與結束皆需自行口誦後確認；緊急返航需手動操作。\n\n獨立練習：依序七科、鎖定目視視角、停用引導與跳科。\nS：練習完成　U：中止　N：略過；不代表正式鑑評成績。\n所有數字容差沿用原專案模擬設定。\n訓練結果自動保存在本機，也可匯出 JSON。",14)
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.custom_minimum_size = Vector2(620,390)
	watch_dialog(help_dialog)
	export_dialog = FileDialog.new()
	export_dialog.title = "儲存訓練紀錄"
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.filters = PackedStringArray(["*.json ; JSON 訓練紀錄"])
	export_dialog.min_size = Vector2i(800,500)
	export_dialog.file_selected.connect(_save_export)
	add_child(export_dialog)
	watch_dialog(export_dialog)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "開始新訓練"
	reset_dialog.dialog_text = "目前紀錄已自動存到本機。開始新訓練將重設畫面上的科目與進度。"
	reset_dialog.confirmed.connect(_reset)
	add_child(reset_dialog)
	watch_dialog(reset_dialog)

func watch_dialog(dialog: Window) -> void:
	dialog.about_to_popup.connect(_popup_opened)
	dialog.visibility_changed.connect(_dialog_visibility.bind(dialog))

func _popup_opened() -> void:
	popup_count += 1
	controls.reset()
	if sim.phase in ["active","declaration","checklist","awaitingEnd"]:
		sim.paused = true
	if audio != null:
		audio.stop_voice()

func _popup_closed() -> void:
	popup_count = maxi(0,popup_count-1)
	controls.reset()
	if left_stick != null:
		left_stick.release()
		right_stick.release()
	refresh_ui()

func _physics_process(dt: float) -> void:
	var result = controls.poll(not focused or popup_count>0)
	if result.disconnected and sim.phase in ["active","declaration","checklist","awaitingEnd"]:
		sim.paused = true
	if result.pause:
		_toggle_pause()
	if result.primary:
		_primary()
	if result.emergency:
		_emergency()
	sim.tick(result.input,dt)

func _process(dt: float) -> void:
	world.update_view(dt)
	audio.update_flight(sim)
	ui_age += dt
	if ui_age >= 0.1:
		ui_age = 0
		refresh_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and popup_count == 0 and focused:
		var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if controls.needs_neutral and key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_R]:
			return
		match key:
			KEY_ENTER,KEY_KP_ENTER: _primary(); get_viewport().set_input_as_handled()
			KEY_SPACE: sim.arm(); get_viewport().set_input_as_handled()
			KEY_P: _toggle_pause(); get_viewport().set_input_as_handled()
			KEY_R: _emergency(); get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if fullscreen_field: _toggle_field()
			KEY_F11: _toggle_field()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		controls.reset()
		if sim.phase in ["active","declaration","checklist","awaitingEnd"]:
			sim.paused = true
		if audio != null:
			audio.set_focused(false)
		if left_stick != null:
			left_stick.release()
			right_stick.release()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		controls.reset()
		if audio != null:
			audio.set_focused(true)

func _joy_changed(_device: int, connected: bool) -> void:
	controls.reset()
	if not connected and sim.phase in ["active","declaration","awaitingEnd","checklist"]:
		sim.paused = true

func _primary() -> void:
	if not focused or popup_count>0:
		return
	sim.primary()
	audio.beep()
	refresh_ui()

func _toggle_pause() -> void:
	if popup_count>0 or sim.phase not in ["active","declaration","checklist","awaitingEnd"]:
		return
	sim.paused = not sim.paused
	controls.reset()
	left_stick.release()
	right_stick.release()
	audio.stop_voice()
	audio.speak("訓練已暫停" if sim.paused else "繼續訓練")
	refresh_ui()

func _emergency() -> void:
	if sim.emergency_origin != null and sim.phase == "declaration":
		sim.confirm_start()
	else:
		sim.trigger_emergency()
	audio.beep(440)
	refresh_ui()

func _choose(index: int) -> void:
	sim.choose(index)
	controls.reset()
	refresh_ui()

func _skip() -> void:
	sim.skip()
	refresh_ui()

func _repeat() -> void:
	sim.repeat()
	controls.reset()
	refresh_ui()

func _setting_changed(_index: int) -> void:
	if sim.phase != "briefing" or sim.total_elapsed > 0:
		return
	sim.config = {"mode":"guided" if mode_option.selected==0 else "mock",
		"level":["I","II","III"][level_option.selected],"assist":"position" if assist_option.selected==0 else "attitude",
		"wind_from":270 if wind_option.selected==0 else 90}
	if sim.config.mode == "mock":
		sim.module_index = 0
		world.camera_mode = "observer"
	refresh_ui()

func _camera(mode: String) -> void:
	if sim.config.mode == "guided":
		world.camera_mode = mode
	refresh_ui()

func _route_changed(value: bool) -> void:
	world.show_route = value
	map.show_route = value

func _sticks_changed(value: bool) -> void:
	left_stick.visible = value
	right_stick.visible = value
	left_stick.release()
	right_stick.release()
	controls.reset()

func _toggle_field() -> void:
	if not fullscreen_field and DisplayServer.get_name() != "headless":
		previous_window_mode = DisplayServer.window_get_mode()
	fullscreen_field = not fullscreen_field
	header.visible = not fullscreen_field
	sidebar.visible = not fullscreen_field
	footer.visible = not fullscreen_field
	control_status.visible = not fullscreen_field
	field_prompt.visible = fullscreen_field
	for edge in ["left","top","right","bottom"]:
		main_margin.add_theme_constant_override("margin_"+edge,0 if fullscreen_field else 20)
	field_card.add_theme_stylebox_override("panel",style(Color("d2e1d7"),
		Color(0,0,0,0) if fullscreen_field else Color("d4ded6"),0 if fullscreen_field else 12,0))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_field else previous_window_mode)

func _resize_ui() -> void:
	if sidebar != null:
		sidebar.custom_minimum_size.x = 260 if size.x<1250 else 286
	if english != null:
		english.visible = size.x>=1250
	if map != null:
		map.custom_minimum_size = Vector2(180,144) if size.x<1250 else Vector2(220,172)

func refresh_ui() -> void:
	if title == null:
		return
	var module = sim.module()
	var mock = sim.config.mode == "mock"
	var locked = sim.phase not in ["briefing","result","complete"]
	for i in range(7):
		var code = Data.MODULES[i].code
		var grade = sim.results[code].grade if sim.results.has(code) else ""
		module_buttons[i].text = "%s   %s%s" % [code,Data.MODULES[i].title,"   "+grade if not grade.is_empty() else ""]
		module_buttons[i].disabled = mock or locked
		module_buttons[i].add_theme_stylebox_override("normal",style(Color("fff0e5") if i==sim.module_index else Color.WHITE,ORANGE if i==sim.module_index else Color("e3e9e0"),7,10))
		module_buttons[i].add_theme_stylebox_override("disabled",style(Color("fff0e5") if i==sim.module_index else Color("f6f7f2"),ORANGE if i==sim.module_index else Color("e3e9e0"),7,10))
	title.text = "%s  /  %s" % [module.code,module.title]
	english.text = module.english
	prompt.text = sim.instruction()
	detail.text = ""
	if sim.phase == "checklist":
		var list = Data.checklist(module.code)
		if sim.checked<list.size():
			prompt.text = list[sim.checked].title
			detail.text = list[sim.checked].detail
			if module.code == "A" and sim.checked==10:
				var checks = []
				for i in range(8):
					checks.append(("✓ " if sim.controls&(1<<i) else "○ ")+Data.CONTROL_CHECKS[i].title)
				detail.text = "  ".join(checks)
	hint.text = sim.correction_hint() if sim.phase in ["active","awaitingEnd"] else sim.notice
	hint.visible = not hint.text.is_empty()
	detail.visible = not detail.text.is_empty()
	var count = Data.checklist(module.code).size() if module.code in ["A","G"] else sim.steps.size()
	var done = sim.checked if module.code in ["A","G"] else sim.step_index
	progress_label.text = "步驟 %d / %d" % [mini(done+1,count),count] if count>0 else "準備就緒"
	var item = sim.current_step()
	if not item.is_empty() and item.kind == "hold" and item.seconds>0:
		progress_label.text += "   ·   有效停懸 %.1f / %.0f 秒" % [sim.stable_for,item.seconds]
	module_progress.value = 100.0*done/count if count>0 else 0
	stats[0].text = "%.1f" % sim.flight.p.y
	stats[1].text = "%.1f" % Vector2(sim.flight.v.x,sim.flight.v.z).length()
	stats[2].text = "%03d" % int(sim.flight.yaw)
	stats[3].text = "%d" % int(sim.flight.battery)
	stats[4].text = Sim.format_time(sim.elapsed)
	time_label.text = "剩餘 "+Sim.format_time(maxf(0,1800-sim.total_elapsed))
	var primary_labels = {"briefing":"開始科目  Enter","declaration":"已口誦 · 確認  Enter","checklist":"完成檢查 · 確認  Enter",
		"active":"啟動馬達  Space","awaitingEnd":"已口誦結束 · 確認","result":"下一科  Enter","complete":"訓練已結束"}
	primary_button.text = primary_labels[sim.phase]
	primary_button.disabled = sim.paused or sim.phase == "complete" or (sim.phase=="active" and sim.flight.armed) or (sim.phase=="awaitingEnd" and not sim.end_ready)
	pause_button.text = "繼續  P" if sim.paused else "暫停  P"
	pause_button.disabled = sim.phase not in ["active","declaration","checklist","awaitingEnd"]
	paused_overlay.visible = sim.paused and popup_count == 0
	paused_label.text = "訓練已暫停"
	emergency_button.visible = module.code == "F" and sim.phase in ["active","declaration"]
	emergency_button.text = "口誦確認  R" if sim.emergency_origin != null else "緊急返航  R"
	emergency_button.disabled = sim.paused or (sim.emergency_origin==null and (not sim.flight.armed or sim.flight.p.y<1))
	repeat_button.visible = not mock and sim.phase=="result"
	skip_button.visible = not mock and sim.phase in ["briefing","declaration","active","checklist","awaitingEnd"]
	for setting in [mode_option,level_option,assist_option,wind_option]:
		setting.disabled = sim.phase!="briefing" or sim.total_elapsed>0
	for i in range(camera_buttons.size()):
		camera_buttons[i].disabled = mock
		camera_buttons[i].modulate = Color("fff1df") if world.camera_mode==["observer","follow","fpv","top"][i] else Color.WHITE
	route_button.disabled = mock
	map_button.disabled = mock
	map.visible = map_button.button_pressed and not mock
	world.show_route = route_button.button_pressed and not mock
	map.show_route = world.show_route
	map.queue_redraw()
	control_status.text = controls.status+"   ·   ↑↓←→ 移動  /  W S 高度  /  Q E 轉向  /  Shift 微調"
	field_prompt.text = prompt.text
	var token = "%s:%s:%d:%d:%s" % [module.code,sim.phase,sim.step_index,sim.checked,sim.paused]
	if token != last_voice and audio != null:
		if not sim.paused:
			audio.speak(prompt.text)
			if not last_voice.is_empty(): audio.beep(720 if sim.phase!="result" else 880)
		last_voice = token
	var signature = JSON.stringify(sim.results)
	if auto_save_enabled and signature != last_results and not sim.results.is_empty():
		last_results = signature
		_save_record("user://last_training.json")

func _show_results() -> void:
	var text = "[font_size=22]本次訓練紀錄[/font_size]\n總時間 %s   ·   S 練習完成 / U 中止 / N 略過\n\n" % Sim.format_time(sim.total_elapsed)
	for item in Data.MODULES:
		text += "[b]%s  %s[/b]\n" % [item.code,item.title]
		if sim.results.has(item.code):
			var result = sim.results[item.code]
			text += "%s   ·   %s   ·   需修正 %.1f 秒\n%s\n" % [result.grade,Sim.format_time(result.duration),result.faults,result.reason]
			for key in result.deviation_seconds:
				if result.deviation_seconds[key]>0.05:
					text += "%s %.1f 秒   " % [Data.DEVIATIONS[key],result.deviation_seconds[key]]
			text += "\n\n"
		else:
			text += "尚未完成\n\n"
	text += "紀錄自動儲存於本機 last_training.json；可另匯出保存。"
	results_text.text = text
	results_dialog.popup_centered()

func _show_audio() -> void:
	audio.refresh_voices()
	sound_status.text = audio.voice_status+"\n重新開啟程式時，聲音皆預設關閉。"
	audio_dialog.popup_centered()

func _show_help() -> void:
	help_dialog.popup_centered()

func _mute() -> void:
	audio.mute_all()
	for item in sound_checks:
		item.set_pressed_no_signal(false)

func _export() -> void:
	var filename = "AEROFIELD-"+Time.get_date_string_from_system()+".json"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(JSON.stringify(sim.export_data(),"\t").to_utf8_buffer(),filename,"application/json")
		return
	export_dialog.current_file = filename
	export_dialog.popup_centered()

func _save_record(path: String) -> Error:
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(sim.export_data(),"\t"))
	file.close()
	return OK

func _save_export(path: String) -> void:
	var error = _save_record(path)
	sim.notice = "紀錄已儲存："+path if error==OK else "儲存失敗："+error_string(error)
	refresh_ui()

func _request_reset() -> void:
	reset_dialog.popup_centered()

func _reset() -> void:
	if auto_save_enabled and not sim.results.is_empty():
		_save_record("user://training-"+str(Time.get_unix_time_from_system()).replace(".","-")+".json")
	sim = Sim.new(sim.config)
	world.simulator = sim
	map.simulator = sim
	controls.reset()
	last_results = ""
	mode_option.disabled = false
	level_option.disabled = false
	assist_option.disabled = false
	wind_option.disabled = false
	refresh_ui()

func _voice_toggled(value: bool) -> void:
	audio.voice_enabled = value
	audio.stop_voice()
	if value:
		audio.speak(sim.instruction())

func _dialog_visibility(dialog: Window) -> void:
	if not dialog.visible:
		_popup_closed()
