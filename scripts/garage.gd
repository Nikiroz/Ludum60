extends Control

@onready var robot_tabs: TabContainer = $VBoxContainer/MarginContainer/HBoxContainer/MarginContainer/MarginContainer2/HBoxContainer/TabContainer2
@onready var robot_name: LineEdit = $VBoxContainer/MarginContainer/HBoxContainer/MarginContainer/MarginContainer/robotname
@onready var health_label: Label = %Health
@onready var damage_label: Label = %Damage
@onready var speed_label: Label = %Speed
@onready var crit_label: Label = %Crit

var _active_unit: BattleUnit
var _active_robot_index := -1

func _ready() -> void:
	var buttons: VBoxContainer = robot_tabs.get_parent().get_node("TabButtons")
	for index in range(robot_tabs.get_tab_count()):
		var tab := robot_tabs.get_tab_control(index)
		var unit: BattleUnit = ControllerGame.units[index] if index < ControllerGame.units.size() else null
		tab.unit = unit
		tab.get_node("EquipmentPreview").unit = unit
		buttons.get_child(index).tooltip_text = unit.name if unit != null else "Robot %d" % (index + 1)
	robot_tabs.tab_changed.connect(_on_robot_selected)
	robot_name.text_changed.connect(_on_robot_name_changed)
	_on_robot_selected(robot_tabs.current_tab)


func _process(_delta: float) -> void:
	_update_robot_stats()


func _on_robot_selected(index: int) -> void:
	_save_robot_name()
	_active_robot_index = index
	_active_unit = ControllerGame.units[index] if index >= 0 and index < ControllerGame.units.size() else null
	robot_name.editable = _active_unit != null
	robot_name.text = _active_unit.name if _active_unit != null else ""
	_update_robot_stats()


func _update_robot_stats() -> void:
	health_label.text = str(roundi(_active_unit.health)) if _active_unit != null else ""
	damage_label.text = str(roundi(_active_unit.damage)) if _active_unit != null else ""
	speed_label.text = String.num(_active_unit.attack_speed, 2) if _active_unit != null else ""
	crit_label.text = String.num(_active_unit.crit_chance * 100.0, 2) + "%" if _active_unit != null else ""


func _on_robot_name_changed(_new_name: String) -> void:
	_save_robot_name()

func _save_robot_name() -> void:
	if _active_unit == null:
		return
	_active_unit.name = robot_name.text
	var buttons: VBoxContainer = robot_tabs.get_parent().get_node("TabButtons")
	buttons.get_child(_active_robot_index).tooltip_text = _active_unit.name


func _exit_tree() -> void:
	_save_robot_name()
