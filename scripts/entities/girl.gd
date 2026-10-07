class_name Girl
extends Node2D
## Kız karakter: ara ara el sallar, göz kırpar, dokununca yumuşak bir "fırt" sesiyle zıplar (kümesteki
## tavuğa dokununca çalan sesin aynısı).
## Sahneler olaylara tepki verdirmek için cheer / wave / surprise / yawn çağırır. Bu tepkiler sessizdir:
## işlerin (hasat, ekim...) kendi sesi zaten vardır, her seferinde üstüne bir ses daha binmesin.
## Sürekli nefes, gövde/baş sallanması ve şapka/örgü salınımı sahnedeki bileşenlerle yapılır
## (PulseComponent, SwayComponent, SpringFollowComponent).

const BLINK_CLOSED_TIME: float = 0.12
const WAVE_RAISE_TIME: float = 0.45
const WAVE_SWING_TIME: float = 0.22
const WAVE_LOWER_TIME: float = 0.8
const JUMP_UP_TIME: float = 0.16
const JUMP_DOWN_TIME: float = 0.2
const REACTION_TIME: float = 0.7
const SURPRISE_TIME: float = 0.9
const SURPRISE_HOP: float = 0.5
const YAWN_STRETCH: Vector2 = Vector2(0.97, 1.06)
const YAWN_ARM_DEGREES: float = 40.0
const YAWN_IN_TIME: float = 0.6
const YAWN_HOLD_TIME: float = 0.6
const YAWN_OUT_TIME: float = 0.5
## Sol kol (aynalanmamış) pozitif, sağ kol (scale.x = -1) negatif açıyla yukarı kalkar.
const ARM_RAISE_SIGN: Array[float] = [1.0, -1.0]
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export_group("El sallama")
@export_range(1.0, 60.0, 0.5, "suffix:s") var wave_interval_min: float = 8.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var wave_interval_max: float = 15.0
## Kolun omuzdan kalkma açısı; daha büyüğünde el başın arkasına geçer.
@export_range(0.0, 180.0, 1.0, "suffix:°") var wave_raise_degrees: float = 100.0
@export_range(0.0, 45.0, 1.0, "suffix:°") var wave_swing_degrees: float = 12.0
@export_range(1, 5) var wave_count_min: int = 2
@export_range(1, 5) var wave_count_max: int = 3

@export_group("Göz kırpma")
@export_range(0.5, 20.0, 0.1, "suffix:s") var blink_interval_min: float = 3.0
@export_range(0.5, 20.0, 0.1, "suffix:s") var blink_interval_max: float = 6.0

@export_group("Dokunma")
@export_range(0.0, 80.0, 1.0, "suffix:px") var jump_height: float = 22.0
@export_file("*.ogg", "*.wav") var happy_sound_path: String = "res://assets/audio/sfx/feather_fluff.ogg"
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var happy_volume_db: float = 0.0
@export_range(0.0, 0.3, 0.01) var happy_pitch_variation: float = 0.1

var _waving: bool = false
var _reacting: bool = false
var _happy_sound: AudioStream
var _blink_timer: Timer
var _wave_timer: Timer

@onready var _body: Node2D = $Body
@onready var _torso: Node2D = $Body/Torso
@onready var _arms: Array[Node2D] = [$Body/Torso/ArmL, $Body/Torso/ArmR]
@onready var _eyes_open: CanvasItem = $Body/Torso/Head/Eyes/Open
@onready var _eyes_closed: CanvasItem = $Body/Torso/Head/Eyes/Closed
@onready var _mouth_smile: CanvasItem = $Body/Torso/Head/Mouth/Smile
@onready var _mouth_open: CanvasItem = $Body/Torso/Head/Mouth/Open
@onready var _tap_area: Tappable = $TapArea
@onready var _hearts: CPUParticles2D = $Hearts
@onready var _stars: CPUParticles2D = $Stars


func _ready() -> void:
	if ResourceLoader.exists(happy_sound_path):
		_happy_sound = load(happy_sound_path) as AudioStream
	_tap_area.tapped.connect(_on_tapped)
	_blink_timer = _make_timer(_blink)
	_wave_timer = _make_timer(_wave)
	_restart(_blink_timer, blink_interval_min, blink_interval_max)
	_restart(_wave_timer, wave_interval_min, wave_interval_max)


func _blink() -> void:
	if not _reacting:
		_set_eyes_closed(true)
		var tween: Tween = create_tween()
		tween.tween_interval(BLINK_CLOSED_TIME)
		tween.tween_callback(func() -> void:
			if not _reacting:
				_set_eyes_closed(false))
	_restart(_blink_timer, blink_interval_min, blink_interval_max)


## Zamanı gelen el sallama bir tepkiye denk gelip atlandıysa bir sonrakini yine kur.
func _wave() -> void:
	wave()
	if not _waving:
		_restart(_wave_timer, wave_interval_min, wave_interval_max)


