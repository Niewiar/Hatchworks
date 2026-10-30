class_name SaveGameService
extends Node

const SAVE_PATH := "user://saves/world.save"
const BACKUP_PATH := "user://saves/world.backup"
const TEMP_PATH := "user://saves/world.tmp"
const MAGIC := "HATCHWORKS-SAVE\n"
const VERSION := 1
const MAX_FILE_BYTES := 268435456
const MAX_ENTITIES := 100000
const CREATURE_FIELDS := ["satiety","happiness","breeding_cooldown","_happiness_target","_wellbeing_elapsed"]
const ACTIVITY_FIELDS := ["carrying_water","_elapsed","_bath_elapsed","_food_retry","_work_cycles","_cycles_until_leisure","_leisure_duration","_leisure_elapsed","_swimming"]

var last_error := ""
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

func reset_save() -> Error:
	if _busy:
		return _fail(ERR_BUSY,"A save operation is already in progress.")
	for path in [SAVE_PATH,BACKUP_PATH,TEMP_PATH]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				return _fail(error,"The saved game could not be removed.")
	last_error = ""
	return OK

func save_game(map: MapManager) -> Error:
	if _busy or not is_instance_valid(map) or not map.is_node_ready():
		return _fail(ERR_BUSY,"The world is not ready to save.")
	_busy = true
	var state := _capture(map)
	var validation := _validate(state,map)
	if not validation.is_empty():
		_busy = false
		return _fail(ERR_INVALID_DATA,validation)
	var payload := var_to_bytes(state)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	if error != OK:
		_busy = false
		return _fail(error,"The save folder could not be created.")
	var file := FileAccess.open(TEMP_PATH,FileAccess.WRITE)
	if file == null:
		_busy = false
		return _fail(FileAccess.get_open_error(),"The saved game could not be written.")
	file.store_buffer(MAGIC.to_utf8_buffer())
	file.store_buffer(_checksum(payload).to_ascii_buffer())
	file.store_64(payload.size())
	file.store_buffer(payload)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or _read_file(TEMP_PATH).is_empty():
		_busy = false
		return _fail(ERR_FILE_CANT_WRITE,"The saved game could not be verified.")
	if FileAccess.file_exists(SAVE_PATH) and _validate(_read_file(SAVE_PATH),map).is_empty():
		error = DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(BACKUP_PATH))
		if error != OK:
			_busy = false
			return _fail(error,"The previous save could not be backed up.")
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH),ProjectSettings.globalize_path(SAVE_PATH))
	_busy = false
	if error != OK:
		return _fail(error,"The saved game could not be replaced.")
	last_error = ""
	return OK

func load_game(map: MapManager) -> Error:
	if _busy or not is_instance_valid(map) or not map.is_node_ready():
		return _fail(ERR_BUSY,"The world is not ready to load.")
	if not has_save():
		return _fail(ERR_FILE_NOT_FOUND,"No saved game was found.")
	var state := _read_file(SAVE_PATH)
	var validation := _validate(state,map)
	var recovered := false
	if not validation.is_empty():
		var backup := _read_file(BACKUP_PATH)
		var backup_validation := _validate(backup,map)
		if backup_validation.is_empty():
			state = backup
			validation = ""
			recovered = true
	if not validation.is_empty():
		return _fail(ERR_INVALID_DATA,validation)
	_busy = true
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	map.set_mode(MapManager.MODE.NONE)
	map.set_modal(true)
	_clear_world(map)
	_restore_catalog(map,state)
	_restore_terrain(map,state.terrain)
	_restore_flora(map,state.flora)
	_restore_rocks(map,state.rocks)
	_restore_fences(map,state.fences)
	var buildings := _restore_buildings(map,state.buildings)
	_restore_inventory(map,state)
	map.new_content.restore_state(state.get("new_content",{}))
	_reset_reward_presentation(map)
	var actors := _restore_creatures(map,state.creatures,buildings)
	_restore_loose_eggs(map,state.eggs)
	map.set_modal(true)
	var navigation := map.navigation
	var old_navigation_mode := navigation.process_mode
	var old_regions_mode := map.regions_controller.process_mode
	navigation.process_mode = Node.PROCESS_MODE_ALWAYS
	map.regions_controller.process_mode = Node.PROCESS_MODE_ALWAYS
	navigation._cursor = -1
	navigation._building = null
	navigation._astar = null
	navigation.ready_for_paths = false
	navigation._claims.clear()
	map.regions_controller._queue_rebuild()
	navigation._queue_rebuild()
	while not navigation.ready_for_paths:
		await tree.process_frame
	for index in actors.size():
		_restore_activity(actors[index],state.creatures[index],buildings,map)
	_restore_pairs(map,state.pairs,actors)
	navigation.process_mode = old_navigation_mode
	map.regions_controller.process_mode = old_regions_mode
	_restore_interface(map,state)
	map.set_modal(false)
	tree.paused = was_paused
	_busy = false
	last_error = "The previous backup was loaded because the latest save was damaged." if recovered else ""
	return OK

