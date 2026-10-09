class_name ShopBell
extends Node2D
## Dükkân kapısının üstündeki zil. Çalınca (ring) tepesinden sarkaç gibi sallanıp yavaşça durulur ve ince
## bir çan sesi çıkar. Dükkâna girilince bir kez kendiliğinden çalar; dokununca yine çalar.
## Kök noktası zilin asıldığı yerdir (sallanmanın pivotu).

const SWING_DEGREES: float = 18.0
## Saniyedeki salınım hızı (radyan).
const SWING_SPEED: float = 11.0
## Sallanmanın sönme hızı (saniyede kaybolan enerji).
const DECAY: float = 0.8
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export_file("*.ogg", "*.wav") var ring_sound_path: String = "res://assets/audio/sfx/cow_bell.ogg"
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var ring_volume_db: float = -6.0
## Ahırdaki çan sesinin perdesi yükseltilir: küçük bir dükkân zili gibi.
@export_range(0.5, 3.0, 0.05) var ring_pitch: float = 1.7
## Sahne açıldıktan bu kadar sonra kendiliğinden bir kez çalar (0: çalmaz).
@export_range(0.0, 5.0, 0.1, "suffix:s") var enter_ring_delay: float = 0.4

var _ring_sound: AudioStream
var _energy: float = 0.0
var _time: float = 0.0

@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	if ResourceLoader.exists(ring_sound_path):
		_ring_sound = load(ring_sound_path) as AudioStream
	_tap_area.tapped.connect(func(_point: Vector2) -> void: ring())
	if enter_ring_delay > 0.0:
		get_tree().create_timer(enter_ring_delay).timeout.connect(ring)


func ring() -> void:
	_energy = 1.0
	_time = 0.0
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_ring_sound, AudioManager.BUS_SFX, ring_volume_db, ring_pitch * randf_range(0.97, 1.03), pan)


func _process(delta: float) -> void:
	if _energy <= 0.0:
		return
	_energy = maxf(_energy - DECAY * delta, 0.0)
	_time += delta
	rotation = sin(_time * SWING_SPEED) * deg_to_rad(SWING_DEGREES) * _energy
