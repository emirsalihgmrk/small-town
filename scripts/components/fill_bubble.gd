class_name FillBubble
extends Node2D
## Hayvanın başının üstünde, beklemeyi sayısız gösteren balon: içindeki resim (boş hali üstünde dolu
## hali) aşağıdan yukarı yavaş yavaş dolar. Bekleme başlayınca açılır (open), ilerleme set_progress ile
## verilir; dolunca finish ile zıplar ve yavaşça nefes almaya başlar (çağırır). close ile kapanır.
## Kayıttan kurarken snap animasyonsuz gösterir. Kök noktası balonun ortasıdır.

const POP_TIME: float = 0.25
const FINISH_SCALE: float = 1.25
const FINISH_UP_TIME: float = 0.12
const FINISH_SETTLE_TIME: float = 0.45
const PULSE_AMOUNT: Vector2 = Vector2(0.1, 0.1)
const PULSE_PERIOD: float = 1.1

## Balonun kendisi (içi boş).
@export var back_texture: Texture2D
## Balonun içindeki resmin boş ve dolu hali; ikisi aynı çerçevede çizilmeli.
@export var empty_texture: Texture2D
@export var full_texture: Texture2D
## Resmin ortası, balonun ortasına göre.
@export var icon_center: Vector2 = Vector2(0.0, -5.0)
## Balonun ve resmin çizildiği ölçek.
@export var content_scale: float = 1.0

var _content: Node2D
var _icon: TextureProgressBar
var _tween: Tween
var _pulse_tween: Tween


func _ready() -> void:
	_content = Node2D.new()
	_content.scale = Vector2.ONE * content_scale
	add_child(_content)
	var back: Sprite2D = Sprite2D.new()
	back.texture = back_texture
	_content.add_child(back)
	_icon = TextureProgressBar.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	_icon.min_value = 0.0
	_icon.max_value = 1.0
	_icon.step = 0.0
	_icon.texture_under = empty_texture
	_icon.texture_progress = full_texture
	if full_texture != null:
		_icon.position = icon_center - full_texture.get_size() * 0.5
	_content.add_child(_icon)
	hide()


func set_progress(progress: float) -> void:
	_icon.value = clampf(progress, 0.0, 1.0)


## Boş (ya da progress kadar dolu) balon küçükten büyüyerek belirir.
func open(progress: float = 0.0) -> void:
	_stop_pulse()
	set_progress(progress)
	_restart_tween()
	scale = Vector2.ZERO
	show()
	_tween.tween_property(self, ^"scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Resim tam dolar, balon zıplar ve nefes almaya başlar.
func finish() -> void:
	set_progress(1.0)
	_restart_tween()
	show()
	_tween.tween_property(self, ^"scale", Vector2.ONE * FINISH_SCALE, FINISH_UP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"scale", Vector2.ONE, FINISH_SETTLE_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_start_pulse()


func close() -> void:
	if not visible:
		return
	_restart_tween()
	_tween.tween_property(self, ^"scale", Vector2.ZERO, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		_stop_pulse()
		hide())


## Animasyonsuz kurar: progress < 0 ise gizli, değilse o kadar dolu görünür; finished ise nefes alır.
func snap(progress: float, finished: bool = false) -> void:
	if _tween != null:
		_tween.kill()
	_stop_pulse()
	scale = Vector2.ONE
	visible = progress >= 0.0
	set_progress(progress)
	if visible and finished:
		_start_pulse()


func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()


func _start_pulse() -> void:
	_stop_pulse()
	var rest: Vector2 = Vector2.ONE * content_scale
	_pulse_tween = Oscillation.ping_pong(self, _content, ^"scale", rest, rest * (Vector2.ONE + PULSE_AMOUNT),
			PULSE_PERIOD, 0.0, false)


func _stop_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_content.scale = Vector2.ONE * content_scale