func _capture(map: MapManager) -> Dictionary:
	var actors: Array[Creature] = []
	for node in get_tree().get_nodes_in_group("creatures"):
		if node is Creature and map.get_parent().is_ancestor_of(node) and node.get_viewport() == map.get_viewport() and not node.is_queued_for_deletion():
			actors.append(node)
	var buildings := map.building_controller.get_buildings()
	var terrain := map.terrain_controller
	var result := {"version":VERSION,"map_size":map.map_size,"pixels_per_unit":map.pixels_per_unit,"saved_at":Time.get_unix_time_from_system(),"terrain":{"world_seed":terrain.world_seed,"nature_enabled":map.environment_controller.enabled,"heights":terrain._heights.duplicate(),"ground":terrain._ground_image.save_png_to_buffer(),"influence":terrain._ground_influence.save_png_to_buffer(),"nature":terrain._natural_image.save_png_to_buffer() if terrain._natural_image != null else PackedByteArray(),"water_level":map.water_controller.water_level},"resources":map.inventory._amounts.duplicate(),"items":map.items._amounts.duplicate(),"known":map.discoveries._known.keys(),"unread":map.discoveries._unread.keys(),"recipes":map.discoveries._recipes.keys(),"science":map.science.amount,"research":map.science._completed.keys(),"flora":[],"rocks":[],"fences":{"posts":[],"spans":[]},"buildings":[],"creatures":[],"eggs":[],"pairs":[],"board":[],"camera":{}}
	result["new_content"] = map.new_content.capture_state()
	var tutorial := map.get_parent().get_node_or_null("CanvasLayer/CameraTutorial")
	if tutorial != null:
		result["camera_tutorial_step"] = tutorial.step
	for plant: FloraPlant in map.vegetation_controller._plants:
		if not plant.removed:
			result.flora.append({"id":plant.species.id,"point":plant.point,"variant":plant.variant,"scale":plant.scale,"yaw":plant.yaw,"growth":plant.growth,"hits":plant.tree_view._hits if is_instance_valid(plant.tree_view) else 0})
	for rock: HarvestableDeposit in map.rock_controller._rocks:
		if not is_instance_valid(rock) or rock.exhausted or rock.is_queued_for_deletion():
			continue
		for data: DepositDefinition in map.database.deposits:
			var variant := data.variants.find(rock.mesh)
			if variant >= 0:
				result.rocks.append({"id":data.id,"variant":variant,"position":rock.global_position,"scale":rock.scale.x,"yaw":rock._rest_rotation.y,"hits":rock._hits,"hits_required":rock.hits_required,"yield_amount":rock.yield_amount,"resource_kind":rock.resource_kind})
				break
	for post: FencePostState in map.fances_controller.get_posts():
		result.fences.posts.append({"id":post.id,"point":post.position,"type":post.data.id,"health":post.health})
	for span: FenceSpanState in map.fances_controller.get_spans():
		result.fences.spans.append({"id":span.id,"start":span.start_post_id,"end":span.end_post_id,"type":span.data.id,"health":span.health})
	for building: Node3D in buildings:
		var data := map.building_controller.building_definition(building)
		var record := {"id":data.id,"kind":_building_kind(data),"transform":building.global_transform,"health":map.building_controller._health[building]}
		if building is FeederController:
			record["stock"] = building.stock
		elif building is IncubatorController or building is WorkshopController:
			record["egg"] = building.current_egg.id if building.current_egg != null else &""
			record["state"] = building.state
			record["remaining"] = building.remaining
			if building is IncubatorController:
				record["sex"] = building.pending_sex
				record["sex_assigned"] = building._sex_assigned
		result.buildings.append(record)
	for actor: Creature in actors:
		var record := {"id":actor.species_id,"sex":actor.sex,"position":actor.global_position,"rotation":actor._rest_rotation,"values":_capture_fields(actor,CREATURE_FIELDS)}
		if actor is TuftlingController:
			record["activity"] = actor.activity
			record["activity_values"] = _capture_fields(actor,ACTIVITY_FIELDS)
			record["feeder"] = buildings.find(actor._feeder)
		if actor is EcosystemCreatureController:
			record["effect_done"] = actor._effect_done
			record["aggression_wait"] = actor._aggression_wait
			var job: Dictionary = actor._job
			if not job.is_empty():
				var saved_job := {"kind":job.kind,"point":job.point}
				if job.kind == "plant":
					saved_job["plant"] = job.plant.id
				elif job.kind == "damage":
					var target: Node3D
					if is_instance_valid(job.get("target")):
						target = job.target as Node3D
					saved_job["building"] = buildings.find(target)
					if is_instance_valid(target) and target is FencePostView:
						saved_job["post"] = target.state.id
					elif is_instance_valid(target) and target.get_script() == load("res://code/contructions/fances/FenceRepresentation.gd"):
						saved_job["span"] = target.state.id
				record["job"] = saved_job
		result.creatures.append(record)
	for node in get_tree().get_nodes_in_group("loose_eggs"):
		if node is LooseEggController and node._map == map and not node._collected:
			result.eggs.append({"id":node.definition.id,"position":node.global_position})
	for pair: Dictionary in map.breeding._pairs:
		var male := actors.find(pair.male)
		var female := actors.find(pair.female)
		if male >= 0 and female >= 0:
			result.pairs.append({"male":male,"female":female,"elapsed":pair.elapsed,"call_elapsed":pair.call_elapsed,"age":pair.age,"courting":pair.courting})
	var panel := map.get_parent().get_node_or_null("CanvasLayer/Discoveries")
	if panel != null and panel.has_method("capture_workspace"):
		result.board = panel.capture_workspace()
	if map.camera_controller != null and map.camera_controller.has_method("capture_view"):
		result.camera = map.camera_controller.capture_view()
	return result

