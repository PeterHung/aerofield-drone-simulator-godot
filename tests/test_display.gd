extends SceneTree
## Regression: rendered UI corners must cover every physical window pixel.
var app
var assertions = 0
var failures: Array[String] = []
var screenshot_dir = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			screenshot_dir = arg.trim_prefix("--screenshots=")
	call_deferred("run")

func frames(count: int = 12) -> void:
	for i in range(count):
		await process_frame

func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: "+message)

func expect_coverage(control: Control, caption: String) -> void:
	var rect = control.get_global_rect()
	var transform = root.get_final_transform()
	var first_pixel = transform*rect.position
	var last_pixel = transform*rect.end
	expect(first_pixel.distance_to(Vector2.ZERO)<1.5,caption+" has a top/left border: "+str(first_pixel))
	expect(last_pixel.distance_to(Vector2(root.size))<1.5,caption+" has a bottom/right border: "+str(last_pixel)+" vs "+str(root.size))

func screenshot(filename: String) -> void:
	if screenshot_dir.is_empty() or DisplayServer.get_name()=="headless":
		return
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(screenshot_dir.path_join(filename))
	expect(result==OK,"screenshot "+filename)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.auto_save_enabled = false
	root.add_child(app)
	current_scene = app
	await frames()
	expect(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_EXPAND,"window adapts to the display aspect ratio")
	for resolution in [Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1200),Vector2i(3440,1440),Vector2i(1600,1200),Vector2i(1080,720)]:
		root.size = resolution
		await frames()
		expect_coverage(app,"workstation "+str(resolution))
		if resolution==Vector2i(1920,1080):
			await screenshot("06-wide-workstation.png")
	root.size = Vector2i(1920,1080)
	await frames()
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		await create_timer(0.7).timeout
		await frames()
		var mode_before = DisplayServer.window_get_mode()
		app._toggle_field()
		await create_timer(1.2).timeout
		await frames()
		expect_coverage(app,"native fullscreen window")
		expect_coverage(app.field_card,"native fullscreen field")
		expect(app.stats[0].is_visible_in_tree() and app.pause_button.is_visible_in_tree(),"fullscreen retains flight instruments and pause")
		await screenshot("07-fullscreen-field.png")
		app._toggle_field()
		await create_timer(1.2).timeout
		await frames()
		expect(DisplayServer.window_get_mode()==mode_before,"returning from fullscreen restores maximized mode")
		expect(app.header.visible and app.sidebar.visible and app.footer.visible,"returning from fullscreen restores station panels")
		expect_coverage(app,"restored maximized workstation")
	else:
		app._toggle_field()
		await frames()
		expect_coverage(app.field_card,"fullscreen field")
		expect(app.stats[0].is_visible_in_tree() and app.pause_button.is_visible_in_tree(),"fullscreen retains flight instruments and pause")
		app._toggle_field()
		await frames()
		expect(app.header.visible and app.sidebar.visible and app.footer.visible,"returning from fullscreen restores station panels")
		expect(app.main_margin.get_theme_constant("margin_left")==20,"returning from fullscreen restores station spacing")
	print("DISPLAY RESULT: %d assertions, %d failures" % [assertions,failures.size()])
	app.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
