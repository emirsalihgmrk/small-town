class_name FieldBunny
extends Node2D
## Sağdaki çalının arkasından arada bir başını çıkaran tavşan; yanında havuç düşünen bir balon belirir.
## Dokunulunca sepette havuç varsa sepetten bir havuç ona uçar: tavşan kıtır kıtır yer, kalpler çıkar,
## sevinçle zıplayıp saklanır. Sepetten verilen havuç geri gelmez, çocuk paylaşmış olur.
## Havuç yoksa burnunu oynatıp saklanır. Kök noktası çalının dibidir. Tavşan, bu çizginin altını
## çizmeyen bir yuvanın (Burrow) içindedir: saklıyken tamamen görünmez, çalının ardından yükselir.

signal peeked
signal fed

enum Mode { HIDDEN, PEEKING, BUSY }

## Body'nin yuva içindeki dikey konumları: saklı (çizginin tamamen altında) ve başı çalının üstünde.
const HIDDEN_Y: float = 430.0
const PEEK_Y: float = 244.0
const PEEK_TIME: float = 0.35
const HIDE_TIME: float = 0.3
const TWITCH_DEGREES: float = 4.0
const TWITCH_PERIOD: float = 0.9
const BUBBLE_DELAY: float = 0.3
const BUBBLE_POP_TIME: float = 0.25
## Body'ye göre ağız noktası (havuç buraya uçar).
const MOUTH: Vector2 = Vector2(26.0, -39.0)
const CHEW_COUNT: int = 3
const CHEW_SQUASH: float = 0.92
const CHEW_TIME: float = 0.11
const HOP_HEIGHT: float = 40.0
const HOP_TIME: float = 0.2
const SHAKE_DEGREES: float = 8.0
const SHAKE_TIME: float = 0.07
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var basket_view: BasketView
@export var heart_scene: PackedScene
@export_range(1.0, 120.0, 0.5, "suffix:s") var first_peek_min: float = 8.0
@export_range(1.0, 120.0, 0.5, "suffix:s") var first_peek_max: float = 14.0
@export_range(1.0, 300.0, 0.5, "suffix:s") var peek_interval_min: float = 20.0
@export_range(1.0, 300.0, 0.5, "suffix:s") var peek_interval_max: float = 40.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var peek_duration: float = 7.0
@export_file("*.ogg", "*.wav") var munch_sound_path: String = "res://assets/audio/sfx/bunny_munch.ogg"

var mode: Mode = Mode.HIDDEN

var _munch_sound: AudioStream
var _peek_timer: Timer
var _hide_timer: Timer
var _twitch_tween: Tween
var _body_scale: Vector2

@onready var _body: Node2D = $Burrow/Body
@onready var _bubble: Node2D = $Bubble
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	_body_scale = _body.scale
	_bubble.hide()
	_tap_area.enabled = false
	_tap_area.tapped.connect(func(_point: Vector2) -> void: _on_tapped())
	if ResourceLoader.exists(munch_sound_path):
		_munch_sound = load(munch_sound_path) as AudioStream
	_peek_timer = _make_timer(peek)
	_hide_timer = _make_timer(_hide)
	_peek_timer.start(randf_range(first_peek_min, first_peek_max))


## Çalının arkasından başını çıkarır.
func peek() -> void:
	if mode != Mode.HIDDEN:
		return
	mode = Mode.PEEKING
	_tap_area.enabled = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"position:y", PEEK_Y, PEEK_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(BUBBLE_DELAY)
	tween.tween_callback(_show_bubble)
	_twitch_tween = Oscillation.ping_pong(self, _body, ^"rotation", deg_to_rad(-TWITCH_DEGREES),
			deg_to_rad(TWITCH_DEGREES), TWITCH_PERIOD)
	_hide_timer.start(peek_duration)
	peeked.emit()


func _on_tapped() -> void:
	if mode != Mode.PEEKING:
		return
	mode = Mode.BUSY
	_tap_area.enabled = false
	_hide_timer.stop()
	_hide_bubble()
	if Basket.take(Items.CARROT):
		basket_view.send(Items.CARROT, _body.to_global(MOUTH), _eat)
	else:
		_shake_then_hide()


## Havuç geldi: kıtır kıtır yer, kalpler çıkar, sevinçle zıplayıp saklanır.
func _eat() -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_munch_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.95, 1.08), pan)
	if heart_scene != null:
		var hearts: CPUParticles2D = heart_scene.instantiate() as CPUParticles2D
		add_child(hearts)
		hearts.global_position = _body.to_global(MOUTH)
		hearts.finished.connect(hearts.queue_free)
		hearts.emitting = true
	fed.emit()
	var tween: Tween = create_tween()
	for i: int in CHEW_COUNT:
		tween.tween_property(_body, ^"scale", Vector2(_body_scale.x, _body_scale.y * CHEW_SQUASH), CHEW_TIME)
		tween.tween_property(_body, ^"scale", _body_scale, CHEW_TIME)
	tween.tween_property(_body, ^"position:y", PEEK_Y - HOP_HEIGHT, HOP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"position:y", PEEK_Y, HOP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_hide)


## Sepette havuç yok: başını sallar (burnunu oynatır) ve saklanır.
func _shake_then_hide() -> void:
	_stop_twitch()
	var tween: Tween = create_tween()
	for i: int in 3:
		tween.tween_property(_body, ^"rotation", deg_to_rad(SHAKE_DEGREES), SHAKE_TIME)
		tween.tween_property(_body, ^"rotation", deg_to_rad(-SHAKE_DEGREES), SHAKE_TIME)
	tween.tween_property(_body, ^"rotation", 0.0, SHAKE_TIME)
	tween.tween_callback(_hide)


func _hide() -> void:
	if mode == Mode.HIDDEN:
		return
	mode = Mode.BUSY
	_tap_area.enabled = false
	_stop_twitch()
	_hide_bubble()
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"position:y", HIDDEN_Y, HIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, ^"rotation", 0.0, HIDE_TIME)
	tween.tween_callback(func() -> void:
		mode = Mode.HIDDEN
		_peek_timer.start(randf_range(peek_interval_min, peek_interval_max)))


func _show_bubble() -> void:
	if mode != Mode.PEEKING:
		return
	_bubble.scale = Vector2.ZERO
	_bubble.show()
	create_tween().tween_property(_bubble, ^"scale", Vector2.ONE, BUBBLE_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_bubble() -> void:
	if not _bubble.visible:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_bubble.hide)


func _stop_twitch() -> void:
	if _twitch_tween != null:
		_twitch_tween.kill()
		_twitch_tween = null


func _make_timer(on_timeout: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer
