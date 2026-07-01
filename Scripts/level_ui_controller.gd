extends RefCounted
class_name LevelUiController

const LEVEL3_THROW_COUNT: int = 3
const TARGET_MARKER_COUNT: int = 3
const TARGET_MARKER_FONT_SIZE: int = 18
const TARGET_MARKER_OFFSET_X: float = 34.0

const MARKER_COLOR_ACTIVE := Color(0.32, 0.32, 0.32, 0.85)
const MARKER_COLOR_DONE := Color(0.19, 0.67, 0.12, 0.6)
const MARKER_COLOR_UPCOMING := Color(0.81, 0.81, 0.81, 0.75)

var host: Node2D
var force_input: LineEdit
var throw_button: Button
var next_level_button: Button
var level_label: Label
var level3_forces_panel: VBoxContainer
var force_input_1: LineEdit
var force_input_2: LineEdit
var force_input_3: LineEdit
var apply_forces_button: Button
var target_markers: Array[Label] = []

func setup(
	target_host: Node2D,
	target_force_input: LineEdit,
	target_throw_button: Button,
	target_next_level_button: Button,
	target_level_label: Label,
	target_level3_forces_panel: VBoxContainer,
	target_force_input_1: LineEdit,
	target_force_input_2: LineEdit,
	target_force_input_3: LineEdit,
	target_apply_forces_button: Button
) -> void:
	host = target_host
	force_input = target_force_input
	throw_button = target_throw_button
	next_level_button = target_next_level_button
	level_label = target_level_label
	level3_forces_panel = target_level3_forces_panel
	force_input_1 = target_force_input_1
	force_input_2 = target_force_input_2
	force_input_3 = target_force_input_3
	apply_forces_button = target_apply_forces_button

func apply_level_state(level: int, total_levels: int) -> void:
	level_label.text = "Уровень %d/%d" % [level, total_levels]
	show_next_level_button(false)
	
	if level == 1:
		force_input.visible = false
		level3_forces_panel.visible = false
		throw_button.disabled = false
	elif level == 2:
		force_input.visible = true
		force_input.clear()
		level3_forces_panel.visible = false
		throw_button.disabled = false
	else:
		force_input.visible = false
		level3_forces_panel.visible = true
		throw_button.disabled = true

func show_next_level_button(visible: bool) -> void:
	next_level_button.visible = visible
	if next_level_button.has_method("set_attention_active"):
		next_level_button.set_attention_active(visible)

func set_throw_button_disabled(disabled: bool) -> void:
	throw_button.disabled = disabled

func set_force_input_value(value_text: String) -> void:
	force_input.text = value_text

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

func update_target_markers(
	level: int,
	current_throw_index: int,
	target_x: float,
	starting_ball_y: float,
	level3_distances_px: PackedFloat32Array,
	pixels_per_meter: float,
	single_target_distance_px: float,
	target_line_y: float
) -> void:
	_ensure_target_markers()
	if level == 3:
		for i in range(target_markers.size()):
			var distance_px: float = _get_distance_px(level3_distances_px, i)
			var distance_m: float = distance_px / max(pixels_per_meter, 1.0)
			var marker := target_markers[i]
			var marker_line_y: float = starting_ball_y - distance_px
			marker.visible = true
			_set_marker_text(marker, distance_m)
			_place_marker(marker, target_x, marker_line_y)
			if i < current_throw_index:
				marker.add_theme_color_override("font_color", MARKER_COLOR_DONE)
			elif i == current_throw_index:
				marker.add_theme_color_override("font_color", MARKER_COLOR_ACTIVE)
			else:
				marker.add_theme_color_override("font_color", MARKER_COLOR_UPCOMING)
		return
	
	for i in range(target_markers.size()):
		target_markers[i].visible = i == 0
	if target_markers.is_empty():
		return
	var distance_m: float = single_target_distance_px / max(pixels_per_meter, 1.0)
	var marker := target_markers[0]
	_set_marker_text(marker, distance_m)
	_place_marker(marker, target_x, target_line_y)
	marker.add_theme_color_override("font_color", MARKER_COLOR_ACTIVE)

func _set_marker_text(marker: Label, distance_m: float) -> void:
	marker.text = "%.2f м" % distance_m

func _place_marker(marker: Label, target_x: float, marker_line_y: float) -> void:
	var text_size := marker.get_minimum_size()
	marker.global_position = Vector2(
		target_x + TARGET_MARKER_OFFSET_X,
		marker_line_y - text_size.y * 0.5
	)

func _ensure_target_markers() -> void:
	if target_markers.size() == TARGET_MARKER_COUNT:
		return
	for marker in target_markers:
		marker.queue_free()
	target_markers.clear()
	for _i in range(TARGET_MARKER_COUNT):
		var marker := Label.new()
		marker.add_theme_font_size_override("font_size", TARGET_MARKER_FONT_SIZE)
		marker.add_theme_color_override("font_color", MARKER_COLOR_UPCOMING)
		var marker_font: Font = load("res://Assets/Fonts/Lora-Regular.ttf")
		marker.add_theme_font_override("font", marker_font)
		marker.modulate = Color.WHITE
		marker.visible = false
		host.add_child(marker)
		target_markers.append(marker)

func _get_distance_px(distances_px: PackedFloat32Array, index: int) -> float:
	if distances_px.is_empty():
		return 0.0
	var max_index: int = min(distances_px.size(), LEVEL3_THROW_COUNT) - 1
	var clamped_index: int = clampi(index, 0, max(max_index, 0))
	return max(distances_px[clamped_index], 0.0)
