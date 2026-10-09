extends Node2D
## Pazar bölümü: eve dönüş, sepete dokununca sepetin içini açma, müşterilerin gelişi ve kızın tepkileri.
## Sepette ürün varsa kısa bir süre sonra bir hayvan dost (Customer) sağdan yürüyerek tezgâhın önüne gelir
## ve başının üstünde isteği (MarketOrders) görünür; müşteri gelince kız ona el sallar. Müşteriler
## sırayla gelir (tavşan, ayıcık, kirpi), ilk gelen rastgeledir.
## Sepet boşsa müşteri gelmez; tezgâhın üstünde tarlayı gösteren bir balon durur, balona dokununca
## tarlaya gidilir. Sepete ürün girince balon kapanır ve müşteri yola çıkar.

const FIELD_SECTION: StringName = &"field"
## Kızın tezgâha (sağa) bakan kolu.
const GIRL_STALL_ARM: int = 1
## Müşteri ekranın sağ kenarının bu kadar dışından yürümeye başlar.
const ENTRY_X: float = 2120.0
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_BOB: float = 8.0
const BUBBLE_BOB_PERIOD: float = 1.8

## Sahne açıldıktan ya da sepete ürün girdikten sonra müşterinin yola çıkmasına kadar geçen süre.
@export_range(0.0, 30.0, 0.5, "suffix:s") var customer_delay: float = 1.5

var _next_kind: int = 0
var _empty_bubble_scale: Vector2
var _empty_bubble_tween: Tween

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _girl: Girl = $World/Girl
@onready var _customer: Customer = $World/Customer
@onready var _customer_spot: Marker2D = $World/CustomerSpot
@onready var _customer_timer: Timer = $CustomerTimer
@onready var _empty_bubble: Node2D = $World/Stall/EmptyBubble
@onready var _empty_bubble_tap: Tappable = $World/Stall/EmptyBubble/TapArea


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	_next_kind = randi_range(0, _customer.look_count() - 1)
	_customer.arrived.connect(_girl.wave.bind(GIRL_STALL_ARM))
	_customer_timer.timeout.connect(_send_customer)
	_empty_bubble_scale = _empty_bubble.scale
	_empty_bubble.hide()
	Oscillation.ping_pong(self, _empty_bubble, ^"position:y", _empty_bubble.position.y,
			_empty_bubble.position.y - BUBBLE_BOB, BUBBLE_BOB_PERIOD)
	_empty_bubble_tap.tapped.connect(func(_point: Vector2) -> void: SceneRouter.go_to_section(FIELD_SECTION))
	Basket.changed.connect(func(_item: StringName, _count: int) -> void: _refresh())
	_refresh()


## Müşteri yoksa: sepette ürün varsa müşteriyi yola çıkarır, yoksa tarla balonunu açar.
func _refresh() -> void:
	if _customer.is_present() or not _customer_timer.is_stopped():
		return
	if MarketOrders.has_anything():
		_set_empty_bubble_visible(false)
		_customer_timer.start(customer_delay)
	else:
		_set_empty_bubble_visible(true)


func _send_customer() -> void:
	var order: Array[StringName] = MarketOrders.make()
	if order.is_empty():
		_refresh()
		return
	var spot: Vector2 = _customer_spot.global_position
	_customer.arrive(_next_kind, order, Vector2(ENTRY_X, spot.y), spot)
	_next_kind = (_next_kind + 1) % _customer.look_count()


func _set_empty_bubble_visible(shown: bool) -> void:
	if shown == _empty_bubble_tap.enabled:
		return
	_empty_bubble_tap.enabled = shown
	if _empty_bubble_tween != null:
		_empty_bubble_tween.kill()
	_empty_bubble_tween = create_tween().set_trans(Tween.TRANS_BACK)
	if shown:
		_empty_bubble.scale = Vector2.ZERO
		_empty_bubble.show()
		_empty_bubble_tween.tween_property(_empty_bubble, ^"scale", _empty_bubble_scale, BUBBLE_POP_TIME) \
				.set_ease(Tween.EASE_OUT)
	else:
		_empty_bubble_tween.tween_property(_empty_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME) \
				.set_ease(Tween.EASE_IN)
		_empty_bubble_tween.tween_callback(_empty_bubble.hide)
