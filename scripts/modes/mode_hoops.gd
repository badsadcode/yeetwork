class_name ModeHoops
extends ModeYeetball
## YeetHoops: basketball with gravity guns. Two hoops (Hoop), a small bouncy basketball,
## everything else as Yeetball: tip-off from the middle, the clock and next-basket-wins,
## the hold limit, the rulesets, the full-time screen.
## - A basket: the ball drops down through the rim. 2 points; 3 from beyond the arc (where
##   it was last thrown or punted from); a dunk (carried in on the gun) is 2 and a show.
## - First to 21 wins early (or, without a clock, first to 21).
## - The basketball is thrown gently (Prop "throw_speed"): lob it, bank it off the board.

const POINTS_TO_WIN := 21

const BASKET_LINES := [
	"NOTHING BUT NET!", "BANG!", "COUNT IT!", "SMOOTH AS BUTTER!", "OFF THE GLASS AND IN!",
	"THE CROWD GOES WILD!", "BUCKETS!",
]
const THREE_LINES := ["FROM DOWNTOWN!", "THREEEEE!", "SPLASH! FROM %d METRES!", "RAINING THREES!"]
const DUNK_LINES := ["SLAM DUNK!", "OH, THE HUMANITY! WHAT A DUNK!", "POSTERISED!", "THROWN DOWN WITH AUTHORITY!"]
const OWN_LINES := ["Wrong basket! WRONG BASKET!", "Two points... for the other team.", "Somebody turn them around!"]
const BUZZER_LINES := ["AT THE BUZZER!", "BUZZER BEATER!"]

var _prev := {} # ball id -> where it was last frame (a basket: down through the rim)
var _streak := {} # player id -> baskets in a row (for "on fire")


func mode_name() -> String:
	return "TOTAL YEETHOOPS" if rules == Rules.TOTAL else "YeetHoops"


func ball_kind() -> String:
	return "basketball"


func unit() -> String:
	return "point"


func setup(p_world: Node) -> void:
	super.setup(p_world)
	score_limit = POINTS_TO_WIN
	countdown = 2.0


func _golden_label() -> String:
	return "NEXT BASKET WINS"


func _kickoff(line_up: bool) -> void:
	super._kickoff(line_up)
	_prev.clear()


func _scored(p: Prop) -> Array:
	var before: Vector3 = _prev.get(p.prop_id, p.global_position)
	var now := p.global_position
	_prev[p.prop_id] = now
	for g in world.arena.goals:
		var h := g as Hoop
		if h and h.through_rim(before, now, p.size.x):
			var three := p.held_by == 0 and _kick_distance(h, p) > h.three_range
			return [h, 3 if three else 2]
	return []


func _score_text(scorer: Player, team: int, own: bool, points: int, b: Prop) -> String:
	var who: String = Game.TEAM_NAMES[team].to_upper()
	if scorer == null:
		return "IT'S IN! +%d for %s" % [points, who]
	if own:
		return "%s scored in their own basket! (+%d %s)" % [scorer.display_name, points, who]
	if b.held_by != 0:
		return "SLAM DUNK! %s +%d" % [scorer.display_name, points]
	if points == 3:
		return "THREE! %s +3" % scorer.display_name
	return "SWISH! %s +%d" % [scorer.display_name, points]


func _commentate(g: GoalZone, b: Prop, scorer: Player, own: bool) -> void:
	var line := ""
	var from := _kick_distance(g, b)
	var red: int = world.team_scores.get(Game.TEAM_RED, 0)
	var blue: int = world.team_scores.get(Game.TEAM_BLUE, 0)
	for id in _streak.keys():
		if scorer == null or id != scorer.player_id:
			_streak[id] = 0
	if scorer and not own:
		_streak[scorer.player_id] = _streak.get(scorer.player_id, 0) + 1
	if own:
		line = OWN_LINES[_rng.randi() % OWN_LINES.size()]
	elif overtime:
		line = "NEXT BASKET WINS... AND THAT'S IT!"
	elif clock_left != INF and clock_left < 5.0:
		line = BUZZER_LINES[_rng.randi() % BUZZER_LINES.size()]
	elif b.held_by != 0:
		line = DUNK_LINES[_rng.randi() % DUNK_LINES.size()]
	elif scorer and _streak.get(scorer.player_id, 0) == 3:
		line = "%s IS ON FIRE!" % scorer.display_name.to_upper()
	elif from > (g as Hoop).three_range:
		line = THREE_LINES[_rng.randi() % THREE_LINES.size()]
		if line.contains("%d"):
			line = line % int(from)
	elif red == blue:
		line = LEVEL_LINES[_rng.randi() % LEVEL_LINES.size()]
	else:
		line = BASKET_LINES[_rng.randi() % BASKET_LINES.size()]
	world.server_message(line, VOICE)
