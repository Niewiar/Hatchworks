extends AudioStreamPlayer

func _ready() -> void:
	play()
	apply_volume()
	Localization.music_volume_changed.connect(func(_value: float): apply_volume())

func apply_volume() -> void:
	var value: float = Localization.music_volume()
	volume_db = linear_to_db(value)-10.0

func _exit_tree() -> void:
	stop()
	stream = null
