extends UIButton

@onready var _battle: Node = owner


func _ready() -> void:
	_battle.connect("battle_started", hide)
	_battle.connect("round_finished", hide)


func _on_pressed() -> void:
	if _battle.start_battle():
		super._on_pressed()
