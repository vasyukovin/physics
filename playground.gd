extends Node2D

@onready var ball: RigidBody2D = $Ball
@onready var force_input: LineEdit = $UI/ForceInput
@onready var throw_button: Button = $UI/ThrowButton
@onready var player_sprite: Sprite2D = $Player/Sprite2D

@export var hand_y_offset: float = 380.0

var default_ball_position: Vector2 
var hand_position_y: float
var ball_is_thrown: bool = false
var max_ball_height: float = 0.0
var starting_ball_y: float

func _ready():
	default_ball_position = ball.global_position
	starting_ball_y = default_ball_position.y
	hand_position_y = default_ball_position.y + hand_y_offset 
	
	ball.freeze = true
	
	throw_button.pressed.connect(_on_throw_button_pressed)
	
	force_input.text = "1000"
	force_input.placeholder_text = "Enter force (e.g., 500)"
	
func _physics_process(_delta):
	if ball_is_thrown and not ball.freeze:
		var current_y = ball.global_position.y
		
		# Track maximum height (lowest Y value = highest up)
		if current_y < max_ball_height:
			max_ball_height = current_y
		
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
		
func _on_throw_button_pressed():
	max_ball_height = default_ball_position.y
	player_sprite.frame = 0  # Start at frame 0
	
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
