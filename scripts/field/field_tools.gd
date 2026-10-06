class_name FieldTools
extends Node
## Alt raftaki araçları parmakla kullanma. Şimdilik yalnızca çapa çalışır:
## raftan tutulunca parmağın hemen üstünde belirir; otlu bir parselin üstünde ovuşturuldukça
## her stroke_distance yolda bir vurur; parmak kalkınca rafa geri uçar.
## Tek parmak izlenir; araç tutulurken gelen diğer dokunuşlar bu düğümü ilgilendirmez.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir.

const NO_TOUCH: int = -1
const SLOT_BOUNCE_SCALE: float = 1.15
const SLOT_BOUNCE_TIME: float = 0.25

@export var hoe_slot: Control
@export var hoe_scene: PackedScene
@export var plots_root: Node2D
## Tutulan araç bu katmanda çizilir; araç rafının (UI) da üstünde kalmalı.
@export var drag_layer: CanvasLayer
## Aracın çalışan ucu parmağın bu kadar uzağında durur; parmak ucu örtmesin.
@export var hold_offset: Vector2 = Vector2(0.0, -36.0)
@export_range(20.0, 400.0, 5.0, "suffix:px") var stroke_distance: float = 100.0
## Parsele girer girmez ilk vuruş çabuk gelsin diye yolun bu oranı peşin sayılır.
@export_range(0.0, 1.0, 0.05) var first_stroke_head_start: float = 0.6

var _touch_index: int = NO_TOUCH
var _tool: HeldTool
var _returning_tool: HeldTool
var _plot: Plot
var _stroke_progress: float = 0.0
var _last_tip: Vector2

@onready var _hoe_icon: Node2D = hoe_slot.get_node(^"Icon")
@onready var _hoe_icon_scale: Vector2 = _hoe_icon.scale


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH and hoe_slot.get_global_rect().has_point(touch.position):
			_pick_up(touch.index, touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_drop()
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_move_to(drag.position)
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: aracı bırak.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_drop()


func _pick_up(index: int, screen_point: Vector2) -> void:
	if _returning_tool != null:
		_returning_tool.queue_free()
		_returning_tool = null
	_touch_index = index
	_hoe_icon.hide()
	_tool = hoe_scene.instantiate() as HeldTool
	drag_layer.add_child(_tool)
	_tool.position = screen_point + hold_offset
	_tool.pop_in()
	_plot = null
	_update_plot()


func _move_to(screen_point: Vector2) -> void:
	_tool.position = screen_point + hold_offset
	_update_plot()


func _drop() -> void:
	_touch_index = NO_TOUCH
	_plot = null
	_returning_tool = _tool
	_tool = null
	_returning_tool.return_to(hoe_slot.get_global_rect().get_center(), _on_tool_returned)


func _on_tool_returned() -> void:
	_returning_tool = null
	_hoe_icon.show()
	_hoe_icon.scale = _hoe_icon_scale * SLOT_BOUNCE_SCALE
	create_tween().tween_property(_hoe_icon, ^"scale", _hoe_icon_scale, SLOT_BOUNCE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Aracın ucunun altındaki parseli izler; otlu bir parselin üstünde biriken yol vuruşa dönüşür.
func _update_plot() -> void:
	var tip: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * _tool.position
	var plot: Plot = _plot_at(tip)
	if plot != _plot:
		_plot = plot
		_stroke_progress = stroke_distance * first_stroke_head_start
	elif plot != null and plot.can_till():
		_stroke_progress += tip.distance_to(_last_tip)
		if _stroke_progress >= stroke_distance:
			# Hızlı bir savuruş birden çok vuruş biriktirmesin.
			_stroke_progress = 0.0
			plot.chop(tip)
			_tool.play_use()
	_last_tip = tip


## Arka ve ön sıra üst üste bindiğinde öndeki (ekranda aşağıdaki) parsel kazanır.
func _plot_at(world_point: Vector2) -> Plot:
	var best: Plot = null
	for node: Node in plots_root.get_children():
		var plot: Plot = node as Plot
		if plot != null and plot.contains(world_point) and (best == null or plot.global_position.y > best.global_position.y):
			best = plot
	return best
