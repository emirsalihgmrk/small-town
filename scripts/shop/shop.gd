extends Node2D
## Dükkân bölümü: eve dönüş, sepete dokununca sepetin içini açma ve rafta satılan ürünler.
## Tezgâhtaki kumbara (CoinJar) Pazar'da kazanılan ortak parayı (Wallet) gösterir. Rafın üst katında kıza
## aksesuarlar, alt katında ana ekran süsleri durur (ShopItems); her birinin önünde fiyatı kadar para
## yuvalı bir etiket vardır (ShelfItem, PriceTag).
## Satın alma: paralar kumbaradan parmakla tek tek ürüne götürülür (CoinHand); her para etiketin sıradaki
## yuvasına oturur ve o anda ödenmiş sayılır (Owned). Son yuva dolunca etiketin yerine rozet çıkar, tilki
## (Shopkeeper) sevinçle zıplayıp paketi uzatır, paket kavis çizerek kıza uçar ve kız sevinir.
## Ürüne dokununca: alınmışsa ya da kalan parası yetiyorsa ürün zıplar (yetiyorsa kumbara da esneyip
## paraların yerini gösterir); yetmiyorsa etiketi sallanır ve kumbaranın üstünde Pazar'ı gösteren balon bir
## süre açılır. Boş kumbaradan para çekilmeye çalışılınca da balon açılır. Alınmamış hiçbir ürüne para
## yetmiyorsa balon sürekli açık durur. Balona dokununca Pazar'a gidilir.

const MARKET_SECTION: StringName = &"market"
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_BOB: float = 8.0
const BUBBLE_BOB_PERIOD: float = 1.8
const BUBBLE_NUDGE_SCALE: float = 1.15
const BUBBLE_NUDGE_TIME: float = 0.12
## Son para oturduktan sonra tilkinin paketi uzatmasına kadar geçen süre.
const DELIVER_DELAY: float = 0.35
const GIFT_POP_TIME: float = 0.25
const GIFT_HOLD_TIME: float = 0.3
const GIFT_FLIGHT_TIME: float = 0.7
const GIFT_ARC_HEIGHT: float = 220.0
const GIFT_ARRIVE_SCALE: float = 0.5
## Paketin kıza vardığı yer (kızın kök noktasına göre): göğsünün önü.
const GIRL_CHEST: Vector2 = Vector2(30.0, -170.0)
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Parası yetmeyen ürüne dokununca Pazar balonu en az bu kadar açık kalır.
@export_range(1.0, 20.0, 0.5, "suffix:s") var hint_time: float = 4.0
@export var gift_texture: Texture2D
@export_file("*.ogg", "*.wav") var gift_sound_path: String = "res://assets/audio/sfx/card_flip.ogg"

var _bubble_scale: Vector2
var _bubble_tween: Tween
var _gift_sound: AudioStream

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _girl: Girl = $World/Girl
@onready var _shopkeeper: Shopkeeper = $World/Shopkeeper
@onready var _coin_jar: CoinJar = $World/CoinJar
@onready var _coin_hand: CoinHand = $CoinHand
@onready var _shelf_items: Node2D = $World/ShelfItems
@onready var _flights: Node2D = $World/Flights
@onready var _bubble: Node2D = $World/MarketBubble
@onready var _bubble_tap: Tappable = $World/MarketBubble/TapArea
@onready var _hint_timer: Timer = $HintTimer


func _ready() -> void:
	if ResourceLoader.exists(gift_sound_path):
		_gift_sound = load(gift_sound_path) as AudioStream
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	for node: Node in _shelf_items.get_children():
		(node as ShelfItem).tapped.connect(_on_item_tapped)
	_coin_hand.coin_placed.connect(_on_coin_placed)
	_coin_hand.refused.connect(_show_hint)
	_bubble_scale = _bubble.scale
	_bubble.hide()
	Oscillation.ping_pong(self, _bubble, ^"position:y", _bubble.position.y, _bubble.position.y - BUBBLE_BOB,
			BUBBLE_BOB_PERIOD)
	_bubble_tap.tapped.connect(func(_point: Vector2) -> void: SceneRouter.go_to_section(MARKET_SECTION))
	_hint_timer.timeout.connect(_refresh_bubble)
	Wallet.changed.connect(func(_count: int) -> void: _refresh_bubble())
	Owned.purchased.connect(func(_item: StringName) -> void: _refresh_bubble())
	_refresh_bubble()


