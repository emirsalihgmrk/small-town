class_name ParentGateButton
extends Control
## Ebeveyn köşesinin kapısı: köşede soluk bir çark. Tek dokunuş bir şey yapmaz; hold_time boyunca
## basılı tutulunca çevresindeki halka dolar ve opened yayılır. Erken bırakılırsa halka geri boşalır.
## Halka düğmeden büyüktür ki parmağın altında kalmasın; basılıyken yanında yetişkine ne yapacağını söyleyen
## yazı (hint) görünür. Böylece çocuk tesadüfen açmaz, yetişkin ne yapacağını anlar.

signal opened

## Bırakılınca halka bu hızla boşalır (saniyede tam halkanın kaçı).
const DRAIN_RATE: float = 3.0
const RING_WIDTH: float = 12.0
const RING_POINTS: int = 64
## Basılıyken halkanın yarıçapı, düğme çapının bu katı (parmağın etrafından görünsün).
const RING_RADIUS_RATIO: float = 1.1
## Dolmamış halka izi, halka renginin bu saydamlığında.
const TRACK_ALPHA: float = 0.25
## Çark, düğme çapının bu oranı kadar.
const ICON_RATIO: float = 0.62
## Bırakıldıktan sonra yazı bu kadar daha görünür.
const HINT_LINGER: float = 2.0

@export var icon: Texture2D
@export_range(0.5, 5.0, 0.1, "suffix:s") var hold_time: float = 2.0
@export var background_color: Color = Color(1, 0.973, 0.906, 0.7)
@export var ring_color: Color = Color(0.36, 0.24, 0.13, 0.9)
## Dokunulmazken düğmenin saydamlığı; arka planda göze batmasın.
@export_range(0.0, 1.0, 0.05) var idle_alpha: float = 0.55
## Basılıyken görünen "basılı tutun" yazısı; düğme soluklaşınca o da gizlenir.
@export var hint: Control

var _progress: float = 0.0
var _touch_index: int = -1
var _hint_left: float = 0.0


func _ready() -> void:
	modulate.a = idle_alpha
	if hint != null:
		hint.hide()
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed and _touch_index < 0:
		_touch_index = touch.index
		modulate.a = 1.0
		if hint != null:
			hint.show()
		set_process(true)
		accept_event()
	elif not touch.pressed and touch.index == _touch_index:
		_touch_index = -1
		_hint_left = HINT_LINGER
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_touch_index = -1


func _process(delta: float) -> void:
	if _touch_index >= 0:
		_progress = minf(_progress + delta / hold_time, 1.0)
		if _progress >= 1.0:
			_touch_index = -1
			_progress = 0.0
			_rest()
			opened.emit()
	else:
		_progress = maxf(_progress - delta * DRAIN_RATE, 0.0)
		_hint_left = maxf(_hint_left - delta, 0.0)
		if is_zero_approx(_progress) and is_zero_approx(_hint_left):
			_rest()
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var diameter: float = minf(size.x, size.y)
	draw_circle(center, diameter * 0.5, background_color)
	if icon != null:
		var icon_size: Vector2 = Vector2.ONE * diameter * ICON_RATIO
		draw_texture_rect(icon, Rect2(center - icon_size * 0.5, icon_size), false)
	if _touch_index >= 0 or _progress > 0.0:
		var radius: float = diameter * RING_RADIUS_RATIO
		var track: Color = Color(ring_color, ring_color.a * TRACK_ALPHA)
		draw_arc(center, radius, 0.0, TAU, RING_POINTS, track, RING_WIDTH, true)
		if _progress > 0.0:
			draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * _progress, RING_POINTS, ring_color, RING_WIDTH, true)


func _rest() -> void:
	modulate.a = idle_alpha
	_hint_left = 0.0
	if hint != null:
		hint.hide()
	set_process(false)
