extends Node2D

const TargetRingControllerScript = preload("res://Scripts/target_ring_controller.gd")
const HeightIndicatorControllerScript = preload("res://Scripts/height_indicator_controller.gd")
const ThrowStateControllerScript = preload("res://Scripts/throw_state_controller.gd")
const PeakTriggerEvaluatorScript = preload("res://Scripts/peak_trigger_evaluator.gd")
const BallStateLegendControllerScript = preload("res://Scripts/ball_state_legend_controller.gd")
const BallScene = preload("res://Ball/ball.tscn")

@onready var ball: RigidBody2D = $Ball
@onready var player_node: Node2D = $Player
@onready var force_input: LineEdit = $UI/ForceInput
@onready var throw_button: Button = $UI/ThrowButton
@onready var next_level_button: Button = $UI/NextLevelButton
@onready var formula_label: Label = $UI/FormulaLabel
@onready var level_label: Label = $UI/LevelLabel
@onready var level3_forces_panel: VBoxContainer = $UI/Level3Forces
@onready var force_input_1: LineEdit = $UI/Level3Forces/ForceInput1
@onready var force_input_2: LineEdit = $UI/Level3Forces/ForceInput2
@onready var force_input_3: LineEdit = $UI/Level3Forces/ForceInput3
@onready var apply_forces_button: Button = $UI/Level3Forces/ApplyForcesButton
@onready var state_legend_panel: PanelContainer = $UI/StateLegend
@onready var gravity_ball_slot: Control = $UI/StateLegend/Margin/Content/GravityRow/GravityBallSlot
@onready var impulse_ball_slot: Control = $UI/StateLegend/Margin/Content/ImpulseRow/ImpulseBallSlot
@onready var gravity_description: Label = $UI/StateLegend/Margin/Content/GravityRow/GravityDescription
@onready var impulse_description: Label = $UI/StateLegend/Margin/Content/ImpulseRow/ImpulseDescription
@onready var player_sprite: Sprite2D = $Player/Sprite2D
@onready var height_line: Line2D = $HeightIndicator
@onready var height_label: Label = $HeightLabel
@onready var target_height_line: Sprite2D = $TargetHeightLine
@onready var target_distance_label: Label = $TargetDistanceLabel
@onready var camera: Camera2D = $Camera2D
@onready var professor_dialog_label: Label = $Professor/SpeechBubble/Margin/SpeechText

@export var hand_y_offset: float = 380.0
@export var pixels_per_meter: float = 100.0  # Conversion factor: 100 pixels = 1 meter
@export var line_x_offset: float = 50.0  # Distance from ball to line
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
@export var target_hit_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var force_outline_width_px: float = 4.0
@export var force_outline_red_base: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var force_outline_blue_base: Color = Color(0.2, 0.5, 1.0, 1.0)
@export var force_outline_blue_alpha: float = 0.9
@export var force_outline_red_min_alpha: float = 0.0
@export var force_outline_softness_px: float = 6.0
@export var force_outline_soft_layers: int = 6
@export_range(0.2, 0.49, 0.01) var force_outline_half_arc_ratio: float = 0.25
@export var force_red_fade_smooth_speed: float = 7.0
@export var level3_target_distances_px: PackedFloat32Array = PackedFloat32Array([380.0, 460.0, 540.0])

const TOTAL_LEVELS: int = 3
const LEVEL3_THROW_COUNT: int = 3
var starting_ball_y: float
var target_line_y: float  # Y position of the target line
var triggers_fired: Dictionary = {}  # Track which triggers have fired this throw
var current_level: int = 1
var level3_current_throw_index: int = 0
var level3_forces: Array[float] = []
var level3_forces_confirmed: bool = false
var level3_markers: Array[Label] = []
var camera_shake_controller: CameraShakeController
var force_outline_renderer: ForceOutlineRenderer
var target_ring_controller
var height_indicator_controller
var throw_state_controller
var peak_trigger_evaluator
var ball_state_legend_controller

func _get_active_target_distance_px() -> float:
	if target_distances_px.is_empty():
		return 232.69947052002
	var clamped_index: int = clampi(active_target_index, 0, target_distances_px.size() - 1)
	return max(target_distances_px[clamped_index], 0.0)

