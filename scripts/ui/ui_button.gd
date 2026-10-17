class_name UIButton
extends Button

func _on_pressed() -> void:
	ControllerGame.play_one_shot(preload("res://sounds/click.wav"))