## side: 0 = ekranda soldaki kol, 1 = sağdaki kol, -1 = rastgele. El sallarken ya da bir tepki sürerken
## gelen istek yok sayılır.
func wave(side: int = -1) -> void:
	if _waving or _reacting:
		return
	_waving = true
	if side < 0:
		side = randi_range(0, 1)
	var arm: Node2D = _arms[side]
	var raised: float = deg_to_rad(wave_raise_degrees) * ARM_RAISE_SIGN[side]
	var swing: float = deg_to_rad(wave_swing_degrees) * ARM_RAISE_SIGN[side]
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(arm, ^"rotation", raised, WAVE_RAISE_TIME).set_ease(Tween.EASE_OUT)
	for i: int in randi_range(wave_count_min, maxi(wave_count_min, wave_count_max)):
		tween.tween_property(arm, ^"rotation", raised + swing, WAVE_SWING_TIME)
		tween.tween_property(arm, ^"rotation", raised - swing, WAVE_SWING_TIME)
	tween.tween_property(arm, ^"rotation", 0.0, WAVE_LOWER_TIME)
	tween.tween_callback(func() -> void:
		_waving = false
		_restart(_wave_timer, wave_interval_min, wave_interval_max))


func _on_tapped(_global_tap_position: Vector2) -> void:
	cheer(true)


## Sevinir: zıplar, kalpler ve yıldızlar saçar; with_sound ise (yalnızca kıza dokunulunca) "fırt" sesi
## de çalar. Tepki sürerken gelen istek yok sayılır; animasyonlar üst üste binmez.
func cheer(with_sound: bool = false) -> void:
	if _reacting:
		return
	_reacting = true
	if with_sound:
		var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
		AudioManager.play_sfx(_happy_sound, AudioManager.BUS_SFX, happy_volume_db,
				1.0 + randf_range(-happy_pitch_variation, happy_pitch_variation), pan)
	_hearts.restart()
	_stars.restart()
	_set_eyes_closed(true)
	_set_mouth_open(true)
	var jump: Tween = create_tween()
	jump.tween_property(_body, ^"position:y", -jump_height, JUMP_UP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump.tween_property(_body, ^"position:y", 0.0, JUMP_DOWN_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var face: Tween = create_tween()
	face.tween_interval(REACTION_TIME)
	face.tween_callback(func() -> void:
		_set_eyes_closed(false)
		_set_mouth_open(false)
		_reacting = false)


## Şaşırır: gözler açık, ağız açık, küçük bir sıçrama.
func surprise() -> void:
	if _reacting:
		return
	_reacting = true
	_set_eyes_closed(false)
	_set_mouth_open(true)
	var hop: Tween = create_tween()
	hop.tween_property(_body, ^"position:y", -jump_height * SURPRISE_HOP, JUMP_UP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(_body, ^"position:y", 0.0, JUMP_DOWN_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var face: Tween = create_tween()
	face.tween_interval(SURPRISE_TIME)
	face.tween_callback(func() -> void:
		_set_mouth_open(false)
		_reacting = false)


## Uzun süre bir şey olmayınca esner: gözler kapanır, ağız açılır, gerinip kollarını biraz kaldırır.
## Başka bir hareketin ortasındaysa esnemez ve false döner.
func yawn() -> bool:
	if _reacting or _waving:
		return false
	_reacting = true
	_set_eyes_closed(true)
	_set_mouth_open(true)
	var stretch: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stretch.tween_property(_torso, ^"scale", YAWN_STRETCH, YAWN_IN_TIME)
	for i: int in _arms.size():
		stretch.parallel().tween_property(_arms[i], ^"rotation", deg_to_rad(YAWN_ARM_DEGREES) * ARM_RAISE_SIGN[i], YAWN_IN_TIME)
	stretch.tween_interval(YAWN_HOLD_TIME)
	stretch.tween_property(_torso, ^"scale", Vector2.ONE, YAWN_OUT_TIME)
	for arm: Node2D in _arms:
		stretch.parallel().tween_property(arm, ^"rotation", 0.0, YAWN_OUT_TIME)
	stretch.tween_callback(func() -> void:
		_set_eyes_closed(false)
		_set_mouth_open(false)
		_reacting = false)
	return true


func _set_eyes_closed(closed: bool) -> void:
	_eyes_open.visible = not closed
	_eyes_closed.visible = closed


func _set_mouth_open(open: bool) -> void:
	_mouth_smile.visible = not open
	_mouth_open.visible = open


func _make_timer(on_timeout: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer


func _restart(timer: Timer, min_seconds: float, max_seconds: float) -> void:
	timer.start(randf_range(min_seconds, maxf(min_seconds, max_seconds)))