func _clear_world(map: MapManager) -> void:
	map.noise.clear()
	map.wellbeing.invalidate()
	_reset_reward_presentation(map)
	var presentation := map.hatch_presentation
	if presentation != null and presentation.visible and is_instance_valid(presentation._incubator):
		presentation.cancel_for(presentation._incubator)
	for pair: Dictionary in map.breeding._pairs.duplicate():
		map.breeding.cancel(pair.male)
	for node in get_tree().get_nodes_in_group("creatures")+get_tree().get_nodes_in_group("loose_eggs"):
		if map.get_parent().is_ancestor_of(node) and node.get_viewport() == map.get_viewport():
			node.free()
	for building in map.building_controller.get_buildings():
		building.free()
	var vegetation := map.vegetation_controller
	for child in vegetation.get_children():
		child.free()
	vegetation._plants.clear()
	vegetation._trees.clear()
	vegetation._batches.clear()
	vegetation._batch_plants.clear()
	vegetation._buckets.clear()
	vegetation._growing.clear()
	vegetation._dirty_batches.clear()
	for child in map.rock_controller.get_children():
		child.free()
	map.rock_controller._rocks.clear()
	var fences := map.fances_controller
	for child in fences._built_root.get_children():
		child.free()
	fences._posts.clear()
	fences._spans.clear()
	fences._post_views.clear()
	fences._span_views.clear()
	fences._next_post_id = 1
	fences._next_span_id = 1
	var notifications := map.get_parent().get_node_or_null("CanvasLayer/Notifications")
	if notifications != null:
		for card in notifications._cards.duplicate():
			notifications._dismiss(card)

func _restore_catalog(map: MapManager, state: Dictionary) -> void:
	map.discoveries._known.clear()
	map.discoveries._unread.clear()
	map.discoveries._recipes.clear()
	for id in state.known:
		map.discoveries._known[StringName(id)] = true
	for id in state.unread:
		map.discoveries._unread[StringName(id)] = true
	for id in state.recipes:
		map.discoveries._recipes[str(id)] = true
	map.science._completed.clear()
	for key in state.research:
		map.science._completed[str(key)] = true
	map.science.amount = state.science

func _restore_terrain(map: MapManager, state: Dictionary) -> void:
	var terrain := map.terrain_controller
	terrain.world_seed = state.world_seed
	terrain._heights = state.heights.duplicate()
	terrain._collision_heights.resize(terrain._heights.size())
	for index in terrain._heights.size():
		terrain._collision_heights[index] = terrain._heights[index]/terrain._height_cell.x
	terrain._height_dirty = Rect2i(Vector2i.ZERO,terrain._height_size)
	terrain._upload_height_surface()
	terrain._ground_image = _decode_image(state.ground,Image.FORMAT_RGBA8)
	terrain._ground_influence = _decode_image(state.influence,Image.FORMAT_R8)
	if not state.nature.is_empty():
		terrain.set_natural_coverage(_decode_image(state.nature,Image.FORMAT_RGBA8))
	terrain._upload_ground_texture()
	map.water_controller.water_level = state.water_level
	var environment := map.environment_controller
	environment.enabled = state.nature_enabled
	environment._noise.seed = terrain.world_seed+8191
	environment._noise.frequency = 0.12
	environment._noise.fractal_octaves = 2
	environment._size = Vector2i(ceil(terrain.world_size/environment.cell_size))
	environment._extent = terrain.world_size/Vector2(environment._size)
	if environment.enabled:
		environment._image = _decode_image(state.nature,Image.FORMAT_RGBA8)
		if not terrain.height_changed.is_connected(environment._queue_refresh):
			terrain.height_changed.connect(environment._queue_refresh)
		if not map.water_controller.water_level_changed.is_connected(environment._queue_refresh):
			map.water_controller.water_level_changed.connect(environment._queue_refresh)
	else:
		if terrain.height_changed.is_connected(environment._queue_refresh):
			terrain.height_changed.disconnect(environment._queue_refresh)
		if map.water_controller.water_level_changed.is_connected(environment._queue_refresh):
			map.water_controller.water_level_changed.disconnect(environment._queue_refresh)
	environment._cursor = -1
	environment._dirty = false
	environment.set_process(false)

