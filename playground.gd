extends Node2D

@onready var ball: RigidBody2D = $Ball
@onready var force_input: LineEdit = $UI/ForceInput
@onready var throw_button: Button = $UI/ThrowButton
@onready var player_animation: AnimationPlayer = $Player/AnimationPlayer

var default_ball_position: Vector2 
var ball_is_thrown: bool = false

func _ready():
	default_ball_position = ball.global_position
	
	ball.freeze = true
	
	throw_button.pressed.connect(_on_throw_button_pressed)
	
	force_input.text = "300"
	force_input.placeholder_text = "Enter force (e.g., 500)"
	
func _physics_process(_delta):
	if ball_is_thrown and not ball.freeze:
		if ball.global_position.y >= default_ball_position.y:
			ball.global_position = default_ball_position
			#player_animation.play("RESET")
		
func _on_throw_button_pressed():
	player_animation.play("hands_up")
	
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
	
	await get_tree().create_timer(1.0).timeout
	
	player_animation.play("RESET")
	
	ball_is_thrown = true
