class_name RequestBubble
extends Node2D
## Müşterinin başının üstündeki istek balonu. İstenen her ürün kendi yuvasında resmiyle durur; sayı yazılmaz,
## iki yumurta istenirse iki yumurta resmi görünür. Balonun genişliği yuva sayısına göre seçilir.
## Müşteriye verilen ürünün yuvası dolar: yuva yeşile döner, ürün resmi zıplar, köşesinde bir onay işareti
## belirir ve yıldızlar saçılır.
## Kök noktası balonun kuyruğunun ucudur. Açılırken büyüyerek belirir, açıkken hafifçe süzülür, kapanırken
## küçülerek kaybolur.

const POP_TIME: float = 0.3
const BOB: float = 8.0
const BOB_PERIOD: float = 1.8
## Yuvaların ortaları arası uzaklık ve yuvaların kuyruk ucuna göre yüksekliği (balon çizimleriyle aynı).
const SLOT_SPACING: float = 104.0
const SLOT_Y: float = -96.0
## Balon çizimlerinin altında, kuyruk ucunun altında kalan boşluk.
const BOTTOM_MARGIN: float = 4.0
const FILL_POP_SCALE: float = 1.3
const FILL_POP_TIME: float = 0.12
const FILL_SETTLE_TIME: float = 0.35
## Onay işaretinin yuvanın ortasına göre yeri.
const TICK_OFFSET: Vector2 = Vector2(32.0, -32.0)
const TICK_POP_TIME: float = 0.25

## Balonda gösterilebilecek ürünler (Items kimliği -> resmi).
@export var item_icons: Dictionary[StringName, Texture2D] = {}
## 1, 2 ve 3 yuvalı balonlar, bu sırayla.
@export var bubble_textures: Array[Texture2D] = []
@export var slot_texture: Texture2D
@export var filled_slot_texture: Texture2D
@export var tick_texture: Texture2D
@export var sparkle_scene: PackedScene
## Ürün resmi bu kareye sığacak kadar büyütülür ya da küçültülür.
@export var icon_size: float = 76.0

var _pop_tween: Tween
var _slot_sprites: Array[Sprite2D] = []

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


## Balon küçülerek kapanır.
func close() -> void:
	if not visible:
		return
	if _pop_tween != null:
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, ^"scale", Vector2.ZERO, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_pop_tween.tween_callback(hide)


## index. yuvayı dolu gösterir; animate değilse (kayıttan kurulurken) zıplamadan ve yıldızsız.
func fill(index: int, animate: bool = true) -> void:
	if index < 0 or index >= _slot_sprites.size():
		return
	var slot: Sprite2D = _slot_sprites[index]
	slot.texture = filled_slot_texture
	if not animate:
		var still_tick: Sprite2D = Sprite2D.new()
		still_tick.texture = tick_texture
		still_tick.position = TICK_OFFSET
		slot.add_child(still_tick)
		return
	var tween: Tween = create_tween()
	tween.tween_property(slot, ^"scale", Vector2.ONE * FILL_POP_SCALE, FILL_POP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, ^"scale", Vector2.ONE, FILL_SETTLE_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var tick: Sprite2D = Sprite2D.new()
	tick.texture = tick_texture
	tick.position = TICK_OFFSET
	tick.scale = Vector2.ZERO
	slot.add_child(tick)
	tick.create_tween().tween_property(tick, ^"scale", Vector2.ONE, TICK_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		slot.add_child(sparkle)
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true


func _build(order: Array[StringName]) -> void:
	for child: Node in _slots.get_children():
		child.queue_free()
	_slot_sprites.clear()
	var count: int = clampi(order.size(), 1, bubble_textures.size())
	var texture: Texture2D = bubble_textures[count - 1]
	_cloud.texture = texture
	_cloud.offset = Vector2(-texture.get_width() * 0.5, BOTTOM_MARGIN - texture.get_height())
	for i: int in order.size():
		var slot: Sprite2D = Sprite2D.new()
		slot.texture = slot_texture
		slot.position = Vector2((i - (order.size() - 1) * 0.5) * SLOT_SPACING, SLOT_Y)
		_slots.add_child(slot)
		_slot_sprites.append(slot)
		var icon_texture: Texture2D = item_icons.get(order[i])
		if icon_texture == null:
			continue
		var icon: Sprite2D = Sprite2D.new()
		icon.texture = icon_texture
		var longest: float = maxf(icon_texture.get_width(), icon_texture.get_height())
		icon.scale = Vector2.ONE * (icon_size / longest)
		slot.add_child(icon)
