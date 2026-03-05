extends RefCounted
class_name Level3SequenceController

const THROW_COUNT: int = 3

var current_throw_index: int = 0
var forces: Array[float] = []
var forces_confirmed: bool = false
var auto_sequence_running: bool = false
var hit_registered_this_throw: bool = false

func reset_state() -> void:
	current_throw_index = 0
	forces.clear()
	forces_confirmed = false
	auto_sequence_running = false
	hit_registered_this_throw = false

func get_throw_count() -> int:
	return THROW_COUNT

func validate_and_apply_forces(values: Array[String]) -> Dictionary:
	if values.size() != THROW_COUNT:
		return {"ok": false, "error": "Нужно ввести ровно 3 силы."}
	
	var parsed: Array[float] = []
	for i in range(values.size()):
		var text_value: String = values[i].strip_edges()
		if text_value.is_empty() or not text_value.is_valid_float():
			return {"ok": false, "error": "Сила %d должна быть числом." % (i + 1)}
		var value: float = float(text_value)
		if value <= 0.0:
			return {"ok": false, "error": "Сила %d должна быть больше нуля." % (i + 1)}
		parsed.append(value)
	
	forces = parsed
	forces_confirmed = true
	current_throw_index = 0
	return {"ok": true}

func can_start_sequence() -> bool:
	return forces_confirmed and not auto_sequence_running and current_throw_index < THROW_COUNT and current_throw_index < forces.size()

func start_sequence() -> bool:
	if not can_start_sequence():
		return false
	auto_sequence_running = true
	return true

func stop_sequence() -> void:
	auto_sequence_running = false

func is_finished() -> bool:
	return current_throw_index >= THROW_COUNT

func get_current_force() -> float:
	if current_throw_index < 0 or current_throw_index >= forces.size():
		return 0.0
	return forces[current_throw_index]

func get_current_throw_number() -> int:
	return current_throw_index + 1

func mark_throw_started() -> void:
	hit_registered_this_throw = false

func register_hit() -> void:
	hit_registered_this_throw = true

func was_hit_this_throw() -> bool:
	return hit_registered_this_throw

func complete_current_throw() -> void:
	current_throw_index += 1