func _on_item_tapped(item: ShelfItem) -> void:
	if item.is_owned():
		item.hop()
		return
	if Wallet.count() >= item.remaining():
		item.hop()
		_coin_jar.bounce()
		return
	item.nudge()
	_show_hint()


func _on_coin_placed(item: ShelfItem) -> void:
	_girl.cheer()
	if Owned.has(item.item) and not item.is_owned():
		item.mark_owned()
		get_tree().create_timer(DELIVER_DELAY).timeout.connect(_deliver)


## Tilki zıplayıp paketi uzatır; paket kavis çizerek kıza uçar.
func _deliver() -> void:
	_shopkeeper.cheer()
	var pan: float = clampf((_shopkeeper.global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_gift_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.95, 1.05), pan)
	var gift: Sprite2D = Sprite2D.new()
	gift.texture = gift_texture
	_flights.add_child(gift)
	var start: Vector2 = _flights.to_local(_shopkeeper.hand_point())
	var end: Vector2 = _flights.to_local(_girl.to_global(GIRL_CHEST))
	gift.position = start
	gift.scale = Vector2.ZERO
	var tween: Tween = gift.create_tween()
	tween.tween_property(gift, ^"scale", Vector2.ONE, GIFT_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(GIFT_HOLD_TIME)
	tween.tween_method(_fly.bind(gift, start, end), 0.0, 1.0, GIFT_FLIGHT_TIME).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(gift, ^"scale", Vector2.ONE * GIFT_ARRIVE_SCALE, GIFT_FLIGHT_TIME)
	tween.tween_callback(func() -> void:
		gift.queue_free()
		_girl.cheer())


## İkinci dereceden Bezier: başlangıç ve varışın ortasının GIFT_ARC_HEIGHT üstünden geçer.
func _fly(t: float, gift: Node2D, start: Vector2, end: Vector2) -> void:
	var control: Vector2 = (start + end) * 0.5 + Vector2(0.0, -GIFT_ARC_HEIGHT)
	gift.position = start.lerp(control, t).lerp(control.lerp(end, t), t)


func _show_hint() -> void:
	_hint_timer.start(hint_time)
	if _bubble_tap.enabled:
		_nudge_bubble()
	_refresh_bubble()


## Alınmamış ürünlerden en az birinin kalan parası kumbarada var mı (hepsi alındıysa da true).
func _can_afford_anything() -> bool:
	var cheapest: int = -1
	for node: Node in _shelf_items.get_children():
		var remaining: int = (node as ShelfItem).remaining()
		if remaining > 0 and (cheapest < 0 or remaining < cheapest):
			cheapest = remaining
	return cheapest < 0 or Wallet.count() >= cheapest


func _refresh_bubble() -> void:
	_set_bubble_visible(not _can_afford_anything() or not _hint_timer.is_stopped())


func _set_bubble_visible(shown: bool) -> void:
	if shown == _bubble_tap.enabled:
		return
	_bubble_tap.enabled = shown
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_tween = create_tween().set_trans(Tween.TRANS_BACK)
	if shown:
		_bubble.scale = Vector2.ZERO
		_bubble.show()
		_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, BUBBLE_POP_TIME).set_ease(Tween.EASE_OUT)
	else:
		_bubble_tween.tween_property(_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME).set_ease(Tween.EASE_IN)
		_bubble_tween.tween_callback(_bubble.hide)


func _nudge_bubble() -> void:
	if _bubble_tween != null and _bubble_tween.is_running():
		return
	_bubble_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale * BUBBLE_NUDGE_SCALE, BUBBLE_NUDGE_TIME)
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, BUBBLE_NUDGE_TIME * 2.0)
