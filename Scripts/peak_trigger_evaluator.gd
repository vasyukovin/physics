extends RefCounted
class_name PeakTriggerEvaluator

func evaluate_peak(
	ball_center_y: float,
	ball_radius: float,
	target_line_y: float,
	ball_pos: Vector2,
	target_ring_controller,
	triggers_fired: Dictionary
) -> Dictionary:
	var result := {
		"below_line_triggered": false,
		"above_line_triggered": false,
		"on_line_triggered": false,
		"hit_distance": INF
	}
	
	var highest_point_y: float = ball_center_y - ball_radius
	
	if highest_point_y > target_line_y and not triggers_fired.get("below_line", false):
		triggers_fired["below_line"] = true
		result["below_line_triggered"] = true
	
	if ball_center_y < target_line_y and not triggers_fired.get("above_line", false):
		triggers_fired["above_line"] = true
		result["above_line_triggered"] = true
	
	if target_ring_controller:
		var dist: float = target_ring_controller.get_distance_to_target(ball_pos)
		result["hit_distance"] = dist
		if target_ring_controller.is_hit(ball_pos) and not triggers_fired.get("on_line", false):
			triggers_fired["on_line"] = true
			result["on_line_triggered"] = true
	
	return result
