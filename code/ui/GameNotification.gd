class_name GameNotification
extends Button

signal activated(notification: GameNotification)
signal dismissed(notification: GameNotification)

var target_mode: MapManager.MODE

func _ready() -> void:
	pressed.connect(func(): activated.emit(self))
	%Close.pressed.connect(func(): dismissed.emit(self))

func configure(title: String, message: String, icon: Texture2D, mode: MapManager.MODE) -> void:
	target_mode = mode
	%Title.text = title
	%Message.text = message
	%Icon.texture = icon
