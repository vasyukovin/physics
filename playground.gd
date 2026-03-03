extends Node2D

const TargetRingControllerScript = preload("res://Scripts/target_ring_controller.gd")
const HeightIndicatorControllerScript = preload("res://Scripts/height_indicator_controller.gd")
const ThrowStateControllerScript = preload("res://Scripts/throw_state_controller.gd")

@onready var ball: RigidBody2D = $Ball
@onready var player_node: Node2D = $Player
@onready var force_input: LineEdit = $UI/ForceInput
@onready var throw_button: Button = $UI/ThrowButton
@onready var player_sprite: Sprite2D = $Player/Sprite2D
@onready var height_line: Line2D = $HeightIndicator
@onready var height_label: Label = $HeightLabel
@onready var target_height_line: Sprite2D = $TargetHeightLine
@onready var camera: Camera2D = $Camera2D

@export var hand_y_offset: float = 380.0
@export var pixels_per_meter: float = 100.0  # Conversion factor: 100 pixels = 1 meter
@export var line_x_offset: float = 50.0  # Distance from ball to line
@export var shake_intensity: float = 15.0  # How strong the shake is
@export var shake_duration: float = 2  # How long the shake lasts (in seconds)
@export var player_z_index: int = 0
@export var force_outline_z_index: int = 1
@export var ball_z_index: int = 2

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

var starting_ball_y: float
var target_line_y: float  # Y position of the target line
var triggers_fired: Dictionary = {}  # Track which triggers have fired this throw
var camera_shake_controller: CameraShakeController
var force_outline_renderer: ForceOutlineRenderer
var target_ring_controller
var height_indicator_controller
var throw_state_controller

func _ready():
	var default_ball_position := ball.global_position
	starting_ball_y = default_ball_position.y
	var hand_position_y: float = default_ball_position.y + hand_y_offset 
	
	ball.freeze = true
	
	throw_button.pressed.connect(_on_throw_button_pressed)
	
	force_input.text = "700"
	
	height_indicator_controller = HeightIndicatorControllerScript.new()
	height_indicator_controller.setup(
		self,
		height_line,
		height_label,
		line_x_offset,
		pixels_per_meter
	)
	
	# Initialize static target height line above player
	target_line_y = starting_ball_y - 232.69947052002  # Fixed Y position above player
	target_ring_controller = TargetRingControllerScript.new()
	var target_x: float = ball.global_position.x
	if player_sprite:
		target_x = player_sprite.global_position.x
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
	
	_apply_fixed_z_order()
	_setup_force_outline()
	
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
	triggers_fired.clear()  # Reset triggers for new throw
	
	var force_value: float = 0.0
	if force_input and force_input.text != "":
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
	# Get ball radius from collision shape
	var ball_radius: float = 10.0  # Default fallback
	if ball.has_node("CollisionShape2D"):
		var collision_shape = ball.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			ball_radius = collision_shape.shape.radius
	
	# Calculate highest point of ball (top of ball = center_y - radius)
	var highest_point_y = ball_center_y - ball_radius
	
	# Trigger 1: Highest point is below the line
	# (Y increases downward, so higher Y = lower position)
	if highest_point_y > target_line_y:
		if not triggers_fired.get("below_line", false):
			triggers_fired["below_line"] = true
			print("ТРИГГЕР 1: Высочайшая точка шара ниже линии")
	
	# Trigger 2: Center of ball is above the line
	if ball_center_y < target_line_y:
		if not triggers_fired.get("above_line", false):
			triggers_fired["above_line"] = true
			print("ТРИГГЕР 2: Центр шара выше линии")
			_start_camera_shake()  # Start earthquake effect
	
	# Trigger 3: "Hit" when ball center is close enough to target circle center (2D distance)
	if target_ring_controller:
		var ball_pos := ball.global_position
		var dist: float = target_ring_controller.get_distance_to_target(ball_pos)
		
		# Note: ring radius is ball_radius + tolerance; for a "hit" we check center offset <= tolerance
		if target_ring_controller.is_hit(ball_pos):
			if not triggers_fired.get("on_line", false):
				triggers_fired["on_line"] = true
				print("ТРИГГЕР 3: попадание в цель (dist=%.2f px)" % dist)
				target_ring_controller.play_hit_fx()

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

