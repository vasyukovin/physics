extends RefCounted
class_name CameraFollowController

var camera: Camera2D
var ball: RigidBody2D
var throw_state_controller
var home_position: Vector2 = Vector2.ZERO
var smooth_speed: float = 6.0

func setup(
	target_camera: Camera2D,
	target_ball: RigidBody2D,
	target_throw_state_controller,
	target_smooth_speed: float
) -> void:
	camera = target_camera
	ball = target_ball
	throw_state_controller = target_throw_state_controller
	smooth_speed = max(target_smooth_speed, 0.01)
	if camera:
		home_position = camera.global_position

func update(delta: float) -> void:
	if not camera:
		return
	var target_position: Vector2 = home_position
	if throw_state_controller and throw_state_controller.is_throw_active() and ball:
		target_position = Vector2(home_position.x, ball.global_position.y)
	var blend: float = clamp(delta * smooth_speed, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target_position, blend)
