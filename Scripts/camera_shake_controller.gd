extends RefCounted
class_name CameraShakeController

var camera: Camera2D
var original_offset: Vector2 = Vector2.ZERO
var intensity: float = 15.0
var duration: float = 2.0
var timer: float = 0.0
var active: bool = false

func setup(target_camera: Camera2D, shake_intensity: float, shake_duration: float) -> void:
	camera = target_camera
	intensity = shake_intensity
	duration = max(shake_duration, 0.001)
	if camera:
		original_offset = camera.offset

func start() -> void:
	if camera:
		active = true
		timer = duration

func update(delta: float) -> void:
	if not camera or not active:
		return
	
	timer -= delta
	
	if timer <= 0.0:
		active = false
		camera.offset = original_offset
		return
	
	var progress: float = timer / duration
	var current_intensity: float = intensity * progress
	var random_offset := Vector2(
		randf_range(-current_intensity, current_intensity),
		randf_range(-current_intensity, current_intensity)
	)
	camera.offset = original_offset + random_offset
