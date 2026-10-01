class_name TrainingData
extends RefCounted
## Training parameters carried from the user's existing simulator.
## Coordinate system: +X pilot right, +Z forward. Rendering mirrors X only.

const REFERENCE = "AC107-005D P159–167（沿用原專案流程）"
const HOME = Vector3(0, 0, 4)
const DEFAULT_CONFIG = {"mode": "guided", "level": "I", "assist": "position", "wind_from": 270}
const LEVELS = {
	"I": {"scale": 1.0, "length": 80.0, "width": 20.0, "backward": 12.0},
	"II": {"scale": 1.5, "length": 120.0, "width": 30.0, "backward": 18.0},
	"III": {"scale": 2.0, "length": 160.0, "width": 40.0, "backward": 24.0},
}
const LIMITS = {
	"heading": 40.0, "track_heading": 45.0, "hover_speed": 1.2, "vertical_speed": 0.8,
	"route_radius": 2.0, "min_cruise": 0.15, "max_cruise": 5.0, "cruise_variation": 2.0,
	"attitude_rate": 1.2, "high_altitude": 4.0, "slope_height": 1.5,
	"recovery": 10.0, "emergency_response": 30.0, "emergency_horizontal": 2.5,
	"emergency_vertical": 1.5, "reverse_correction": 8.0, "hover_radius": 1.5,
	"circle_radius": 1.2, "descent_height": 2.5, "descent_speed": 0.65,
	"hard_landing": 1.65, "safe_landing": 1.0, "glide_slope": 1.0,
	"aircraft_radius": 1.8, "gear_width": 0.6, "gear_length": 0.525,
	"line_width": 0.1, "cone_radius": 0.22, "cone_height": 0.55,
	"hold_correction": 4.0,
}
const MODULES = [
	{"code":"A", "title":"飛行前檢查", "english":"PRE-FLIGHT INSPECTION", "description":"確認九類系統知識、八方向搖桿與開關功能，依自備表逆時針繞機檢查。"},
	{"code":"B", "title":"定點起降及四面停懸", "english":"FOUR-DIRECTION HOVER", "description":"H 點約 1–2 m，順時針轉向，完成五段各至少 5 秒停懸，再降落 H。"},
	{"code":"C", "title":"8 字水平圓", "english":"FIGURE-EIGHT FLIGHT", "description":"先左逆時針、再右順時針，機頭沿航線，約 1–2 m 等高飛行，後退返回 H。"},
	{"code":"D", "title":"側面停懸與移動", "english":"LATERAL MANEUVER", "description":"機頭朝左及朝右，前進、後退並完成八段各 5 秒停懸。"},
	{"code":"E", "title":"五邊飛行", "english":"FIVE-LEG CIRCUIT", "description":"第一邊迎風前進爬升至約 20 m，中段等高，第五邊前進下降回 H 低空。"},
	{"code":"F", "title":"緊急處置程序", "english":"EMERGENCY RETURN", "description":"接獲口令立即原處懸停，確認後手動進場，降落最近一側八字內圈。"},
	{"code":"G", "title":"飛行後檢查", "english":"POST-FLIGHT INSPECTION", "description":"停機斷電，依自備表逆時針繞機 360°，完成飛行後檢查與紀錄。"},
]
const DEVIATIONS = {
	"height":"高度", "heading":"機頭朝向", "position":"位置／航線", "speed":"水平速度",
	"descent":"升降速度", "direction":"移動方向", "attitude":"轉彎平順", "approach":"進場斜率",
}
const CONTROL_CHECKS = [
	{"title":"前進 ↑", "axis":"forward", "sign":1}, {"title":"後退 ↓", "axis":"forward", "sign":-1},
	{"title":"右移 →", "axis":"right", "sign":1}, {"title":"左移 ←", "axis":"right", "sign":-1},
	{"title":"上升 W", "axis":"throttle", "sign":1}, {"title":"下降 S", "axis":"throttle", "sign":-1},
	{"title":"右轉 E", "axis":"yaw", "sign":1}, {"title":"左轉 Q", "axis":"yaw", "sign":-1},
]

static func fresh_flight() -> Dictionary:
	return {"p":HOME, "v":Vector3.ZERO, "yaw":0.0, "pitch":0.0, "roll":0.0,
		"battery":100.0, "armed":false, "impact":false}

static func zero_input() -> Dictionary:
	return {"forward":0.0, "right":0.0, "throttle":0.0, "yaw":0.0}

static func empty_deviations() -> Dictionary:
	var result = {}
	for key in DEVIATIONS:
		result[key] = 0.0
	return result

