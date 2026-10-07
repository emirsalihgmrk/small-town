class_name BasketView
extends Node2D
## Sepet (tarlada ve kümeste aynı sahne: scenes/entities/basket.tscn). Hasat edilen ürün topraktan
## havalanıp kavis çizerek sepete uçar ve içine düşer; sepet esner. İçeride ürünlerden küçük bir yığın,
## altında havuç ve buğday sayıları görünür.
## Ürün ortak sepete (Basket) hasat anında zaten eklenmiştir: sahne aniden kapansa da kaybolmaz.
## Burada yalnızca görünüş vardır; yoldaki ürünler sepete varınca sayılır. Sepetten bir yere verilen
## ürün de (tavşana havuç) sepetin ağzından oraya uçar.
## Parmakla sepetten dışarı çıkarılan ürün (kümeste buğday demeti) take_out ile sepette görünmez olur ama
## ortak sepetten ancak hand_over ile düşer; yarıda bırakılırsa put_back ile yerine döner.
## Sepete dokununca sepet esner ve tapped yayılır (sepet menüsünü açmak için).

signal tapped

const MOUTH: Vector2 = Vector2(0.0, -120.0)
const PRODUCE_START_SCALE: float = 0.6
const RISE: float = 130.0
const RISE_TIME: float = 0.4
const SPIN_DEGREES: float = 360.0
const HOLD_TIME: float = 0.15
const FLIGHT_TIME: float = 0.6
## Uçuş kavisinin, başlangıç ile varış arasındaki doğrunun ortasından ne kadar yukarı çıktığı.
const ARC_HEIGHT: float = 260.0
const FLIGHT_END_SCALE: float = 0.55
const DROP: float = 24.0
const DROP_TIME: float = 0.12
const SQUASH: Vector2 = Vector2(1.08, 0.92)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.4
const PILE_POP_TIME: float = 0.3
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var carrot_texture: Texture2D
@export var wheat_texture: Texture2D
## Uçan ürünler burada çizilir; tarladaki her şeyin üstünde olmalı.
@export var flights: Node2D
@export var sparkle_scene: PackedScene
@export_file("*.ogg", "*.wav") var land_sound_path: String = "res://assets/audio/sfx/basket_drop.ogg"

var _in_flight: Dictionary[StringName, int] = {}
## Parmakla dışarı çıkarılmış, henüz ortak sepetten düşmemiş ürünler.
var _carried: Dictionary[StringName, int] = {}
var _slots: Array[Node2D] = []
var _land_sound: AudioStream

@onready var _body: Node2D = $Body
@onready var _carrot_count: Label = $Tally/CarrotCount
@onready var _wheat_count: Label = $Tally/WheatCount
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	_slots.assign($Body/Items.get_children())
	if ResourceLoader.exists(land_sound_path):
		_land_sound = load(land_sound_path) as AudioStream
	Basket.changed.connect(func(_item: StringName, _count: int) -> void: _refresh(false))
	_tap_area.tapped.connect(func(_point: Vector2) -> void: tap())
	_refresh(false)


func contains(global_point: Vector2) -> bool:
	return _tap_area.contains(global_point)


## Sepetin ağzı (dünya konumu); dışarı çıkan ürün buradan çıkar, buraya döner.
func mouth() -> Vector2:
	return to_global(MOUTH)


## Dokunulmuş gibi esner ve tapped yayar (TapRouter yerine başka bir el dokunuşu yakaladığında).
func tap() -> void:
	_squash()
	tapped.emit()


## Sepette görünen bir ürün varsa onu dışarı çıkarır (yığından ve sayıdan düşer) ve true döner.
func take_out(item: StringName) -> bool:
	if _shown_count(item) <= 0:
		return false
	_carried[item] = _carried.get(item, 0) + 1
	_squash()
	_refresh(false)
	return true


## Dışarı çıkarılan ürün sepete geri düşer.
func put_back(item: StringName) -> void:
	_carried[item] = maxi(_carried.get(item, 0) - 1, 0)
	_play_land_sound()
	_squash()
	_refresh(true)


## Dışarı çıkarılan ürün verildi: ortak sepetten de düşer.
func hand_over(item: StringName) -> void:
	_carried[item] = maxi(_carried.get(item, 0) - 1, 0)
	Basket.take(item)


## Sepette şu an görünen sayı: yolda olanlar ve dışarı çıkarılanlar düşülür.
func _shown_count(item: StringName) -> int:
	return maxi(Basket.count(item) - _in_flight.get(item, 0) - _carried.get(item, 0), 0)


