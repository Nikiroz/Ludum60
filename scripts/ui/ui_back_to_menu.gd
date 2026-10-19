extends UIShowButton

func _on_pressed() -> void:
	super._on_pressed()
	ControllerGame.return_to_main_menu()