static func angle(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0

static func distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func bearing(a: Vector3, b: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(b.x - a.x, b.z - a.z)), 360.0)

static func scene_position(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, p.z)

static func geometry(level: String) -> Dictionary:
	var size_data = LEVELS[level]
	var r = size_data.backward / 2.0
	return {"radius":r, "inner_radius":r * 0.6, "outer_radius":r * 1.4, "home_radius":1.5,
		"left":Vector3(-r, 0, HOME.z + r), "right":Vector3(r, 0, HOME.z + r),
		"half_length":size_data.length / 2.0, "depth":size_data.width,
		"points": {"P1":Vector3(-r,0,HOME.z+2*r), "P2":Vector3(-2*r,0,HOME.z+r),
			"P3":Vector3(-r,0,HOME.z), "P4":Vector3(0,0,HOME.z+r),
			"P5":Vector3(r,0,HOME.z+2*r), "P6":Vector3(2*r,0,HOME.z+r), "P7":Vector3(r,0,HOME.z)}}

static func checklist(code: String) -> Array:
	var result = []
	if code == "A":
		var titles = ["型式／型號", "最大起飛總重量", "酬載能力", "重心", "螺旋槳／旋翼規格",
			"馬達／引擎規格", "電池／燃油規格", "遙控器／無線電頻率", "續航能力"]
		for title in titles:
			result.append({"title":"系統知識 · " + title, "detail":"口述實際使用設備的" + title + "與限制，完成後確認。"})
		result.append({"title":"自備檢查表與場地", "detail":"依自備表確認環境、機體、電池及通訊；設備規格以實際機種為準。"})
		result.append({"title":"搖桿功能實測", "detail":"依序操作八個方向，馬達保持停止。所有方向都完成後才能確認。"})
		result.append({"title":"開關功能檢查", "detail":"操作並確認遙控器所有開關，包含飛行模式與馬達開關。"})
	else:
		result.append({"title":"落地停機與斷電", "detail":"確認槳葉停止，依機種程序關閉機體及遙控器並取出電池。"})
	var sides = ["機頭", "左側", "機尾", "右側", "回到機頭"]
	for i in range(5):
		result.append({"title":"逆時針繞機 %d° · %s" % [i*90, sides[i]],
			"detail":"依自備檢查表檢查此側機臂、槳葉、動力、起落架與接頭，再確認。"})
	if code == "G":
		result.append({"title":"飛行後紀錄", "detail":"記錄機體、槳葉、馬達及電池狀況，完成後口誦結束。"})
	return result

static func step(title: String, p: Vector3, kind: String = "reach", yaw = null, seconds: float = 0.0) -> Dictionary:
	var result = {"title":title, "p":p, "kind":kind, "seconds":seconds, "radius":LIMITS.hover_radius}
	if yaw != null:
		result.yaw = float(yaw)
	return result

static func hold(title: String, p: Vector3, yaw = 0.0, seconds: float = 5.0) -> Dictionary:
	return step(title, p, "hold", yaw, seconds)

static func link_steps(steps: Array) -> Array:
	for i in range(steps.size()):
		if not steps[i].has("from"):
			steps[i]["from"] = HOME if i == 0 else steps[i-1].p
	return steps

static func circuit(level: String, wind_from: int, descend: bool) -> Array:
	var g = geometry(level)
	var sign_x = -1.0 if wind_from == 270 else 1.0
	var vertices = [Vector3(0,20,HOME.z), Vector3(sign_x*g.half_length,20,HOME.z),
		Vector3(sign_x*g.half_length,20,HOME.z+g.depth), Vector3(-sign_x*g.half_length,20,HOME.z+g.depth),
		Vector3(-sign_x*g.half_length,20,HOME.z), Vector3(0,20,HOME.z)]
	var route = []
	var cursor: Vector3 = vertices[0]
	for i in range(1, vertices.size()):
		var vertex: Vector3 = vertices[i]
		var previous: Vector3 = vertices[i-1]
		var trim = 3.0 * LEVELS[level].scale
		var before = vertex
		if i + 1 < vertices.size():
			before = vertex.lerp(previous, minf(0.2, trim / distance(previous, vertex)))
		var start = cursor
		var n = maxi(1, ceili(distance(start, before) / 2.0))
		for k in range(1, n+1):
			var p = start.lerp(before, float(k)/n)
			var item = step("五邊第 %d 邊 · 約 20 m" % i, p, "reach", bearing(cursor,p))
			item.merge({"continuous":true, "leg":i, "radius":0.7})
			route.append(item)
			cursor = p
		if i+1 < vertices.size():
			var after = vertex.lerp(vertices[i+1], minf(0.2, trim / distance(vertex,vertices[i+1])))
			for k in range(1,13):
				var t = float(k)/12.0
				var p = before*(1-t)*(1-t) + vertex*2*(1-t)*t + after*t*t
				var item = step("五邊第 %d 邊 · 約 20 m" % i, p, "reach", bearing(cursor,p))
				item.merge({"continuous":true, "leg":i, "radius":0.7})
				route.append(item)
				cursor = p
	var slope_length = g.half_length - 3.0*LEVELS[level].scale
	for i in range(route.size()):
		var item = route[i]
		var climb = item.leg == 1 and absf(item.p.x) <= slope_length and is_equal_approx(item.p.z, HOME.z)
		var descent = descend and item.leg == 5
		if climb or descent:
			item.p.y = 1.5 + 18.5 * minf(1,absf(item.p.x)/slope_length)
			item["flight_path"] = "climb" if climb else "descent"
			item.title = "五邊第 %d 邊 · %s至 %.1f m" % [item.leg,"迎風前進爬升" if climb else "前進下降進場",item.p.y]
			if i == 0:
				item["from"] = Vector3(0,1.5,HOME.z)
	return route

