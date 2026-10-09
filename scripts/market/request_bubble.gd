class_name RequestBubble
extends Node2D
## Müşterinin başının üstündeki istek balonu. İstenen her ürün kendi yuvasında resmiyle durur; sayı yazılmaz,
## iki yumurta istenirse iki yumurta resmi görünür. Balonun genişliği yuva sayısına göre seçilir.
## Kök noktası balonun kuyruğunun ucudur. Açılırken büyüyerek belirir, açıkken hafifçe süzülür.

const POP_TIME: float = 0.3
const BOB: float = 8.0
const BOB_PERIOD: float = 1.8
## Yuvaların ortaları arası uzaklık ve yuvaların kuyruk ucuna göre yüksekliği (balon çizimleriyle aynı).
const SLOT_SPACING: float = 104.0
const SLOT_Y: float = -96.0
## Balon çizimlerinin altında, kuyruk ucunun altında kalan boşluk.
const BOTTOM_MARGIN: float = 4.0

## Balonda gösterilebilecek ürünler (Items kimliği -> resmi).
@export var item_icons: Dictionary[StringName, Texture2D] = {}
## 1, 2 ve 3 yuvalı balonlar, bu sırayla.
@export var bubble_textures: Array[Texture2D] = []
@export var slot_texture: Texture2D
## Ürün resmi bu kareye sığacak kadar büyütülür ya da küçültülür.
@export var icon_size: float = 76.0

var _pop_tween: Tween

@onready var _float: Node2D = $Float
@onready var _cloud: Sprite2D = $Float/Cloud
@onready var _slots: Node2D = $Float/Slots


func _ready() -> void:
	hide()
	Oscillation.ping_pong(self, _float, ^"position:y", 0.0, -BOB, BOB_PERIOD)


## Balonu verilen istekle kurup büyüterek açar.
func open(order: Array[StringName]) -> void:
	_build(order)
	if _pop_tween != null:
		_pop_tween.kill()
	scale = Vector2.ZERO
	show()
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, ^"scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build(order: Array[StringName]) -> void:
	for child: Node in _slots.get_children():
		child.queue_free()
	var count: int = clampi(order.size(), 1, bubble_textures.size())
	var texture: Texture2D = bubble_textures[count - 1]
	_cloud.texture = texture
	_cloud.offset = Vector2(-texture.get_width() * 0.5, BOTTOM_MARGIN - texture.get_height())
	for i: int in order.size():
		var slot: Sprite2D = Sprite2D.new()
		slot.texture = slot_texture
		slot.position = Vector2((i - (order.size() - 1) * 0.5) * SLOT_SPACING, SLOT_Y)
		_slots.add_child(slot)
		var icon_texture: Texture2D = item_icons.get(order[i])
		if icon_texture == null:
			continue
		var icon: Sprite2D = Sprite2D.new()
		icon.texture = icon_texture
		var longest: float = maxf(icon_texture.get_width(), icon_texture.get_height())
		icon.scale = Vector2.ONE * (icon_size / longest)
		slot.add_child(icon)
