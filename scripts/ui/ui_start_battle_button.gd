extends UIButton

@onready var _battle: Node = owner


func _ready() -> void:
	_battle.connect("battle_started", _disable)
	_battle.connect("round_finished", _disable)


func _disable() -> void:
	disabled = true


func _on_pressed() -> void:
	if _battle.start_battle():
		super._on_pressed()
