class_name FloraPlant
extends RefCounted

var species: FloraSpecies
var point := Vector2.ZERO
var variant := 0
var scale := 1.0
var yaw := 0.0
var growth := 0.0
var batch_key := ""
var tree_view: HarvestableDeposit
var removed := false
