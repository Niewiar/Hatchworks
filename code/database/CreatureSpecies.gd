@tool
class_name CreatureSpecies
extends DatabaseEntry

@export var scene: PackedScene
@export var icon: Texture2D
@export_range(0.5, 4.0, 0.1) var hold_height := 1.8
@export_range(0.1, 50.0, 0.1) var follow_speed := 14.0
@export_range(0.1, 50.0, 0.1) var rotation_speed := 9.0
@export_range(0.0, 0.8, 0.01) var maximum_tilt := 0.24

@export_group("Movement and production")
@export_range(0.2, 5.0, 0.1) var walk_speed := 1.4
@export_range(0.2, 5.0, 0.1) var swim_speed := 1.05
@export_range(0.1, 1.0, 0.05) var minimum_swim_depth := 0.3
@export_range(1.0, 30.0, 0.5) var bathing_seconds := 3.0
@export_range(0.5, 10.0, 0.1) var shaking_seconds := 1.8
@export_range(0.5, 30.0, 0.5) var resting_seconds := 3.0
@export_range(1, 12, 1) var grass_per_cycle := 3
@export_range(0.4, 3.0, 0.1) var grass_radius := 1.0
@export var food_resource := 5
@export_range(1, 10, 1) var food_per_feeding := 1

@export_range(0.5, 10.0, 0.1) var feeding_seconds := 2.0

@export_group("Breeding")
@export_range(1.0, 120.0, 1.0) var breeding_seconds := 6.0
@export_range(1.0, 3600.0, 1.0) var breeding_cooldown := 120.0
@export_range(1.0, 100.0, 1.0) var breeding_min_satiety := 60.0
@export_range(0.0, 100.0, 1.0) var breeding_satiety_cost := 20.0

@export_group("Satiety")
@export_range(30.0,3600.0,1.0) var satiety_seconds := 240.0
@export_range(1.0,90.0,1.0) var feeding_threshold := 35.0
@export_range(1.0,100.0,1.0) var satiety_per_meal := 60.0

@export_group("Leisure")
@export_range(1.0,120.0,0.5) var leisure_seconds_min := 8.0
@export_range(1.0,120.0,0.5) var leisure_seconds_max := 16.0
@export_range(1,10,1) var leisure_cycles_min := 1
@export_range(1,10,1) var leisure_cycles_max := 2

@export_group("Contentment")
@export_range(1.0,300.0,1.0) var happiness_response_seconds := 30.0
@export_range(1.0,100.0,0.5) var preferred_area := 12.0
@export_range(1.0,30.0,0.5) var company_radius := 6.0

@export_group("Sensitivities")
@export_range(0.0,1.0,0.05) var noise_sensitivity := 0.5
@export_range(0.0,1.0,0.05) var crowding_sensitivity := 1.0
@export var species_aversions: Dictionary[StringName,float] = {}

@export_group("Courtship")
@export_range(0.5,30.0,0.5) var breeding_call_seconds := 3.0

enum PRODUCTION { NONE, GARDENER, QUARRY, HERBALIST }

@export_group("Habitat")
@export var requires_water := true
@export_range(-1,4,1) var habitat_ground := 0

@export_group("Ecosystem production")
@export var production: PRODUCTION = PRODUCTION.NONE
@export_range(1.0,30.0,0.1) var production_seconds := 4.0
@export_range(0.1,30.0,0.1) var impact_time := 2.0
@export_range(1.0,15.0,0.5) var production_radius := 5.0
@export_range(1,40,1) var production_limit := 12
@export_range(0.4,3.0,0.1) var impact_radius := 1.2
@export_range(0.01,0.3,0.01) var impact_strength := 0.08
@export_range(0.0,100.0,1.0) var aggression_threshold := 40.0
@export_range(1.0,100.0,1.0) var impact_damage := 25.0
@export_range(1.0,60.0,1.0) var aggression_cooldown := 12.0
