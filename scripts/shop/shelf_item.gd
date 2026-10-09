class_name ShelfItem
extends Node2D
## Dükkân rafında satılan bir ürün (ShopItems): resmi rafın üstünde durur, aksesuarlar küçük bir minderin
## üstünde. Önünde, rafın kenarında fiyat etiketi (PriceTag) vardır. Dokununca tapped yayılır; parası
## yetiyorsa ürün sevinçle zıplar (hop), yetmiyorsa etiketi sallanır (nudge).
## Kumbaradan çekilen para ürünün üstüne getirilince ürün parlar (set_highlighted); para etiketin sıradaki
## yuvasına uçar (coin_target, coin_arrived). Açılışta yarım ödemeler ve alınmışlık Owned'dan kurulur;
## alınmış ürünün etiketinde rozet durur ve ona para konmaz. Kızın başındaki aksesuarın minderi boş durur
## (set_worn).
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
const HIGHLIGHT_COLOR: Color = Color(1.18, 1.18, 1.1)
const RETURN_POP_TIME: float = 0.3

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
	_tag.set_price(ShopItems.price(item), Owned.paid(item))
	if Owned.has(item):
		_tag.set_owned(false)
	set_worn(Owned.worn() == item, false)
	var top: float = -lift - size.y - TAP_MARGIN
	var width: float = maxf(size.x, _cushion.texture.get_width() if on_cushion else 0.0) + TAP_MARGIN * 2.0
	_tap_area.area = Rect2(-width * 0.5, top, width, tag_offset.y + PriceTag.SLOT_SIZE - top)
	_tap_area.tapped.connect(func(_point: Vector2) -> void: tapped.emit(self))


## Ürünün alınması için daha kaç para gerektiği (alınmışsa 0).
func remaining() -> int:
	return Owned.remaining(item)


func is_owned() -> bool:
	return _tag.is_owned()


func contains(global_point: Vector2) -> bool:
	return _tap_area.contains(global_point)


func set_highlighted(highlighted: bool) -> void:
	_body.modulate = HIGHLIGHT_COLOR if highlighted else Color.WHITE


## Son ödenen paranın oturacağı yuva (dünya konumu); Owned.pay'den hemen sonra sorulmalı.
func coin_target() -> Vector2:
	return _tag.slot_position(ShopItems.price(item) - Owned.remaining(item) - 1)


func coin_scale() -> float:
	return _tag.coin_scale()


## Uçan para yuvasına oturdu.
func coin_arrived() -> void:
	_tag.fill()


## Ürün alındı: etiketin yerine rozet çıkar.
func mark_owned() -> void:
	_tag.set_owned()


## Aksesuar kızın başındayken minderi boş kalır; geri gelince (animate ise) büyüyerek yerine oturur.
func set_worn(worn: bool, animate: bool = true) -> void:
	_art.visible = not worn
	if worn or not animate:
		return
	var rest: Vector2 = Vector2.ONE * art_scale
	_art.scale = Vector2.ZERO
	create_tween().tween_property(_art, ^"scale", rest, RETURN_POP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func art_texture() -> Texture2D:
	return _art.texture


## Ürün resminin ortası ve ölçeği (dünyada); uçan kopyası buradan kalkar.
func art_center() -> Vector2:
	return _art.global_position


func art_global_scale() -> Vector2:
	return _art.global_scale


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
