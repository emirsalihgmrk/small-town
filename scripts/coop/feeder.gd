class_name Feeder
extends Node2D
## Kümesteki yemlik. Sepetten getirilen bir buğday demeti dökülünce dolar; dolu yemlik üç tavuğa birer
## pay yeter. Tavuk yemeye gelmeden payını ayırır (reserve), yiyince pay düşer (eat) ve yığın küçülür.
## Boşken üstünde bir düşünce balonu durur: ortak sepette buğday varsa balonda buğday demeti, yoksa tarla
## görünür. Tarla görünürken balona dokununca bubble_tapped yayılır (kümes tarlaya götürür).
## Tavukların yemlikte durduğu yerler Spots altındaki işaretlerdir. Kök noktası ayakların ortasıdır.

signal filled
signal bubble_tapped

const PORTIONS: int = 3
const HIGHLIGHT_SCALE: Vector2 = Vector2(1.06, 1.06)
const HIGHLIGHT_TIME: float = 0.12
## Demet eğilip dökülmeye başladıktan sonra taneler yemlikte görünür.
const GRAIN_DELAY: float = 0.2
const GRAIN_RISE_TIME: float = 0.35
const GRAIN_SHRINK_TIME: float = 0.3
const POUR_TIME: float = 0.55
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.4
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_BOB: float = 8.0
const BUBBLE_BOB_PERIOD: float = 1.8
const NUDGE_SCALE: float = 1.25
const NUDGE_TIME: float = 0.12
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Buğday demetinin bırakılınca yemliğe sayıldığı alan (kök noktasına göre); küçük parmaklar için cömert.
@export var drop_area: Rect2 = Rect2(-170.0, -200.0, 340.0, 240.0)
@export var sparkle_scene: PackedScene
@export_file("*.ogg", "*.wav") var pour_sound_path: String = "res://assets/audio/sfx/seed_sprinkle.ogg"

## Yemlikteki pay sayısı (0..PORTIONS).
var portions: int = 0

var _reserved: int = 0
var _pour_sound: AudioStream
var _highlighted: bool = false
var _highlight_tween: Tween
var _grain_tween: Tween
var _bubble_tween: Tween
var _bubble_scale: Vector2
var _spots: Array[Node2D] = []

@onready var _body: Node2D = $Body
@onready var _grain: Node2D = $Body/Grain
@onready var _pour: CPUParticles2D = $Pour
@onready var _bubble: Node2D = $Bubble
@onready var _bubble_wheat: Node2D = $Bubble/Wheat
@onready var _bubble_field: Node2D = $Bubble/Field
@onready var _bubble_tap: Tappable = $Bubble/TapArea


func _ready() -> void:
	if ResourceLoader.exists(pour_sound_path):
		_pour_sound = load(pour_sound_path) as AudioStream
	_spots.assign($Spots.get_children())
	_grain.hide()
	_bubble_scale = _bubble.scale
	Oscillation.ping_pong(self, _bubble, ^"position:y", _bubble.position.y, _bubble.position.y - BUBBLE_BOB,
			BUBBLE_BOB_PERIOD)
	_bubble_tap.tapped.connect(func(_point: Vector2) -> void: bubble_tapped.emit())
	Basket.changed.connect(func(_item: StringName, _count: int) -> void: _refresh_bubble_content())
	_refresh_bubble_content()


func contains(global_point: Vector2) -> bool:
	return drop_area.has_point(to_local(global_point))


## index. tavuğun yemlikte durduğu yer (dünya konumu).
func spot(index: int) -> Vector2:
	return _spots[index].global_position


## Yemlik tam dolu değilse bir demet daha dökülebilir (yemlik yine tam dolar).
func can_fill() -> bool:
	return portions < PORTIONS


## Henüz bir tavuğa ayrılmamış pay var mı.
func has_free_portion() -> bool:
	return portions - _reserved > 0


