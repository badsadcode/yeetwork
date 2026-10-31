extends Node
## Music (autoload): tracks dropped into assets/music/ play by name, no code.
## - `menu.ogg` (and `menu_1.ogg`, `menu_2.ogg`... for more): the main menu.
## - `<map>.ogg` (`highseas.ogg`, `pump_house.ogg`, `haunted_yard.ogg`...): that map's
##   matches; a variant's key falls back to its map's (`highseas_storm` plays `highseas`).
## - `match.ogg`: any match without a track of its own.
## One track loops; several play one after another in a shuffled order. Changing from one to
## another (menu to match) fades across. Its own bus, "Music": the Music slider and switch in
## Options (Game.music_volume, music_on); Game.match_music turns it off during matches.

const DIR := "res://assets/music/"
const EXT := ["ogg", "mp3", "wav"]
const FADE_IN := 2.0
const FADE_OUT := 1.5

var tracks := {} # name -> Array[AudioStream]
var playing_list := "" # the name of what's on ("" nothing)
var _players: Array[AudioStreamPlayer] = []
var _cur := 0
var _fade := {} # player -> [from_db, to_db, time, length]
var _queue: Array = []
var _match_key := "" # (in a match: its map; "" on the menu)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # (the pause menu doesn't stop the music)
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		p.finished.connect(_on_finished.bind(p))
		add_child(p)
		_players.append(p)
	_scan()
	Game.apply_audio()


## Finds the tracks in assets/music/ (in an exported game listed as name.ogg.import).
func _scan() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	var found := {}
	for f in DirAccess.get_files_at(DIR):
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		if file.get_extension().to_lower() not in EXT:
			continue
		var stem := file.get_basename().to_lower()
		var cut := stem.rfind("_")
		var list_name := stem.substr(0, cut) if cut > 0 and stem.substr(cut + 1).is_valid_int() else stem
		if not found.has(list_name):
			found[list_name] = []
		if not (DIR + file) in found[list_name]:
			found[list_name].append(DIR + file)
	for list_name in found:
		for path in found[list_name]:
			var s := load(path) as AudioStream
			if s:
				add_track(list_name, s)
			else:
				push_warning("Music %s didn't load" % path)


func add_track(list_name: String, stream: AudioStream) -> void:
	if not tracks.has(list_name):
		tracks[list_name] = []
	tracks[list_name].append(stream)


## The main menu's music.
func play_menu() -> void:
	_match_key = ""
	play_list("menu")


## A match on this map (a key, or a map scene's path): its own track, else `match`; nothing
## when the player has turned music in matches off.
func play_match(map_key: String) -> void:
	_match_key = map_key
	if not Game.match_music:
		play_list("")
		return
	var key := map_key.get_file().get_basename().to_lower() if map_key.contains("/") else map_key.to_lower()
	while key != "":
		if tracks.has(key):
			play_list(key)
			return
		var cut := key.rfind("_")
		key = key.substr(0, cut) if cut > 0 else ""
	play_list("match")


## Match music switched on or off in Options mid-match: follow it.
func refresh_match() -> void:
	if _match_key != "":
		play_match(_match_key)


## Fades over to a list of tracks ("" or a name without tracks: fades out to silence). The
## same list already playing carries on.
func play_list(list_name: String) -> void:
	if not tracks.has(list_name):
		list_name = ""
	if list_name == playing_list:
		return
	playing_list = list_name
	_fade_to(_players[_cur], -80.0, FADE_OUT)
	_queue.clear()
	if list_name == "":
		return
	_cur = 1 - _cur
	_next_track()


func _next_track() -> void:
	var list: Array = tracks.get(playing_list, [])
	if list.is_empty():
		return
	if _queue.is_empty():
		_queue = list.duplicate()
		_queue.shuffle()
	var s: AudioStream = _queue.pop_back()
	var single := list.size() == 1
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if single else AudioStreamWAV.LOOP_DISABLED
		if single:
			(s as AudioStreamWAV).loop_end = int(s.get_length() * (s as AudioStreamWAV).mix_rate)
	elif "loop" in s:
		s.set("loop", single) # (one track loops seamlessly; several follow each other)
	var p := _players[_cur]
	p.stream = s
	p.volume_db = -80.0
	p.play()
	_fade_to(p, 0.0, FADE_IN)


func _on_finished(p: AudioStreamPlayer) -> void:
	if p == _players[_cur] and playing_list != "":
		_next_track()


func _fade_to(p: AudioStreamPlayer, to_db: float, length: float) -> void:
	_fade[p] = [p.volume_db, to_db, 0.0, length]


func _process(delta: float) -> void:
	for p: AudioStreamPlayer in _fade.keys():
		var f: Array = _fade[p]
		f[2] += delta
		var k := clampf(f[2] / f[3], 0.0, 1.0)
		# (in linear volume, so the fade sounds even, not a sudden drop at the end)
		p.volume_db = linear_to_db(lerpf(db_to_linear(f[0]), db_to_linear(f[1]), k))
		if k >= 1.0:
			_fade.erase(p)
			if f[1] <= -79.0:
				p.stop()


## The track playing now (null: none).
func current() -> AudioStream:
	var p := _players[_cur]
	return p.stream if p.playing and playing_list != "" else null
