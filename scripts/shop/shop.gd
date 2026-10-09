extends Node2D
## Dükkân bölümü: eve dönüş, sepete dokununca sepetin içini açma ve rafta satılan ürünler.
## Tezgâhtaki kumbara (CoinJar) Pazar'da kazanılan ortak parayı (Wallet) gösterir. Rafın üst katında kıza
## aksesuarlar, alt katında ana ekran süsleri durur (ShopItems); her birinin önünde fiyatı kadar para
## yuvalı bir etiket vardır (ShelfItem, PriceTag).
## Ürüne dokununca: para yetiyorsa ürün sevinçle zıplar; yetmiyorsa etiketi sallanır ve kumbaranın üstünde
## Pazar'ı gösteren balon bir süre açılır. Hiçbir ürüne para yetmiyorsa balon sürekli açık durur. Balona
## dokununca Pazar'a gidilir.

const MARKET_SECTION: StringName = &"market"
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_BOB: float = 8.0
const BUBBLE_BOB_PERIOD: float = 1.8
const BUBBLE_NUDGE_SCALE: float = 1.15
const BUBBLE_NUDGE_TIME: float = 0.12

## Parası yetmeyen ürüne dokununca Pazar balonu en az bu kadar açık kalır.
@export_range(1.0, 20.0, 0.5, "suffix:s") var hint_time: float = 4.0

var _bubble_scale: Vector2
var _bubble_tween: Tween

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _shelf_items: Node2D = $World/ShelfItems
@onready var _bubble: Node2D = $World/MarketBubble
@onready var _bubble_tap: Tappable = $World/MarketBubble/TapArea
@onready var _hint_timer: Timer = $HintTimer


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	for node: Node in _shelf_items.get_children():
		(node as ShelfItem).tapped.connect(_on_item_tapped)
	_bubble_scale = _bubble.scale
	_bubble.hide()
	Oscillation.ping_pong(self, _bubble, ^"position:y", _bubble.position.y, _bubble.position.y - BUBBLE_BOB,
			BUBBLE_BOB_PERIOD)
	_bubble_tap.tapped.connect(func(_point: Vector2) -> void: SceneRouter.go_to_section(MARKET_SECTION))
	_hint_timer.timeout.connect(_refresh_bubble)
	Wallet.changed.connect(func(_count: int) -> void: _refresh_bubble())
	_refresh_bubble()


func _on_item_tapped(item: ShelfItem) -> void:
	if Wallet.count() >= item.price():
		item.hop()
		return
	item.nudge()
	_hint_timer.start(hint_time)
	if _bubble_tap.enabled:
		_nudge_bubble()
	_refresh_bubble()


func _can_afford_anything() -> bool:
	var items: Array[StringName] = []
	for node: Node in _shelf_items.get_children():
		items.append((node as ShelfItem).item)
	var cheapest: int = ShopItems.cheapest(items)
	return cheapest >= 0 and Wallet.count() >= cheapest


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
