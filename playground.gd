extends Node2D

const TargetRingControllerScript = preload("res://Scripts/target_ring_controller.gd")
const ThrowStateControllerScript = preload("res://Scripts/throw_state_controller.gd")
const PeakTriggerEvaluatorScript = preload("res://Scripts/peak_trigger_evaluator.gd")
const LevelProgressionControllerScript = preload("res://Scripts/level_progression_controller.gd")
const Level3SequenceControllerScript = preload("res://Scripts/level3_sequence_controller.gd")
const LevelUiControllerScript = preload("res://Scripts/level_ui_controller.gd")
const ProfessorDialogueControllerScript = preload("res://Scripts/professor_dialogue_controller.gd")
const CameraFollowControllerScript = preload("res://Scripts/camera_follow_controller.gd")
const BallScene = preload("res://Ball/ball.tscn")

@onready var ball: RigidBody2D = $Ball
@onready var player_node: Node2D = $Player
@onready var professor_node: Node2D = $Professor
@onready var force_input: LineEdit = $UILayer/UI/BottomBar/ForceInput
@onready var throw_button: Button = $UILayer/UI/BottomBar/ThrowButton
@onready var next_level_button: Button = $UILayer/UI/TopBar/NextLevelButton
@onready var restart_button: Button = $UILayer/UI/TopBar/RestartButton
@onready var level_label: Label = $UILayer/UI/TopBar/LevelLabel
@onready var level3_forces_panel: VBoxContainer = $UILayer/UI/Level3Forces
@onready var force_input_1: LineEdit = $UILayer/UI/Level3Forces/ForceInput1
@onready var force_input_2: LineEdit = $UILayer/UI/Level3Forces/ForceInput2
@onready var force_input_3: LineEdit = $UILayer/UI/Level3Forces/ForceInput3
@onready var apply_forces_button: Button = $UILayer/UI/Level3Forces/ApplyForcesButton
@onready var player_sprite: Sprite2D = $Player/Sprite2D
@onready var target_height_line: Sprite2D = $TargetHeightLine
@onready var camera: Camera2D = $Camera2D
@onready var professor_dialog_label: Label = $UILayer/UI/SpeechBubble/Margin/SpeechText
@onready var ui_root: Control = $UILayer/UI
@onready var speech_bubble: PanelContainer = $UILayer/UI/SpeechBubble

const SPEECH_BUBBLE_ABOVE_HEAD_OFFSET := Vector2(0.0, -10.0)

@export var hand_y_offset: float = 380.0
@export var pixels_per_meter: float = 100.0  # Conversion factor: 100 pixels = 1 meter
@export var shake_intensity: float = 15.0  # How strong the shake is
@export var shake_duration: float = 2  # How long the shake lasts (in seconds)
@export var player_z_index: int = 0
@export var force_outline_z_index: int = 1
@export var ball_z_index: int = 2
@export var target_distances_px: PackedFloat32Array = PackedFloat32Array([232.69947052002, 300.0, 380.0])
@export var active_target_index: int = 0

# Target ring (procedural circle indicator)
@export var target_tolerance_px: float = 10.0  # Allowed center offset for a "hit"
@export var target_ring_line_width_px: float = 3.0
@export var target_ring_idle_alpha: float = 0.25
@export var target_hit_color: Color = SiteColors.GREEN
@export var force_outline_width_px: float = 4.0
@export var force_outline_red_base: Color = SiteColors.PRIMARY
@export var force_outline_blue_base: Color = SiteColors.BLUE
@export var force_outline_blue_alpha: float = 0.9
@export var force_outline_red_min_alpha: float = 0.0
@export var force_outline_softness_px: float = 6.0
@export var force_outline_soft_layers: int = 6
@export_range(0.2, 0.49, 0.01) var force_outline_half_arc_ratio: float = 0.25
@export var force_red_fade_smooth_speed: float = 7.0
@export var level3_target_distances_px: PackedFloat32Array = PackedFloat32Array([380.0, 460.0, 540.0])
@export var camera_follow_smooth_speed: float = 6.0
@export var autofill_test_force_values: bool = true
@export var professor_verdict_delay_sec: float = 0.4
@export var professor_typewriter_enabled: bool = true

