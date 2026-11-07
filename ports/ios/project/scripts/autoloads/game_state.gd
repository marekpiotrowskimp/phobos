extends Node

const SAVE_PATH := "user://phobos.cfg"
const SCHEMA_VERSION := 2
const MAX_ENTRIES := 10
const ALL_DIFFICULTIES := "all"
const DIFFICULTY_EASY := "easy"
const DIFFICULTY_NORMAL := "normal"
const DIFFICULTY_HARD := "hard"
const DIFFICULTY_IDS := [DIFFICULTY_EASY, DIFFICULTY_NORMAL, DIFFICULTY_HARD]
const DIFFICULTY_LABELS := {
	DIFFICULTY_EASY: "ŁATWY",
	DIFFICULTY_NORMAL: "NORMALNY",
	DIFFICULTY_HARD: "TRUDNY",
}
const DIFFICULTY_PROFILES := {
	DIFFICULTY_EASY: {"heal_chance": 0.14, "overdrive_chance": 0.09, "heal_pity_kills": 6},
	DIFFICULTY_NORMAL: {"heal_chance": 0.08, "overdrive_chance": 0.05, "heal_pity_kills": 10},
	DIFFICULTY_HARD: {"heal_chance": 0.04, "overdrive_chance": 0.02, "heal_pity_kills": 14},
}

var score := 0
var kills := 0
var best := 0
var selected_difficulty := DIFFICULTY_NORMAL
var run_difficulty := DIFFICULTY_NORMAL
var last_initials := "AAA"
var _boot_mode := "menu"
var _leaderboards: Dictionary = _empty_leaderboards()


func _ready() -> void:
	load_best()


func reset() -> void:
	score = 0
	kills = 0
	run_difficulty = selected_difficulty
	best = get_best(run_difficulty)


func add_score(v: int) -> void:
	score += v
	if score > best:
		best = score


func add_kill() -> void:
	kills += 1


func set_selected_difficulty(difficulty_id: String) -> bool:
	if not _is_difficulty(difficulty_id):
		return false
	var previous := selected_difficulty
	selected_difficulty = difficulty_id
	if _save_data() != OK:
		selected_difficulty = previous
		return false
	return true


func request_boot_mode(mode: String) -> void:
	_boot_mode = "play" if mode == "play" else "menu"


func consume_boot_mode() -> String:
	var mode := _boot_mode
	_boot_mode = "menu"
	return mode


func get_difficulty_labels() -> Dictionary:
	return DIFFICULTY_LABELS.duplicate(true)


func get_difficulty_profiles() -> Dictionary:
	return DIFFICULTY_PROFILES.duplicate(true)


func get_difficulty_profile(difficulty_id: String = "") -> Dictionary:
	var resolved := run_difficulty if difficulty_id.is_empty() else difficulty_id
	if not _is_difficulty(resolved):
		return {}
	return DIFFICULTY_PROFILES[resolved].duplicate(true)


func qualifies(score_value: int, difficulty_id: String = "", wave := 0, kill_count := 0, run_time := 0.0) -> bool:
	var resolved := run_difficulty if difficulty_id.is_empty() else difficulty_id
	if score_value <= 0 or not _is_difficulty(resolved):
		return false
	var board: Array = _leaderboards[resolved]
	if board.size() < MAX_ENTRIES:
		return true
	var candidate := _make_entry("ZZZ", score_value, wave, kill_count, run_time, Time.get_date_string_from_system(), resolved)
	return _entry_before(candidate, board.back())


