class_name ParentGateButton
extends Control
## Ebeveyn köşesinin kapısı: köşede küçük, soluk bir çark. Tek dokunuş bir şey yapmaz; hold_time boyunca
## basılı tutulunca çevresindeki halka dolar ve opened yayılır. Erken bırakılırsa halka geri boşalır.
## Böylece çocuk tesadüfen açmaz, yetişkin ne yapacağını dolan halkadan anlar.

signal opened

## Bırakılınca halka bu hızla boşalır (saniyede tam halkanın kaçı).
const DRAIN_RATE: float = 3.0
const RING_WIDTH: float = 7.0
const RING_POINTS: int = 48
## Çark, düğme çapının bu oranı kadar.
const ICON_RATIO: float = 0.62

@export var icon: Texture2D
@export_range(0.5, 5.0, 0.1, "suffix:s") var hold_time: float = 2.0
@export var background_color: Color = Color(1, 0.973, 0.906, 0.7)
@export var ring_color: Color = Color(0.36, 0.24, 0.13, 0.9)
## Dokunulmazken düğmenin saydamlığı; arka planda göze batmasın.
@export_range(0.0, 1.0, 0.05) var idle_alpha: float = 0.55

var _progress: float = 0.0
var _touch_index: int = -1


func _ready() -> void:
	modulate.a = idle_alpha
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed and _touch_index < 0:
		_touch_index = touch.index
		modulate.a = 1.0
		set_process(true)
		accept_event()
	elif not touch.pressed and touch.index == _touch_index:
		_touch_index = -1
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
		if is_zero_approx(_progress):
			_rest()
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - RING_WIDTH * 0.5
	draw_circle(center, radius, background_color)
	if icon != null:
		var icon_size: Vector2 = Vector2.ONE * minf(size.x, size.y) * ICON_RATIO
		draw_texture_rect(icon, Rect2(center - icon_size * 0.5, icon_size), false)
	if _progress > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * _progress, RING_POINTS, ring_color, RING_WIDTH, true)


func _rest() -> void:
	modulate.a = idle_alpha
	set_process(false)