static func build_steps(code: String, level: String, wind_from: int = 270) -> Array:
	var g = geometry(level)
	var h = Vector3(0,1.5,HOME.z)
	var steps = []
	if code == "B":
		steps.append(hold("H 朝外 · 停懸至少 5 秒",h))
		for yaw in [90,180,270,0]:
			var rotate = step("順時針旋轉 90° → %d°" % yaw,h,"rotate",yaw)
			rotate["clockwise"] = true
			steps.append(rotate)
			steps.append(hold("H 航向 %d° · 停懸至少 5 秒" % yaw,h,yaw))
		var landing = step("朝外降落 H · 起落架不得超線", HOME,"land",0)
		landing["landing"] = "H"
		steps.append(landing)
	elif code == "C":
		steps.append(hold("H 朝外 · 停懸至少 5 秒",h))
		steps.append(step("朝外前進 P4，進入左圓",g.points.P4+Vector3.UP*1.5,"reach",0))
		for side in ["left","right"]:
			for i in range(1,65):
				var t = float(i)*TAU/64.0
				var left = side == "left"
				var center: Vector3 = g[side]
				var p = center + Vector3((1 if left else -1)*g.radius*cos(t),1.5,g.radius*sin(t))
				var title = "左圓逆時針 P4→P1→P2→P3→P4" if left else "右圓順時針 P4→P5→P6→P7→P4"
				var item = step(title+" · %d/64" % i,p,"reach",fposmod((-1 if left else 1)*rad_to_deg(t),360))
				item.merge({"continuous":true,"arc":{"center":center,"radius":g.radius},"radius":LIMITS.circle_radius},true)
				steps.append(item)
		var back = step("機頭朝外，後退返回 H",h,"reach",0)
		back["backwards"] = true
		steps.append(back)
		steps.append(hold("H 朝外等高懸停 · 口誦結束",h,0,0))
	elif code == "D":
		steps = [hold("H 朝外穩定高度約 1–2 m",h,0,0),step("原地轉機頭朝左",h,"rotate",270),hold("H 朝左 · 停懸至少 5 秒",h,270)]
		for yaw in [270,90]:
			if yaw == 90:
				steps.append(step("原地轉機頭朝右",h,"rotate",90))
				steps.append(hold("H 朝右 · 停懸至少 5 秒",h,90))
			var names = ["P3","P7","H"] if yaw == 270 else ["P7","P3","H"]
			for i in range(3):
				var p: Vector3 = h if names[i] == "H" else g.points[names[i]] + Vector3.UP*1.5
				var item = step(("後退" if i == 1 else "前進")+"至 "+names[i],p,"reach",yaw)
				item["backwards"] = i == 1
				steps.append(item)
				steps.append(hold(names[i]+" · 停懸至少 5 秒",p,yaw))
		steps.append(step("原地轉機頭朝外",h,"rotate",0))
		steps.append(hold("H 朝外等高懸停 · 口誦結束",h,0,0))
	elif code in ["E","F"]:
		steps = circuit(level,wind_from,code == "E")
		if code == "E":
			steps.append(step("H 低空轉機頭朝外，準備科目銜接",h,"rotate",0))
			steps.append(hold("H 約 1–2 m 懸停 · 口誦結束並待命 F",h,0,0))
		else:
			steps.append(hold("等候監評緊急返航指令",Vector3(0,20,HOME.z),wind_from,0))
	return link_steps(steps)
