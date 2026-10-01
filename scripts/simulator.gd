class_name FlightSimulator
extends RefCounted
## Pure training state and fixed-step flight model; no scene/UI dependencies.

const Data = preload("res://scripts/training_data.gd")
var config: Dictionary
var flight: Dictionary = Data.fresh_flight()
var module_index = 0
var phase = "briefing"
var steps: Array = []
var step_index = 0
var checked = 0
var controls = 0
var elapsed = 0.0
var total_elapsed = 0.0
var stable_for = 0.0
var step_age = 0.0
var faults = 0.0
var max_height_error = 0.0
var deviation_seconds = Data.empty_deviations()
var current_deviations: Array = []
var unstable_for = 0.0
var results: Dictionary = {}
var paused = false
var notice = ""
var rotation = 0.0
var reverse_rotation = 0.0
var cruise_speed = -1.0
var cruise_for = 0.0
var emergency_origin = null
var emergency_at = 35.0
var emergency_side = ""
var started = false
var end_ready = false
var landed = false
var rng = RandomNumberGenerator.new()

func _init(options: Dictionary = Data.DEFAULT_CONFIG) -> void:
	config = options.duplicate(true)
	rng.randomize()

func module() -> Dictionary:
	return Data.MODULES[module_index]

func current_step() -> Dictionary:
	return steps[step_index] if step_index < steps.size() else {}

func primary() -> void:
	if paused:
		return
	match phase:
		"briefing": start_module()
		"declaration": confirm_start()
		"checklist": check_next(checked)
		"active": arm()
		"awaitingEnd": confirm_end()
		"result": next_module()

func start_module() -> void:
	if phase != "briefing":
		return
	if module().code in ["E","F"] and not flight.armed:
		flight.yaw = float(config.wind_from)
	checked = 0
	controls = 0
	elapsed = 0
	stable_for = 0
	step_index = 0
	faults = 0
	max_height_error = 0
	deviation_seconds = Data.empty_deviations()
	current_deviations = []
	unstable_for = 0
	step_age = 0
	notice = ""
	paused = false
	rotation = 0
	reverse_rotation = 0
	cruise_speed = -1
	cruise_for = 0
	emergency_origin = null
	emergency_side = ""
	started = false
	end_ready = false
	landed = false
	steps = Data.build_steps(module().code,config.level,config.wind_from)
	phase = "checklist" if module().code in ["A","G"] else "declaration"
	emergency_at = rng.randf_range(18,53)

func confirm_start() -> void:
	if phase != "declaration" or paused:
		return
	started = true
	if emergency_origin == null:
		emergency_at += elapsed
	phase = "active"
	step_age = 0
	notice = "已口誦 3、2、1、Go。立即原處懸停，再自行判斷進場。" if emergency_origin != null else "已接獲監評指令並口誦 3、2、1、Go。"

func finish(grade: String, reason: String) -> void:
	results[module().code] = {"code":module().code,"grade":grade,"reason":reason,"duration":elapsed,
		"faults":faults,"height_error":max_height_error,"deviation_seconds":deviation_seconds.duplicate(),
		"assessment":"practice-completion","assist":config.assist,"reference":Data.REFERENCE}
	phase = "result"
	paused = false
	if grade != "S" or module().code not in ["C","D","E"]:
		flight.armed = false

func check_next(index: int) -> void:
	if phase != "checklist" or paused or index != checked or module().code not in ["A","G"]:
		return
	if module().code == "A" and index == 10 and controls != 255:
		notice = "請先完成八方向搖桿功能實測。"
		return
	checked += 1
	notice = ""
	if checked == Data.checklist(module().code).size():
		phase = "awaitingEnd"
		end_ready = true

func confirm_end() -> void:
	if phase != "awaitingEnd" or paused or not end_ready:
		return
	if module().code in ["C","D","E"] and not evaluate(flight,steps.back()).stable:
		notice = "請在 H 約 1–2 m 朝外穩定懸停，再口誦結束。"
		return
	finish("S","已完成練習步驟及口誦確認；一般偏差列為改善建議，S 表示練習完成。")

