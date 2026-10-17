extends CanvasLayer

@export_enum("garage", "scrapyard", "battle") var location: String = "garage"


func _ready() -> void:
	set_location(location)


func set_location(value: String) -> void:
	location = value
	$GarageButton.visible = location == "battle"
	$ScrapyardButton.visible = location == "garage"
	$BattleButton.visible = location == "garage"


func show_return_to_garage() -> void:
	$GarageButton.show()
	$ScrapyardButton.hide()
	$BattleButton.hide()
