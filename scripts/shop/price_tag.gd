class_name PriceTag
extends Node2D
## Rafın kenarındaki fiyat etiketi: fiyat kadar boş para yuvası yan yana dizilir, sayı yazılmaz. Konan her
## para soldan sağa sıradaki yuvaya oturur (fill). Ürün alınınca yuvalar kaybolur, yerine yeşil kalpli bir
## rozet çıkar (set_owned). Para yetmeyince etiket sağa sola sallanır (nudge).
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
const FILL_POP_SCALE: float = 1.4
const FILL_POP_TIME: float = 0.12
const FILL_SETTLE_TIME: float = 0.3
const OWNED_POP_TIME: float = 0.35

@export var slot_texture: Texture2D
@export var coin_texture: Texture2D
@export var owned_texture: Texture2D

var _price: int = 0
var _filled: int = 0
var _owned: bool = false
var _slots: Array[Sprite2D] = []
var _coins: Array[Sprite2D] = []
var _badge: Sprite2D
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
	_badge = Sprite2D.new()
	_badge.texture = owned_texture
	_badge.hide()
	add_child(_badge)


## Yuvaları price adet olarak kurar; ilk filled tanesi dolu görünür.
func set_price(price: int, filled: int = 0) -> void:
	_price = maxi(price, 0)
	for sprite: Sprite2D in _slots + _coins:
		sprite.queue_free()
	_slots.clear()
	_coins.clear()
	var x: float = -SLOT_SPACING * (_price - 1) * 0.5
	for i: int in _price:
		var slot: Sprite2D = Sprite2D.new()
		slot.texture = slot_texture
		slot.position.x = x
		_body.add_child(slot)
		_slots.append(slot)
		var coin: Sprite2D = Sprite2D.new()
		coin.texture = coin_texture
		if coin_texture != null:
			coin.scale = Vector2.ONE * (SLOT_SIZE / coin_texture.get_width())
		coin.position.x = x
		coin.hide()
		_body.add_child(coin)
		_coins.append(coin)
		x += SLOT_SPACING
	_filled = 0
	for i: int in mini(filled, _price):
		fill(false)
	_body.queue_redraw()


func price() -> int:
	return _price


func is_owned() -> bool:
	return _owned


## index. yuvanın dünya konumu.
func slot_position(index: int) -> Vector2:
	if _slots.is_empty():
		return global_position
	return _slots[clampi(index, 0, _slots.size() - 1)].global_position


## Bir para görünen yuvadan küçük gelsin diye taşınan paranın varışta alacağı ölçek.
func coin_scale() -> float:
	return SLOT_SIZE / coin_texture.get_width() if coin_texture != null else 1.0


## Sıradaki yuvaya bir para oturur (animate ise zıplar).
func fill(animate: bool = true) -> void:
	if _filled >= _price:
		return
	var coin: Sprite2D = _coins[_filled]
	_filled += 1
	coin.show()
	if not animate:
		return
	var rest: Vector2 = coin.scale
	var tween: Tween = create_tween()
	tween.tween_property(coin, ^"scale", rest * FILL_POP_SCALE, FILL_POP_TIME).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(coin, ^"scale", rest, FILL_SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Ürün alındı: kâğıt ve yuvalar kaybolur, rozet çıkar (animate ise büyüyerek).
func set_owned(animate: bool = true) -> void:
	if _owned:
		return
	_owned = true
	_body.hide()
	_badge.show()
	if not animate:
		return
	_badge.scale = Vector2.ZERO
	create_tween().tween_property(_badge, ^"scale", Vector2.ONE, OWNED_POP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


## Dikkat çekmek için bir kez sağa sola sallanır.
func nudge() -> void:
	if _owned or (_nudge_tween != null and _nudge_tween.is_running()):
		return
	_nudge_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0, 1.0, -1.0]:
		_nudge_tween.tween_property(_body, ^"rotation", deg_to_rad(NUDGE_DEGREES * side), NUDGE_TIME)
	_nudge_tween.tween_property(_body, ^"rotation", 0.0, NUDGE_TIME)


func _draw_paper() -> void:
	var size: Vector2 = Vector2(SLOT_SPACING * maxi(_price - 1, 0) + SLOT_SIZE, SLOT_SIZE) + PADDING * 2.0
	_body.draw_style_box(_paper, Rect2(-size * 0.5, size))
