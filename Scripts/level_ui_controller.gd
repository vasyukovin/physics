extends RefCounted
class_name LevelUiController

const LEVEL3_THROW_COUNT: int = 3

var host: Node2D
var force_input: LineEdit
var throw_button: Button
var next_level_button: Button
var formula_label: Label
var level_label: Label
var level3_forces_panel: VBoxContainer
var force_input_1: LineEdit
var force_input_2: LineEdit
var force_input_3: LineEdit
var apply_forces_button: Button
var target_distance_label: Label
var level3_markers: Array[Label] = []

func setup(
	target_host: Node2D,
	target_force_input: LineEdit,
	target_throw_button: Button,
	target_next_level_button: Button,
	target_formula_label: Label,
	target_level_label: Label,
	target_level3_forces_panel: VBoxContainer,
	target_force_input_1: LineEdit,
	target_force_input_2: LineEdit,
	target_force_input_3: LineEdit,
	target_apply_forces_button: Button,
	target_target_distance_label: Label
) -> void:
	host = target_host
	force_input = target_force_input
	throw_button = target_throw_button
	next_level_button = target_next_level_button
	formula_label = target_formula_label
	level_label = target_level_label
	level3_forces_panel = target_level3_forces_panel
	force_input_1 = target_force_input_1
	force_input_2 = target_force_input_2
	force_input_3 = target_force_input_3
	apply_forces_button = target_apply_forces_button
	target_distance_label = target_target_distance_label

func apply_level_state(level: int, total_levels: int) -> void:
	level_label.text = "Уровень %d/%d" % [level, total_levels]
	next_level_button.visible = false
	
	if level == 1:
		force_input.visible = false
		formula_label.visible = false
		level3_forces_panel.visible = false
		throw_button.disabled = false
	elif level == 2:
		force_input.visible = true
		force_input.clear()
		formula_label.visible = true
		level3_forces_panel.visible = false
		throw_button.disabled = false
	else:
		force_input.visible = false
		formula_label.visible = true
		level3_forces_panel.visible = true
		throw_button.disabled = true

func show_next_level_button(visible: bool) -> void:
	next_level_button.visible = visible

func set_throw_button_disabled(disabled: bool) -> void:
	throw_button.disabled = disabled

func set_force_input_value(value_text: String) -> void:
	force_input.text = value_text

func set_target_distance(distance_m: float, target_x: float, target_y: float) -> void:
	target_distance_label.text = "%.2f м" % distance_m
	target_distance_label.global_position = Vector2(target_x + 28.0, target_y - 18.0)

func update_formula_for_level2(target_distance_m: float) -> void:
	formula_label.text = "Формула: J = m * sqrt(2gh)\nДля цели: h = %.2f м" % target_distance_m

func update_formula_for_level3(h1: float, h2: float, h3: float) -> void:
	formula_label.text = "Формула: J = m * sqrt(2gh)\nЦели: h1=%.2f м, h2=%.2f м, h3=%.2f м" % [h1, h2, h3]

func get_level3_force_values() -> Array[String]:
	return [
		force_input_1.text,
		force_input_2.text,
		force_input_3.text
	]

func set_level3_force_values(value_1: String, value_2: String, value_3: String) -> void:
	force_input_1.text = value_1
	force_input_2.text = value_2
	force_input_3.text = value_3

func reset_level3_inputs() -> void:
	force_input_1.clear()
	force_input_2.clear()
	force_input_3.clear()
	force_input_1.editable = true
	force_input_2.editable = true
	force_input_3.editable = true
	apply_forces_button.disabled = false

func lock_level3_inputs() -> void:
	force_input_1.editable = false
	force_input_2.editable = false
	force_input_3.editable = false
	apply_forces_button.disabled = true

func hide_level3_panel() -> void:
	level3_forces_panel.visible = false

func update_level3_markers(
	is_level3: bool,
	current_throw_index: int,
	target_x: float,
	starting_ball_y: float,
	distances_px: PackedFloat32Array,
	pixels_per_meter: float
) -> void:
	if not is_level3:
		for marker in level3_markers:
			marker.visible = false
		return
	
	_ensure_level3_markers()
	for i in range(level3_markers.size()):
		var distance_px: float = _get_distance_px(distances_px, i)
		var distance_m: float = distance_px / max(pixels_per_meter, 1.0)
		var marker := level3_markers[i]
		marker.visible = true
		marker.text = "● %.2f м" % distance_m
		marker.global_position = Vector2(target_x + 34.0, starting_ball_y - distance_px - 12.0)
		if i < current_throw_index:
			marker.modulate = Color(0.3, 1.0, 0.3, 0.95)
		elif i == current_throw_index:
			marker.modulate = Color(0.2, 0.7, 1.0, 1.0)
		else:
			marker.modulate = Color(1.0, 1.0, 1.0, 0.55)

func _ensure_level3_markers() -> void:
	if level3_markers.size() == LEVEL3_THROW_COUNT:
		return
	for marker in level3_markers:
		marker.queue_free()
	level3_markers.clear()
	for _i in range(LEVEL3_THROW_COUNT):
		var marker := Label.new()
		marker.visible = false
		host.add_child(marker)
		level3_markers.append(marker)

func _get_distance_px(distances_px: PackedFloat32Array, index: int) -> float:
	if distances_px.is_empty():
		return 0.0
	var max_index: int = min(distances_px.size(), LEVEL3_THROW_COUNT) - 1
	var clamped_index: int = clampi(index, 0, max(max_index, 0))
	return max(distances_px[clamped_index], 0.0)
