extends SceneTree
## Native scene/input integration; pass -- --screenshots=/absolute/path to render.
var failures: Array[String] = []
var assertions = 0
var app
var screenshot_dir = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			screenshot_dir = arg.trim_prefix("--screenshots=")
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: "+message)

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func key(code: int, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)

func tap(code: int) -> void:
	await key(code,true)
	await key(code,false)

func screenshot(filename: String) -> void:
	if screenshot_dir.is_empty() or DisplayServer.get_name()=="headless":
		return
	await frames(12)
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	expect(image.save_png(screenshot_dir.path_join(filename))==OK,"screenshot "+filename)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.auto_save_enabled = false
	root.add_child(app)
	current_scene = app
	await frames(12)
	app.focused = true
	expect(app.sim.phase=="briefing" and app.module_buttons.size()==7,"seven native modules")
	expect(app.world.drone!=null and app.world.camera!=null,"native 3D scene")
	expect(app.field_view.size.x>400 and app.field_view.size.y>250,"render viewport has area")
	expect(not app.audio.effects_enabled and not app.audio.voice_enabled and not app.audio.music_enabled,"audio defaults off")
	await screenshot("01-workstation.png")
	await tap(KEY_ENTER)
	expect(app.sim.phase=="checklist","Enter begins A inspection")
	for i in range(10): await tap(KEY_ENTER)
	expect(app.sim.checked==10,"ordered keyboard inspection")
	await tap(KEY_ENTER)
	expect(app.sim.checked==10,"control check cannot be bypassed")
	for code in [KEY_UP,KEY_DOWN,KEY_RIGHT,KEY_LEFT,KEY_W,KEY_S,KEY_E,KEY_Q]: await tap(code)
	expect(app.sim.controls==255 and not app.sim.flight.armed,"keyboard controls reach native input state")
	await tap(KEY_ENTER)
	for i in range(6): await tap(KEY_ENTER)
	expect(app.sim.phase=="awaitingEnd","inspection awaits spoken end")
	await tap(KEY_ENTER)
	expect(app.sim.results.A.grade=="S","inspection end confirmation")
	app._show_results()
	await screenshot("05-training-records.png")
	app.results_dialog.hide()
	await frames(3)
	await tap(KEY_ENTER)
	expect(app.sim.module().code=="B" and app.sim.phase=="briefing","next subject via Enter")
	await tap(KEY_ENTER)
	await tap(KEY_SPACE)
	expect(not app.sim.flight.armed,"Space cannot bypass declaration")
	await tap(KEY_ENTER)
	await tap(KEY_SPACE)
	expect(app.sim.flight.armed,"Space arms after oral confirmation")
	await key(KEY_W,true)
	await create_timer(0.9).timeout
	await key(KEY_W,false)
	expect(app.sim.flight.p.y>0.6,"native keyboard climbs")
	await screenshot("02-hover-training.png")
	await tap(KEY_P)
	var before = app.sim.flight.duplicate(true)
	var time = app.sim.elapsed
	await key(KEY_UP,true)
	await create_timer(0.15).timeout
	expect(app.sim.flight==before and app.sim.elapsed==time,"pause blocks movement and timing")
	await key(KEY_UP,false)
	await tap(KEY_P)
	expect(not app.sim.paused,"P resumes")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(app.sim.paused and not app.focused and not app.audio.focused,"focus loss pauses and mutes")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(app.sim.paused and app.focused and app.controls.needs_neutral,"focus return preserves pause and neutral gate")
	await frames(3)
	app.audio.effects_enabled = true
	app.audio.music_enabled = true
	app.audio.voice_enabled = true
	app._mute()
	expect(not app.audio.effects_enabled and not app.audio.music_enabled and not app.audio.voice_enabled,"mute all channels")
	app.audio.effects_enabled = true
	app.audio.beep()
	expect(app.audio.tone.stream is AudioStreamWAV and app.audio.tone.stream.data.size()>1000,"synthesized audio has real samples")
	app.audio.effects_enabled = false
	app._show_help()
	expect(app.popup_count==1 and app.sim.paused,"help dialog blocks flight")
	app.help_dialog.hide()
	await frames(3)
	expect(app.popup_count==0 and app.sim.paused,"closing dialog does not resume automatically")
	app._reset()
	app.sim.config.mode = "mock"
	app.refresh_ui()
	expect(app.camera_buttons[1].disabled and app.route_button.disabled and not app.map.visible,"independent practice locks aids")
	app._camera("fpv")
	expect(app.world.camera_mode=="observer","mock camera locked")
	app.sim.config.mode = "guided"
	app._choose(4)
	app._camera("follow")
	expect(app.world.camera_mode=="follow","guided follow camera")
	app._sticks_changed(true)
	app.left_stick.move_pointer(Vector2(110,30))
	expect(app.controls.left_stick.length()>0.1,"virtual stick produces analog input")
	app.left_stick.release()
	expect(app.controls.left_stick==Vector2.ZERO,"virtual stick releases to neutral")
	app._sticks_changed(false)
	app._camera("observer")
	await screenshot("03-five-leg-course.png")
	app._show_results()
	expect(app.results_dialog.visible and app.results_text.text.contains("本次訓練紀錄"),"native result dialog")
	app.results_dialog.hide()
	await frames(3)
	if not screenshot_dir.is_empty():
		var path = screenshot_dir.path_join("test-export.json")
		expect(app._save_record(path)==OK,"JSON file export")
		var exported = JSON.parse_string(FileAccess.get_file_as_string(path))
		expect(exported.application=="AEROFIELD Godot" and exported.simulation_limits.heading==40,"export contents")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1080,720)
		await frames(8)
		await screenshot("04-compact-window.png")
	print("UI RESULT: %d assertions, %d failures" % [assertions,failures.size()])
	app.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