const TOTAL_LEVELS: int = 3
const LEVEL3_THROW_COUNT: int = 3
var starting_ball_y: float
var target_line_y: float  # Y position of the target line
var triggers_fired: Dictionary = {}  # Track which triggers have fired this throw
var camera_shake_controller: CameraShakeController
var camera_follow_controller
var force_outline_renderer: ForceOutlineRenderer
var target_ring_controller
var throw_state_controller
var peak_trigger_evaluator
var level_progression_controller
var level3_sequence_controller
var level_ui_controller
var professor_dialogue_controller: ProfessorDialogueController

func _get_active_target_distance_px() -> float:
	if target_distances_px.is_empty():
		return 232.69947052002
	var clamped_index: int = clampi(active_target_index, 0, target_distances_px.size() - 1)
	return max(target_distances_px[clamped_index], 0.0)

func _get_character_head_global_position(character_root: Node2D) -> Vector2:
	var sprite: Sprite2D = null
	if character_root.has_node("Sprite2D"):
		sprite = character_root.get_node("Sprite2D") as Sprite2D
	elif character_root.has_node("ProfessorSprite"):
		sprite = character_root.get_node("ProfessorSprite") as Sprite2D
	if not sprite:
		return character_root.global_position
	
	var head_y: float = sprite.global_position.y
	if sprite.texture:
		head_y -= sprite.texture.get_height() * sprite.scale.y * 0.5
	return Vector2(sprite.global_position.x, head_y)

func _get_camera_home_position() -> Vector2:
	var player_head := _get_character_head_global_position(player_node)
	var professor_head := _get_character_head_global_position(professor_node)
	return (player_head + professor_head) * 0.5

func _current_level() -> int:
	if level_progression_controller:
		return level_progression_controller.get_current_level()
	return 1

