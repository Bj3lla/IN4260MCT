class_name Leaderboard
## Responsibility: the timed-mode scores for this session. Lives in static
## memory only, so it survives scene changes but resets when the game closes.
## Each entry: { name, meters, ball, map }.

static var entries: Array[Dictionary] = []
static var _runs := 0


## Name to suggest when the player leaves the name box empty.
static func default_name() -> String:
	return "Player %d" % (_runs + 1)


## Adds a score and returns its rank (0 = first place).
static func add(player_name: String, meters: float, ball: String, map: String) -> int:
	_runs += 1
	var entry := {
		"name": player_name.strip_edges() if not player_name.strip_edges().is_empty() else "Player %d" % _runs,
		"meters": int(meters), "ball": ball, "map": map,
	}
	entries.append(entry)
	entries.sort_custom(func(a, b): return a.meters > b.meters)
	return entries.find(entry)