func choose(index: int) -> void:
	if config.mode != "guided" or index < 0 or index >= 7 or phase not in ["briefing","result","complete"]:
		return
	module_index = index
	phase = "briefing"
	steps = []
	step_index = 0
	checked = 0
	flight = Data.fresh_flight()
	elapsed = 0
	paused = false
	notice = ""

func next_module() -> void:
	if phase != "result":
		return
	if module_index == 6:
		phase = "complete"
		return
	if results[module().code].grade != "S":
		flight = Data.fresh_flight()
	module_index += 1
	phase = "briefing"
	steps = []
	step_index = 0
	checked = 0
	elapsed = 0
	notice = ""

func skip() -> void:
	if config.mode == "guided" and phase in ["briefing","declaration","checklist","active","awaitingEnd"]:
		finish("N","本次科目略過。")

func repeat() -> void:
	if config.mode != "guided" or phase != "result":
		return
	results.erase(module().code)
	flight = Data.fresh_flight()
	phase = "briefing"
	start_module()

func arm() -> void:
	if phase != "active" or paused or flight.armed or not started or landed:
		return
	flight.armed = true
	flight.p.y = 0.12
	flight.v.y = 1.0

static func nearest_circle(p: Vector3, level: String) -> Dictionary:
	var g = Data.geometry(level)
	var side = "left" if Data.distance(p,g.left) <= Data.distance(p,g.right) else "right"
	return {"side":side,"center":g[side],"radius":g.inner_radius}

func trigger_emergency() -> void:
	if paused or module().code != "F" or emergency_origin != null or phase != "active" or not flight.armed or flight.p.y < 1:
		return
	emergency_origin = flight.p
	var near = nearest_circle(flight.p,config.level)
	emergency_side = near.side
	var emergency_step = Data.step("緊急返航：立即原處懸停",flight.p,"emergency",flight.yaw)
	var approach = Data.step("手動穩定進場至%s側內圈約 1–2 m" % ("左" if near.side == "left" else "右"),near.center+Vector3.UP*1.5)
	approach.merge({"approach":true,"radius":0.8},true)
	var landing_step = Data.step("精準降落近側內圈，不得壓線或撞角錐",near.center,"land")
	landing_step.merge({"radius":near.radius,"landing":near.side},true)
	steps = Data.link_steps([emergency_step,approach,Data.hold("內圈上方穩定下降率",near.center+Vector3.UP*1.5,null,0),landing_step])
	step_index = 0
	step_age = 0
	stable_for = 0
	phase = "declaration"
	started = false
	notice = "監評：緊急返航！立即原處懸停，口誦「3、2、1、Go」後確認。"

static func advance(f: Dictionary, input: Dictionary, options: Dictionary, dt: float, time: float) -> void:
	if not f.armed or dt <= 0:
		return
	f.impact = false
	var position_mode = options.assist == "position"
	var wind = 0.0 if position_mode else (0.35 if options.mode == "guided" else 0.9)
	var rad = deg_to_rad(f.yaw)
	var ax = (input.right*cos(rad)+input.forward*sin(rad))*5.0
	var az = (input.forward*cos(rad)-input.right*sin(rad))*5.0
	var neutral = absf(input.forward) < 0.01 and absf(input.right) < 0.01
	var damping = (4.5 if neutral else 2.2) if position_mode else 0.7
	f.v.x += (ax+(sin(time*0.43)*0.15+(1 if options.wind_from == 270 else -1))*wind-f.v.x*damping)*dt
	f.v.z += (az+cos(time*0.31)*wind*0.15-f.v.z*damping)*dt
	var vertical = input.throttle*2.0
	if input.throttle < 0 and f.p.y < Data.LIMITS.descent_height:
		vertical = maxf(vertical,-Data.LIMITS.descent_speed)
	f.v.y += (vertical-f.v.y)*minf(1,dt*4)
	f.yaw = fposmod(f.yaw+input.yaw*65*dt,360)
	f.p += f.v*dt
	f.pitch = lerpf(f.pitch,input.forward*0.18,minf(1,dt*5))
	f.roll = lerpf(f.roll,-input.right*0.18,minf(1,dt*5))
	f.battery = maxf(0,f.battery-dt*0.035)
	if f.p.y <= 0:
		f.impact = f.v.y < -Data.LIMITS.hard_landing
		f.p.y = 0
		f.v = Vector3.ZERO
		f.armed = false

