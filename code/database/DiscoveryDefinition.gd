@tool
class_name DiscoveryDefinition
extends DatabaseEntry

enum CATEGORY { NATURE, MATERIALS, PLANTS, CONCEPTS, EGGS, CREATURES, BUILDINGS }
const CATEGORY_NAMES := ["Nature","Materials","Plants","Concepts","Eggs","Creatures","Buildings"]

@export var category: CATEGORY = CATEGORY.NATURE
@export var icon: Texture2D
@export var reward_item: StringName
@export_range(0,100,1) var reward_count := 0
