class_name RewardFlight
extends MarginContainer

func configure(icon: Texture2D, quantity: float, ground := false) -> void:
	$Content/Icon.texture = icon
	$Content/Quantity.text = "+%.2f m²" % quantity if ground else "+"+(str(roundi(quantity)) if is_equal_approx(quantity,roundf(quantity)) else String.num(quantity,1))
