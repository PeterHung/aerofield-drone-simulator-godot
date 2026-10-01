extends SceneTree
const Data = preload("res://scripts/training_data.gd")
const Sim = preload("res://scripts/simulator.gd")
const Controls = preload("res://scripts/flight_controls.gd")
var assertions = 0
var cases = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: "+message)

func started(code: String = "B", options: Dictionary = Data.DEFAULT_CONFIG) -> FlightSimulator:
	var sim = Sim.new(options)
	sim.module_index = "ABCDEFG".find(code)
	sim.start_module()
	sim.confirm_start()
	sim.arm()
	return sim

func at(p: Vector3, yaw: float = 0) -> Dictionary:
	var f = Data.fresh_flight()
	f.p = p
	f.yaw = yaw
	f.armed = true
	return f

func hover(sim: FlightSimulator, seconds: float) -> void:
	for i in range(ceili(seconds*120)):
		sim.tick(Data.zero_input(),1.0/120)

## Positive integration cases move solely through flight inputs, without teleports.
func fly(code: String, options: Dictionary, existing = null, automatic: bool = false) -> FlightSimulator:
	var sim: FlightSimulator = started(code,options) if existing==null else existing
	if existing != null:
		sim.start_module()
		sim.confirm_start()
		sim.arm()
	sim.emergency_at = (18.0 if options.wind_from==90 else 42.0) if automatic else 10000.0
	for frame in range(120*900):
		if sim.phase not in ["active","declaration"]:
			break
		if sim.phase == "declaration":
			sim.confirm_start()
			continue
		if code == "F" and not automatic and sim.emergency_origin==null and absf(sim.flight.p.x)>25:
			sim.trigger_emergency()
			continue
		var item = sim.current_step()
		var f = sim.flight
		var rad = deg_to_rad(f.yaw)
		var desired = item.get("yaw",f.yaw)
		var delta = Data.angle(desired,f.yaw)
		var distance = Data.distance(item.p,f.p)
		var height = (-0.1 if distance<0.3 else 1.5) if item.kind=="land" else item.p.y
		var wx = clampf((item.p.x-f.p.x)*0.9-f.v.x*0.4,-0.85,0.85)
		var wz = clampf((item.p.z-f.p.z)*0.9-f.v.z*0.4,-0.85,0.85)
		if item.get("continuous",false):
			var angle = deg_to_rad(item.get("yaw",0))
			var direction = Vector2(item.p.x-f.p.x+sin(angle)*0.8,item.p.z-f.p.z+cos(angle)*0.8).normalized()
			wx = clampf((direction.x*1.2-f.v.x)*1.6,-1,1)
			wz = clampf((direction.y*1.2-f.v.z)*1.6,-1,1)
		var throttle_limit = 0.22 if item.kind=="land" else 0.65
		var input = {"right":clampf(wx*cos(rad)-wz*sin(rad),-1,1),"forward":clampf(wz*cos(rad)+wx*sin(rad),-1,1),
			"throttle":clampf((height-f.p.y)*0.8-f.v.y*0.2,-throttle_limit,throttle_limit),"yaw":clampf(delta/25,-1,1)}
		sim.tick(input,1.0/120)
	var context = "%s/%s/%s/%s/%d" % [options.mode,options.level,options.assist,code,options.wind_from]
	expect(sim.phase=="awaitingEnd","physical flight "+context+" failed: "+sim.phase+" step "+str(sim.step_index)+" "+str(sim.results))
	sim.confirm_end()
	expect(sim.results.has(code) and sim.results[code].grade=="S","physical completion "+context)
	return sim

