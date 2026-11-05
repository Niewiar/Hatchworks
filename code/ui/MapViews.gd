extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController

const REGION_LABEL = preload("res://scenes/ui/map_region_label.tscn")
const NOISE_MARKER = preload("res://scenes/ui/map_noise_marker.tscn")
const TERRAIN_NAMES := {0:"Grass",1:"Soil",3:"Sand",4:"Rocky ground"}

var _labels: Dictionary[int,Control] = {}
var _markers: Array[Control] = []
var _elapsed := 0.0
var _hover_id := 0
var _hover_point := Vector2.INF
var _hover_time := 0.0
var _hint_elapsed := 0.0
var _hint_delta := 0.0
var _hint_text := ""
var _layout_dirty := true
var _markers_dirty := true
var _camera_transform := Transform3D()
var _camera_size := -1.0
var _hud_bounds: Array[Rect2] = []
var _pointer_screen := Vector2.INF
var _pointer_transform := Transform3D()
var _pointer_zoom := -1.0
var _pointer_invalid := true
var _pointer_world: Variant = null

func _ready() -> void:
	for button: Button in %Views.get_children():
		var value: MapOverlayController.VIEW = int(button.get_meta("view"))
		button.pressed.connect(map_manager.overlay.set_view.bind(value))
		button.mouse_entered.connect(_button_hint.bind(button))
		button.mouse_exited.connect(tooltip_controller.hide_text.bind(button))
	map_manager.overlay.view_changed.connect(_view_changed)
	map_manager.overlay.regions_updated.connect(_sync_labels)
	map_manager.overlay.noise_updated.connect(_sync_markers)
	map_manager.modal_changed.connect(_modal_changed)
	map_manager.mode_changed.connect(_mode_changed)
	map_manager.terrain_controller.height_changed.connect(_invalidate_pointer)
	resized.connect(_mark_layout_dirty)
	_view_changed(map_manager.overlay.view)

func _view_changed(view: MapOverlayController.VIEW) -> void:
	tooltip_controller.hide_text(self)
	for button: Button in %Views.get_children():
		button.set_pressed_no_signal(int(button.get_meta("view")) == view)
	%NoiseLegend.visible = view == MapOverlayController.VIEW.NOISE
	%RegionLegend.visible = view == MapOverlayController.VIEW.REGIONS
	%RegionLabels.visible = view == MapOverlayController.VIEW.REGIONS
	%NoiseMarkers.visible = view == MapOverlayController.VIEW.NOISE
	_elapsed = 0.0
	_hover_time = 0.0
	_hover_id = 0
	_hint_text = ""
	_hint_elapsed = 0.0
	_hint_delta = 0.0
	_pointer_invalid = true
	_refresh_summaries()
	_mark_layout_dirty()
	set_process(view != MapOverlayController.VIEW.NORMAL and not map_manager.modal_active)

func _modal_changed(active: bool) -> void:
	visible = not active
	set_process(not active and map_manager.overlay.view != MapOverlayController.VIEW.NORMAL)
	_clear_hint()
	_mark_layout_dirty()

func _mode_changed(_mode: MapManager.MODE) -> void:
	_clear_hint()
	_mark_layout_dirty()

func _mark_layout_dirty() -> void:
	_layout_dirty = true
	_markers_dirty = true
	_pointer_invalid = true

func _invalidate_pointer() -> void:
	_pointer_invalid = true

func _sync_labels() -> void:
	var points := map_manager.overlay.region_points
	var changed := false
	for id: int in _labels.keys():
		if not points.has(id):
			_labels[id].queue_free()
			_labels.erase(id)
			changed = true
	for id: int in points:
		if _labels.has(id):
			continue
		var label := REGION_LABEL.instantiate() as Control
		%RegionLabels.add_child(label)
		_labels[id] = label
		changed = true
		label.get_node("Compact/Title").text = tr("Region %d") % id
		label.get_node("Detail/Content/Header/Swatch").color = MapOverlayController.region_color(id)
		label.get_node("Detail").resized.connect(_mark_layout_dirty)
		label.get_node("Compact").resized.connect(_mark_layout_dirty)
	_mark_layout_dirty()
	if changed:
		_refresh_summaries()