static func footprint_inside(f: Dictionary, center: Vector3, radius: float) -> bool:
	var a = deg_to_rad(f.yaw)
	for sx in [-1,1]:
		for sz in [-1,1]:
			var x = sx*Data.LIMITS.gear_width
			var z = sz*Data.LIMITS.gear_length
			var point = f.p+Vector3(x*cos(a)+z*sin(a),0,z*cos(a)-x*sin(a))
			if Data.distance(point,center) >= radius-Data.LIMITS.line_width/2.0:
				return false
	return true

static func height_ok(y: float, target: float) -> bool:
	return y >= 1 and y <= 2 if is_equal_approx(target,1.5) else absf(y-target) <= Data.LIMITS.high_altitude

static func evaluate(f: Dictionary, item: Dictionary) -> Dictionary:
	var distance = Data.distance(f.p,item.p)
	var speed = Vector2(f.v.x,f.v.z).length()
	var heading_ok = not item.has("yaw") or absf(Data.angle(f.yaw,item.yaw)) <= Data.LIMITS.heading
	var airborne = f.armed and f.p.y > 0.5
	var in_position = distance <= item.radius
	var altitude_ok = absf(f.p.y-item.p.y) <= Data.LIMITS.slope_height if item.has("flight_path") else height_ok(f.p.y,item.p.y)
	var heading = deg_to_rad(item.get("yaw",f.yaw))
	var forward_speed = f.v.x*sin(heading)+f.v.z*cos(heading)
	var slope_ok = not item.has("flight_path") or (forward_speed >= Data.LIMITS.min_cruise and (f.v.y > 0.03 if item.flight_path == "climb" else f.v.y < -0.03))
	var track_yaw = fposmod(rad_to_deg(atan2(f.v.x,f.v.z)),360)
	var motion_ok = not item.has("yaw") or absf(Data.angle(track_yaw,item.get("yaw",0)+(180 if item.get("backwards",false) else 0))) <= Data.LIMITS.track_heading
	var direction_ok = item.get("continuous",false) or speed < 0.15 or motion_ok
	var stable = airborne and in_position and altitude_ok and heading_ok and speed < Data.LIMITS.hover_speed and absf(f.v.y) < Data.LIMITS.vertical_speed
	var complete = false
	if item.kind == "land":
		complete = not f.armed and f.p.y == 0 and heading_ok and footprint_inside(f,item.p,item.radius)
	elif item.kind == "reach":
		complete = airborne and in_position and altitude_ok and heading_ok and direction_ok and slope_ok
	return {"distance":distance,"stable":stable,"complete":complete,"height_error":absf(f.p.y-item.p.y),
		"height_ok":altitude_ok,"heading_ok":heading_ok,"direction_ok":direction_ok,"slope_ok":slope_ok}

static func projection(p: Vector3, a: Vector3, b: Vector3) -> float:
	var line = Vector2(b.x-a.x,b.z-a.z)
	return 0.0 if line.length_squared() == 0 else clampf(Vector2(p.x-a.x,p.z-a.z).dot(line)/line.length_squared(),0,1)

static func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	return Data.distance(p,a.lerp(b,projection(p,a,b)))