## Bir payı tavuk için ayırır; ayrılacak pay yoksa false döner.
func reserve() -> bool:
	if not has_free_portion():
		return false
	_reserved += 1
	return true


## Ayrılmış payı tavuk yedi.
func eat() -> void:
	portions = maxi(portions - 1, 0)
	_reserved = maxi(_reserved - 1, 0)
	_show_grain_level()
	if portions == 0:
		_show_bubble()


func save_state() -> Dictionary:
	return {"portions": portions}


## Kayıttan animasyonsuz kurar; ayrılmış paylar sıfırlanır (tavuklar kendi kayıtlarından yeniden kurulur).
func load_state(data: Dictionary) -> void:
	portions = clampi(int(data.get("portions", 0)), 0, PORTIONS)
	_reserved = 0
	if _grain_tween != null:
		_grain_tween.kill()
	_grain.visible = portions > 0
	_grain.scale = Vector2(1.0, float(portions) / PORTIONS)
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble.visible = portions == 0
	_bubble.scale = _bubble_scale
	_refresh_bubble_content()


## Parmaktaki demet yemliğin üstündeyken yemlik hafifçe büyür.
func set_highlighted(highlighted: bool) -> void:
	if highlighted == _highlighted:
		return
	_highlighted = highlighted
	if _highlight_tween != null:
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(_body, ^"scale", HIGHLIGHT_SCALE if highlighted else Vector2.ONE, HIGHLIGHT_TIME)


## Yemlik hemen dolu sayılır; taneler kısa bir dökülmeyle görünür olur.
func fill() -> void:
	if not can_fill():
		return
	var was_empty: bool = portions == 0
	portions = PORTIONS
	set_highlighted(false)
	_hide_bubble()
	_pour.emitting = true
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_pour_sound, AudioManager.BUS_SFX, 0.0, 1.0, pan)
	if _grain_tween != null:
		_grain_tween.kill()
	_grain_tween = create_tween()
	_grain_tween.tween_interval(GRAIN_DELAY)
	if was_empty:
		_grain_tween.tween_callback(func() -> void:
			_grain.scale = Vector2(1.0, 0.0)
			_grain.show())
	_grain_tween.tween_property(_grain, ^"scale", Vector2.ONE, GRAIN_RISE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_grain_tween.tween_interval(maxf(POUR_TIME - GRAIN_DELAY - GRAIN_RISE_TIME, 0.0))
	_grain_tween.tween_callback(_on_poured)


## Balon boşken dikkat çekmek için bir kez zıplar (sepette buğday yokken demet çekilmeye çalışılınca).
func nudge_bubble() -> void:
	if not _bubble.visible or (_bubble_tween != null and _bubble_tween.is_running()):
		return
	_bubble_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale * NUDGE_SCALE, NUDGE_TIME)
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, NUDGE_TIME * 2.0)


func _on_poured() -> void:
	_pour.emitting = false
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = _grain.position
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	filled.emit()


## Yığın kalan paya göre basıklaşır; pay kalmayınca kaybolur.
func _show_grain_level() -> void:
	if _grain_tween != null:
		_grain_tween.kill()
	_grain_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_grain_tween.tween_property(_grain, ^"scale:y", float(portions) / PORTIONS, GRAIN_SHRINK_TIME)
	if portions == 0:
		_grain_tween.tween_callback(_grain.hide)


func _refresh_bubble_content() -> void:
	var has_wheat: bool = Basket.count(Items.WHEAT) > 0
	_bubble_wheat.visible = has_wheat
	_bubble_field.visible = not has_wheat
	_bubble_tap.enabled = portions == 0 and not has_wheat


func _show_bubble() -> void:
	if _bubble_tween != null:
		_bubble_tween.kill()
	_refresh_bubble_content()
	_bubble.scale = Vector2.ZERO
	_bubble.show()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_bubble() -> void:
	_bubble_tap.enabled = false
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_bubble_tween.tween_callback(_bubble.hide)