func run() -> void:
	var sim = Sim.new()
	sim.module_index = 1
	sim.start_module()
	sim.arm()
	expect(not sim.flight.armed and sim.phase=="declaration","oral confirmation gates arming")
	sim.paused = true
	sim.confirm_start()
	expect(sim.phase=="declaration","paused confirmation blocked")
	sim.paused = false
	sim.confirm_start()
	sim.arm()
	expect(sim.flight.armed,"arming after confirmation")
	cases += 1

	for code in ["A","G"]:
		sim = Sim.new()
		sim.module_index = "ABCDEFG".find(code)
		sim.start_module()
		sim.check_next(1)
		expect(sim.checked==0,"inspection order "+code)
		var list = Data.checklist(code)
		var walk_count = 0
		for item in list:
			if item.title.begins_with("逆時針"):
				walk_count += 1
		expect(walk_count==5,"360 degree inspection "+code)
		for i in range(list.size()):
			if code=="A" and i==10:
				sim.check_next(i)
				expect(sim.checked==10,"eight controls required")
				for control in Data.CONTROL_CHECKS:
					var input = Data.zero_input()
					input[control.axis] = float(control.sign)
					sim.tick(input,0.02)
				expect(sim.controls==255 and not sim.flight.armed,"eight actual controls with motors stopped")
			sim.check_next(i)
		expect(sim.phase=="awaitingEnd" and not sim.results.has(code),"end oral confirmation "+code)
		sim.confirm_end()
		expect(sim.results[code].grade=="S","inspection completion "+code)
		cases += 1

	for level in ["I","II","III"]:
		var g = Data.geometry(level)
		expect(is_equal_approx(Data.distance(g.points.P3,g.points.P7),Data.LEVELS[level].backward),"sideways backward distance "+level)
		var b = Data.build_steps("B",level)
		var holds = []
		var rotates = 0
		for item in b:
			if item.kind=="hold": holds.append(item)
			if item.get("clockwise",false): rotates += 1
		expect(holds.size()==5 and rotates==4,"five holds and four clockwise rotations "+level)
		for item in holds:
			expect(item.seconds==5 and item.p==Vector3(0,1.5,4),"B target low altitude "+level)
		var d = Data.build_steps("D",level)
		var timed_holds = 0
		for item in d:
			if item.kind=="hold" and item.seconds==5: timed_holds += 1
		expect(timed_holds==8,"D eight timed holds "+level)
		var c = Data.build_steps("C",level)
		expect(c[2].p.x<0 and c[65].p.is_equal_approx(g.points.P4+Vector3.UP*1.5),"left circle first "+level)
		expect(c[66].p.x>0 and c[129].p.is_equal_approx(g.points.P4+Vector3.UP*1.5),"right circle second "+level)
		for wind in [90,270]:
			var e = Data.build_steps("E",level,wind)
			var climb_count = 0
			var descent_count = 0
			var legs = {}
			for item in e:
				if item.has("leg"): legs[item.leg] = true
				if item.has("flight_path"):
					if item.flight_path=="climb": climb_count += 1
					else: descent_count += 1
					var f = at(item.p,item.yaw)
					var a = deg_to_rad(item.yaw)
					f.v = Vector3(sin(a),0.4 if item.flight_path=="climb" else -0.4,cos(a))
					expect(Sim.evaluate(f,item).complete,"slope reachable "+level)
					f.v.y = 0
					expect(not Sim.evaluate(f,item).complete,"slope rejects level flight "+level)
					f.v = Vector3(0,1,0)
					expect(not Sim.evaluate(f,item).complete,"slope rejects vertical-only flight "+level)
			expect(climb_count>0 and descent_count>0 and legs.size()==5,"five complete slope legs "+level)
			cases += 1
		cases += 1

	sim = started()
	sim.flight = at(Vector3(0,18,4))
	hover(sim,5.1)
	expect(sim.step_index==0 and sim.stable_for==0,"18m does not count as low hover")
	sim = started()
	sim.flight = at(Vector3(0,1.5,4),50)
	sim.stable_for = 4
	hover(sim,3)
	expect(sim.stable_for==4,"brief correction preserves earned time")
	sim.flight.yaw = 0
	hover(sim,1.1)
	expect(sim.step_index==1,"valid hover completes after correction")
	var old_time = sim.elapsed
	var old_flight = sim.flight.duplicate(true)
	sim.paused = true
	sim.tick({"forward":1.0,"right":1.0,"throttle":1.0,"yaw":1.0},1)
	expect(sim.elapsed==old_time and sim.flight==old_flight,"pause freezes physics and clock")
	cases += 1

	sim = started()
	sim.flight = at(Vector3(3,3,4),90)
	hover(sim,90)
	expect(sim.phase=="active" and sim.faults>45 and sim.step_index==0,"long deviation remains recoverable")
	expect(sim.deviation_seconds.height>0 and sim.deviation_seconds.heading>0,"classified deviations")
	expect(sim.faults < sim.deviation_seconds.height+sim.deviation_seconds.heading+sim.deviation_seconds.position,"total faults counted once")
	var data = JSON.parse_string(JSON.stringify(sim.export_data()))
	expect(data.assessment=="practice-completion" and data.simulation_limits.heading==40,"JSON contains limits and practice meaning")
	cases += 1

	sim = started()
	sim.step_index = 1
	sim.flight = at(Vector3(0,1.5,4))
	var reverse = Data.zero_input()
	reverse.yaw = -1.0
	for i in range(30): sim.tick(reverse,1.0/120)
	expect(sim.phase=="result" and sim.results.B.grade=="U","wrong turn direction fails")
	cases += 1

	for fault in ["behind","bounds","height","cone","early_land","hard_land"]:
		sim = started()
		match fault:
			"behind": sim.flight = at(Vector3(0,1.5,-0.1))
			"bounds": sim.flight = at(Vector3(60,1.5,4))
			"height": sim.flight = at(Vector3(0,36,4))
			"cone": sim.flight = at(Data.geometry("I").points.P1+Vector3.UP*0.2)
			"early_land": sim.flight = at(Vector3(0,0.001,4)); sim.flight.v.y = -0.5
			"hard_land": sim.flight = at(Vector3(0,0.001,4)); sim.flight.v.y = -2.0
		sim.tick(Data.zero_input(),0.01)
		expect(sim.phase=="result" and sim.results.B.grade=="U","safety boundary "+fault)
		cases += 1

	for yaw in [0,45,90,180,270]:
		var f = at(Vector3(0.1,0,4),yaw)
		expect(Sim.footprint_inside(f,Data.HOME,1.5),"gear footprint centered "+str(yaw))
		f.p.x = 1.2
		expect(not Sim.footprint_inside(f,Data.HOME,1.5),"gear over line "+str(yaw))
		cases += 1

	for side in ["left","right"]:
		sim = started("F")
		sim.flight = at(Vector3(-25 if side=="left" else 25,20,20),90)
		var origin = sim.flight.p
		sim.trigger_emergency()
		expect(sim.phase=="declaration" and sim.emergency_origin==origin and sim.emergency_side==side,"emergency retains position and picks near circle "+side)
		hover(sim,15)
		expect(sim.phase=="declaration","30s emergency response margin "+side)
		sim.confirm_start()
		expect(sim.phase=="active","emergency oral confirmation "+side)
		cases += 1
	sim = started("F")
	sim.flight = at(Vector3(25,20,20))
	sim.trigger_emergency()
	sim.flight.p.x += 3
	sim.tick(Data.zero_input(),0.01)
	expect(sim.phase=="result" and sim.results.F.grade=="U","emergency drift fails")
	cases += 1
	sim = started("F")
	sim.flight = at(Vector3(25,20,20))
	sim.trigger_emergency()
	hover(sim,30.2)
	expect(sim.phase=="result" and sim.results.F.grade=="U","emergency confirmation timeout")
	cases += 1

	var f = at(Vector3(0,1.5,4))
	Sim.advance(f,{"forward":1.0,"right":0.0,"yaw":0.0,"throttle":0.0},Data.DEFAULT_CONFIG,1.0/120,0)
	expect(f.v.z>0 and is_zero_approx(f.v.x),"yaw zero forward coordinate")
	f = at(Vector3(0,1.5,4),90)
	Sim.advance(f,{"forward":1.0,"right":0.0,"yaw":0.0,"throttle":0.0},Data.DEFAULT_CONFIG,1.0/120,0)
	expect(f.v.x>0 and absf(f.v.z)<0.00001,"yaw 90 forward coordinate")
	expect(Data.scene_position(Vector3(1,2,3))==Vector3(-1,2,3),"single render coordinate conversion")
	expect(Controls.stick_axis(0.1)==0 and Controls.stick_axis(1)==1 and Controls.stick_axis(-1)==-1,"gamepad deadzone")
	cases += 1
	var input = Data.zero_input()
	input.throttle = -1.0
	f = at(Vector3(0,1.5,4))
	for i in range(120): Sim.advance(f,input,Data.DEFAULT_CONFIG,1.0/120,float(i)/120)
	expect(f.v.y>=-0.65-0.0001,"low-altitude descent limit")
	var options = Data.DEFAULT_CONFIG.duplicate()
	options.assist = "attitude"
	f = at(Vector3(0,1.5,4))
	for i in range(120): Sim.advance(f,Data.zero_input(),options,1.0/120,float(i)/120)
	expect(f.p.x>0.05,"attitude mode retains wind drift")
	cases += 1

	for mode in ["guided","mock"]:
		for code in ["B","C","D","E","F"]:
			options = Data.DEFAULT_CONFIG.duplicate()
			options.mode = mode
			fly(code,options)
			cases += 1
	for level in ["I","II","III"]:
		for code in ["B","C","D","E","F"]:
			options = Data.DEFAULT_CONFIG.duplicate()
			options.level = level
			options.assist = "attitude"
			options.mode = "mock"
			fly(code,options)
			cases += 1
	for level in ["I","II","III"]:
		options = Data.DEFAULT_CONFIG.duplicate()
		options.level = level
		options.wind_from = 90
		fly("E",options)
		cases += 1
	for wind in [90,270]:
		options = Data.DEFAULT_CONFIG.duplicate()
		options.wind_from = wind
		fly("F",options,null,true)
		cases += 1

	for mode in ["guided","mock"]:
		options = Data.DEFAULT_CONFIG.duplicate()
		options.mode = mode
		sim = Sim.new(options)
		for code in ["A","B","C","D","E","F","G"]:
			expect(sim.module().code==code,"full session order "+code)
			if code in ["A","G"]:
				sim.start_module()
				for i in range(Data.checklist(code).size()):
					if code=="A" and i==10:
						for control in Data.CONTROL_CHECKS:
							input = Data.zero_input()
							input[control.axis] = float(control.sign)
							sim.tick(input,0.02)
					sim.check_next(i)
				sim.confirm_end()
			else:
				fly(code,options,sim)
			var before = sim.flight.duplicate(true)
			sim.next_module()
			if code in ["C","D","E","F"]:
				expect(sim.flight==before,"aircraft continuity after "+code)
		expect(sim.phase=="complete" and sim.passed(),"full seven-subject completion "+mode)
		cases += 1
	print("RESULT: %d cases, %d assertions, %d failures" % [cases,assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
