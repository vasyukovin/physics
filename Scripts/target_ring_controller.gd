extends RefCounted
class_name TargetRingController

const RING_TEXTURE := preload("res://Assets/ring_gray.png")

var host: Node
var target_sprite: Sprite2D
var tolerance_px: float = 10.0
var ring_line_width_px: float = 3.0
var ring_idle_alpha: float = 0.25
var hit_color: Color = Color(0.2, 0.6, 1.0, 1.0)
var ring_radius_px: float = 0.0

func setup(
	target_host: Node,
	target_line_sprite: Sprite2D,
	target_line_y: float,
	target_x: float,
	ball_radius_px: float,
	target_tolerance_px: float,
	target_ring_line_width_px: float,
	target_ring_idle_alpha: float,
	target_hit_color: Color
) -> void:
	host = target_host
	target_sprite = target_line_sprite
	tolerance_px = target_tolerance_px
	ring_line_width_px = target_ring_line_width_px
	ring_idle_alpha = target_ring_idle_alpha
	hit_color = target_hit_color
	ring_radius_px = ball_radius_px + tolerance_px
	
	if not target_sprite:
		return
	
	target_sprite.visible = true
	target_sprite.global_position = Vector2(target_x, target_line_y)
	target_sprite.centered = true
	target_sprite.material = null
	
	if RING_TEXTURE:
		target_sprite.texture = RING_TEXTURE
		var tex_size: Vector2 = RING_TEXTURE.get_size()
		var max_side: float = maxf(tex_size.x, tex_size.y)
		if max_side > 0.0:
			var desired_diameter: float = ring_radius_px * 2.0
			var scale_value: float = desired_diameter / max_side
			target_sprite.scale = Vector2.ONE * scale_value
		else:
			target_sprite.scale = Vector2.ONE
	else:
		target_sprite.texture = _make_ring_texture(ring_radius_px, ring_line_width_px)
		target_sprite.scale = Vector2.ONE
	
	target_sprite.modulate = Color(1, 1, 1, ring_idle_alpha)
	target_sprite.z_index = 10

func get_distance_to_target(ball_pos: Vector2) -> float:
	if not target_sprite:
		return INF
	return ball_pos.distance_to(target_sprite.global_position)

func is_hit(ball_pos: Vector2) -> bool:
	return get_distance_to_target(ball_pos) <= tolerance_px

func play_hit_fx() -> void:
	if not target_sprite or not host:
		return
	
	var base_scale := target_sprite.scale
	
	_ensure_add_material(target_sprite)
	target_sprite.modulate = hit_color
	
	var tween := host.create_tween()
	tween.tween_property(target_sprite, "scale", base_scale * 1.08, 0.12).from(base_scale)
	tween.tween_property(target_sprite, "scale", base_scale, 0.18)
	tween.parallel().tween_property(target_sprite, "modulate:a", 0.15, 0.45).from(1.0)
	tween.tween_callback(func():
		target_sprite.material = null
		target_sprite.modulate = Color(1, 1, 1, ring_idle_alpha)
		target_sprite.scale = base_scale
	)
	
	var flash := Sprite2D.new()
	flash.texture = _make_ring_texture(ring_radius_px, ring_line_width_px * 2.0)
	flash.centered = true
	flash.global_position = target_sprite.global_position
	flash.z_index = target_sprite.z_index + 1
	flash.modulate = hit_color
	_ensure_add_material(flash)
	host.add_child(flash)
	
	var t2 := host.create_tween()
	t2.tween_property(flash, "scale", Vector2.ONE * 1.35, 0.18).from(Vector2.ONE * 0.85)
	t2.parallel().tween_property(flash, "modulate:a", 0.0, 0.18).from(1.0)
	t2.tween_callback(flash.queue_free)

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
