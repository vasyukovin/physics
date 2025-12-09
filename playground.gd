extends Node2D

@onready var ball: RigidBody2D = $Ball
@onready var force_input: LineEdit = $UI/ForceInput
@onready var throw_button: Button = $UI/ThrowButton
@onready var player_sprite: Sprite2D = $Player/Sprite2D
@onready var height_line: Line2D = $HeightIndicator
@onready var height_label: Label = $HeightLabel
@onready var target_height_line: Line2D = $TargetHeightLine

@export var hand_y_offset: float = 380.0
@export var pixels_per_meter: float = 100.0  # Conversion factor: 100 pixels = 1 meter
@export var line_x_offset: float = 50.0  # Distance from ball to line

var default_ball_position: Vector2 
var hand_position_y: float
var ball_is_thrown: bool = false
var max_ball_height: float = 0.0
var starting_ball_y: float
var target_line_y: float  # Y position of the target line
var previous_velocity_y: float = 0.0  # Previous frame's vertical velocity
var triggers_fired: Dictionary = {}  # Track which triggers have fired this throw

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
	if target_height_line:
		target_height_line.width = 3.0
		target_height_line.default_color = Color(0.6, 0.4, 0.2)  # Brown color
		target_height_line.visible = true
		
		# Create a static horizontal line above the player
		var line_length: float = 2000.0
		target_line_y = starting_ball_y - 232.69947052002  # Fixed Y position above player
		
		target_height_line.clear_points()
		target_height_line.add_point(Vector2(-line_length, target_line_y))
		target_height_line.add_point(Vector2(line_length, target_line_y))
	
func _physics_process(_delta):
	if ball_is_thrown and not ball.freeze:
		var current_y = ball.global_position.y
		var current_velocity_y = ball.linear_velocity.y

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
		
		if current_y >= default_ball_position.y:
			ball.global_position = default_ball_position
			player_sprite.frame = 0  # Reset to frame 0
			max_ball_height = 0.0
			triggers_fired.clear()  # Reset triggers
			previous_velocity_y = 0.0
			if height_line:
				height_line.visible = false
			if height_label:
				height_label.visible = false
		
func _on_throw_button_pressed():
	max_ball_height = default_ball_position.y
	player_sprite.frame = 0  # Start at frame 0
	triggers_fired.clear()  # Reset triggers for new throw
	previous_velocity_y = 0.0
	
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
	
	ball_is_thrown = true

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
	
	# Tolerance for "perfectly on line"
	var tolerance: float = 10.0
	
	# Calculate distance from center to line
	var distance_from_line = abs(ball_center_y - target_line_y)
	
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
	
	# Trigger 3: Center of ball is on the line (within tolerance)
	if distance_from_line <= tolerance:
		if not triggers_fired.get("on_line", false):
			triggers_fired["on_line"] = true
			print("ТРИГГЕР 3: Центр шара идеально на линии (погрешность: %.2f пикселей)" % distance_from_line)
