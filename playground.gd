extends Node2D

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
var camera_original_offset: Vector2 = Vector2.ZERO  # Store original camera offset
var shake_timer: float = 0.0  # Timer for shake duration
var is_shaking: bool = false  # Whether camera is currently shaking
var target_ring_radius_px: float = 0.0
var throw_initial_upward_speed: float = 0.0
var throw_force_ratio: float = 0.0
var throw_force_visual_ratio: float = 0.0
var force_outline_container: Node2D
var force_outline_top_lines: Array[Line2D] = []
var force_outline_bottom_lines: Array[Line2D] = []

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
		target_height_line.visible = true
		

		target_line_y = starting_ball_y - 232.69947052002  # Fixed Y position above player

		if player_sprite:
			var player_x = player_sprite.global_position.x
			target_height_line.global_position = Vector2(player_x, target_line_y)
		
		# Procedural ring: same size as ball + tolerance (for "forgiveness")
		var ball_radius := _get_ball_radius_px()
		target_ring_radius_px = ball_radius + target_tolerance_px
		
		target_height_line.texture = _make_ring_texture(target_ring_radius_px, target_ring_line_width_px)
		target_height_line.centered = true
		target_height_line.material = null
		target_height_line.scale = Vector2.ONE
		target_height_line.modulate = Color(1, 1, 1, target_ring_idle_alpha)
		target_height_line.z_index = 10

	# Store original camera offset
	if camera:
		camera_original_offset = camera.offset
	
	_apply_fixed_z_order()
	_setup_force_outline()
	
func _physics_process(_delta):
	# Update camera shake
	if is_shaking:
		_update_camera_shake(_delta)
	
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
	force_outline_container = Node2D.new()
	force_outline_container.name = "ForceOutlineOverlay"
	force_outline_container.z_as_relative = false
	force_outline_container.z_index = force_outline_z_index
	ball.add_child(force_outline_container)
	_rebuild_force_outline_lines()
	force_outline_container.visible = false

func _apply_fixed_z_order() -> void:
	if player_node:
		player_node.z_as_relative = false
		player_node.z_index = player_z_index
	
	if ball:
		ball.z_as_relative = false
		ball.z_index = ball_z_index

func _rebuild_force_outline_lines() -> void:
	if not force_outline_container:
		return
	
	for line in force_outline_top_lines:
		if is_instance_valid(line):
			line.queue_free()
	for line in force_outline_bottom_lines:
		if is_instance_valid(line):
			line.queue_free()
	
	force_outline_top_lines.clear()
	force_outline_bottom_lines.clear()
	
	var soft_layers: int = max(force_outline_soft_layers, 0)
	var total_layers: int = soft_layers + 1
	
	for _i in range(total_layers):
		var top_line := Line2D.new()
		top_line.antialiased = true
		top_line.closed = false
		top_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		top_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		force_outline_container.add_child(top_line)
		force_outline_top_lines.append(top_line)
		
		var bottom_line := Line2D.new()
		bottom_line.antialiased = true
		bottom_line.closed = false
		bottom_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		bottom_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		force_outline_container.add_child(bottom_line)
		force_outline_bottom_lines.append(bottom_line)

