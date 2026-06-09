extends Button

@export var shimmer_speed_sec: float = 0.55
@export var shimmer_color_a: Color = Color(0.72, 1.0, 0.58, 1.0)
@export var shimmer_color_b: Color = Color(1.0, 0.9, 0.38, 1.0)

var _shimmer_tween: Tween
var _rest_modulate: Color = Color.WHITE


func _ready() -> void:
	_rest_modulate = modulate
	_set_attention_active(false)


func set_attention_active(active: bool) -> void:
	_set_attention_active(active)


func _set_attention_active(active: bool) -> void:
	_stop_shimmer()
	if active:
		_start_shimmer()
	else:
		modulate = _rest_modulate


func _start_shimmer() -> void:
	modulate = shimmer_color_a
	_shimmer_tween = create_tween().set_loops()
	_shimmer_tween.tween_property(self, "modulate", shimmer_color_b, shimmer_speed_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shimmer_tween.tween_property(self, "modulate", shimmer_color_a, shimmer_speed_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_shimmer() -> void:
	if _shimmer_tween:
		_shimmer_tween.kill()
		_shimmer_tween = null
