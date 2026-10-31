@tool
class_name CreatureAiGraph
extends RefCounted

const STATES := {"any":"Any state","feed":"Eat","attack":"Attack","rest":"Rest","work":"Work"}
const FIELDS := {"hungry":"Hungry","needs_break":"Needs a break","aggressive":"Unhappy or cramped","can_attack":"Can attack","satiety":"Satiety (%)","happiness":"Happiness (%)","companions":"Companions","crowding":"Crowding stress (%)","noise":"Noise stress (%)","neighbours":"Neighbour stress (%)","work_cycles":"Completed work cycles","female":"Female","carrying_water":"Carrying water","swimming":"Swimming","dry_ground":"On dry ground","navigation_ready":"Navigation ready"}
const BOOLEAN_FIELDS := ["hungry","needs_break","aggressive","can_attack","female","carrying_water","swimming","dry_ground","navigation_ready"]
const OPERATORS := ["<","<=",">",">=","==","!="]
const DEFAULT_GRAPH := {"version":1,"nodes":[{"id":"any","enabled":true,"position":[40,170]},{"id":"feed","enabled":true,"position":[340,20]},{"id":"attack","enabled":true,"position":[340,170]},{"id":"rest","enabled":true,"position":[340,320]},{"id":"work","enabled":true,"position":[340,470]}],"transitions":[
		{"id":"feed","from":"any","to":"feed","priority":100,"match":"all","conditions":[{"field":"hungry","op":"==","value":1}]},
		{"id":"attack","from":"any","to":"attack","priority":80,"match":"all","conditions":[{"field":"can_attack","op":"==","value":1},{"field":"aggressive","op":"==","value":1}]},
		{"id":"rest","from":"any","to":"rest","priority":60,"match":"all","conditions":[{"field":"needs_break","op":"==","value":1}]},
		{"id":"work","from":"any","to":"work","priority":0,"match":"all","conditions":[]}
	]}

static func defaults() -> Dictionary:
	return DEFAULT_GRAPH.duplicate(true)

static func schema() -> Dictionary:
	return {"states":STATES,"fields":FIELDS,"boolean_fields":BOOLEAN_FIELDS,"operators":OPERATORS,"default_graph":defaults()}

static func validate(graph: Variant) -> String:
	if not graph is Dictionary:
		return "AI graph must be an object."
	if graph.is_empty():
		return ""
	if graph.get("version") != 1 or not graph.get("nodes") is Array or not graph.get("transitions") is Array:
		return "AI graph requires version 1, nodes and transitions."
	if graph.nodes.size() != STATES.size() or graph.transitions.size() > 40:
		return "AI graph needs all five built-in nodes and at most 40 transitions."
	var nodes := {}
	for node: Variant in graph.nodes:
		if not node is Dictionary or not STATES.has(node.get("id")) or nodes.has(node.id) or not node.get("enabled") is bool:
			return "AI graph has an invalid or duplicate state."
		if node.id == "any" and not node.enabled:
			return "The global Any state source must remain enabled."
		var position: Variant = node.get("position")
		if not position is Array or position.size() != 2 or not _number(position[0],0,10000) or not _number(position[1],0,10000):
			return "AI node positions must be finite coordinates between 0 and 10000."
		nodes[node.id] = true
	var ids := {}
	for edge: Variant in graph.transitions:
		if not edge is Dictionary or not edge.get("id") is String or edge.id.is_empty() or edge.id.length() > 80 or ids.has(edge.id):
			return "AI transitions need unique IDs."
		ids[edge.id] = true
		if not STATES.has(edge.get("from")) or not STATES.has(edge.get("to")) or edge.to == "any":
			return "AI transition references an unavailable state."
		if not _number(edge.get("priority"),-1000,1000) or float(edge.priority) != floorf(float(edge.priority)) or edge.get("match") not in ["all","any"]:
			return "AI transition priority or condition mode is invalid."
		if not edge.get("conditions") is Array or edge.conditions.size() > 12:
			return "AI transitions support up to 12 conditions."
		for condition: Variant in edge.conditions:
			if not condition is Dictionary or not FIELDS.has(condition.get("field")) or condition.get("op") not in OPERATORS or not _number(condition.get("value"),-100000,100000):
				return "AI transition contains an invalid condition."
			if condition.field in BOOLEAN_FIELDS and float(condition.value) not in [0.0,1.0]:
				return "Boolean AI conditions use 0 (false) or 1 (true)."
	return ""

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func choices(graph: Dictionary, current: String, context: Dictionary) -> Array[String]:
	var active := DEFAULT_GRAPH if graph.is_empty() else graph
	var enabled := {}
	for node: Dictionary in active.nodes:
		enabled[node.id] = node.enabled
	var candidates: Array[Dictionary] = []
	for edge: Dictionary in active.transitions:
		if edge.from not in ["any",current] or not enabled.get(edge.to,false):
			continue
		var hits := 0
		for condition: Dictionary in edge.conditions:
			var actual := float(context.get(condition.field,0.0))
			var expected := float(condition.value)
			var matched := false
			match condition.op:
				"<": matched = actual < expected
				"<=": matched = actual <= expected
				">": matched = actual > expected
				">=": matched = actual >= expected
				"==": matched = is_equal_approx(actual,expected)
				"!=": matched = not is_equal_approx(actual,expected)
			hits += int(matched)
		if edge.conditions.is_empty() or (hits == edge.conditions.size() if edge.match == "all" else hits > 0):
			candidates.append(edge)
	candidates.sort_custom(func(first: Dictionary, second: Dictionary): return first.priority > second.priority if first.priority != second.priority else str(first.id) < str(second.id))
	var result: Array[String] = []
	for edge: Dictionary in candidates:
		if not result.has(edge.to):
			result.append(edge.to)
	return result
