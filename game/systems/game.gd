extends Node
## Autoload "Game": settings (volume, fullscreen, shake) and music that survives scene changes.

const TRACKS := {"menu": "res://audio/music/menu.ogg", "run": "res://audio/music/run.ogg", "boss": "res://audio/music/boss.ogg"}
const FADE := 1.2

var settings := {}
var _players: Array = []
var _cur := 0
var _track := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	settings = Save.load_data()["settings"]
	apply(settings)


func apply(s: Dictionary) -> void:
	settings = s
	_bus("Music", float(s["music"]))
	_bus("SFX", float(s["sfx"]))
	if DisplayServer.get_name() != "headless":
		var fs := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(s["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != fs:
			DisplayServer.window_set_mode(fs)


func shake() -> float:
	return float(settings.get("shake", 1.0))


func _bus(name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, v)))
		AudioServer.set_bus_mute(i, v <= 0.001)


## Cross-fade to a track ("menu" | "run" | "boss"); the same track keeps playing.
func music(name: String) -> void:
	if name == _track or not TRACKS.has(name):
		return
	_track = name
	var old: AudioStreamPlayer = _players[_cur]
	_cur = 1 - _cur
	var nw: AudioStreamPlayer = _players[_cur]
	var st: AudioStream = load(TRACKS[name])
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	nw.stream = st
	nw.volume_db = -40.0
	nw.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nw, "volume_db", 0.0, FADE)
	tw.tween_property(old, "volume_db", -60.0, FADE)
	tw.chain().tween_callback(old.stop)
