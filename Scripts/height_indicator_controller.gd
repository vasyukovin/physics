extends RefCounted
class_name HeightIndicatorController

var host: Node2D
var line: Line2D
var label: Label
var line_x_offset: float = 50.0
var pixels_per_meter: float = 100.0

func setup(
	target_host: Node2D,
	target_line: Line2D,
	target_label: Label,
	target_line_x_offset: float,
	target_pixels_per_meter: float
) -> void:
	host = target_host
	line = target_line
	label = target_label
	line_x_offset = target_line_x_offset
	pixels_per_meter = target_pixels_per_meter
	
	if line:
		line.width = 2.0
		line.default_color = Color.RED
		line.visible = false
	
	if label:
		label.visible = false
		label.add_theme_color_override("font_color", Color.RED)
		label.add_theme_font_size_override("font_size", 24)

func update_indicator(ball_center: Vector2, reference_y: float) -> void:
	var height_pixels: float = reference_y - ball_center.y
	var height_meters: float = height_pixels
	
	if height_meters > 0:
		if line:
			line.visible = true
			
			var line_start_global := Vector2(ball_center.x + line_x_offset, reference_y)
			var line_end_global := Vector2(ball_center.x + line_x_offset, ball_center.y)
			
			var line_start := line.to_local(line_start_global)
			var line_end := line.to_local(line_end_global)
			
			line.clear_points()
			line.add_point(line_start)
			line.add_point(line_end)
		
		if label and host:
			label.visible = true
			label.text = "%.2f m" % height_meters
			label.position = host.to_local(Vector2(ball_center.x + line_x_offset + 10, ball_center.y - 20))
	else:
		reset()

func reset() -> void:
	if line:
		line.visible = false
	if label:
		label.visible = false
