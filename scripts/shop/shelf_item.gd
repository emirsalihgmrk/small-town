class_name ShelfItem
extends Node2D
## Dükkân rafında satılan bir ürün (ShopItems): resmi rafın üstünde durur, aksesuarlar küçük bir minderin
## üstünde. Önünde, rafın kenarında fiyat etiketi (PriceTag) vardır. Dokununca tapped yayılır; parası
## yetiyorsa ürün sevinçle zıplar (hop), yetmiyorsa etiketi sallanır (nudge).
## Kök noktası ürünün rafa değdiği yerin ortasıdır; etiket rafın kenarındadır (tag_offset).

signal tapped(item: ShelfItem)

## Minderin üstü (aksesuarlar bunun üstüne oturur).
const CUSHION_TOP: float = 30.0
const TAP_MARGIN: float = 12.0
const HOP_HEIGHT: float = 16.0
const HOP_TIME: float = 0.14
const SQUASH: Vector2 = Vector2(1.08, 0.92)
const SQUASH_TIME: float = 0.07
const SHAKE_DEGREES: float = 4.0
const SHAKE_TIME: float = 0.07

@export var item: StringName
@export var texture: Texture2D
@export_range(0.1, 2.0, 0.05) var art_scale: float = 1.0
@export var on_cushion: bool = false
@export var tag_offset: Vector2 = Vector2(0.0, 13.0)

var _hop_tween: Tween

@onready var _body: Node2D = $Body
@onready var _art: Sprite2D = $Body/Art
@onready var _cushion: Sprite2D = $Body/Cushion
@onready var _tag: PriceTag = $Tag
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	_cushion.visible = on_cushion
	_art.texture = texture
	_art.scale = Vector2.ONE * art_scale
	var size: Vector2 = texture.get_size() * art_scale if texture != null else Vector2.ZERO
	var lift: float = CUSHION_TOP if on_cushion else 0.0
	_art.position = Vector2(0.0, -lift - size.y * 0.5)
	_tag.position = tag_offset
	_tag.set_price(ShopItems.price(item))
	var top: float = -lift - size.y - TAP_MARGIN
	var width: float = maxf(size.x, _cushion.texture.get_width() if on_cushion else 0.0) + TAP_MARGIN * 2.0
	_tap_area.area = Rect2(-width * 0.5, top, width, tag_offset.y + PriceTag.SLOT_SIZE - top)
	_tap_area.tapped.connect(func(_point: Vector2) -> void: tapped.emit(self))


func price() -> int:
	return _tag.price()


## Parası yetiyor: ürün yerinde sevinçle zıplar.
func hop() -> void:
	if _hop_tween != null and _hop_tween.is_running():
		return
	_hop_tween = create_tween()
	_hop_tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_body, ^"scale", Vector2.ONE, SQUASH_TIME)
	_hop_tween.tween_property(_body, ^"position:y", -HOP_HEIGHT, HOP_TIME).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_body, ^"position:y", 0.0, HOP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Parası yetmiyor: etiket sallanır, ürün hafifçe kıpırdar.
func nudge() -> void:
	_tag.nudge()
	if _hop_tween != null and _hop_tween.is_running():
		return
	_hop_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0]:
		_hop_tween.tween_property(_body, ^"rotation", deg_to_rad(SHAKE_DEGREES * side), SHAKE_TIME)
	_hop_tween.tween_property(_body, ^"rotation", 0.0, SHAKE_TIME)
