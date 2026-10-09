class_name PriceTag
extends Node2D
## Rafın kenarındaki fiyat etiketi: fiyat kadar boş para yuvası yan yana dizilir, sayı yazılmaz. Para
## yetmeyince etiket sağa sola sallanır (nudge).
## Kök noktası etiketin ortasıdır; kâğıt (Body'nin kendi çizimi), yuva sayısına göre genişler.

const SLOT_SPACING: float = 27.0
const SLOT_SIZE: float = 24.0
const PADDING: Vector2 = Vector2(10.0, 8.0)
const CORNER_RADIUS: int = 10
const BORDER_WIDTH: int = 4
const PAPER_COLOR: Color = Color(1.0, 0.973, 0.906)
const BORDER_COLOR: Color = Color(0.788, 0.655, 0.486)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.18)
const SHADOW_OFFSET: Vector2 = Vector2(0.0, 4.0)
const NUDGE_DEGREES: float = 9.0
const NUDGE_TIME: float = 0.07

@export var slot_texture: Texture2D

var _price: int = 0
var _slots: Array[Sprite2D] = []
var _paper: StyleBoxFlat
var _nudge_tween: Tween

@onready var _body: Node2D = $Body


func _ready() -> void:
	_paper = StyleBoxFlat.new()
	_paper.bg_color = PAPER_COLOR
	_paper.border_color = BORDER_COLOR
	_paper.set_border_width_all(BORDER_WIDTH)
	_paper.set_corner_radius_all(CORNER_RADIUS)
	_paper.shadow_color = SHADOW_COLOR
	_paper.shadow_size = 1
	_paper.shadow_offset = SHADOW_OFFSET
	_body.draw.connect(_draw_paper)


## Yuvaları price adet olarak kurar.
func set_price(price: int) -> void:
	_price = maxi(price, 0)
	for slot: Sprite2D in _slots:
		slot.queue_free()
	_slots.clear()
	var x: float = -SLOT_SPACING * (_price - 1) * 0.5
	for i: int in _price:
		var slot: Sprite2D = Sprite2D.new()
		slot.texture = slot_texture
		slot.position.x = x
		_body.add_child(slot)
		_slots.append(slot)
		x += SLOT_SPACING
	_body.queue_redraw()


func price() -> int:
	return _price


## Dikkat çekmek için bir kez sağa sola sallanır.
func nudge() -> void:
	if _nudge_tween != null and _nudge_tween.is_running():
		return
	_nudge_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0, 1.0, -1.0]:
		_nudge_tween.tween_property(_body, ^"rotation", deg_to_rad(NUDGE_DEGREES * side), NUDGE_TIME)
	_nudge_tween.tween_property(_body, ^"rotation", 0.0, NUDGE_TIME)


func _draw_paper() -> void:
	var size: Vector2 = Vector2(SLOT_SPACING * maxi(_price - 1, 0) + SLOT_SIZE, SLOT_SIZE) + PADDING * 2.0
	_body.draw_style_box(_paper, Rect2(-size * 0.5, size))
