extends Node
## Single point for all sound: play(name). Small voice pool, slight pitch variation.

const NAMES := ["swish", "coin", "equip", "melt", "rise", "grab"]
var _streams := {}
var _pool: Array = []
var _next := 0
var played: Array = []   # names played (for capture metrics)


func _ready() -> void:
	for n in NAMES:
		_streams[n] = load("res://audio/sfx/%s.wav" % n)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play(name: String, pitch := 1.0, db := 0.0) -> void:
	if not _streams.has(name):
		return
	played.append(name)
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.volume_db = db
	p.play()