func _restore_flora(map: MapManager, records: Array) -> void:
	var vegetation := map.vegetation_controller
	for record: Dictionary in records:
		var data := map.database.plant(record.id)
		var plant := FloraPlant.new()
		plant.species = data
		plant.point = record.point
		plant.variant = record.variant
		plant.scale = record.scale
		plant.yaw = record.yaw
		plant.growth = record.growth
		var chunk := Vector2i(((plant.point+map.terrain_controller.world_size*0.5)/vegetation.chunk_size).floor())
		plant.batch_key = "%d:%d:%d:%d" % [vegetation.species.find(data),plant.variant,chunk.x,chunk.y]
		vegetation._plants.append(plant)
		if data.kind == FloraSpecies.KIND.TREE:
			vegetation._trees.append(plant)
		else:
			var batch: Array = vegetation._batch_plants.get(plant.batch_key,[])
			batch.append(plant)
			vegetation._batch_plants[plant.batch_key] = batch
		var key := Vector2i((plant.point/2.0).floor())
		var bucket: Array = vegetation._buckets.get(key,[])
		bucket.append(plant)
		vegetation._buckets[key] = bucket
		if plant.growth < 1.0:
			vegetation._growing.append(plant)
	vegetation._create_batches()
	vegetation._upload_batches()
	vegetation._update_tree_views()
	for index in vegetation._plants.size():
		var plant: FloraPlant = vegetation._plants[index]
		if is_instance_valid(plant.tree_view):
			_restore_hits(plant.tree_view,records[index].hits)
	vegetation.set_process(not vegetation._growing.is_empty())
	vegetation.obstacles_changed.emit()

func _restore_rocks(map: MapManager, records: Array) -> void:
	for record: Dictionary in records:
		var data := _deposit(map.database,record.id)
		var rock := map.rock_controller.DEPOSIT_SCENE.instantiate() as HarvestableDeposit
		rock.kind = HarvestableDeposit.KIND.ROCK
		rock.resource_kind = record.resource_kind
		rock.hits_required = record.hits_required
		rock.yield_amount = record.yield_amount
		map.rock_controller.add_child(rock)
		var source := data.variants[record.variant]
		var bounds := source.get_aabb()
		rock.configure(source,data.material,record.yaw,maxf(bounds.size.x,bounds.size.z)*0.42,bounds.size.y*0.9)
		rock.scale = Vector3.ONE*record.scale
		rock.global_position = record.position
		rock.depleted.connect(map.rock_controller._on_rock_depleted)
		map.rock_controller._rocks.append(rock)
		_restore_hits(rock,record.hits)
	map.rock_controller.obstacles_changed.emit()

func _restore_fences(map: MapManager, state: Dictionary) -> void:
	var fences := map.fances_controller
	var maximum_post := 0
	var maximum_span := 0
	for record: Dictionary in state.posts:
		var data := _fence(map.database,record.type)
		fences._next_post_id = record.id
		var id := fences._ensure_post(record.point,data)
		fences._posts[id].health = record.health
		maximum_post = maxi(maximum_post,id)
	for record: Dictionary in state.spans:
		var data := _fence(map.database,record.type)
		fences._next_span_id = record.id
		var id := fences._add_span(record.start,record.end,data,record.health/data.max_health)
		maximum_span = maxi(maximum_span,id)
	fences._next_post_id = maximum_post+1
	fences._next_span_id = maximum_span+1
	fences._finish_edit()

func _restore_buildings(map: MapManager, records: Array) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for record: Dictionary in records:
		var data := _building(map.database,record.id)
		var building := data.scene.instantiate() as Node3D
		map.building_controller.add_child(building)
		building.global_transform = record.transform
		map.building_controller._register_building(building,data)
		map.building_controller._health[building] = record.health
		if building is FeederController:
			building.stock = record.stock
			building._refresh()
		elif building is IncubatorController or building is WorkshopController:
			building.current_egg = map.database.egg(record.egg) if not str(record.egg).is_empty() else null
			building.state = record.state
			building.remaining = record.remaining
			if building is IncubatorController:
				building.pending_sex = record.sex
				building._sex_assigned = record.sex_assigned
				if building.state == IncubatorController.STATE.PRESENTING:
					building.state = IncubatorController.STATE.READY
				if building.current_egg != null:
					building._egg_visual = building.current_egg.model.instantiate()
					building.get_node("EggSocket").add_child(building._egg_visual)
				building.get_node("EggSocket").visible = building.state != IncubatorController.STATE.EMPTY
			else:
				if building.state == WorkshopController.STATE.READY:
					building._egg_visual = building.current_egg.model.instantiate()
					building._egg_visual.process_mode = Node.PROCESS_MODE_DISABLED
					building._egg_visual.scale = Vector3.ONE*0.63
					building.get_node("%Socket").add_child(building._egg_visual)
				building._update_visuals()
		result.append(building)
	return result

func _restore_inventory(map: MapManager, state: Dictionary) -> void:
	map.inventory._amounts.clear()
	map.discoveries._stocks.clear()
	for kind in state.resources:
		map.inventory._amounts[int(kind)] = float(state.resources[kind])
		map.discoveries._stocks[int(kind)] = float(state.resources[kind])
	map.items._amounts.clear()
	for id in state.items:
		map.items._amounts[StringName(id)] = int(state.items[id])
	for kind in map.inventory._amounts:
		map.inventory.changed.emit(kind,map.inventory._amounts[kind])
	map.items.changed.emit()
	map.science.changed.emit(map.science.amount)

