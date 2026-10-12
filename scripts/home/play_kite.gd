class_name PlayKite
extends Node2D
## Ana ekrandaki uçurtma (Dükkân'dan alınınca görünür). Parmakla tutulup gökyüzünde gezdirilir; ipi sağdaki
## ağacın gövdesine bağlıdır ve her an sarkık bir eğri olarak yeniden çizilir. Bırakılınca olduğu yerde
## rüzgârda hafifçe süzülür. Kaydırmadan dokununca bir takla atar, kız sevinir. Kayıt yoktur.
## Kök noktası ipin uçurtmaya bağlandığı yerdir (alt ucu); Tilt harekete göre yatar, Tilt/Spin uçurtmanın
## ortasından takla attırır, Body rüzgârda sallanır.
## Dokunuşu kendisi yakalar (TapRouter'a girmez); ana ekranda uçurtmayla çakışan Tappable yoktur.

const NO_TOUCH: int = -1
## Kaydırma bundan kısaysa dokunuş sayılır (takla).
const TAP_DISTANCE: float = 16.0
## Uçurtmanın gezebildiği gökyüzü (kök noktası için, dünya): kartlara ve yere inmesin.
const SKY: Rect2 = Rect2(340.0, 130.0, 1240.0, 250.0)
const FOLLOW_SHARPNESS: float = 8.0
## Yatay hız başına yatma (radyan / (px/sn)).
const TILT_FACTOR: float = 0.0012
const MAX_TILT: float = 0.45
const TILT_SHARPNESS: float = 6.0
const DRIFT: Vector2 = Vector2(14.0, 9.0)
const DRIFT_PERIOD: float = 6.0
const LOOP_TIME: float = 0.9
const LOOP_LIFT: float = 40.0
## İpin bağlandığı yer: sağdaki ağacın gövdesi (dünya).
const ANCHOR: Vector2 = Vector2(1370.0, 630.0)
## İpin sarkması, uçurtma ile bağ arasındaki uzaklığa oranla.
const SAG: float = 0.12
const STRING_POINTS: int = 16
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var girl: Girl
## Uçurtmanın tutulabildiği alan (kök noktasına göre).
@export var grab_area: Rect2 = Rect2(-60.0, -130.0, 120.0, 190.0)
@export_file("*.ogg", "*.wav") var loop_sound_path: String = "res://assets/audio/sfx/sickle_swish.ogg"
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var loop_volume_db: float = -8.0

var _touch_index: int = NO_TOUCH
var _press_point: Vector2
var _grab_offset: Vector2
var _moved: bool = false
var _rest: Vector2
var _target: Vector2
var _time: float = 0.0
var _looping: bool = false
var _loop_sound: AudioStream

@onready var _tilt: Node2D = $Tilt
@onready var _spin: Node2D = $Tilt/Spin
@onready var _body: Node2D = $Tilt/Spin/Body
@onready var _string: Line2D = $String


func _ready() -> void:
	if ResourceLoader.exists(loop_sound_path):
		_loop_sound = load(loop_sound_path) as AudioStream
	_rest = position
	_target = position
	_time = randf() * DRIFT_PERIOD


func _process(delta: float) -> void:
	_time += delta
	var previous_x: float = position.x
	if _touch_index == NO_TOUCH:
		var phase: float = _time * TAU / DRIFT_PERIOD
		_target = _rest + Vector2(sin(phase) * DRIFT.x, sin(phase * 2.0) * DRIFT.y)
	position = position.lerp(_target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	if not _looping and delta > 0.0:
		var tilt: float = clampf((position.x - previous_x) / delta * TILT_FACTOR, -MAX_TILT, MAX_TILT)
		_tilt.rotation = lerp_angle(_tilt.rotation, tilt, 1.0 - exp(-TILT_SHARPNESS * delta))
	_draw_string()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		var point: Vector2 = _to_world(touch.position)
		if touch.pressed and _touch_index == NO_TOUCH and grab_area.has_point(point - position):
			_touch_index = touch.index
			_press_point = point
			_grab_offset = position - point
			_moved = false
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = NO_TOUCH
			_rest = _target
			if not _moved:
				_loop()
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		var point: Vector2 = _to_world(drag.position)
		if point.distance_to(_press_point) >= TAP_DISTANCE:
			_moved = true
		if _moved:
			_target = (point + _grab_offset).clamp(SKY.position, SKY.end)
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: uçurtma olduğu yerde kalır.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_touch_index = NO_TOUCH
			_rest = _target


## Bir tam tur atarken biraz yükselir.
func _loop() -> void:
	if _looping:
		return
	_looping = true
	var direction: float = -1.0 if randf() < 0.5 else 1.0
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_loop_sound, AudioManager.BUS_SFX, loop_volume_db, randf_range(0.85, 1.0), pan)
	if girl != null:
		girl.cheer()
	var center_y: float = _spin.position.y
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_spin, ^"rotation", TAU * direction, LOOP_TIME)
	tween.parallel().tween_method(func(t: float) -> void:
		_spin.position.y = center_y - sin(PI * t) * LOOP_LIFT, 0.0, 1.0, LOOP_TIME)
	tween.tween_callback(func() -> void:
		_spin.rotation = 0.0
		_looping = false)


## İp, uçurtmanın alt ucundan (takla atarken de) ağaca doğru aşağı sarkan bir eğri (ikinci dereceden Bezier).
func _draw_string() -> void:
	var start: Vector2 = to_local(_body.global_position)
	var end: Vector2 = to_local(ANCHOR)
	var control: Vector2 = (start + end) * 0.5 + Vector2(0.0, start.distance_to(end) * SAG)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in STRING_POINTS + 1:
		var t: float = float(i) / STRING_POINTS
		points.append(start.lerp(control, t).lerp(control.lerp(end, t), t))
	_string.points = points


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point
