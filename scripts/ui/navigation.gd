extends CanvasLayer

@export_enum("garage", "scrapyard", "battle") var location: String = "garage"

func _ready() -> void:
	ControllerGame.register_navigation(self, location)
