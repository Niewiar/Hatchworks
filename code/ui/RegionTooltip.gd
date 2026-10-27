class_name RegionTooltip
extends PanelContainer

@onready var _title: Label = $Content/Header/Title
@onready var _area: Label = $Content/Area
@onready var _rows: VBoxContainer = $Content/TerrainRows

func set_region(region: Region) -> void:
	_title.text = "Region %d" % region.id
	_area.text = "%s · %.1f m²" % ["Open terrain" if region.touches_map_edge else "Fenced area", region.area]
	var tenths := PackedInt32Array()
	tenths.resize(5)
	var remainders := PackedFloat32Array()
	remainders.resize(5)
	var total := 0
	for index in 5:
		var exact := region.terrain_coverage[index] * 10.0
		tenths[index] = floori(exact)
		remainders[index] = exact - tenths[index]
		total += tenths[index]
	for unused in range(maxi(0, 1000 - total)):
		var largest := 0
		for index in range(1, 5):
			if remainders[index] > remainders[largest]:
				largest = index
		tenths[largest] += 1
		remainders[largest] = -1
	for index in 5:
		var row := _rows.get_child(index)
		(row.get_node("Value") as Label).text = "%.1f%%" % (tenths[index] / 10.0)
		(row.get_node("Bar") as ProgressBar).value = region.terrain_coverage[index]
