extends RefCounted
class_name LevelProgressionController

var total_levels: int = 3
var current_level: int = 1

func setup(target_total_levels: int) -> void:
	total_levels = max(target_total_levels, 1)
	current_level = 1

func get_current_level() -> int:
	return current_level

func is_last_level() -> bool:
	return current_level >= total_levels

func can_go_next() -> bool:
	return current_level < total_levels

func go_next() -> bool:
	if not can_go_next():
		return false
	current_level += 1
	return true

func get_level_label_text() -> String:
	return "Уровень %d/%d" % [current_level, total_levels]