func _restore_creatures(map: MapManager, records: Array, buildings: Array[Node3D]) -> Array[Creature]:
	var result: Array[Creature] = []
	for record: Dictionary in records:
		var data := map.database.creature(record.id)
		var actor := data.scene.instantiate() as Creature
		actor.species_id = data.id
		actor.sex = record.sex
		actor.terrain_controller = map.terrain_controller
		actor.position = map.get_parent().to_local(record.position)
		actor.rotation = record.rotation
		map.get_parent().add_child(actor)
		_restore_fields(actor,record.values)
		actor.velocity = Vector3.ZERO
		actor._state = Creature.STATE.GROUNDED
		result.append(actor)
	return result

func _restore_activity(actor: Creature, record: Dictionary, buildings: Array[Node3D], map: MapManager) -> void:
	if not actor is TuftlingController:
		return
	_restore_fields(actor,record.activity_values)
	actor._path.clear()
	actor._path_revision = map.navigation.revision
	actor._feeder = buildings[record.feeder] as FeederController if record.feeder >= 0 else null
	var activity: int = record.activity
	if actor is EcosystemCreatureController:
		actor._effect_done = record.get("effect_done",false)
		actor._aggression_wait = record.get("aggression_wait",0.0)
		var job: Dictionary = record.get("job",{})
		if not job.is_empty() and activity == TuftlingController.ACTIVITY.SHAKING:
			actor._job = {"kind":job.kind,"point":job.point}
			if job.kind == "plant":
				actor._job["plant"] = map.database.plant(job.plant)
			elif job.kind == "damage":
				var target: Node3D
				if job.get("building",-1) >= 0:
					target = buildings[job.building]
				elif job.has("post"):
					target = map.fances_controller._post_views.get(job.post)
				elif job.has("span"):
					target = map.fances_controller._span_views.get(job.span)
				if target == null:
					actor._job.clear()
				else:
					actor._job["target"] = target
			if not actor._job.is_empty():
				actor.activity = TuftlingController.ACTIVITY.SHAKING
				actor._play_animation(&"Work")
				if actor.animation_player != null and actor.animation_player.has_animation(&"Work"):
					actor.animation_player.seek(minf(actor._elapsed,actor.animation_player.get_animation(&"Work").length),true)
				return
	if activity in [TuftlingController.ACTIVITY.LEISURE]:
		actor.activity = activity
		actor._play_animation(&"behaviour/Rest")
	elif activity == TuftlingController.ACTIVITY.EATING and actor._feeder != null:
		actor.activity = activity
		actor._play_animation(&"Eat")
	elif activity == TuftlingController.ACTIVITY.SHAKING and not actor is EcosystemCreatureController:
		actor.activity = activity
		actor._play_animation(&"Work")
	else:
		actor._elapsed = 0.8
		actor.activity = TuftlingController.ACTIVITY.SEEKING_GROUND if actor is EcosystemCreatureController or actor.carrying_water else TuftlingController.ACTIVITY.SEEKING_WATER

func _restore_loose_eggs(map: MapManager, records: Array) -> void:
	for record: Dictionary in records:
		var pickup := preload("res://scenes/incubation/loose_egg.tscn").instantiate() as LooseEggController
		map.add_child(pickup)
		pickup.initialize(map,map.database.egg(record.id),record.position)

func _restore_pairs(map: MapManager, records: Array, actors: Array[Creature]) -> void:
	for record: Dictionary in records:
		var male := actors[record.male]
		var female := actors[record.female]
		var path := map.navigation.route_to_partner(female,male)
		if path.is_empty() and not record.courting:
			continue
		for actor in [male,female]:
			actor.interrupt_activity()
			actor.tree_exiting.connect(map.breeding.cancel.bind(actor))
		var pair := {"male":male,"female":female,"path":path,"index":0,"revision":map.navigation.revision,"elapsed":record.elapsed,"call_elapsed":record.call_elapsed,"age":record.age,"courting":record.courting,"stuck":0.0,"last_position":female.global_position,"male_position":male.global_position,"check":0.0,"blocked_retries":0}
		map.breeding._pairs.append(pair)
		map.breeding._active[male] = pair
		map.breeding._active[female] = pair
		map.navigation.reserve_place(male,male.global_position)
		map.navigation.reserve_place(female,female.global_position if record.courting or path.is_empty() else path[-1])
		male.set_breeding_effect(record.courting)
		female.set_breeding_effect(record.courting)
		male.face_point(female.global_position,&"Idle" if record.courting else &"behaviour/Call")
	map.breeding.set_physics_process(not map.breeding._pairs.is_empty())
	map.breeding.changed.emit()

func _restore_interface(map: MapManager, state: Dictionary) -> void:
	var canvas := map.get_parent().get_node_or_null("CanvasLayer")
	if canvas == null:
		return
	var tutorial := canvas.get_node_or_null("CameraTutorial")
	if tutorial != null:
		tutorial.restore_step(int(state.get("camera_tutorial_step",2)))
	var panel := canvas.get_node_or_null("Discoveries")
	if panel != null:
		if panel.has_method("restore_workspace"):
			panel.restore_workspace(state.board)
		panel._refresh_catalog()
	var toolbar := canvas.get_node_or_null("GameToolbar")
	if toolbar != null:
		toolbar._refresh_unlocks()
		toolbar._refresh_badges()
	if map.camera_controller != null and map.camera_controller.has_method("restore_view") and not state.camera.is_empty():
		map.camera_controller.restore_view(state.camera)