static func deviations(f: Dictionary, item: Dictionary) -> Array:
	var e = evaluate(f,item)
	var prior: Vector3 = item.get("from",Data.HOME)
	var speed = Vector2(f.v.x,f.v.z).length()
	var bad = {}
	if item.kind == "land":
		bad = {"position":not footprint_inside(f,item.p,item.radius),"descent":absf(f.v.y)>Data.LIMITS.safe_landing,"heading":not e.heading_ok}
	elif item.kind in ["hold","emergency","rotate"]:
		bad = {"position":e.distance>item.radius,"height":not e.height_ok,"heading":item.kind!="rotate" and not e.heading_ok,
			"speed":speed>=Data.LIMITS.hover_speed,"descent":absf(f.v.y)>=Data.LIMITS.vertical_speed}
	elif item.get("approach",false):
		bad = {"height":f.p.y>prior.y+2 or f.p.y<1,"approach":f.p.y>2 and -f.v.y>maxf(0.3,speed*Data.LIMITS.glide_slope),"speed":speed>Data.LIMITS.max_cruise}
	else:
		var expected = lerpf(prior.y,item.p.y,projection(f.p,prior,item.p))
		bad["height"] = absf(f.p.y-expected)>Data.LIMITS.slope_height if item.has("flight_path") else not height_ok(f.p.y,expected)
		bad["position"] = absf(Data.distance(f.p,item.arc.center)-item.arc.radius)>item.arc.radius*0.4+Data.LIMITS.aircraft_radius if item.has("arc") else segment_distance(f.p,prior,item.p)>Data.LIMITS.route_radius
		bad["heading"] = not e.heading_ok
		if item.get("continuous",false):
			bad["speed"] = speed < Data.LIMITS.min_cruise or speed > Data.LIMITS.max_cruise
			var track_yaw = fposmod(rad_to_deg(atan2(f.v.x,f.v.z)),360)
			bad["direction"] = speed >= Data.LIMITS.min_cruise and absf(Data.angle(f.yaw,track_yaw))>Data.LIMITS.track_heading
		else:
			bad["direction"] = not e.direction_ok
		if item.has("flight_path"):
			bad["direction"] = bad.get("direction",false) or not e.slope_ok
	var reasons = []
	for key in bad:
		if bad[key]:
			reasons.append(key)
	return reasons

func record(reasons: Array, dt: float, count: bool) -> void:
	current_deviations = []
	for key in reasons:
		if key not in current_deviations:
			current_deviations.append(key)
	if count and not current_deviations.is_empty():
		faults += dt
		for key in current_deviations:
			deviation_seconds[key] += dt

func update_hold(item: Dictionary, stable: bool, dt: float) -> void:
	if stable:
		stable_for += dt
		unstable_for = 0
		return
	unstable_for += dt
	var minor = Data.distance(flight.p,item.p)<=item.radius+0.5 and absf(flight.p.y-item.p.y)<=0.75 and (not item.has("yaw") or absf(Data.angle(flight.yaw,item.yaw))<=55) and Vector2(flight.v.x,flight.v.z).length()<1.8 and absf(flight.v.y)<1
	if not minor or unstable_for > Data.LIMITS.hold_correction:
		stable_for = 0