func submit_score(
	initials: String,
	score_value: int,
	wave: int,
	kill_count: int,
	run_time: float,
	difficulty_id: String = "",
	date: String = ""
) -> bool:
	var resolved := run_difficulty if difficulty_id.is_empty() else difficulty_id
	if not _valid_initials(initials) or score_value <= 0 or wave < 0 or kill_count < 0:
		return false
	if run_time < 0.0 or not is_finite(run_time) or not _is_difficulty(resolved):
		return false
	var entry_date := Time.get_date_string_from_system() if date.is_empty() else date
	var entry := _make_entry(initials, score_value, wave, kill_count, run_time, entry_date, resolved)
	var previous: Array = (_leaderboards[resolved] as Array).duplicate(true)
	var previous_initials := last_initials
	last_initials = initials
	_insert_entry(_leaderboards, entry)
	var retained := (_leaderboards[resolved] as Array).has(entry)
	if not retained:
		last_initials = previous_initials
		return false
	if _save_data() != OK:
		_leaderboards[resolved] = previous
		last_initials = previous_initials
		return false
	if resolved == run_difficulty and score_value > best:
		best = score_value
	return true


func get_leaderboard(filter: String = ALL_DIFFICULTIES) -> Array[Dictionary]:
	return _get_leaderboard_from(_leaderboards, filter)


func get_best(difficulty_id: String = "") -> int:
	var resolved := run_difficulty if difficulty_id.is_empty() else difficulty_id
	var entries := get_leaderboard(resolved)
	return 0 if entries.is_empty() else int(entries[0]["score"])


func save_best() -> void:
	_save_data()


func load_best() -> void:
	var cfg := ConfigFile.new()
	var load_error := cfg.load(SAVE_PATH)
	_leaderboards = _empty_leaderboards()
	selected_difficulty = DIFFICULTY_NORMAL
	last_initials = "AAA"
	if load_error == OK:
		selected_difficulty = str(cfg.get_value("game_state", "selected_difficulty", DIFFICULTY_NORMAL))
		last_initials = str(cfg.get_value("game_state", "last_initials", "AAA")).to_upper()
		if not _valid_initials(last_initials):
			last_initials = "AAA"
		if not _is_difficulty(selected_difficulty):
			selected_difficulty = DIFFICULTY_NORMAL
		for difficulty_id in DIFFICULTY_IDS:
			_leaderboards[difficulty_id] = _validated_entries(
				cfg.get_value("leaderboard", difficulty_id, []), difficulty_id
			)
		if int(cfg.get_value("game_state", "schema_version", 0)) < SCHEMA_VERSION:
			_migrate_legacy_best(
				_leaderboards,
				int(cfg.get_value("game", "best", 0)),
				Time.get_date_string_from_system()
			)
	run_difficulty = selected_difficulty
	best = get_best(run_difficulty)
	if load_error == OK or load_error == ERR_FILE_NOT_FOUND:
		_save_data()


func run_self_test() -> bool:
	var boards := _empty_leaderboards()
	for value in range(10, 130, 10):
		_insert_entry(boards, _make_entry("AAA", value, value / 10, value, float(value), "2026-01-01", DIFFICULTY_EASY))
	_insert_entry(boards, _make_entry("BBB", 500, 2, 3, 4.0, "2026-01-02", DIFFICULTY_NORMAL))
	_insert_entry(boards, _make_entry("CCC", 700, 2, 3, 4.0, "2026-01-03", DIFFICULTY_HARD))
	var easy := _get_leaderboard_from(boards, DIFFICULTY_EASY)
	var all := _get_leaderboard_from(boards, ALL_DIFFICULTIES)
	if easy.size() != MAX_ENTRIES or int(easy[0]["score"]) != 120 or int(easy[9]["score"]) != 30:
		return false
	if all.size() != 12 or int(all[0]["score"]) != 700 or int(all[1]["score"]) != 500:
		return false
	var migrated := _empty_leaderboards()
	_migrate_legacy_best(migrated, 321, "2000-01-01")
	var normal := _get_leaderboard_from(migrated, DIFFICULTY_NORMAL)
	if normal.size() != 1 or normal[0]["initials"] != "OLD" or normal[0]["difficulty"] != DIFFICULTY_NORMAL:
		return false
	_migrate_legacy_best(migrated, 0, "2000-01-01")
	return (_get_leaderboard_from(migrated, DIFFICULTY_NORMAL) as Array).size() == 1