func _build_arc_points(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count: int = max(point_count, 4)
	for i in range(safe_count + 1):
		var t := float(i) / float(safe_count)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _update_force_outline_visual() -> void:
	if not force_outline_container:
		return
	
	var should_show := ball and ball_is_thrown and not ball.freeze
	force_outline_container.visible = should_show
	if not should_show:
		return
	
	var soft_layers: int = max(force_outline_soft_layers, 0)
	var total_layers: int = soft_layers + 1
	if force_outline_top_lines.size() != total_layers or force_outline_bottom_lines.size() != total_layers:
		_rebuild_force_outline_lines()
	
	var center := Vector2.ZERO
	var radius: float = _get_ball_radius_px() + 2.0
	var point_count: int = 36
	
	# Each force arc uses less than 50% of circumference to avoid color overlap.
	var arc_ratio: float = clamp(force_outline_half_arc_ratio, 0.2, 0.49)
	var arc_span: float = TAU * arc_ratio
	var top_center_angle: float = -PI * 0.5
	var bottom_center_angle: float = PI * 0.5
	
	var top_start: float = top_center_angle - arc_span * 0.5
	var top_end: float = top_center_angle + arc_span * 0.5
	var bottom_start: float = bottom_center_angle - arc_span * 0.5
	var bottom_end: float = bottom_center_angle + arc_span * 0.5
	
	var top_points := _build_arc_points(center, radius, top_start, top_end, point_count)
	var bottom_points := _build_arc_points(center, radius, bottom_start, bottom_end, point_count)
	
	for i in range(total_layers):
		var layer_factor: float = 1.0
		var width: float = force_outline_width_px
		
		if i > 0 and soft_layers > 0:
			var t := float(i) / float(soft_layers)
			layer_factor = pow(1.0 - t, 2.0) * 0.9
			width = force_outline_width_px + (max(force_outline_softness_px, 0.0) * 2.0 * t)
		
		var top_line: Line2D = force_outline_top_lines[i]
		var bottom_line: Line2D = force_outline_bottom_lines[i]
		
		top_line.position = Vector2.ZERO
		bottom_line.position = Vector2.ZERO
		top_line.points = top_points
		bottom_line.points = bottom_points
		top_line.width = width
		bottom_line.width = width
		
		var top_color := force_outline_red_base
		top_color.a = lerp(force_outline_red_min_alpha, 1.0, throw_force_visual_ratio) * layer_factor
		
		var bottom_color := force_outline_blue_base
		bottom_color.a = clamp(force_outline_blue_alpha, 0.0, 1.0) * layer_factor
		
		top_line.default_color = top_color
		bottom_line.default_color = bottom_color

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
	if target_height_line:
		var ball_pos := ball.global_position
		var target_pos := target_height_line.global_position
		var dist := ball_pos.distance_to(target_pos)
		
		# Note: ring radius is ball_radius + tolerance; for a "hit" we check center offset <= tolerance
		if dist <= target_tolerance_px:
			if not triggers_fired.get("on_line", false):
				triggers_fired["on_line"] = true
				print("ТРИГГЕР 3: попадание в цель (dist=%.2f px)" % dist)
				_play_target_hit_fx()

func _start_camera_shake():
	"""Start the camera shake effect (earthquake)"""
	if camera:
		is_shaking = true
		shake_timer = shake_duration

func _update_camera_shake(delta: float):
	"""Update camera shake effect each frame"""
	if not camera or not is_shaking:
		return
	
	shake_timer -= delta
	
	if shake_timer <= 0.0:
		# Shake is over, reset camera to original position
		is_shaking = false
		camera.offset = camera_original_offset
	else:
		# Calculate shake intensity (decreases over time)
		var progress = shake_timer / shake_duration
		var current_intensity = shake_intensity * progress
		
		# Apply random offset to camera
		var random_offset = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		camera.offset = camera_original_offset + random_offset

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

func _make_ring_texture(radius_px: float, line_width_px: float) -> Texture2D:
	var pad := int(ceil(line_width_px)) + 2
	var r := float(radius_px)
	var lw := float(line_width_px)
	
	var size := int(ceil((r + pad) * 2.0))
	size = max(size, 8)
	
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var c := Vector2(size * 0.5, size * 0.5)
	var half := lw * 0.5
	
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if abs(d - r) <= half:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	
	return ImageTexture.create_from_image(img)

func _ensure_add_material(ci: CanvasItem) -> void:
	var m := ci.material as CanvasItemMaterial
	if m == null:
		m = CanvasItemMaterial.new()
		ci.material = m
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func _play_target_hit_fx() -> void:
	if not target_height_line:
		return
	
	# Glow on the ring
	_ensure_add_material(target_height_line)
	target_height_line.modulate = target_hit_color
	
	var tween := create_tween()
	tween.tween_property(target_height_line, "scale", Vector2.ONE * 1.08, 0.12).from(Vector2.ONE)
	tween.tween_property(target_height_line, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(target_height_line, "modulate:a", 0.15, 0.45).from(1.0)
	tween.tween_callback(func():
		# return to idle
		target_height_line.material = null
		target_height_line.modulate = Color(1, 1, 1, target_ring_idle_alpha)
		target_height_line.scale = Vector2.ONE
	)
	
	# Flash ring (one-shot)
	var flash := Sprite2D.new()
	flash.texture = _make_ring_texture(target_ring_radius_px, target_ring_line_width_px * 2.0)
	flash.centered = true
	flash.global_position = target_height_line.global_position
	flash.z_index = target_height_line.z_index + 1
	flash.modulate = target_hit_color
	_ensure_add_material(flash)
	add_child(flash)
	
	var t2 := create_tween()
	t2.tween_property(flash, "scale", Vector2.ONE * 1.35, 0.18).from(Vector2.ONE * 0.85)
	t2.parallel().tween_property(flash, "modulate:a", 0.0, 0.18).from(1.0)
	t2.tween_callback(flash.queue_free)
