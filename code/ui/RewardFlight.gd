class_name RewardFlight
extends MarginContainer

func configure(icon: Texture2D, quantity: float) -> void:
	$Content/Icon.texture = icon
	$Content/Quantity.text = "+"+(str(roundi(quantity)) if is_equal_approx(quantity,roundf(quantity)) else String.num(quantity,1))
