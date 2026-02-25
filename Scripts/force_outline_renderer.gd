extends RefCounted
class_name ForceOutlineRenderer

var ball: RigidBody2D
var container: Node2D
var top_lines: Array[Line2D] = []
var bottom_lines: Array[Line2D] = []

var outline_z_index: int = 1
var outline_width_px: float = 4.0
var red_base: Color = Color(1.0, 0.2, 0.2, 1.0)
var blue_base: Color = Color(0.2, 0.5, 1.0, 1.0)
var blue_alpha: float = 0.9
var red_min_alpha: float = 0.0
var softness_px: float = 6.0
var soft_layers: int = 6
var half_arc_ratio: float = 0.25

func setup(
	target_ball: RigidBody2D,
	target_outline_z_index: int,
	target_outline_width_px: float,
	target_red_base: Color,
	target_blue_base: Color,
	target_blue_alpha: float,
	target_red_min_alpha: float,
	target_softness_px: float,
	target_soft_layers: int,
	target_half_arc_ratio: float
) -> void:
	ball = target_ball
	outline_z_index = target_outline_z_index
	outline_width_px = target_outline_width_px
	red_base = target_red_base
	blue_base = target_blue_base
	blue_alpha = target_blue_alpha
	red_min_alpha = target_red_min_alpha
	softness_px = target_softness_px
	soft_layers = target_soft_layers
	half_arc_ratio = target_half_arc_ratio
	
	if not ball:
		return
	
	container = Node2D.new()
	container.name = "ForceOutlineOverlay"
	container.z_as_relative = false
	container.z_index = outline_z_index
	ball.add_child(container)
	_rebuild_lines()
	container.visible = false

func update_visual(
	ball_is_thrown: bool,
	ball_is_frozen: bool,
	throw_force_visual_ratio: float,
	ball_radius_px: float
) -> void:
	if not container:
		return
	
	var should_show := ball and ball_is_thrown and not ball_is_frozen
	container.visible = should_show
	if not should_show:
		return
	
	var target_soft_layers: int = max(soft_layers, 0)
	var total_layers: int = target_soft_layers + 1
	if top_lines.size() != total_layers or bottom_lines.size() != total_layers:
		_rebuild_lines()
	
	var center := Vector2.ZERO
	var radius: float = ball_radius_px + 2.0
	var point_count: int = 36
	
	var arc_ratio: float = clamp(half_arc_ratio, 0.2, 0.49)
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
		var width: float = outline_width_px
		
		if i > 0 and target_soft_layers > 0:
			var t := float(i) / float(target_soft_layers)
			layer_factor = pow(1.0 - t, 2.0) * 0.9
			width = outline_width_px + (max(softness_px, 0.0) * 2.0 * t)
		
		var top_line: Line2D = top_lines[i]
		var bottom_line: Line2D = bottom_lines[i]
		
		top_line.position = Vector2.ZERO
		bottom_line.position = Vector2.ZERO
		top_line.points = top_points
		bottom_line.points = bottom_points
		top_line.width = width
		bottom_line.width = width
		
		var top_color := red_base
		top_color.a = lerp(red_min_alpha, 1.0, throw_force_visual_ratio) * layer_factor
		
		var bottom_color := blue_base
		bottom_color.a = clamp(blue_alpha, 0.0, 1.0) * layer_factor
		
		top_line.default_color = top_color
		bottom_line.default_color = bottom_color

func _rebuild_lines() -> void:
	if not container:
		return
	
	for line in top_lines:
		if is_instance_valid(line):
			line.queue_free()
	for line in bottom_lines:
		if is_instance_valid(line):
			line.queue_free()
	
	top_lines.clear()
	bottom_lines.clear()
	
	var target_soft_layers: int = max(soft_layers, 0)
	var total_layers: int = target_soft_layers + 1
	
	for _i in range(total_layers):
		var top_line := Line2D.new()
		top_line.antialiased = true
		top_line.closed = false
		top_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		top_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		container.add_child(top_line)
		top_lines.append(top_line)
		
		var bottom_line := Line2D.new()
		bottom_line.antialiased = true
		bottom_line.closed = false
		bottom_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		bottom_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		container.add_child(bottom_line)
		bottom_lines.append(bottom_line)

func _build_arc_points(
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	point_count: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count: int = max(point_count, 4)
	for i in range(safe_count + 1):
		var t := float(i) / float(safe_count)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