func tick(input: Dictionary, dt: float) -> void:
	if paused or phase not in ["active","declaration","checklist","awaitingEnd"] or dt <= 0:
		return
	if dt > 0.05:
		var remaining = dt
		while remaining > 0.00000001:
			tick(input,minf(0.05,remaining))
			remaining -= 0.05
		return
	elapsed += dt
	total_elapsed += dt
	var code = module().code
	if total_elapsed >= 1800:
		finish("U","超過 30 分鐘模擬訓練上限。")
		return
	if phase == "checklist":
		if code == "A" and checked == 10:
			for i in range(8):
				var control = Data.CONTROL_CHECKS[i]
				if input[control.axis]*control.sign > 0.7:
					controls |= 1 << i
		return
	if code in ["A","G"] and phase == "awaitingEnd":
		return
	if phase == "declaration" and emergency_origin == null:
		return
	var before = flight.duplicate(true)
	advance(flight,input,config,dt,total_elapsed)
	var f = flight
	var g = Data.geometry(config.level)
	var item = current_step()
	if f.impact:
		finish("U","下降速度過大，造成撞擊性落地。")
		return
	if f.p.z < 0:
		finish("U","重大違失：飛越應考人後方。")
		return
	if absf(f.p.x)>g.half_length+10 or f.p.z>Data.HOME.z+g.depth+15 or f.p.y>35:
		finish("U","超出模擬安全空域。")
		return
	if f.battery <= 0:
		finish("U","電池耗盡，訓練中止。")
		return
	if f.p.y < Data.LIMITS.cone_height:
		for p in g.points.values():
			if segment_distance(p,before.p,f.p)<Data.LIMITS.aircraft_radius+Data.LIMITS.cone_radius:
				finish("U","重大違失：撞擊角錐。")
				return
	if before.armed and not f.armed:
		landed = true
		if item.is_empty() or item.kind != "land" or not evaluate(f,item).complete:
			finish("U","未依程序降落，或起落架超出落區／壓到標線。")
			return
		if absf(before.v.y)>Data.LIMITS.safe_landing or Vector2(before.v.x,before.v.z).length()>Data.LIMITS.hover_speed:
			finish("U","降落不穩定：下降率或水平速度超過模擬容差。")
			return
	if phase == "declaration":
		step_age += dt
		if emergency_origin != null and (Data.distance(f.p,emergency_origin)>Data.LIMITS.emergency_horizontal or absf(f.p.y-emergency_origin.y)>Data.LIMITS.emergency_vertical):
			finish("U","接獲緊急返航後未立即原處懸停。")
		elif step_age > Data.LIMITS.emergency_response:
			finish("U","緊急口令未在 30 秒內確認。")
		return
	if phase == "awaitingEnd":
		if code in ["C","D","E"]:
			end_ready = evaluate(f,steps.back()).stable
			record(deviations(f,steps.back()),dt,true)
		return
	if item.is_empty():
		return
	step_age += dt
	if code == "F" and emergency_origin == null and f.armed and f.p.y>=1 and elapsed>=emergency_at:
		trigger_emergency()
		return
	var e = evaluate(f,item)
	if f.armed and not item.get("approach",false) and item.kind != "land" and (item.get("continuous",false) or step_age>Data.LIMITS.recovery):
		max_height_error = maxf(max_height_error,e.height_error)
	var yaw_delta = Data.angle(f.yaw,before.yaw)
	if item.kind == "rotate" and item.get("clockwise",false):
		rotation += yaw_delta
		reverse_rotation += maxf(0,-yaw_delta)
		if reverse_rotation > Data.LIMITS.reverse_correction:
			finish("U","四面停懸未依規定順時針旋轉。")
			return
	var speed = Vector2(f.v.x,f.v.z).length()
	if item.get("continuous",false) and speed >= 0.5:
		if cruise_for < 2:
			cruise_speed = speed if cruise_speed<0 else (cruise_speed*cruise_for+speed*dt)/(cruise_for+dt)
		cruise_for += dt
	if not item.get("continuous",false):
		cruise_speed = -1
		cruise_for = 0
	var reasons = deviations(f,item)
	if item.get("continuous",false):
		if cruise_for>=2 and cruise_speed>=0 and absf(speed-cruise_speed)>Data.LIMITS.cruise_variation:
			reasons.append("speed")
		if maxf(absf(f.roll-before.roll),absf(f.pitch-before.pitch))/dt>Data.LIMITS.attitude_rate:
			reasons.append("attitude")
	record(reasons,dt,f.armed and (item.get("continuous",false) or step_age>Data.LIMITS.recovery))
	if item.kind in ["hold","emergency"]:
		update_hold(item,e.stable,dt)
	var rotate_done = item.kind == "rotate" and e.stable and (not item.get("clockwise",false) or rotation>=90-Data.LIMITS.heading)
	var hold_done = item.kind in ["hold","emergency"] and e.stable and stable_for>=item.seconds
	if e.complete or rotate_done or hold_done:
		if code == "F" and emergency_origin == null and step_index == steps.size()-1:
			trigger_emergency()
			return
		step_index += 1
		stable_for = 0
		unstable_for = 0
		current_deviations = []
		step_age = 0
		rotation = 0
		reverse_rotation = 0
		if step_index >= steps.size():
			phase = "awaitingEnd"
			end_ready = true

