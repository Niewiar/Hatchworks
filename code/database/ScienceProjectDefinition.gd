@tool
class_name ScienceProjectDefinition
extends DatabaseEntry

@export var costs: Dictionary[int,int] = {}
@export_range(1,1000000,1) var science_reward := 1
