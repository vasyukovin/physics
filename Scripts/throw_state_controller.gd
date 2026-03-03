extends RefCounted
class_name ThrowStateController

var ball: RigidBody2D
var player_sprite: Sprite2D
var default_ball_position: Vector2 = Vector2.ZERO
var hand_position_y: float = 0.0
var starting_ball_y: float = 0.0
var force_red_fade_smooth_speed: float = 7.0

var ball_is_thrown: bool = false
var max_ball_height: float = 0.0
var previous_velocity_y: float = 0.0
var throw_initial_upward_speed: float = 0.0
var throw_force_ratio: float = 0.0
var throw_force_visual_ratio: float = 0.0
var ball_left_hand_after_throw: bool = false

var frame_processed: bool = false
var frame_peak_detected: bool = false
var frame_reset_detected: bool = false
var frame_current_y: float = 0.0

func setup(
	target_ball: RigidBody2D,
	target_player_sprite: Sprite2D,
	target_default_ball_position: Vector2,
	target_hand_position_y: float,
	target_starting_ball_y: float,
	target_force_red_fade_smooth_speed: float
) -> void:
	ball = target_ball
	player_sprite = target_player_sprite
	default_ball_position = target_default_ball_position
	hand_position_y = target_hand_position_y
	starting_ball_y = target_starting_ball_y
	force_red_fade_smooth_speed = target_force_red_fade_smooth_speed

func begin_throw_prep() -> void:
	if not ball:
		return
	
	max_ball_height = default_ball_position.y
	if player_sprite:
		player_sprite.frame = 0
	previous_velocity_y = 0.0
	ball_left_hand_after_throw = false
	
	ball.freeze = true
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0

func launch_throw(force_value: float) -> void:
	if not ball:
		return
	
	ball.freeze = false
	ball.apply_impulse(Vector2(0, -force_value))
	throw_initial_upward_speed = max(-ball.linear_velocity.y, 1.0)
	throw_force_ratio = 1.0
	throw_force_visual_ratio = 1.0
	ball_is_thrown = true

func physics_step(delta: float) -> void:
	frame_processed = false
	frame_peak_detected = false
	frame_reset_detected = false
	
	if not ball_is_thrown or not ball or ball.freeze:
		return
	
	frame_processed = true
	var current_y: float = ball.global_position.y
	var current_velocity_y: float = ball.linear_velocity.y
	frame_current_y = current_y
	_update_throw_force_ratio(current_velocity_y, delta)
	
	if current_y < max_ball_height:
		max_ball_height = current_y
	
	if previous_velocity_y < 0 and current_velocity_y >= 0:
		frame_peak_detected = true
	elif abs(current_velocity_y) < 5.0 and previous_velocity_y < 0:
		frame_peak_detected = true
	
	previous_velocity_y = current_velocity_y
	
	if not ball_left_hand_after_throw and current_y < default_ball_position.y - 1.0:
		ball_left_hand_after_throw = true
	
	var total_range: float = abs(max_ball_height - starting_ball_y)
	if total_range > 0 and player_sprite:
		var distance_from_start: float = abs(current_y - hand_position_y)
		var progress: float = distance_from_start / total_range
		var frame: int = int(progress * 2.0)
		frame = clamp(frame, 0, 2)
		player_sprite.frame = frame
	
	if ball_left_hand_after_throw and current_velocity_y >= 0.0 and current_y >= default_ball_position.y:
		ball.global_position = default_ball_position
		ball.linear_velocity = Vector2.ZERO
		ball.angular_velocity = 0.0
		ball.freeze = true
		ball_is_thrown = false
		ball_left_hand_after_throw = false
		if player_sprite:
			player_sprite.frame = 0
		max_ball_height = 0.0
		previous_velocity_y = 0.0
		throw_force_ratio = 0.0
		throw_force_visual_ratio = 0.0
		frame_reset_detected = true

func is_ball_thrown() -> bool:
	return ball_is_thrown

func is_throw_active() -> bool:
	return ball_is_thrown and ball and not ball.freeze

func get_throw_force_visual_ratio() -> float:
	return throw_force_visual_ratio

func did_process_frame() -> bool:
	return frame_processed

func is_at_peak_this_frame() -> bool:
	return frame_peak_detected

func did_reset_this_frame() -> bool:
	return frame_reset_detected

func get_current_y() -> float:
	return frame_current_y

func _update_throw_force_ratio(current_velocity_y: float, delta: float) -> void:
	if throw_initial_upward_speed <= 0.0:
		throw_force_ratio = 0.0
		throw_force_visual_ratio = 0.0
		return
	
	var upward_speed: float = max(-current_velocity_y, 0.0)
	throw_force_ratio = clamp(upward_speed / throw_initial_upward_speed, 0.0, 1.0)
	
	var smooth_speed: float = max(force_red_fade_smooth_speed, 0.01)
	var blend: float = clamp(delta * smooth_speed, 0.0, 1.0)
	throw_force_visual_ratio = lerp(throw_force_visual_ratio, throw_force_ratio, blend)
