class_name CreatureWellbeingController
extends Node

var _map: MapManager
var _members: Dictionary = {}
var _species: Dictionary = {}
var _updated_at := -1000

func initialize(map: MapManager) -> void:
	_map = map
	map.regions_controller.regions_changed.connect(invalidate)
	invalidate()

func invalidate() -> void:
	_updated_at = -1000

func sample(creature: Creature) -> Dictionary:
	if _map == null:
		return {}
	var region := _map.regions_controller.get_region_at(creature.global_position)
	if region == null:
		return {}
	if Time.get_ticks_msec()-_updated_at >= 1000:
		_refresh()
	var members: Array = _members.get(region.id,[])
	var population := maxi(1,members.size())
	var companions := 0
	var data := creature.species_data()
	for other: Creature in members:
		if is_instance_valid(other) and other != creature and other.blocks_space() and other.species_id == creature.species_id and creature.global_position.distance_squared_to(other.global_position) <= data.company_radius*data.company_radius:
			companions += 1
	var aversion := 0.0
	var present: Dictionary = _species.get(region.id,{})
	for id: StringName in data.species_aversions:
		if id != creature.species_id and present.get(id,0) > 0:
			aversion += data.species_aversions[id]
	return {"space":maxf(0.0,region.area-region.water_area)/population,"companions":companions,"aversion":clampf(aversion,0.0,1.0)}

func _refresh() -> void:
	_members.clear()
	_species.clear()
	for node in get_tree().get_nodes_in_group("creatures"):
		if not node is Creature or not node.blocks_space() or node.get_viewport() != _map.get_viewport() or not _map.get_parent().is_ancestor_of(node):
			continue
		var region := _map.regions_controller.region_id_at(node.global_position)
		if region <= 0:
			continue
		if not _members.has(region):
			_members[region] = []
			_species[region] = {}
		_members[region].append(node)
		_species[region][node.species_id] = _species[region].get(node.species_id,0)+1
	_updated_at = Time.get_ticks_msec()