func passed() -> bool:
	for item in Data.MODULES:
		if not results.has(item.code) or results[item.code].grade != "S":
			return false
	return true

func instruction() -> String:
	match phase:
		"briefing": return module().description
		"declaration": return "監評：緊急返航！立即原處懸停，口誦「3、2、1、Go」後確認。" if emergency_origin != null else "接獲監評指令，請口誦「3、2、1、Go」後確認。"
		"checklist": return "依自備表及指定順序檢查，完成後按確認。"
		"awaitingEnd": return "保持 H 上方約 1–2 m 朝外懸停，口誦「結束」後確認。" if module().code in ["C","D","E"] else "請口誦「結束」後確認。"
		"result": return results[module().code].reason
		"complete": return "七科練習完成，可匯出本次訓練紀錄。" if passed() else "本次訓練結束，請查看科目紀錄與待改善項目。"
	var item = current_step()
	if item.is_empty():
		return ""
	if not flight.armed and item.kind != "land":
		return "按 Space 啟動馬達，再同時前進與爬升（↑＋W）。" if item.get("flight_path","") == "climb" else "按 Space 啟動馬達，W 緩緩爬升至 1–2 m。"
	if item.has("flight_path"):
		return item.title + (" · 同時使用 ↑＋W" if item.flight_path == "climb" else " · 同時使用 ↑＋S")
	if item.kind == "land":
		return item.title+" · S 緩降，觸地下降率需低於 1 m/s。"
	return item.title

func correction_hint() -> String:
	var item = current_step()
	if item.is_empty():
		return ""
	if item.has("flight_path") and not current_deviations.is_empty():
		return "同時前進與%s，目標航點高度 %.1f m。" % ["上升（↑＋W）" if item.flight_path == "climb" else "下降（↑＋S）",item.p.y]
	if "height" in current_deviations:
		return "W／S 調整高度：目前 %.1f m → 目標 %.1f m。" % [flight.p.y,item.p.y]
	if "heading" in current_deviations:
		return "Q／E 調整機頭：目前 %03d° → 目標 %03d°。" % [flight.yaw,item.get("yaw",0)]
	if "position" in current_deviations:
		return "修正位置：距離目標 %.1f m，沿引導航線靠近。" % Data.distance(flight.p,item.p)
	if "descent" in current_deviations:
		return "放開 W／S 並稍候穩定，減少升降速度。"
	if "direction" in current_deviations:
		return "維持機頭朝向，使用後退鍵。" if item.get("backwards",false) else "調整機頭，使飛行方向與航向一致。"
	if "speed" in current_deviations:
		return "放開方向鍵減速；按住 Shift 可慢速微調。"
	if "approach" in current_deviations:
		return "延長進場距離，配合前進放緩下降。"
	return ""

func export_data() -> Dictionary:
	var serial_results = results.duplicate(true)
	return {"schema_version":1,"application":"AEROFIELD Godot","engine":Engine.get_version_info().string,
		"exported_at":Time.get_datetime_string_from_system(),"reference":Data.REFERENCE,
		"assessment":"practice-completion","config":config.duplicate(),"simulation_limits":Data.LIMITS.duplicate(),
		"practice_rules":{"deviation_policy":"feedback-only","hold_correction_seconds":4,"result_meaning":"practice-completion"},
		"total_duration":total_elapsed,"passed":passed(),"results":serial_results}

static func format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]
