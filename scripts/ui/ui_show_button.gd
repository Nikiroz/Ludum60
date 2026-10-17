class_name UIShowButton
extends UIButton

@export var nodeName: String
var node:Control

func _ready() -> void:
	node = get_tree().root.find_child(nodeName, true, false)

func _on_pressed() -> void:
	super._on_pressed()
	if node:
		node.show()
	else:
		push_error("Node not found: " + nodeName)
