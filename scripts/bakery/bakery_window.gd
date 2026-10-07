class_name BakeryWindow
extends Node2D
## Fırının perdeli penceresi. Dışarıda bir bulut yavaşça süzülür, arada bir pencerenin önünden bir kuş
## uçup geçer; ikisi de camın içinde kalır (Mask, altındakileri cam alanına kırpar). Perdeler hafifçe
## nefes alır gibi sallanır. Pencereye dokununca perdeler savrulur, yumuşak bir hışırtı çalar ve (o an
## uçmuyorsa) bir kuş geçer. Ekonomiye karışmaz. Kök noktası pencerenin ortasıdır.

## Bulut camın bir ucundan öbürüne bu hızla gider, sonra baştan başlar.
const CLOUD_SPEED: float = 10.0
const CLOUD_X_RANGE: float = 200.0
## Kuş camın bu kadar dışından girip çıkar; uçuşu bu yükseklikler arasında, hafif bir kavisle geçer.
const BIRD_X_RANGE: float = 190.0
const BIRD_Y_MIN: float = -110.0
const BIRD_Y_MAX: float = -50.0
const BIRD_ARC: float = 30.0
const BIRD_FLIGHT_TIME: float = 1.6
const FLAP_DEGREES: float = 50.0
const FLAP_TIME: float = 0.08
const CURTAIN_BREATH_DEGREES: float = 1.2
const CURTAIN_BREATH_PERIOD: float = 4.0
## Dokununca perdeler dışa doğru bu kadar savrulup yaylanarak yerine döner.
const CURTAIN_SWAY_DEGREES: float = 9.0
const CURTAIN_SWAY_OUT_TIME: float = 0.15
const CURTAIN_SWAY_BACK_TIME: float = 0.9
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export_range(1.0, 120.0, 0.5, "suffix:s") var bird_interval_min: float = 10.0
@export_range(1.0, 120.0, 0.5, "suffix:s") var bird_interval_max: float = 20.0
@export_file("*.ogg", "*.wav") var rustle_sound_path: String = "res://assets/audio/sfx/feather_fluff.ogg"

var _rustle_sound: AudioStream
var _bird_flying: bool = false
var _bird_timer: Timer
var _flap_tween: Tween
var _curtain_tweens: Array[Tween] = []

@onready var _cloud: Sprite2D = $Mask/Cloud
@onready var _bird: Node2D = $Mask/Bird
@onready var _wing: Node2D = $Mask/Bird/Wing
## Sol perde dışa (sola) savrulurken pozitif, sağ perde negatif döner.
@onready var _curtains: Array[Node2D] = [$CurtainLeft as Node2D, $CurtainRight as Node2D]
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	if ResourceLoader.exists(rustle_sound_path):
		_rustle_sound = load(rustle_sound_path) as AudioStream
	_cloud.position.x = randf_range(-CLOUD_X_RANGE, CLOUD_X_RANGE)
	_bird.hide()
	_curtain_tweens.resize(_curtains.size())
	for i: int in _curtains.size():
		_breathe(i)
	_bird_timer = Timer.new()
	_bird_timer.one_shot = true
	_bird_timer.timeout.connect(_fly_bird)
	add_child(_bird_timer)
	_bird_timer.start(randf_range(bird_interval_min, bird_interval_max))
	_tap_area.tapped.connect(_on_tapped)


func _process(delta: float) -> void:
	_cloud.position.x += CLOUD_SPEED * delta
	if _cloud.position.x > CLOUD_X_RANGE:
		_cloud.position.x = -CLOUD_X_RANGE


func _on_tapped(_point: Vector2) -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_rustle_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.9, 1.1), pan)
	for i: int in _curtains.size():
		_sway(i)
	_fly_bird()


func _outward(index: int) -> float:
	return 1.0 if index == 0 else -1.0


func _breathe(index: int) -> void:
	var curtain: Node2D = _curtains[index]
	var angle: float = deg_to_rad(CURTAIN_BREATH_DEGREES) * _outward(index)
	_curtain_tweens[index] = Oscillation.ping_pong(self, curtain, ^"rotation", -angle, angle,
			CURTAIN_BREATH_PERIOD, 0.2)


func _sway(index: int) -> void:
	var curtain: Node2D = _curtains[index]
	if _curtain_tweens[index] != null:
		_curtain_tweens[index].kill()
	var tween: Tween = create_tween()
	tween.tween_property(curtain, ^"rotation", deg_to_rad(CURTAIN_SWAY_DEGREES) * _outward(index),
			CURTAIN_SWAY_OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(curtain, ^"rotation", 0.0, CURTAIN_SWAY_BACK_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_breathe.bind(index))
	_curtain_tweens[index] = tween


## Kuş camın bir yanından girip kanat çırparak öbür yanından çıkar.
func _fly_bird() -> void:
	if _bird_flying:
		return
	_bird_flying = true
	var from_left: bool = randf() < 0.5
	var from: Vector2 = Vector2(-BIRD_X_RANGE if from_left else BIRD_X_RANGE, randf_range(BIRD_Y_MIN, BIRD_Y_MAX))
	var to: Vector2 = Vector2(-from.x, randf_range(BIRD_Y_MIN, BIRD_Y_MAX))
	_bird.scale.x = absf(_bird.scale.x) * (1.0 if from_left else -1.0)
	_bird.position = from
	_bird.show()
	_flap_tween = create_tween().set_loops()
	_flap_tween.tween_property(_wing, ^"rotation", deg_to_rad(-FLAP_DEGREES), FLAP_TIME)
	_flap_tween.tween_property(_wing, ^"rotation", 0.0, FLAP_TIME)
	var tween: Tween = create_tween()
	tween.tween_method(_arc.bind(from, to), 0.0, 1.0, BIRD_FLIGHT_TIME)
	tween.tween_callback(_on_bird_gone)


## İkinci dereceden Bezier: başlangıç ve varışın ortasının BIRD_ARC üstünden geçer.
func _arc(t: float, from: Vector2, to: Vector2) -> void:
	var control: Vector2 = (from + to) * 0.5 + Vector2(0.0, -BIRD_ARC)
	_bird.position = from.lerp(control, t).lerp(control.lerp(to, t), t)


func _on_bird_gone() -> void:
	_flap_tween.kill()
	_bird.hide()
	_bird_flying = false
	_bird_timer.start(randf_range(bird_interval_min, bird_interval_max))
