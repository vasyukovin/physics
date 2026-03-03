extends RefCounted
class_name BallStateLegendController

var legend_panel: PanelContainer
var gravity_slot: Control
var impulse_slot: Control
var gravity_label: Label
var impulse_label: Label
var preview_ball_scene: PackedScene
var pixels_per_meter: float = 100.0
var gravity_color: Color = Color(0.2, 0.5, 1.0, 1.0)
var impulse_color: Color = Color(1.0, 0.2, 0.2, 1.0)

func setup(
	target_legend_panel: PanelContainer,
	target_gravity_slot: Control,
	target_impulse_slot: Control,
	target_gravity_label: Label,
	target_impulse_label: Label,
	target_preview_ball_scene: PackedScene,
	target_pixels_per_meter: float,
	target_gravity_color: Color,
	target_impulse_color: Color
) -> void:
	legend_panel = target_legend_panel
	gravity_slot = target_gravity_slot
	impulse_slot = target_impulse_slot
	gravity_label = target_gravity_label
	impulse_label = target_impulse_label
	preview_ball_scene = target_preview_ball_scene
	pixels_per_meter = max(target_pixels_per_meter, 1.0)
	gravity_color = target_gravity_color
	impulse_color = target_impulse_color
	
	if not legend_panel or not gravity_slot or not impulse_slot:
		return
	if not gravity_label or not impulse_label or not preview_ball_scene:
		return
	
	_update_descriptions()
	_populate_ball_slot(gravity_slot, gravity_color)
	_populate_ball_slot(impulse_slot, impulse_color)

func _update_descriptions() -> void:
	gravity_label.text = ("Синий: гравитация")
	impulse_label.text = ("Красный: импульс броска")

func _populate_ball_slot(slot: Control, state_color: Color) -> void:
	for child in slot.get_children():
		child.queue_free()
	
	var anchor := Node2D.new()
	var slot_size := slot.custom_minimum_size
	if slot_size.x <= 0.0 or slot_size.y <= 0.0:
		slot_size = Vector2(84.0, 84.0)
	anchor.position = slot_size * 0.5
	slot.add_child(anchor)
	
	var preview_ball := preview_ball_scene.instantiate() as RigidBody2D
	if not preview_ball:
		return
	
	preview_ball.freeze = true
	preview_ball.sleeping = true
	preview_ball.gravity_scale = 0.0
	preview_ball.linear_velocity = Vector2.ZERO
	preview_ball.angular_velocity = 0.0
	anchor.add_child(preview_ball)
	
	var collision := preview_ball.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.disabled = true
	
	var sprite := preview_ball.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(state_color, 0.35)
	
	_add_radial_glow(preview_ball, state_color, _get_ball_radius_px(preview_ball))

func _add_radial_glow(target_ball: RigidBody2D, base_color: Color, ball_radius_px: float) -> void:
	var glow := Node2D.new()
	glow.name = "StateGlow"
	target_ball.add_child(glow)
	
	var points := _build_circle_points(ball_radius_px + 4.0, 42)
	var layers := 4
	for i in range(layers):
		var line := Line2D.new()
		line.antialiased = true
		line.closed = true
		line.points = points
		line.width = 2.0 + float(i) * 2.0
		line.default_color = base_color
		line.default_color.a = 0.65 * pow(0.6, i)
		glow.add_child(line)

func _build_circle_points(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = max(point_count, 12)
	for i in range(count):
		var angle: float = (TAU * float(i)) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _get_ball_radius_px(target_ball: RigidBody2D) -> float:
	if target_ball and target_ball.has_node("CollisionShape2D"):
		var cs := target_ball.get_node("CollisionShape2D") as CollisionShape2D
		if cs and cs.shape is CircleShape2D:
			var r := (cs.shape as CircleShape2D).radius
			if r > 0.0:
				return r
	
	if target_ball and target_ball.has_node("Sprite2D"):
		var s := target_ball.get_node("Sprite2D") as Sprite2D
		if s and s.texture:
			var size := s.texture.get_size()
			return 0.5 * size.x * s.scale.x
	
	return 10.0
