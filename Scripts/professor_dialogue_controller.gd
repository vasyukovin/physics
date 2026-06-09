extends RefCounted
class_name ProfessorDialogueController

enum ThrowOutcome { NONE, HIT, TOO_LOW, TOO_HIGH }

const SERIES_THROW_COUNT: int = 3

var host: Node
var dialog_label: Label
var verdict_delay_sec: float = 0.4
var typewriter_chars_per_sec: float = 42.0
var typewriter_enabled: bool = true

var _say_generation: int = 0
var _pending_outcome: ThrowOutcome = ThrowOutcome.NONE
var _pending_can_go_next: bool = false
var _pending_is_final_level: bool = false
var _miss_counts: Dictionary = {}
var _series_silent: bool = false

const _LEVEL_INTRO: Dictionary = {
	1: [
		"Добро пожаловать! Нажми «Бросить» — покажу идеальную траекторию.",
		"Первый уровень: смотри, как мяч летит в цель при правильном импульсе.",
	],
	2: [
		"Уровень два. Теперь сам посчитай силу и бросай.",
		"Цель чуть выше. Подбери импульс — я промолчу, пока мяч не вернётся.",
	],
}

const _LEVEL3_MANUAL: Array[String] = [
	"Финал: три цели и три силы. Введи значения и нажми «Применить 3 силы».",
	"Последний уровень. Три расчёта — три броска. Сначала зафиксируй силы.",
]

const _LEVEL3_AUTOFILL: Array[String] = [
	"Третий уровень. Силы уже подставлены — можно сразу жать «Бросить».",
	"Финальная серия готова к старту. Проверь силы и запускай броски.",
]

const _FORCES_APPLIED: Array[String] = [
	"Принято. Три цели — три расчёта. Поехали.",
	"Хорошо. Когда будешь готов — жми «Бросить».",
]

const _HIT_LINES: Array[String] = [
	"Точно в цель! Импульс подобран верно.",
	"Вот она — идеальная парабола.",
	"Ровно в кольцо. Так и должно быть.",
]

const _HIT_GO_NEXT: Array[String] = [
	"Можно переходить дальше.",
	"Отлично. Следующий уровень ждёт.",
]

const _HIT_FINAL_LEVEL: Array[String] = [
	"Все уровни пройдены!",
	"Финиш! Ты прошёл весь курс.",
]

const _TOO_LOW_LINES: Array[String] = [
	"Недотянул — мяч не поднялся достаточно высоко.",
	"Слабовато. Нужен чуть больший импульс.",
	"Не добрал до высоты цели.",
]

const _TOO_LOW_REPEAT: Array[String] = [
	"Снова недотянул. Попробуй увеличить силу.",
	"Опять не хватило высоты — добавь импульс.",
]

const _TOO_HIGH_LINES: Array[String] = [
	"Перебор! Слишком большой импульс.",
	"Мяч улетел выше цели — убавь силу.",
	"Слишком мощно. Цель ниже пика траектории.",
]

const _TOO_HIGH_REPEAT: Array[String] = [
	"Опять перелёт. Силу можно уменьшить.",
	"Снова выше линии — попробуй скромнее.",
]

const _SERIES_MISS_BY_OUTCOME: Dictionary = {
	ThrowOutcome.TOO_LOW: [
		"На %d-й цели не хватило высоты. Пересчитай силу и попробуй снова.",
		"Промах: %d-й бросок был слабоват. Подправь силу для этой цели.",
	],
	ThrowOutcome.TOO_HIGH: [
		"На %d-й цели перелёт. Уменьши силу и запусти серию заново.",
		"Промах: %d-й бросок слишком сильный. Пересчитай и повтори.",
	],
	ThrowOutcome.NONE: [
		"Промах на %d-й цели. Пересчитай силы и нажми «Бросить» снова.",
		"Не попал в %d-ю цель. Исправь силу и попробуй ещё раз.",
	],
}

const _SERIES_PERFECT: Array[String] = [
	"Три из трёх! Ты не угадываешь — ты считаешь.",
	"Все три цели взяты. Закон сохранения импульса усвоен.",
	"Идеальная серия. Можно ставить зачёт.",
]

const _INPUT_ERRORS: Dictionary = {
	"need_forces": [
		"Сначала введи три силы и нажми «Применить 3 силы».",
	],
	"series_done": [
		"Серия уже завершена — поздравляю!",
	],
	"missing_forces": [
		"Не хватает значений сил для серии.",
	],
	"invalid_force": [
		"Нужно число в поле силы.",
	],
	"missing_force_values": [
		"Не хватает введённых сил для продолжения.",
	],
}


func setup(
	target_host: Node,
	target_dialog_label: Label,
	target_verdict_delay_sec: float = 0.4,
	target_typewriter_enabled: bool = true,
	target_typewriter_chars_per_sec: float = 42.0
) -> void:
	host = target_host
	dialog_label = target_dialog_label
	verdict_delay_sec = max(target_verdict_delay_sec, 0.0)
	typewriter_enabled = target_typewriter_enabled
	typewriter_chars_per_sec = max(target_typewriter_chars_per_sec, 1.0)


func set_series_silent(silent: bool) -> void:
	_series_silent = silent


