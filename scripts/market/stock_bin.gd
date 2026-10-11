class_name StockBin
extends Node2D
## Pazarda bir ürünün reyondaki yeri: çiftlik tezgâhında tahta kasa, pastane tezgâhında raf bölmesi.
## İçinde ortak sepette (Basket) o üründen kaç tane varsa o kadar görünür; sayı yazılmaz, en fazla Items
## altındaki işaret sayısı kadar ürün görünür. Her işaret bir ürünün oturduğu noktayı (alt orta) ve
## eğimini belirler; işaretler dolma sırasıyla dizilir. Items alttakiler öne gelsin diye y'ye göre sıralanır.
## Ürün kalmayınca ilk işarette ürünün soluk gölgesi durur, böylece kasanın neyin yeri olduğu bilinir.
## Sepete ürün girince ya da ürün yerine geri konunca yeni ürünler büyüyerek belirir.
## Parmakla ürün alınabilir (SellHand): take_out ürünü reyondan gizler ama ortak sepetten ancak hand_over
## ile düşer; ürün geri dönerse put_back ile yerine konur. Sahne aniden kapansa da ürün kaybolmaz.

const POP_TIME: float = 0.3
const GHOST_COLOR: Color = Color(0.45, 0.3, 0.2, 0.3)

@export var item: StringName
@export var texture: Texture2D
## Ürünün en uzun kenarı bu boyda görünür.
@export var item_size: float = 64.0
## Parmakla ürün alınabilen alan (kök noktasına göre).
@export var grab_area: Rect2 = Rect2(-66.0, -110.0, 132.0, 112.0)

var _sprites: Array[Sprite2D] = []
var _shown: int = 0
var _rest_scale: Vector2 = Vector2.ONE
## Parmakla dışarı çıkarılmış, henüz ortak sepetten düşmemiş ürünler.
var _carried: int = 0

@onready var _items: Node2D = $Items


func _ready() -> void:
	_rest_scale = Vector2.ONE * (item_size / maxf(texture.get_width(), texture.get_height()))
	for spot: Node2D in _items.get_children():
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.offset = Vector2(0.0, -texture.get_height() * 0.5)
		sprite.scale = _rest_scale
		sprite.hide()
		spot.add_child(sprite)
		_sprites.append(sprite)
	Basket.changed.connect(func(changed: StringName, _count: int) -> void:
		if changed == item:
			_refresh(true))
	_refresh(false)


func contains(global_point: Vector2) -> bool:
	return grab_area.has_point(to_local(global_point))


func has_stock() -> bool:
	return _available() > 0


## Reyonda görünen en üstteki ürünün ortası (dünya konumu); dışarı çıkan ürün buradan kalkar.
func top_point() -> Vector2:
	return _sprite_center(maxi(mini(_available(), _sprites.size()) - 1, 0))


## Geri konan ürünün oturacağı yerin ortası (dünya konumu).
func return_point() -> Vector2:
	return _sprite_center(mini(_available(), _sprites.size() - 1))


## Reyonda ürün varsa birini dışarı çıkarır (reyonda görünmez olur) ve true döner.
func take_out() -> bool:
	if not has_stock():
		return false
	_carried += 1
	_refresh(false)
	return true


## Dışarı çıkarılan ürün yerine döner.
func put_back() -> void:
	_carried = maxi(_carried - 1, 0)
	_refresh(true)


## Dışarı çıkarılan ürün verildi: ortak sepetten de düşer.
func hand_over() -> void:
	_carried = maxi(_carried - 1, 0)
	Basket.take(item)


## Ürünün taşınırken ve reyondayken en uzun kenarı bu boyda görünsün diye gereken ölçek.
func size_scale(size: float) -> Vector2:
	return Vector2.ONE * (size / maxf(texture.get_width(), texture.get_height()))


func _available() -> int:
	return maxi(Basket.count(item) - _carried, 0)


func _sprite_center(index: int) -> Vector2:
	var sprite: Sprite2D = _sprites[index]
	return sprite.get_parent().to_global(sprite.position + sprite.offset.rotated(sprite.rotation) * _rest_scale)


func _refresh(animate: bool) -> void:
	var shown: int = mini(_available(), _sprites.size())
	for i: int in _sprites.size():
		var sprite: Sprite2D = _sprites[i]
		sprite.visible = i < shown or (shown == 0 and i == 0)
		sprite.modulate = GHOST_COLOR if shown == 0 else Color.WHITE
		if animate and i >= _shown and i < shown:
			sprite.scale = Vector2.ZERO
			sprite.create_tween().tween_property(sprite, ^"scale", _rest_scale, POP_TIME) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shown = shown