func _refresh_summaries() -> void:
	if map_manager.overlay.view != MapOverlayController.VIEW.REGIONS:
		return
	for id: int in _labels:
		var summary := map_manager.landscape.region_summary(id)
		var label: Control = _labels[id]
		label.get_node("Detail/Content/Header/Title").text = tr("Region %d") % id
		label.get_node("Compact/Title").text = tr("Region %d") % id
		if not summary.ready:
			continue
		label.get_node("Detail/Content/Area").text = tr("Dry land: %s m²") % _number(summary.dry_area)
		for kind: int in TERRAIN_NAMES:
			label.get_node("Detail/Content/Ground/Kind%d/Name" % kind).text = tr(TERRAIN_NAMES[kind])
			label.get_node("Detail/Content/Ground/Kind%d/Share" % kind).text = _number(summary.coverage[kind])+"%"
		label.get_node("Detail/Content/Ground").visible = summary.dry_area > 0.000001
		label.get_node("Detail/Content/Flooded").visible = summary.dry_area <= 0.000001
		label.get_node("Detail/Content/Water").text = tr("Water: %s%% of region") % _number(summary.water_coverage)

func _sync_markers() -> void:
	_markers_dirty = true
	var sources := map_manager.overlay.sources
	while _markers.size() < sources.size():
		var marker := NOISE_MARKER.instantiate() as Control
		%NoiseMarkers.add_child(marker)
		_markers.append(marker)
	for index in _markers.size():
		_markers[index].visible = index < sources.size()
		if index < sources.size():
			_markers[index].modulate.a = clampf(sources[index].strength*1.6,0.25,1.0)

func _process(delta: float) -> void:
	_elapsed -= delta
	if _elapsed <= 0.0:
		_elapsed = 0.35
		_refresh_summaries()
		var bounds := _hud_rects()
		if bounds != _hud_bounds:
			_hud_bounds = bounds
			_layout_dirty = true
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var camera_changed := camera.global_transform != _camera_transform or camera.size != _camera_size
	if camera_changed:
		_camera_transform = camera.global_transform
		_camera_size = camera.size
		_mark_layout_dirty()
	if map_manager.overlay.view == MapOverlayController.VIEW.REGIONS and _layout_dirty:
		_layout_dirty = false
		_position_regions(camera)
	elif map_manager.overlay.view == MapOverlayController.VIEW.NOISE and _markers_dirty:
		_markers_dirty = false
		_position_sources(camera)
	_hint_elapsed -= delta
	_hint_delta += delta
	if _hint_elapsed <= 0.0:
		_hint_elapsed = 0.1
		_update_hint(camera,_hint_delta)
		_hint_delta = 0.0

func _position_regions(camera: Camera3D) -> void:
	var occupied := _hud_rects()
	var bounds := get_viewport_rect().grow(-12.0)
	var detailed := camera.size <= 24.0
	var ordered := _labels.keys()
	ordered.sort_custom(func(first: int,second: int): return first != second and (first == _hover_id or (second != _hover_id and first < second)))
	for id: int in ordered:
		var label: Control = _labels[id]
		var point: Vector3 = map_manager.overlay.region_points[id]
		if camera.is_position_behind(point):
			label.visible = false
			continue
		var screen := camera.unproject_position(point)
		if not bounds.has_point(screen):
			label.visible = false
			continue
		var use_detail := detailed
		var panel := label.get_node("Detail" if use_detail else "Compact") as Control
		var rect = _label_rect(panel.size,screen,bounds,occupied)
		if rect == null and use_detail:
			use_detail = false
			panel = label.get_node("Compact") as Control
			rect = _label_rect(panel.size,screen,bounds,occupied)
		if rect == null:
			label.visible = false
			continue
		label.get_node("Detail").visible = use_detail
		label.get_node("Compact").visible = not use_detail
		label.position = rect.position
		label.visible = true
		occupied.append(rect.grow(8.0))

func _hud_rects() -> Array[Rect2]:
	var result: Array[Rect2] = [%Dock.get_node("Panel").get_global_rect().grow(8.0)]
	for path: String in ["ResourcePanel/Panel","CameraTutorial/Panel","GameToolbar/VBoxContainer/BaseButtons","GameToolbar/VBoxContainer/BuildingButtons","GameToolbar/VBoxContainer/SculptButtons","GameToolbar/VBoxContainer/PaintButtons","GameToolbar/VBoxContainer/GatherButtons","Notifications/Scroll","InspectionPanel/Panel"]:
		var control := get_parent().get_node_or_null(path) as Control
		if control != null and control.is_visible_in_tree():
			result.append(control.get_global_rect().grow(8.0))
	return result

func _label_rect(extent: Vector2, point: Vector2, bounds: Rect2, occupied: Array[Rect2]) -> Variant:
	var candidates := [point-Vector2(extent.x*0.5,extent.y+12.0),point+Vector2(-extent.x*0.5,12.0),point-Vector2(extent.x+12.0,extent.y*0.5),point+Vector2(12.0,-extent.y*0.5)]
	for candidate: Vector2 in candidates:
		var rect := Rect2(candidate.clamp(bounds.position,(bounds.end-extent).max(bounds.position)),extent)
		if bounds.encloses(rect) and not _overlaps(rect,occupied):
			return rect
	return null