func queue_throw_verdict(
	outcome: ThrowOutcome,
	can_go_next: bool = false,
	is_final_level: bool = false
) -> void:
	if outcome == ThrowOutcome.NONE:
		return
	_pending_outcome = outcome
	_pending_can_go_next = can_go_next
	_pending_is_final_level = is_final_level


func clear_pending_verdict() -> void:
	_pending_outcome = ThrowOutcome.NONE
	_pending_can_go_next = false
	_pending_is_final_level = false


func has_pending_verdict() -> bool:
	return _pending_outcome != ThrowOutcome.NONE


func peek_pending_outcome() -> ThrowOutcome:
	return _pending_outcome


func deliver_pending_verdict() -> void:
	if not has_pending_verdict() or _series_silent:
		clear_pending_verdict()
		return
	var outcome := _pending_outcome
	var can_go_next := _pending_can_go_next
	var is_final_level := _pending_is_final_level
	clear_pending_verdict()
	var line := _pick_throw_verdict_line(outcome, can_go_next, is_final_level)
	await _say(line, true)


func on_level_started(level: int, level3_autofill: bool) -> void:
	_miss_counts.clear()
	clear_pending_verdict()
	if level == 3:
		var pool: Array = _LEVEL3_AUTOFILL if level3_autofill else _LEVEL3_MANUAL
		await _say(_pick_random(pool), false)
		return
	var lines: Array = _LEVEL_INTRO.get(level, ["Уровень %d. Удачи!" % level])
	await _say(_pick_random(lines), false)


func on_forces_applied() -> void:
	await _say(_pick_random(_FORCES_APPLIED), false)


func on_input_error(error_key: String) -> void:
	var pool: Array = _INPUT_ERRORS.get(error_key, ["Что-то пошло не так — проверь ввод."])
	await _say(_pick_random(pool), false)


func on_force_validation_error(raw_error: String) -> void:
	var human := _humanize_force_error(raw_error)
	await _say(human, false)


func on_series_miss(throw_number: int, outcome: ThrowOutcome) -> void:
	var pool: Array = _SERIES_MISS_BY_OUTCOME.get(outcome, _SERIES_MISS_BY_OUTCOME[ThrowOutcome.NONE])
	var template: String = _pick_random(pool)
	await _say(template % throw_number, true)


func on_series_finished(hit_count: int, total: int) -> void:
	if hit_count >= total:
		await _say(_pick_random(_SERIES_PERFECT), true)
		return
	if hit_count == total - 1:
		await _say("Почти идеально — одна цель ускользнула. Но серия сильная.", true)
		return
	await _say("Серия завершена: %d из %d." % [hit_count, total], true)


func say_immediate(text: String) -> void:
	await _say(text, false)


func _pick_throw_verdict_line(
	outcome: ThrowOutcome,
	can_go_next: bool,
	is_final_level: bool
) -> String:
	var base := ""
	match outcome:
		ThrowOutcome.HIT:
			base = _pick_random(_HIT_LINES)
			if is_final_level:
				base += " " + _pick_random(_HIT_FINAL_LEVEL)
			elif can_go_next:
				base += " " + _pick_random(_HIT_GO_NEXT)
		ThrowOutcome.TOO_LOW:
			base = _pick_outcome_line(ThrowOutcome.TOO_LOW, _TOO_LOW_LINES, _TOO_LOW_REPEAT)
		ThrowOutcome.TOO_HIGH:
			base = _pick_outcome_line(ThrowOutcome.TOO_HIGH, _TOO_HIGH_LINES, _TOO_HIGH_REPEAT)
	return base


func _pick_outcome_line(outcome: ThrowOutcome, first_pool: Array, repeat_pool: Array) -> String:
	var count: int = int(_miss_counts.get(outcome, 0))
	_miss_counts[outcome] = count + 1
	if count > 0:
		return _pick_random(repeat_pool)
	return _pick_random(first_pool)


func _humanize_force_error(raw_error: String) -> String:
	if raw_error.contains("ровно 3"):
		return "Нужно ввести ровно три силы."
	if raw_error.contains("должна быть числом"):
		var idx := raw_error.get_slice(" ", 1)
		return "Сила %s должна быть числом." % idx
	if raw_error.contains("больше нуля"):
		var idx2 := raw_error.get_slice(" ", 1)
		return "Сила %s должна быть больше нуля." % idx2
	return "Проверь значения сил — что-то не сходится."


func _pick_random(pool: Array) -> String:
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


func _say(text: String, use_verdict_delay: bool) -> void:
	if not dialog_label or text.is_empty():
		return
	_say_generation += 1
	var generation := _say_generation
	if use_verdict_delay and verdict_delay_sec > 0.0:
		await host.get_tree().create_timer(verdict_delay_sec).timeout
	if generation != _say_generation:
		return
	if typewriter_enabled:
		await _typewrite(text, generation)
	else:
		dialog_label.text = text


func _typewrite(text: String, generation: int) -> void:
	dialog_label.text = ""
	var delay := 1.0 / typewriter_chars_per_sec
	for i in range(text.length()):
		if generation != _say_generation:
			return
		dialog_label.text = text.left(i + 1)
		await host.get_tree().create_timer(delay).timeout