func _capture_fields(node: Object, names: Array) -> Dictionary:
	var result := {}
	for name in names:
		result[name] = node.get(name)
	return result

func _restore_fields(node: Object, values: Dictionary) -> void:
	for name in values:
		node.set(name,values[name])

func _restore_hits(deposit: HarvestableDeposit, hits: int) -> void:
	deposit._hits = hits
	deposit._progress.text = "%d / %d" % [hits,deposit.hits_required]
	deposit._progress.hide()

func _building(database: GameDatabase, id: StringName) -> BuildingDefinition:
	for entry: BuildingDefinition in database.buildings:
		if entry.id == id:
			return entry
	return null

func _building_kind(data: BuildingDefinition) -> String:
	var scene := data.scene
	while scene != null:
		var state := scene.get_state()
		for index in state.get_node_property_count(0):
			if state.get_node_property_name(0,index) == &"script":
				var script := state.get_node_property_value(0,index) as Script
				while script != null:
					match script.resource_path:
						"res://code/contructions/FeederController.gd": return "feeder"
						"res://code/incubation/IncubatorController.gd": return "incubator"
						"res://code/contructions/WorkshopController.gd": return "workshop"
					script = script.get_base_script()
		scene = state.get_node_instance(0)
	return "structure"

func _deposit(database: GameDatabase, id: StringName) -> DepositDefinition:
	for entry: DepositDefinition in database.deposits:
		if entry.id == id:
			return entry
	return null

func _fence(database: GameDatabase, id: StringName) -> FanceData:
	for entry: FanceData in database.construction.fances:
		if entry.id == id:
			return entry
	return null

func _decode_image(buffer: PackedByteArray, format: Image.Format) -> Image:
	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return null
	image.convert(format)
	return image