## Topraktan çıkan ürünü sepete uçurur (ürün ortak sepete önceden eklenmiş olmalı).
func receive(item: StringName, from_global: Vector2) -> void:
	_in_flight[item] = _in_flight.get(item, 0) + 1
	_refresh(false)
	var produce: Sprite2D = Sprite2D.new()
	produce.texture = carrot_texture if item == Items.CARROT else wheat_texture
	flights.add_child(produce)
	produce.global_position = from_global
	produce.scale = Vector2.ONE * PRODUCE_START_SCALE
	var start: Vector2 = produce.position + Vector2(0.0, -RISE)
	var end: Vector2 = flights.to_local(to_global(MOUTH))
	var tween: Tween = create_tween().set_parallel()
	# Topraktan havalanıp döner...
	tween.tween_property(produce, ^"position", start, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(produce, ^"scale", Vector2.ONE, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(produce, ^"rotation", deg_to_rad(SPIN_DEGREES), RISE_TIME).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(HOLD_TIME)
	# ...kavis çizerek sepetin ağzına uçar...
	tween.chain().tween_method(_fly.bind(produce, start, end), 0.0, 1.0, FLIGHT_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(produce, ^"scale", Vector2.ONE * FLIGHT_END_SCALE, FLIGHT_TIME)
	# ...ve içine düşer.
	tween.chain().tween_property(produce, ^"position:y", end.y + DROP, DROP_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(produce, ^"modulate:a", 0.0, DROP_TIME)
	tween.chain().tween_callback(_land.bind(item, produce))


## Sepetten bir ürünü kavisle bir yere uçurur (ürün ortak sepetten önceden alınmış olmalı);
## varınca ürün kaybolur ve on_arrived çağrılır.
func send(item: StringName, to_global: Vector2, on_arrived: Callable) -> void:
	_refresh(false)
	var produce: Sprite2D = Sprite2D.new()
	produce.texture = carrot_texture if item == Items.CARROT else wheat_texture
	flights.add_child(produce)
	var start: Vector2 = flights.to_local(to_global(MOUTH))
	var end: Vector2 = flights.to_local(to_global)
	produce.position = start
	produce.scale = Vector2.ONE * FLIGHT_END_SCALE
	var tween: Tween = create_tween().set_parallel()
	tween.tween_method(_fly.bind(produce, start, end), 0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(produce, ^"rotation", deg_to_rad(-SPIN_DEGREES), FLIGHT_TIME)
	tween.chain().tween_callback(func() -> void:
		produce.queue_free()
		on_arrived.call())
	_squash()


## İkinci dereceden Bezier: başlangıç ve varışın ortasının ARC_HEIGHT üstünden geçer.
func _fly(t: float, produce: Node2D, start: Vector2, end: Vector2) -> void:
	var control: Vector2 = (start + end) * 0.5 + Vector2(0.0, -ARC_HEIGHT)
	produce.position = start.lerp(control, t).lerp(control.lerp(end, t), t)


func _land(item: StringName, produce: Node2D) -> void:
	produce.queue_free()
	_in_flight[item] = maxi(_in_flight.get(item, 0) - 1, 0)
	_play_land_sound()
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		add_child(sparkle)
		sparkle.position = MOUTH
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	_squash()
	_refresh(true)


func _play_land_sound() -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_land_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.92, 1.08), pan)


func _squash() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Sayılar ve yığın: sepettekilerden yolda olanlar ve dışarı çıkarılanlar düşülür. Yığında demetler
## arkaya, havuçlar öne dizilir; slot sayısından fazlası sayıda görünür, yığında değil. Her iki üründen
## de varsa ikisi de görünür.
func _refresh(animate: bool) -> void:
	var carrots: int = _shown_count(Items.CARROT)
	var wheat: int = _shown_count(Items.WHEAT)
	_carrot_count.text = str(carrots)
	_wheat_count.text = str(wheat)
	var shown: int = mini(carrots + wheat, _slots.size())
	var shown_wheat: int = 0
	if shown > 0:
		shown_wheat = roundi(float(shown) * wheat / (carrots + wheat))
		if wheat > 0 and shown_wheat == 0:
			shown_wheat = 1
		if carrots > 0 and shown_wheat == shown and shown > 1:
			shown_wheat = shown - 1
	for i: int in _slots.size():
		var slot: Node2D = _slots[i]
		var wheat_sprite: CanvasItem = slot.get_node(^"Wheat") as CanvasItem
		var carrot_sprite: CanvasItem = slot.get_node(^"Carrot") as CanvasItem
		var was_visible: bool = wheat_sprite.visible or carrot_sprite.visible
		wheat_sprite.visible = i < shown_wheat
		carrot_sprite.visible = i >= shown_wheat and i < shown
		if animate and not was_visible and i < shown:
			slot.scale = Vector2.ZERO
			create_tween().tween_property(slot, ^"scale", Vector2.ONE, PILE_POP_TIME) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