func _save_data() -> Error:
	var cfg := ConfigFile.new()
	var load_error := cfg.load(SAVE_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	cfg.set_value("game_state", "schema_version", SCHEMA_VERSION)
	cfg.set_value("game_state", "selected_difficulty", selected_difficulty)
	cfg.set_value("game_state", "last_initials", last_initials)
	for difficulty_id in DIFFICULTY_IDS:
		cfg.set_value("leaderboard", difficulty_id, _leaderboards[difficulty_id])
	return cfg.save(SAVE_PATH)


func _validated_entries(value: Variant, difficulty_id: String) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for candidate in value:
		if not candidate is Dictionary:
			continue
		var entry: Dictionary = candidate
		var initials := str(entry.get("initials", ""))
		var entry_difficulty := str(entry.get("difficulty", ""))
		var score_value := int(entry.get("score", 0))
		var wave := int(entry.get("wave", -1))
		var kill_count := int(entry.get("kills", -1))
		var run_time := float(entry.get("time", -1.0))
		var date := str(entry.get("date", ""))
		if not _valid_initials(initials) or entry_difficulty != difficulty_id or score_value <= 0:
			continue
		if wave < 0 or kill_count < 0 or run_time < 0.0 or not is_finite(run_time) or date.is_empty():
			continue
		result.append(_make_entry(initials, score_value, wave, kill_count, run_time, date, difficulty_id))
	result.sort_custom(_entry_before)
	result.resize(mini(result.size(), MAX_ENTRIES))
	return result


func _migrate_legacy_best(boards: Dictionary, legacy_best: int, date: String) -> void:
	if legacy_best > 0:
		_insert_entry(boards, _make_entry("OLD", legacy_best, 0, 0, 0.0, date, DIFFICULTY_NORMAL))


func _insert_entry(boards: Dictionary, entry: Dictionary) -> void:
	var difficulty_id: String = entry["difficulty"]
	var board: Array = boards[difficulty_id]
	board.append(entry)
	board.sort_custom(_entry_before)
	board.resize(mini(board.size(), MAX_ENTRIES))


func _get_leaderboard_from(boards: Dictionary, filter: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if filter != ALL_DIFFICULTIES and not _is_difficulty(filter):
		return result
	var difficulty_ids: Array = DIFFICULTY_IDS if filter == ALL_DIFFICULTIES else [filter]
	for difficulty_id in difficulty_ids:
		for value in boards[difficulty_id]:
			var entry: Dictionary = value
			result.append(entry.duplicate(true))
	result.sort_custom(_entry_before)
	return result


func _make_entry(
	initials: String,
	score_value: int,
	wave: int,
	kill_count: int,
	run_time: float,
	date: String,
	difficulty_id: String
) -> Dictionary:
	return {
		"initials": initials,
		"score": score_value,
		"wave": wave,
		"kills": kill_count,
		"time": run_time,
		"date": date,
		"difficulty": difficulty_id,
	}


func _entry_before(a: Dictionary, b: Dictionary) -> bool:
	for key in ["score", "wave", "kills"]:
		if int(a[key]) != int(b[key]):
			return int(a[key]) > int(b[key])
	if float(a["time"]) != float(b["time"]):
		return float(a["time"]) > float(b["time"])
	if str(a["date"]) != str(b["date"]):
		return str(a["date"]) < str(b["date"])
	if str(a["initials"]) != str(b["initials"]):
		return str(a["initials"]) < str(b["initials"])
	return DIFFICULTY_IDS.find(a["difficulty"]) < DIFFICULTY_IDS.find(b["difficulty"])


func _valid_initials(initials: String) -> bool:
	if initials.length() != 3:
		return false
	for index in 3:
		var character := initials.unicode_at(index)
		if character < 65 or character > 90:
			return false
	return true


func _is_difficulty(difficulty_id: String) -> bool:
	return difficulty_id in DIFFICULTY_IDS


func _empty_leaderboards() -> Dictionary:
	return {
		DIFFICULTY_EASY: [],
		DIFFICULTY_NORMAL: [],
		DIFFICULTY_HARD: [],
	}