func _ready():
	var default_ball_position := ball.global_position
	starting_ball_y = default_ball_position.y
	var hand_position_y: float = default_ball_position.y + hand_y_offset 
	
	ball.freeze = true
	
	throw_button.pressed.connect(_on_throw_button_pressed)
	next_level_button.pressed.connect(_on_next_level_button_pressed)
	apply_forces_button.pressed.connect(_on_apply_level3_forces_pressed)
	
	force_input.text = "700"
	
	height_indicator_controller = HeightIndicatorControllerScript.new()
	height_indicator_controller.setup(
		self,
		height_line,
		height_label,
		line_x_offset,
		pixels_per_meter
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
	throw_state_controller = ThrowStateControllerScript.new()
	throw_state_controller.setup(
		ball,
		player_sprite,
		default_ball_position,
		hand_position_y,
		starting_ball_y,
		force_red_fade_smooth_speed
	)
	peak_trigger_evaluator = PeakTriggerEvaluatorScript.new()
	ball_state_legend_controller = BallStateLegendControllerScript.new()
	ball_state_legend_controller.setup(
		state_legend_panel,
		gravity_ball_slot,
		impulse_ball_slot,
		gravity_description,
		impulse_description,
		BallScene,
		pixels_per_meter,
		force_outline_blue_base,
		force_outline_red_base
	)
	
	_apply_fixed_z_order()
	_setup_force_outline()
	_apply_level_state()
	_professor_say("Профессор: уровень 1. Нажмите бросок, и я покажу идеальную траекторию.")
	
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
			_update_height_indicator()
		
		if throw_state_controller.did_reset_this_frame():
			triggers_fired.clear()  # Reset triggers
			if height_indicator_controller:
				height_indicator_controller.reset()
	
	_update_force_outline_visual()
		
func _on_throw_button_pressed():
	if throw_state_controller and throw_state_controller.is_throw_active():
		return
	
	triggers_fired.clear()  # Reset triggers for new throw
	_professor_say("Профессор: наблюдаю за траекторией...")
	
	var force_value: float = 0.0
	if current_level == 1:
		force_value = _calculate_required_impulse(_get_active_target_distance_px())
	elif current_level == 3:
		if not level3_forces_confirmed:
			_professor_say("Профессор: сначала введите и примените три силы.")
			return
		if level3_current_throw_index >= level3_forces.size():
			_professor_say("Профессор: все три броска уже выполнены.")
			return
		force_value = level3_forces[level3_current_throw_index]
	elif force_input and force_input.text != "":
		if not force_input.text.is_valid_float():
			_professor_say("Профессор: введите число в поле силы.")
			return
		force_value = float(force_input.text)
	else:
		force_value = 500.0
	
	if throw_state_controller:
		throw_state_controller.begin_throw_prep()
	
	await get_tree().process_frame
	
	if throw_state_controller:
		throw_state_controller.launch_throw(force_value)
	_update_force_outline_visual()

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

func _update_height_indicator():
	if not throw_state_controller or not throw_state_controller.is_throw_active():
		return
	
	if height_indicator_controller:
		height_indicator_controller.update_indicator(ball.global_position, starting_ball_y)

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
		var message := "ТРИГГЕР 1: Высочайшая точка шара ниже линии"
		print(message)
		_professor_say("Профессор: " + message)
	
	if result.get("above_line_triggered", false):
		var message := "ТРИГГЕР 2: Центр шара выше линии"
		print(message)
		_professor_say("Профессор: " + message)
		_start_camera_shake()  # Start earthquake effect
	
	if result.get("on_line_triggered", false):
		var message := "ТРИГГЕР 3: попадание в цель (dist=%.2f px)" % result.get("hit_distance", INF)
		print(message)
		if current_level == 3:
			_handle_level3_hit(message)
		elif current_level < TOTAL_LEVELS:
			next_level_button.visible = true
			_professor_say("Профессор: " + message + ". Нажмите «Перейти на следующий уровень».")
		else:
			_professor_say("Профессор: " + message + ". Все уровни пройдены!")
		if target_ring_controller:
			target_ring_controller.play_hit_fx()

func _on_next_level_button_pressed() -> void:
	if throw_state_controller and throw_state_controller.is_throw_active():
		return
	if current_level >= TOTAL_LEVELS:
		return
	current_level += 1
	next_level_button.visible = false
	triggers_fired.clear()
	if height_indicator_controller:
		height_indicator_controller.reset()
	_apply_level_state()
	if current_level == 3:
		_professor_say("Профессор: уровень 3. Введите три силы, нажмите «Применить 3 силы», затем бросайте по очереди в цели 1/3, 2/3 и 3/3.")
	else:
		_professor_say("Профессор: уровень %d. Теперь рассчитайте силу и бросайте." % current_level)

func _apply_level_state() -> void:
	level_label.text = "Уровень %d/%d" % [current_level, TOTAL_LEVELS]
	next_level_button.visible = false
	
	if current_level == 1:
		force_input.visible = false
		formula_label.visible = false
		level3_forces_panel.visible = false
		throw_button.disabled = false
		active_target_index = 0
	else:
		if current_level == 2:
			force_input.visible = true
			force_input.clear()
			formula_label.visible = true
			level3_forces_panel.visible = false
			throw_button.disabled = false
			active_target_index = min(1, target_distances_px.size() - 1)
		else:
			force_input.visible = false
			formula_label.visible = true
			level3_forces_panel.visible = true
			_reset_level3_state()
	
	_refresh_target_visual()
	_update_level3_markers()
	_update_formula_text()

func _on_apply_level3_forces_pressed() -> void:
	if current_level != 3:
		return
	
	var parsed_forces: Array[float] = []
	var fields: Array[LineEdit] = [force_input_1, force_input_2, force_input_3]
	for i in range(fields.size()):
		var text_value: String = fields[i].text.strip_edges()
		if text_value.is_empty() or not text_value.is_valid_float():
			_professor_say("Профессор: сила %d должна быть числом." % (i + 1))
			return
		var value: float = float(text_value)
		if value <= 0.0:
			_professor_say("Профессор: сила %d должна быть больше нуля." % (i + 1))
			return
		parsed_forces.append(value)
	
	level3_forces = parsed_forces
	level3_forces_confirmed = true
	throw_button.disabled = false
	force_input_1.editable = false
	force_input_2.editable = false
	force_input_3.editable = false
	apply_forces_button.disabled = true
	_professor_say("Профессор: силы сохранены. Бросайте в цель 1/3.")

func _handle_level3_hit(message: String) -> void:
	var completed_throw: int = level3_current_throw_index + 1
	if level3_current_throw_index < LEVEL3_THROW_COUNT - 1:
		level3_current_throw_index += 1
		_refresh_target_visual()
		_update_level3_markers()
		_professor_say(
			"Профессор: %s. Выполнено %d/3. Дождитесь возврата шара и бросайте в цель %d/3."
			% [message, completed_throw, level3_current_throw_index + 1]
		)
	else:
		throw_button.disabled = true
		level3_forces_panel.visible = false
		_professor_say("Профессор: " + message + ". Выполнено 3/3. Все уровни пройдены!")

func _reset_level3_state() -> void:
	level3_current_throw_index = 0
	level3_forces.clear()
	level3_forces_confirmed = false
	throw_button.disabled = true
	force_input_1.clear()
	force_input_2.clear()
	force_input_3.clear()
	force_input_1.editable = true
	force_input_2.editable = true
	force_input_3.editable = true
	apply_forces_button.disabled = false

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
	var target_distance_m: float = _get_current_target_distance_px() / pixels_per_meter
	target_distance_label.text = "%.2f м" % target_distance_m
	target_distance_label.global_position = Vector2(_get_target_x() + 28.0, target_line_y - 18.0)

func _get_current_target_distance_px() -> float:
	if current_level == 3:
		return _get_level3_target_distance_px(level3_current_throw_index)
	return _get_active_target_distance_px()

func _get_level3_target_distance_px(index: int) -> float:
	if level3_target_distances_px.is_empty():
		return 232.69947052002
	var max_index: int = min(level3_target_distances_px.size(), LEVEL3_THROW_COUNT) - 1
	var clamped_index: int = clampi(index, 0, max(max_index, 0))
	return max(level3_target_distances_px[clamped_index], 0.0)

func _update_level3_markers() -> void:
	if current_level != 3:
		for marker in level3_markers:
			marker.visible = false
		return
	
	_ensure_level3_markers()
	for i in range(level3_markers.size()):
		var distance_px: float = _get_level3_target_distance_px(i)
		var distance_m: float = distance_px / pixels_per_meter
		var marker := level3_markers[i]
		marker.visible = true
		marker.text = "● %.2f м" % distance_m
		marker.global_position = Vector2(_get_target_x() + 34.0, starting_ball_y - distance_px - 12.0)
		if i < level3_current_throw_index:
			marker.modulate = Color(0.3, 1.0, 0.3, 0.95)
		elif i == level3_current_throw_index:
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
		add_child(marker)
		level3_markers.append(marker)

func _update_formula_text() -> void:
	if current_level == 1:
		return
	if current_level == 2:
		var target_distance_m: float = _get_current_target_distance_px() / pixels_per_meter
		formula_label.text = "Формула: J = m * sqrt(2gh)\nДля цели: h = %.2f м" % target_distance_m
		return
	var h1: float = _get_level3_target_distance_px(0) / pixels_per_meter
	var h2: float = _get_level3_target_distance_px(1) / pixels_per_meter
	var h3: float = _get_level3_target_distance_px(2) / pixels_per_meter
	formula_label.text = "Формула: J = m * sqrt(2gh)\nЦели: h1=%.2f м, h2=%.2f м, h3=%.2f м" % [h1, h2, h3]

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

func _professor_say(text: String) -> void:
	if not professor_dialog_label:
		return
	professor_dialog_label.text = text

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