func _checksum(payload: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()

func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		return {}
	var header_size := MAGIC.to_utf8_buffer().size()+64+8
	if file.get_length() < header_size or file.get_length() > MAX_FILE_BYTES:
		return {}
	if file.get_buffer(MAGIC.to_utf8_buffer().size()).get_string_from_utf8() != MAGIC:
		return {}
	var checksum := file.get_buffer(64).get_string_from_ascii()
	var size := file.get_64()
	if size != file.get_length()-header_size or size <= 0:
		return {}
	var payload := file.get_buffer(size)
	if _checksum(payload) != checksum:
		return {}
	var value: Variant = bytes_to_var(payload)
	if not value is Dictionary:
		return {}
	if value.get("version",0) == VERSION and value.get("creatures") is Array:
		for record in value.creatures:
			if not record is Dictionary:
				continue
			if record.get("values") is Dictionary:
				record.values.erase("energy")
			if record.get("activity_values") is Dictionary:
				record.activity_values.erase("_recovering")
			if record.get("activity",-1) == 16:
				record.activity = TuftlingController.ACTIVITY.LEISURE
	return value

func _validate(state: Dictionary, map: MapManager) -> String:
	if state.has("camera_tutorial_step") and not _integer(state.camera_tutorial_step,0,2):
		return "The saved camera view is invalid."
	if state.has("new_content"):
		if not state.new_content is Dictionary or not state.new_content.get("seen") is Array or state.new_content.seen.size() > 1024:
			return "The saved inventory is invalid."
		for key in state.new_content.seen:
			if not key is String or key.is_empty() or key.length() > 256:
				return "The saved inventory is invalid."
	if state.get("version",0) != VERSION:
		return "The saved game is damaged or uses an unsupported version."
	if state.get("map_size") != map.map_size or state.get("pixels_per_unit") != map.pixels_per_unit:
		return "The saved game uses a different map size or pixel density."
	for key in ["terrain","resources","items","fences","camera"]:
		if not state.get(key) is Dictionary:
			return "The saved game contains invalid world data."
	for key in ["known","unread","recipes","research","flora","rocks","buildings","creatures","eggs","pairs","board"]:
		if not state.get(key) is Array or state[key].size() > MAX_ENTITIES:
			return "The saved game contains invalid entity data."
	var terrain: Dictionary = state.terrain
	if not terrain.get("heights") is PackedFloat32Array or terrain.heights.size() != map.terrain_controller._heights.size() or not _integer(terrain.get("world_seed"),1,2147483647) or not terrain.get("nature_enabled") is bool or not _number(terrain.get("water_level"),-100,100):
		return "The saved terrain is invalid."
	for height in terrain.heights:
		if not _number(height,map.terrain_controller.minimum_height,map.terrain_controller.maximum_height):
			return "The saved terrain is invalid."
	for key in ["ground","influence","nature"]:
		if not terrain.get(key) is PackedByteArray:
			return "The saved terrain textures are invalid."
		if key == "nature" and terrain[key].is_empty():
			if terrain.nature_enabled:
				return "The saved terrain textures are invalid."
			continue
		var image := _decode_image(terrain[key],Image.FORMAT_RGBA8)
		if image == null or image.get_size().x > map.map_size.x or image.get_size().y > map.map_size.y or (key != "nature" and image.get_size() != map.map_size):
			return "The saved terrain textures are invalid."
	if not _integer(state.get("science"),0,2147483647):
		return "The saved science is invalid."
	for kind in state.resources:
		if not kind is int or map.inventory.definition(kind) == null or not _number(state.resources[kind],0,1e12):
			return "The saved inventory is invalid."
	if state.resources.size() != map.inventory.definitions.size():
		return "The saved inventory is invalid."
	for id in state.items:
		if not _id(id) or (map.database.egg(id) == null and map.database.sapling(id) == null) or not _integer(state.items[id],0,2147483647):
			return "The saved inventory is invalid."
	for id in state.known:
		if not _id(id) or map.database.discovery(id) == null:
			return "The saved discoveries no longer match the game database."
	for id in state.unread:
		if not id in state.known:
			return "The saved discoveries no longer match the game database."
	var recipe_ids: Array = map.database.recipes.map(func(entry): return str(entry.id))
	for id in state.recipes:
		if not _id(id) or not str(id) in recipe_ids:
			return "The saved discoveries no longer match the game database."
	for key in state.research:
		if not key is String or key.length() > 256:
			return "The saved science is invalid."
	for record in state.flora:
		if not record is Dictionary or not _id(record.get("id")):
			return "The saved plants are invalid."
		var data := map.database.plant(record.id)
		if data == null or not _point2(record.get("point"),map.terrain_controller.world_size*0.5) or not _integer(record.get("variant"),0,data.variants.size()-1) or not _number(record.get("scale"),0.01,100) or not _number(record.get("yaw"),-1000,1000) or not _number(record.get("growth"),0,1) or not _integer(record.get("hits"),0,data.hits_required-1):
			return "The saved plants are invalid."
	for record in state.rocks:
		if not record is Dictionary or not _id(record.get("id")):
			return "The saved deposits are invalid."
		var data := _deposit(map.database,record.id)
		if data == null or not _point3(record.get("position"),map) or not _integer(record.get("variant"),0,data.variants.size()-1) or not _number(record.get("scale"),0.01,100) or not _number(record.get("yaw"),-1000,1000) or not _integer(record.get("hits_required"),1,10000) or not _integer(record.get("hits"),0,record.hits_required-1) or not _integer(record.get("yield_amount"),1,2147483647) or map.inventory.definition(record.get("resource_kind",-1)) == null:
			return "The saved deposits are invalid."
	var fence_ids := {}
	var post_points := {}
	if not state.fences.get("posts") is Array or not state.fences.get("spans") is Array or state.fences.posts.size() > MAX_ENTITIES or state.fences.spans.size() > MAX_ENTITIES:
		return "The saved fences are invalid."
	for record in state.fences.posts:
		if not record is Dictionary or not _id(record.get("type")):
			return "The saved fences are invalid."
		var data := _fence(map.database,record.type)
		if data == null or not _integer(record.get("id"),1,2147483646) or fence_ids.has(record.id) or not _point2(record.get("point"),Vector2(map.map_size)*0.5) or not _number(record.get("health"),0.001,data.post_max_health):
			return "The saved fences are invalid."
		var key := Vector2i((record.point/FenceController.MERGE_DISTANCE).floor())
		for y in range(key.y-1,key.y+2):
			for x in range(key.x-1,key.x+2):
				for point: Vector2 in post_points.get(Vector2i(x,y),[]):
					if point.distance_squared_to(record.point) <= FenceController.MERGE_DISTANCE*FenceController.MERGE_DISTANCE:
						return "The saved fences are invalid."
		var bucket: Array = post_points.get(key,[])
		bucket.append(record.point)
		post_points[key] = bucket
		fence_ids[record.id] = true
	var span_ids := {}
	var connections := {}
	var connected_posts := {}
	for record in state.fences.spans:
		if not record is Dictionary or not _id(record.get("type")):
			return "The saved fences are invalid."
		var data := _fence(map.database,record.type)
		if data == null or not _integer(record.get("id"),1,2147483646) or span_ids.has(record.id) or not _integer(record.get("start"),1,2147483646) or not _integer(record.get("end"),1,2147483646) or not fence_ids.has(record.start) or not fence_ids.has(record.end) or record.start == record.end or not _number(record.get("health"),0.001,data.max_health):
			return "The saved fences are invalid."
		var connection := Vector2i(mini(record.start,record.end),maxi(record.start,record.end))
		if connections.has(connection):
			return "The saved fences are invalid."
		connections[connection] = true
		connected_posts[record.start] = true
		connected_posts[record.end] = true
		span_ids[record.id] = true
	if connected_posts.size() != fence_ids.size():
		return "The saved fences are invalid."
	for record in state.buildings:
		if not record is Dictionary or not _id(record.get("id")):
			return "The saved buildings are invalid."
		var data := _building(map.database,record.id)
		if data == null or not record.get("transform") is Transform3D or not record.transform.is_finite() or not _point3(record.transform.origin,map) or not _number(record.get("health"),0.001,data.max_health):
			return "The saved buildings are invalid."
		if record.get("kind") != _building_kind(data):
			return "The saved buildings are invalid."
		if record.kind == "feeder":
			if not _integer(record.get("stock"),0,data.storage_capacity):
				return "The saved buildings are invalid."
		elif record.kind in ["incubator","workshop"]:
			if not _id(record.get("egg")) or (not str(record.egg).is_empty() and map.database.egg(record.egg) == null) or not _integer(record.get("state"),0,3 if record.kind == "incubator" else 2) or not _number(record.get("remaining"),0,86400) or (record.state != 0 and str(record.egg).is_empty()):
				return "The saved buildings are invalid."
			if record.kind == "incubator" and (not _integer(record.get("sex"),0,1) or not record.get("sex_assigned") is bool):
				return "The saved buildings are invalid."
	for record in state.creatures:
		if not record is Dictionary or not _id(record.get("id")) or map.database.creature(record.id) == null or not _integer(record.get("sex"),0,1) or not _point3(record.get("position"),map) or not record.get("rotation") is Vector3 or not record.rotation.is_finite() or not record.get("values") is Dictionary:
			return "The saved creatures are invalid."
		for key in CREATURE_FIELDS:
			if not _number(record.values.get(key),0,100 if key in ["satiety","happiness","_happiness_target"] else 86400):
				return "The saved creatures are invalid."
		if record.values.size() != CREATURE_FIELDS.size() or not record.get("activity_values") is Dictionary or record.activity_values.size() != ACTIVITY_FIELDS.size() or not _integer(record.get("activity"),0,TuftlingController.ACTIVITY.size()-1) or not _integer(record.get("feeder"),-1,state.buildings.size()-1):
			return "The saved creature activities are invalid."
		if record.get("feeder",-1) >= 0 and state.buildings[record.feeder].kind != "feeder":
			return "The saved creature activities are invalid."
		if record.has("effect_done") and not record.effect_done is bool:
			return "The saved creature activities are invalid."
		if record.has("aggression_wait") and not _number(record.aggression_wait,0,86400):
			return "The saved creature activities are invalid."
		for key in ACTIVITY_FIELDS:
			var value: Variant = record.activity_values.get(key)
			if key in ["carrying_water","_swimming"]:
				if not value is bool:
					return "The saved creature activities are invalid."
			elif key in ["_work_cycles","_cycles_until_leisure"]:
				if not _integer(value,0,100000):
					return "The saved creature activities are invalid."
			elif not _number(value,-86400,86400):
				return "The saved creature activities are invalid."
		if record.has("job"):
			var job: Variant = record.job
			if not job is Dictionary or not job.get("kind") in ["plant","quarry","damage"] or not _point3(job.get("point"),map) or not _number(record.get("aggression_wait"),0,86400) or not record.get("effect_done") is bool:
				return "The saved creature activities are invalid."
			if job.kind == "plant" and (not _id(job.get("plant")) or map.database.plant(job.plant) == null):
				return "The saved creature activities are invalid."
			if job.kind == "damage" and (not _integer(job.get("building",-1),-1,state.buildings.size()-1) or (job.has("post") and not fence_ids.has(job.post)) or (job.has("span") and not span_ids.has(job.span))):
				return "The saved creature activities are invalid."
	for record in state.eggs:
		if not record is Dictionary or not _id(record.get("id")) or map.database.egg(record.id) == null or not _point3(record.get("position"),map):
			return "The saved eggs are invalid."
	var paired := {}
	for record in state.pairs:
		if not record is Dictionary or not _integer(record.get("male"),0,state.creatures.size()-1) or not _integer(record.get("female"),0,state.creatures.size()-1) or record.male == record.female or paired.has(record.male) or paired.has(record.female) or not record.get("courting") is bool:
			return "The saved breeding pairs are invalid."
		var male: Dictionary = state.creatures[record.male]
		var female: Dictionary = state.creatures[record.female]
		if male.id != female.id or male.sex != Creature.SEX.MALE or female.sex != Creature.SEX.FEMALE:
			return "The saved breeding pairs are invalid."
		for key in ["elapsed","call_elapsed","age"]:
			if not _number(record.get(key),0,86400):
				return "The saved breeding pairs are invalid."
		paired[record.male] = true
		paired[record.female] = true
	for record in state.board:
		if not record is Dictionary or not record.get("id") in state.known or not record.get("position") is Vector2 or not record.position.is_finite():
			return "The saved discovery board is invalid."
	if not state.camera.is_empty() and (not state.camera.get("transform") is Transform3D or not state.camera.transform.is_finite() or not _number(state.camera.get("size"),0.1,10000)):
		return "The saved camera is invalid."
	return ""

func _id(value: Variant) -> bool:
	return (value is String or value is StringName) and str(value).length() <= 256

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return value is int and value >= minimum and value <= maximum

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _point2(value: Variant, extent: Vector2) -> bool:
	return value is Vector2 and value.is_finite() and absf(value.x) <= extent.x and absf(value.y) <= extent.y

func _point3(value: Variant, map: MapManager) -> bool:
	if not value is Vector3 or not value.is_finite() or absf(value.y) > 1000:
		return false
	var local := map.terrain_controller.to_local(value)
	return absf(local.x) <= map.terrain_controller.world_size.x*0.5 and absf(local.z) <= map.terrain_controller.world_size.y*0.5

func _fail(error: Error, message: String) -> Error:
	last_error = message
	return error

func _reset_reward_presentation(map: MapManager) -> void:
	var rewards := map.get_parent().get_node_or_null("CanvasLayer/Rewards")
	if rewards != null:
		rewards.reset_presentation()