func _ready() -> void:
	_apply_site_theme()

	var default_ball_position := ball.global_position
	starting_ball_y = default_ball_position.y
	var hand_position_y: float = default_ball_position.y + hand_y_offset 
	
	ball.freeze = true
	
	throw_button.pressed.connect(_on_throw_button_pressed)
	next_level_button.pressed.connect(_on_next_level_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	apply_forces_button.pressed.connect(_on_apply_level3_forces_pressed)
	
	force_input.text = "700"
	
	level_progression_controller = LevelProgressionControllerScript.new()
	level_progression_controller.setup(TOTAL_LEVELS)
	level3_sequence_controller = Level3SequenceControllerScript.new()
	level_ui_controller = LevelUiControllerScript.new()
	level_ui_controller.setup(
		self,
		force_input,
		throw_button,
		next_level_button,
		restart_button,
		level_label,
		level3_forces_panel,
		force_input_1,
		force_input_2,
		force_input_3,
		apply_forces_button
	)
	
	# Initialize target line from configured distances above player.
	target_line_y = starting_ball_y - _get_active_target_distance_px()
	target_ring_controller = TargetRingControllerScript.new()
	var target_x: float = _get_target_x()
	target_ring_controller.setup(
		self,
		target_height_line,
		target_line_y,
		target_x,
		_get_ball_radius_px(),
		target_tolerance_px,
		target_ring_line_width_px,
		target_ring_idle_alpha,
		target_hit_color
	)

	camera_shake_controller = CameraShakeController.new()
	camera_shake_controller.setup(camera, shake_intensity, shake_duration)
	camera.global_position = _get_camera_home_position()
	throw_state_controller = ThrowStateControllerScript.new()
	throw_state_controller.setup(
		ball,
		player_sprite,
		default_ball_position,
		hand_position_y,
		starting_ball_y,
		force_red_fade_smooth_speed
	)
	camera_follow_controller = CameraFollowControllerScript.new()
	camera_follow_controller.setup(
		camera,
		ball,
		throw_state_controller,
		camera_follow_smooth_speed
	)
	peak_trigger_evaluator = PeakTriggerEvaluatorScript.new()
	professor_dialogue_controller = ProfessorDialogueControllerScript.new()
	professor_dialogue_controller.setup(
		self,
		professor_dialog_label,
		professor_verdict_delay_sec,
		professor_typewriter_enabled
	)
	
	_apply_fixed_z_order()
	_setup_force_outline()
	_apply_level_state()
	await professor_dialogue_controller.on_level_started(1, false)
	
func _physics_process(_delta):
	# Update camera shake
	if camera_shake_controller:
		camera_shake_controller.update(_delta)
	
	if throw_state_controller:
		throw_state_controller.physics_step(_delta)
		if throw_state_controller.did_process_frame():
			if throw_state_controller.is_at_peak_this_frame() and not triggers_fired.get("peak_checked", false):
				triggers_fired["peak_checked"] = true
				_check_peak_triggers(throw_state_controller.get_current_y())
		
		if throw_state_controller.did_reset_this_frame():
			triggers_fired.clear()  # Reset triggers
			_schedule_professor_verdict_delivery()
	
	if camera_follow_controller:
		camera_follow_controller.update(_delta)
	_update_force_outline_visual()
	_update_speech_bubble_position()
		
func _on_throw_button_pressed():
	if throw_state_controller and throw_state_controller.is_throw_active():
		return
	
	var force_value: float = 0.0
	if _current_level() == 1:
		force_value = _calculate_required_impulse(_get_active_target_distance_px())
	elif _current_level() == 3:
		if not level3_sequence_controller or not level3_sequence_controller.forces_confirmed:
			await professor_dialogue_controller.on_input_error("need_forces")
			return
		if level3_sequence_controller.auto_sequence_running:
			return
		if level3_sequence_controller.is_finished():
			await professor_dialogue_controller.on_input_error("series_done")
			return
		if not level3_sequence_controller.can_start_sequence():
			await professor_dialogue_controller.on_input_error("missing_forces")
			return
		level3_sequence_controller.start_sequence()
		level_ui_controller.set_throw_button_disabled(true)
		await _run_level3_auto_sequence()
		level3_sequence_controller.stop_sequence()
		if _current_level() == 3 and not level3_sequence_controller.is_finished():
			level_ui_controller.set_throw_button_disabled(false)
		return
	elif force_input and force_input.text != "":
		if not force_input.text.is_valid_float():
			await professor_dialogue_controller.on_input_error("invalid_force")
			return
		force_value = float(force_input.text)
	else:
		force_value = 500.0
	
	await _start_throw_with_force(force_value)

func _setup_force_outline() -> void:
	force_outline_renderer = ForceOutlineRenderer.new()
	force_outline_renderer.setup(
		ball,
		force_outline_z_index,
		force_outline_width_px,
		force_outline_red_base,
		force_outline_blue_base,
		force_outline_blue_alpha,
		force_outline_red_min_alpha,
		force_outline_softness_px,
		force_outline_soft_layers,
		force_outline_half_arc_ratio
	)

func _apply_fixed_z_order() -> void:
	if player_node:
		player_node.z_as_relative = false
		player_node.z_index = player_z_index
	
	if ball:
		ball.z_as_relative = false
		ball.z_index = ball_z_index

func _update_force_outline_visual() -> void:
	if not force_outline_renderer:
		return
	
	force_outline_renderer.update_visual(
		throw_state_controller and throw_state_controller.is_ball_thrown(),
		ball.freeze,
		throw_state_controller.get_throw_force_visual_ratio() if throw_state_controller else 0.0,
		_get_ball_radius_px()
	)

func _check_peak_triggers(ball_center_y: float):
	if not peak_trigger_evaluator:
		return
	
	var result: Dictionary = peak_trigger_evaluator.evaluate_peak(
		ball_center_y,
		_get_ball_radius_px(),
		target_line_y,
		ball.global_position,
		target_ring_controller,
		triggers_fired
	)
	
	if result.get("below_line_triggered", false):
		print("ТРИГГЕР 1: Высочайшая точка шара ниже линии")
		if professor_dialogue_controller:
			professor_dialogue_controller.queue_throw_verdict(
				ProfessorDialogueControllerScript.ThrowOutcome.TOO_LOW
			)
	
	if result.get("above_line_triggered", false):
		print("ТРИГГЕР 2: Центр шара выше линии")
		if professor_dialogue_controller:
			professor_dialogue_controller.queue_throw_verdict(
				ProfessorDialogueControllerScript.ThrowOutcome.TOO_HIGH
			)
		_start_camera_shake()  # Start earthquake effect
	
	if result.get("on_line_triggered", false):
		print(
			"ТРИГГЕР 3: попадание в цель (dist=%.2f px)" % result.get("hit_distance", INF)
		)
		if _is_level3_series_active():
			level3_sequence_controller.register_hit()
			if professor_dialogue_controller:
				professor_dialogue_controller.clear_pending_verdict()
		elif professor_dialogue_controller:
			var can_go_next := _current_level() < TOTAL_LEVELS
			var is_final_level := _current_level() >= TOTAL_LEVELS
			professor_dialogue_controller.queue_throw_verdict(
				ProfessorDialogueControllerScript.ThrowOutcome.HIT,
				can_go_next,
				is_final_level
			)
			if can_go_next and level_ui_controller:
				level_ui_controller.show_next_level_button(true)
		if target_ring_controller:
			target_ring_controller.play_hit_fx()

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_next_level_button_pressed() -> void:
	if throw_state_controller and throw_state_controller.is_throw_active():
		return
	if not level_progression_controller or not level_progression_controller.can_go_next():
		return
	level_progression_controller.go_next()
	level_ui_controller.show_next_level_button(false)
	triggers_fired.clear()
	_apply_level_state()
	if professor_dialogue_controller:
		var autofill := _current_level() == 3 and autofill_test_force_values
		await professor_dialogue_controller.on_level_started(_current_level(), autofill)

func _apply_level_state() -> void:
	if level_ui_controller:
		level_ui_controller.apply_level_state(_current_level(), TOTAL_LEVELS)
	
	if _current_level() == 1:
		active_target_index = 0
	elif _current_level() == 2:
		active_target_index = min(1, target_distances_px.size() - 1)
	else:
		_reset_level3_state()
	
	_refresh_target_visual()
	_update_target_markers()
	_apply_test_force_defaults_if_needed()

func _on_apply_level3_forces_pressed() -> void:
	if _current_level() != 3:
		return
	
	var result: Dictionary = level3_sequence_controller.validate_and_apply_forces(
		level_ui_controller.get_level3_force_values()
	)
	if not result.get("ok", false):
		await professor_dialogue_controller.on_force_validation_error(
			result.get("error", "Ошибка ввода сил.")
		)
		return
	level_ui_controller.lock_level3_inputs()
	level_ui_controller.set_throw_button_disabled(false)
	await professor_dialogue_controller.on_forces_applied()

func _reset_level3_state() -> void:
	if level3_sequence_controller:
		level3_sequence_controller.reset_state()
	if level_ui_controller:
		level_ui_controller.reset_level3_inputs()
		level_ui_controller.set_throw_button_disabled(true)

func _refresh_target_visual() -> void:
	target_line_y = starting_ball_y - _get_current_target_distance_px()
	if target_ring_controller:
		target_ring_controller.setup(
			self,
			target_height_line,
			target_line_y,
			_get_target_x(),
			_get_ball_radius_px(),
			target_tolerance_px,
			target_ring_line_width_px,
			target_ring_idle_alpha,
			target_hit_color
		)
func _get_current_target_distance_px() -> float:
	if _current_level() == 3 and level3_sequence_controller:
		return _get_level3_target_distance_px(level3_sequence_controller.current_throw_index)
	return _get_active_target_distance_px()

func _get_level3_target_distance_px(index: int) -> float:
	if level3_target_distances_px.is_empty():
		return 232.69947052002
	var max_index: int = min(level3_target_distances_px.size(), LEVEL3_THROW_COUNT) - 1
	var clamped_index: int = clampi(index, 0, max(max_index, 0))
	return max(level3_target_distances_px[clamped_index], 0.0)

func _update_target_markers() -> void:
	if not level_ui_controller:
		return
	var throw_index: int = 0
	if level3_sequence_controller:
		throw_index = level3_sequence_controller.current_throw_index
	level_ui_controller.update_target_markers(
		_current_level(),
		throw_index,
		_get_target_x(),
		starting_ball_y,
		level3_target_distances_px,
		pixels_per_meter,
		_get_current_target_distance_px(),
		target_line_y
	)

func _run_level3_auto_sequence() -> void:
	if professor_dialogue_controller:
		professor_dialogue_controller.set_series_silent(true)
	while _current_level() == 3 and level3_sequence_controller and not level3_sequence_controller.is_finished():
		if level3_sequence_controller.current_throw_index >= level3_sequence_controller.forces.size():
			if professor_dialogue_controller:
				professor_dialogue_controller.set_series_silent(false)
				await professor_dialogue_controller.on_input_error("missing_force_values")
			return
		level3_sequence_controller.mark_throw_started()
		_refresh_target_visual()
		_update_target_markers()
		await _start_throw_with_force(level3_sequence_controller.get_current_force())
		await _wait_until_ball_returns_to_hand()
		if _current_level() != 3:
			if professor_dialogue_controller:
				professor_dialogue_controller.set_series_silent(false)
			return
		if not level3_sequence_controller.was_hit_this_throw():
			if professor_dialogue_controller:
				professor_dialogue_controller.clear_pending_verdict()
		level3_sequence_controller.complete_current_throw()
	
	if _current_level() == 3 and level3_sequence_controller and level3_sequence_controller.is_finished():
		level_ui_controller.set_throw_button_disabled(true)
		level_ui_controller.hide_level3_panel()
		_update_target_markers()
		if professor_dialogue_controller:
			professor_dialogue_controller.set_series_silent(false)
			await professor_dialogue_controller.on_series_finished(
				level3_sequence_controller.get_hits_count(),
				level3_sequence_controller.get_throw_count()
			)
		if level_ui_controller:
			level_ui_controller.show_restart_button(true)

func _start_throw_with_force(force_value: float) -> void:
	triggers_fired.clear()  # Reset triggers for new throw
	if throw_state_controller:
		throw_state_controller.begin_throw_prep()
	await get_tree().process_frame
	if throw_state_controller:
		throw_state_controller.launch_throw(force_value)
	_update_force_outline_visual()

func _wait_until_ball_returns_to_hand() -> void:
	while true:
		await get_tree().process_frame
		if not throw_state_controller:
			return
		if not throw_state_controller.is_throw_active() and ball and ball.freeze:
			return

func _get_target_x() -> float:
	var target_x: float = ball.global_position.x
	if player_sprite:
		target_x = player_sprite.global_position.x
	return target_x

func _calculate_required_impulse(distance_px: float) -> float:
	var gravity_px: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var speed_px: float = sqrt(max(2.0 * gravity_px * max(distance_px, 0.0), 0.0))
	var ball_mass: float = 1.0
	if ball:
		ball_mass = max(ball.mass, 0.001)
	return ball_mass * speed_px

func _apply_test_force_defaults_if_needed() -> void:
	if not autofill_test_force_values or not level_ui_controller:
		return
	
	if _current_level() == 1:
		var level1_force := _calculate_required_impulse(_get_active_target_distance_px())
		level_ui_controller.set_force_input_value(_format_force_value(level1_force))
		return
	
	if _current_level() == 2:
		var level2_force := _calculate_required_impulse(_get_active_target_distance_px())
		level_ui_controller.set_force_input_value(_format_force_value(level2_force))
		return
	
	var f1: float = _calculate_required_impulse(_get_level3_target_distance_px(0))
	var f2: float = _calculate_required_impulse(_get_level3_target_distance_px(1))
	var f3: float = _calculate_required_impulse(_get_level3_target_distance_px(2))
	level_ui_controller.set_level3_force_values(
		_format_force_value(f1),
		_format_force_value(f2),
		_format_force_value(f3)
	)

func _format_force_value(value: float) -> String:
	return "%.2f" % value

func _is_level3_series_active() -> bool:
	return (
		_current_level() == 3
		and level3_sequence_controller
		and level3_sequence_controller.auto_sequence_running
	)


func _schedule_professor_verdict_delivery() -> void:
	if not professor_dialogue_controller or not professor_dialogue_controller.has_pending_verdict():
		return
	if _is_level3_series_active():
		return
	_deliver_professor_verdict.call_deferred()


func _deliver_professor_verdict() -> void:
	if professor_dialogue_controller:
		await professor_dialogue_controller.deliver_pending_verdict()


func _start_camera_shake():
	"""Start the camera shake effect (earthquake)"""
	if camera_shake_controller:
		camera_shake_controller.start()

func _update_camera_shake(delta: float):
	"""Update camera shake effect each frame"""
	if camera_shake_controller:
		camera_shake_controller.update(delta)

func _get_ball_radius_px() -> float:
	# 1) Prefer collision radius (physics-accurate)
	if ball and ball.has_node("CollisionShape2D"):
		var cs := ball.get_node("CollisionShape2D") as CollisionShape2D
		if cs and cs.shape is CircleShape2D:
			var r := (cs.shape as CircleShape2D).radius
			if r > 0.0:
				return r
	
	# 2) Fallback: estimate from sprite size * scale
	if ball and ball.has_node("Sprite2D"):
		var s := ball.get_node("Sprite2D") as Sprite2D
		if s and s.texture:
			var size := s.texture.get_size()
			return 0.5 * size.x * s.scale.x
	
	return 10.0


func _get_speech_bubble_anchor_world() -> Vector2:
	return _get_character_head_global_position(professor_node) + SPEECH_BUBBLE_ABOVE_HEAD_OFFSET


func _world_to_ui_canvas(world_pos: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return (world_pos - camera.global_position) * camera.zoom + viewport_size * 0.5


func _update_speech_bubble_position() -> void:
	var anchor_screen := _world_to_ui_canvas(_get_speech_bubble_anchor_world())
	var bubble_size := speech_bubble.size
	speech_bubble.position = (
		anchor_screen - Vector2(bubble_size.x * 0.5, bubble_size.y)
	).round()


func _apply_site_theme() -> void:
	var theme: Theme = load("res://Theme/site_theme.tres")
	if theme:
		ui_root.theme = theme
	else:
		ui_root.theme = SiteThemeBuilder.build()
	speech_bubble.add_theme_stylebox_override("panel", SiteThemeBuilder.build_professor_bubble_style())

	var font_italic: Font = load("res://Assets/Fonts/Lora-Italic.ttf")
	professor_dialog_label.add_theme_font_override("font", font_italic)
	professor_dialog_label.add_theme_color_override("font_color", SiteColors.TEXT)

	var font_semibold: Font = load("res://Assets/Fonts/Lora-SemiBold.ttf")
	level_label.add_theme_font_override("font", font_semibold)
	level_label.add_theme_color_override("font_color", SiteColors.TEXT)
