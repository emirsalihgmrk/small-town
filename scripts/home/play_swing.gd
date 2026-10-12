class_name PlaySwing
extends Node2D
## Ana ekrandaki salıncak (Dükkân'dan alınınca görünür). Salıncağa dokununca kız zıplayıp oturur; oturunca
## her dokunuş salıncağı biraz daha iter. Salınım sarkaç gibi yavaş yavaş söner; salıncak durup bir süre
## dokunulmayınca kız zıplayıp kendi yerine döner. Kayıt yoktur: sahne her açılışta kız yerinde başlar.
## Kök noktası salıncağın yerdeki ortasıdır; Seat (ipler + oturak) üst kirişin ortasından döner.

enum State { EMPTY, HOPPING, SEATED }

## Kızın kök noktasının (ayaklarının) oturaktaki yeri, Seat'e göre.
const GIRL_ON_SEAT: Vector2 = Vector2(0.0, 380.0)
## g/L: büyüdükçe salınım hızlanır (7.5 ≈ 2.3 sn'lik tam gidiş-dönüş).
const STIFFNESS: float = 7.5
const DAMPING: float = 0.22
## Bir dokunuşun açısal hıza eklediği (radyan/sn).
const PUSH: float = 0.6
const MAX_ANGLE_DEGREES: float = 24.0
## Bacaklar harekete göre geride kalır: açısal hız başına radyan.
const KICK_FACTOR: float = 0.22
const MAX_KICK: float = 0.45
const HOP_TIME: float = 0.6
const HOP_HEIGHT: float = 130.0
## Bu açının ve hızın altında salıncak durmuş sayılır; kız GET_OFF_DELAY sonra iner.
const REST_ANGLE: float = 0.03
const REST_SPEED: float = 0.06
const GET_OFF_DELAY: float = 5.0
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var girl: Girl
@export_file("*.ogg", "*.wav") var hop_sound_path: String = "res://assets/audio/sfx/feather_fluff.ogg"
@export_file("*.ogg", "*.wav") var push_sound_path: String = "res://assets/audio/sfx/sickle_swish.ogg"
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var push_volume_db: float = -10.0

var _state: State = State.EMPTY
var _angle: float = 0.0
var _velocity: float = 0.0
var _rest_time: float = 0.0
var _home: Vector2
var _hop_sound: AudioStream
var _push_sound: AudioStream

@onready var _seat: Node2D = $Seat
@onready var _seat_shadow: Node2D = $SeatShadow


func _ready() -> void:
	if ResourceLoader.exists(hop_sound_path):
		_hop_sound = load(hop_sound_path) as AudioStream
	if ResourceLoader.exists(push_sound_path):
		_push_sound = load(push_sound_path) as AudioStream
	for tap: Tappable in [$FrameTap, $Seat/SeatTap]:
		tap.tapped.connect(_on_tapped)
	if girl != null:
		_home = girl.global_position


func _process(delta: float) -> void:
	_velocity += (-STIFFNESS * sin(_angle) - DAMPING * _velocity) * delta
	_angle += _velocity * delta
	_seat.rotation = _angle
	_seat_shadow.position.x = _seat.position.x + GIRL_ON_SEAT.rotated(_angle).x
	if _state != State.SEATED:
		return
	_place_girl()
	girl.kick(clampf(-_velocity * KICK_FACTOR, -MAX_KICK, MAX_KICK))
	if absf(_angle) < REST_ANGLE and absf(_velocity) < REST_SPEED:
		_rest_time += delta
		if _rest_time >= GET_OFF_DELAY:
			_hop_off()
	else:
		_rest_time = 0.0


func _on_tapped(_point: Vector2) -> void:
	if girl == null:
		return
	match _state:
		State.EMPTY:
			_hop_on()
		State.SEATED:
			_push()


## Hareket yönüne doğru iter (dururken sola); salınım MAX_ANGLE_DEGREES'i aşmaz.
func _push() -> void:
	var direction: float = signf(_velocity) if absf(_velocity) > REST_SPEED else 1.0
	_velocity += direction * PUSH
	var max_energy: float = STIFFNESS * (1.0 - cos(deg_to_rad(MAX_ANGLE_DEGREES)))
	var potential: float = STIFFNESS * (1.0 - cos(_angle))
	var max_speed: float = sqrt(2.0 * maxf(max_energy - potential, 0.0))
	_velocity = clampf(_velocity, -max_speed, max_speed)
	_rest_time = 0.0
	_play(_push_sound, push_volume_db)
	girl.cheer(false, false)


func _hop_on() -> void:
	_hop(func() -> Vector2: return _seat.to_global(GIRL_ON_SEAT), func() -> void:
		girl.sit(true)
		_rest_time = 0.0
		_state = State.SEATED)


func _hop_off() -> void:
	girl.kick(0.0)
	girl.rotation = 0.0
	_hop(func() -> Vector2: return _home, func() -> void:
		girl.sit(false)
		girl.cheer()
		_state = State.EMPTY)


## Kızı bir yay çizerek hedefe zıplatır; hedef her karede yeniden okunur (oturak hâlâ kıpırdıyor olabilir).
func _hop(target: Callable, on_landed: Callable) -> void:
	_state = State.HOPPING
	_play(_hop_sound, 0.0)
	var from: Vector2 = girl.global_position
	var tween: Tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		var to: Vector2 = target.call()
		girl.global_position = from.lerp(to, t) + Vector2(0.0, -sin(PI * t) * HOP_HEIGHT), 0.0, 1.0, HOP_TIME)
	tween.tween_callback(on_landed)


func _place_girl() -> void:
	girl.global_position = _seat.to_global(GIRL_ON_SEAT)
	girl.global_rotation = _seat.global_rotation


func _play(stream: AudioStream, volume_db: float) -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(stream, AudioManager.BUS_SFX, volume_db, randf_range(0.9, 1.1), pan)