func _overlaps(rect: Rect2, occupied: Array[Rect2]) -> bool:
	for other: Rect2 in occupied:
		if rect.intersects(other):
			return true
	return false

func _position_sources(camera: Camera3D) -> void:
	var bounds := get_viewport_rect().grow(-18.0)
	var sources := map_manager.overlay.sources
	for index in _markers.size():
		var marker: Control = _markers[index]
		if index >= sources.size():
			marker.visible = false
			continue
		var point: Vector3 = sources[index].point
		point.y = maxf(point.y,map_manager.water_controller.global_position.y)+0.5
		if camera.is_position_behind(point):
			marker.visible = false
			continue
		var screen := camera.unproject_position(point)
		marker.visible = bounds.has_point(screen)
		if marker.visible:
			marker.position = screen-marker.size*0.5

func _update_hint(camera: Camera3D, delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	if get_viewport().gui_get_hovered_control() != null:
		_clear_hint()
		return
	if mouse.distance_squared_to(_hover_point) > 16.0:
		_hover_time = 0.0
		_hover_point = mouse
		tooltip_controller.hide_text(self)
		_hint_text = ""
	_hover_time += delta
	if _pointer_invalid or mouse != _pointer_screen or camera.global_transform != _pointer_transform or camera.size != _pointer_zoom:
		_pointer_screen = mouse
		_pointer_transform = camera.global_transform
		_pointer_zoom = camera.size
		_pointer_invalid = false
		_pointer_world = GroundPicker3D.from_screen(camera,mouse,map_manager.terrain_controller)
	var point: Variant = _pointer_world
	if point == null or not map_manager.terrain_controller.contains_world_point(point):
		_clear_hint()
		return
	if map_manager.overlay.view == MapOverlayController.VIEW.REGIONS:
		var id := map_manager.regions_controller.region_id_at(point)
		map_manager.overlay.highlight_region(id)
		if id != _hover_id:
			_hover_id = id
			_hover_time = 0.0
			_layout_dirty = true
			tooltip_controller.hide_text(self)
			_hint_text = ""
		if id > 0 and _hover_time >= 0.3:
			var summary := map_manager.landscape.region_summary(id)
			if summary.ready:
				_show_map_hint(_region_hint(summary))
	elif _hover_time >= 0.3:
		point.y = maxf(point.y,map_manager.water_controller.global_position.y)
		var name := ""
		for index in mini(_markers.size(),map_manager.overlay.sources.size()):
			if _markers[index].visible and _markers[index].get_global_rect().grow(5.0).has_point(mouse):
				name = _source_name(map_manager.overlay.sources[index])+"\n"
				break
		_show_map_hint(name+tr("Noise: %d/100") % roundi(map_manager.noise.level_at(point)*100.0))

func _show_map_hint(text: String) -> void:
	if text == _hint_text:
		return
	_hint_text = text
	tooltip_controller.show_hint(text,self)

func _clear_hint() -> void:
	if _hover_id != 0:
		_hover_id = 0
		_layout_dirty = true
		map_manager.overlay.highlight_region(0)
	_hover_time = 0.0
	_hint_text = ""
	tooltip_controller.hide_text(self)

func _region_hint(summary: Dictionary) -> String:
	var lines := PackedStringArray([tr("Region %d") % summary.id,tr("Dry land: %s m²") % _number(summary.dry_area)])
	if summary.dry_area <= 0.000001:
		lines.append(tr("No dry land"))
	else:
		for kind: int in TERRAIN_NAMES:
			lines.append(tr(TERRAIN_NAMES[kind])+": "+_number(summary.coverage[kind])+"%")
		lines.append(tr("Ground percentages refer to dry land."))
	lines.append(tr("Water: %s%% of region") % _number(summary.water_coverage))
	return "\n".join(lines)

func _source_name(data: Dictionary) -> String:
	var source: Variant = data.source
	if is_instance_valid(source):
		var building := map_manager.building_controller.building_definition(source)
		if building != null:
			return tr(building.display_name)
		if source is Creature:
			return tr(source.species_data().display_name)
	return tr("Impact") if data.transient else tr("Noise source")

func _button_hint(button: Button) -> void:
	_hint_text = ""
	tooltip_controller.show_text(tr(str(button.get_meta("hint"))),button)

func _number(value: float) -> String:
	return String.num(value,1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_summaries()
