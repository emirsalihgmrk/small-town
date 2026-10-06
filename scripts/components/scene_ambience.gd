class_name SceneAmbience
extends Node
## Bir sahnenin ses ortamı (ana ekran, tarla): müzik, kesintisiz rüzgâr döngüsü, rastgele aralıklı
## kuş cıvıltıları ve seyrek, uzak bir çiftlik sesi. Sahneden çıkınca müzik ve ortam yumuşakça kapanır; sonraki sahne
## aynı müziği istiyorsa AudioManager kesmeden sürdürür.
## Ses yolları dosya olarak verilir; dosya yoksa o ses sessizce atlanır.

const MIN_BIRD_VARIANTS_FOR_NO_REPEAT: int = 2

@export_group("Müzik")
@export_file("*.ogg", "*.wav") var music_path: String = "res://assets/audio/music/home_theme.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var music_volume_db: float = 0.0

@export_group("Rüzgâr")
@export_file("*.ogg", "*.wav") var wind_path: String = "res://assets/audio/ambience/wind_loop.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var wind_volume_db: float = -10.0

@export_group("Kuşlar")
@export var bird_paths: Array[String] = [
	"res://assets/audio/ambience/bird_chirp_1.ogg",
	"res://assets/audio/ambience/bird_chirp_2.ogg",
	"res://assets/audio/ambience/bird_chirp_3.ogg",
	"res://assets/audio/ambience/bird_chirp_4.ogg",
	"res://assets/audio/ambience/bird_chirp_5.ogg",
]
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var bird_volume_db: float = -4.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var bird_interval_min: float = 6.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var bird_interval_max: float = 14.0
## Her çalışta perde bu oranda rastgele kayar (0.08 = ±%8).
@export_range(0.0, 0.3, 0.01) var bird_pitch_variation: float = 0.08
## Stereo pan aralığı (0 = ortada, 1 = tam sol/sağ).
@export_range(0.0, 1.0, 0.05) var bird_pan_range: float = 0.7

@export_group("Uzak çiftlik sesi")
@export_file("*.ogg", "*.wav") var distant_farm_path: String = "res://assets/audio/ambience/distant_cow.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var distant_farm_volume_db: float = -12.0
## En fazla dakikada bir çalması için alt sınır 60 sn.
@export_range(60.0, 600.0, 1.0, "suffix:s") var distant_farm_interval_min: float = 70.0
@export_range(60.0, 600.0, 1.0, "suffix:s") var distant_farm_interval_max: float = 150.0

var _music: AudioStream
var _wind: AudioStream
var _birds: Array[AudioStream] = []
var _distant_farm: AudioStream
var _last_bird_index: int = -1
var _bird_timer: Timer
var _farm_timer: Timer


func _ready() -> void:
	_music = _load_stream(music_path)
	_wind = _load_stream(wind_path)
	_distant_farm = _load_stream(distant_farm_path)
	for path: String in bird_paths:
		var stream: AudioStream = _load_stream(path)
		if stream != null:
			_birds.append(stream)

	AudioManager.play_music(_music, music_volume_db)
	AudioManager.play_ambience(_wind, wind_volume_db)

	_bird_timer = _make_timer(_on_bird_timer_timeout)
	_farm_timer = _make_timer(_on_farm_timer_timeout)
	_restart(_bird_timer, bird_interval_min, bird_interval_max)
	_restart(_farm_timer, distant_farm_interval_min, distant_farm_interval_max)


func _exit_tree() -> void:
	AudioManager.stop_music()
	AudioManager.stop_ambience()


func _on_bird_timer_timeout() -> void:
	if not _birds.is_empty():
		var index: int = _pick_bird_index()
		_last_bird_index = index
		AudioManager.play_sfx(_birds[index], AudioManager.BUS_AMBIENCE, bird_volume_db,
				1.0 + randf_range(-bird_pitch_variation, bird_pitch_variation),
				randf_range(-bird_pan_range, bird_pan_range))
	_restart(_bird_timer, bird_interval_min, bird_interval_max)


func _on_farm_timer_timeout() -> void:
	AudioManager.play_sfx(_distant_farm, AudioManager.BUS_AMBIENCE, distant_farm_volume_db,
			1.0, randf_range(-bird_pan_range, bird_pan_range))
	_restart(_farm_timer, distant_farm_interval_min, distant_farm_interval_max)


## Aynı cıvıltı art arda iki kez çalmasın.
func _pick_bird_index() -> int:
	if _birds.size() < MIN_BIRD_VARIANTS_FOR_NO_REPEAT or _last_bird_index < 0:
		return randi_range(0, _birds.size() - 1)
	var index: int = randi_range(0, _birds.size() - 2)
	if index >= _last_bird_index:
		index += 1
	return index


func _make_timer(on_timeout: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer


func _restart(timer: Timer, min_seconds: float, max_seconds: float) -> void:
	timer.start(randf_range(min_seconds, maxf(min_seconds, max_seconds)))


func _load_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
