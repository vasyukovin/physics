extends Node2D

const TargetRingControllerScript = preload("res://Scripts/target_ring_controller.gd")

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

var default_ball_position: Vector2 
var hand_position_y: float
var ball_is_thrown: bool = false
var max_ball_height: float = 0.0
var starting_ball_y: float
var target_line_y: float  # Y position of the target line
var previous_velocity_y: float = 0.0  # Previous frame's vertical velocity
var triggers_fired: Dictionary = {}  # Track which triggers have fired this throw
var throw_initial_upward_speed: float = 0.0
var throw_force_ratio: float = 0.0
var throw_force_visual_ratio: float = 0.0
var ball_left_hand_after_throw: bool = false
var camera_shake_controller: CameraShakeController
var force_outline_renderer: ForceOutlineRenderer
var target_ring_controller

func _ready():
	default_ball_position = ball.global_position
	starting_ball_y = default_ball_position.y
	hand_position_y = default_ball_position.y + hand_y_offset 
	
	ball.freeze = true
	
	throw_button.pressed.connect(_on_throw_button_pressed)
	
	force_input.text = "700"
	
	# Initialize height line
	if height_line:
		height_line.width = 2.0
		height_line.default_color = Color.RED
		height_line.visible = false

	# Initialize height label
	if height_label:
		height_label.visible = false
		height_label.add_theme_color_override("font_color", Color.RED)
		height_label.add_theme_font_size_override("font_size", 24)
	
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
	
	_apply_fixed_z_order()
	_setup_force_outline()
	
func _physics_process(_delta):
	# Update camera shake
	if camera_shake_controller:
		camera_shake_controller.update(_delta)
	
	if ball_is_thrown and not ball.freeze:
		var current_y = ball.global_position.y
		var current_velocity_y = ball.linear_velocity.y
		_update_throw_force_ratio(current_velocity_y, _delta)

		# Track maximum height (lowest Y value = highest up)
		if current_y < max_ball_height:
			max_ball_height = current_y

		# Detect peak: when velocity changes from negative (going up) to positive (going down)
		# or when velocity is close to zero and was negative before
		var is_at_peak = false
		if previous_velocity_y < 0 and current_velocity_y >= 0:
			is_at_peak = true
		elif abs(current_velocity_y) < 5.0 and previous_velocity_y < 0:
			is_at_peak = true
		
		# Check triggers at peak
		if is_at_peak and not triggers_fired.get("peak_checked", false):
			triggers_fired["peak_checked"] = true
			_check_peak_triggers(current_y)
		
		previous_velocity_y = current_velocity_y

		# Update height indicator
		_update_height_indicator()
		if not ball_left_hand_after_throw and current_y < default_ball_position.y - 1.0:
			ball_left_hand_after_throw = true
		
		# Calculate which frame to show (0, 1, or 2)
		# Frame 0 = ball at start (hands down)
		# Frame 1 = ball at middle
		# Frame 2 = ball at peak (hands up)
		var total_range = abs(max_ball_height - starting_ball_y)
		
		if total_range > 0:
			# How far is ball from starting position?
			var distance_from_start = abs(current_y - hand_position_y)
			var progress = distance_from_start / total_range
			
			# Map to frame (0, 1, or 2)
			# Going up: progress 0->1, frame 0->2
			# Coming down: progress 1->0, frame 2->0
			var frame = int(progress * 2.0)  # 0, 1, or 2
			frame = clamp(frame, 0, 2)
			
			# Directly set sprite frame
			player_sprite.frame = frame
		
		if ball_left_hand_after_throw and current_velocity_y >= 0.0 and current_y >= default_ball_position.y:
			ball.global_position = default_ball_position
			ball.linear_velocity = Vector2.ZERO
			ball.angular_velocity = 0.0
			ball.freeze = true
			ball_is_thrown = false
			ball_left_hand_after_throw = false
			player_sprite.frame = 0  # Reset to frame 0
			max_ball_height = 0.0
			triggers_fired.clear()  # Reset triggers
			previous_velocity_y = 0.0
			throw_force_ratio = 0.0
			throw_force_visual_ratio = 0.0
			if height_line:
				height_line.visible = false
			if height_label:
				height_label.visible = false
	
	_update_force_outline_visual()
		
func _on_throw_button_pressed():
	max_ball_height = default_ball_position.y
	player_sprite.frame = 0  # Start at frame 0
	triggers_fired.clear()  # Reset triggers for new throw
	previous_velocity_y = 0.0
	ball_left_hand_after_throw = false
	
	var force_value: float = 0.0
	if force_input and force_input.text != "":
		force_value = float(force_input.text)
	else:
		force_value = 500.0
	
	ball.freeze = true
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	
	await get_tree().process_frame
	
	ball.freeze = false
	ball.apply_impulse(Vector2(0, -force_value))
	throw_initial_upward_speed = max(-ball.linear_velocity.y, 1.0)
	throw_force_ratio = 1.0
	throw_force_visual_ratio = 1.0
	
	ball_is_thrown = true
	_update_force_outline_visual()

func _update_throw_force_ratio(current_velocity_y: float, delta: float) -> void:
	if throw_initial_upward_speed <= 0.0:
		throw_force_ratio = 0.0
		throw_force_visual_ratio = 0.0
		return
	
	# "Throw force" exists only while the ball still moves upward.
	var upward_speed = max(-current_velocity_y, 0.0)
	throw_force_ratio = clamp(upward_speed / throw_initial_upward_speed, 0.0, 1.0)
	
	# Smooth fade so red doesn't disappear abruptly near apex.
	var smooth_speed: float = max(force_red_fade_smooth_speed, 0.01)
	var blend: float = clamp(delta * smooth_speed, 0.0, 1.0)
	throw_force_visual_ratio = lerp(throw_force_visual_ratio, throw_force_ratio, blend)

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
		ball_is_thrown,
		ball.freeze,
		throw_force_visual_ratio,
		_get_ball_radius_px()
	)

func _update_height_indicator():
	if not ball_is_thrown or ball.freeze:
		return
	
	var ball_center = ball.global_position
	var reference_y = starting_ball_y  # Reference point (0 height)
	
	# Calculate height in pixels (Y increases downward, so lower Y = higher up)
	var height_pixels = reference_y - ball_center.y
	
	# Convert to meters
	# var height_meters = height_pixels / pixels_per_meter
	var height_meters = height_pixels
	
	# Only show if ball is above reference point
	if height_meters > 0:
		if height_line:
			height_line.visible = true
			
			# Position line next to ball (in global coordinates)
			var line_start_global = Vector2(ball_center.x + line_x_offset, reference_y)
			var line_end_global = Vector2(ball_center.x + line_x_offset, ball_center.y)
			
			# Convert to local coordinates (relative to HeightIndicator node)
			var line_start = height_line.to_local(line_start_global)
			var line_end = height_line.to_local(line_end_global)
			
			height_line.clear_points()
			height_line.add_point(line_start)
			height_line.add_point(line_end)
		
		# Update height label - show meters next to the ball
		if height_label:
			height_label.visible = true
			height_label.text = "%.2f m" % height_meters  # Format: "X.XX m"
			# Position label at the top of the line (at ball's current height)
			height_label.position = to_local(Vector2(ball_center.x + line_x_offset + 10, ball_center.y - 20))
			# print("Height label position: ", height_meters)
		else:
			if height_line:
				height_line.visible = false
			if height_label:
				height_label.visible = false

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

