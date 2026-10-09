extends Node2D
## Pazar bölümü: eve dönüş, sepete dokununca sepetin içini açma, müşterilerin gelişi ve kızın tepkileri.
## Sepette ürün varsa kısa bir süre sonra bir hayvan dost (Customer) sağdan yürüyerek tezgâhın önüne gelir
## ve başının üstünde isteği (MarketOrders) görünür; müşteri gelince kız ona el sallar. Müşteriler
## sırayla gelir (tavşan, ayıcık, kirpi), ilk gelen rastgeledir. İstenen ürünler sepetten parmakla
## müşteriye götürülür (SellHand); her verilen üründe kız sevinir.
## İstek tamamlanınca müşteri teşekkür eder (balonu kapanır, kalpler çıkar) ve istediği her ürün için bir
## bozuk parayı tezgâhtaki kumbaraya (CoinJar) atar; paralar ortak paraya (Wallet) ödeme başlarken hemen
## geçer. Sonra müşteri sağa yürüyüp gider, kız arkasından el sallar.
## Biraz sonra sıradaki müşteri gelir.
## Uzun süre dokunulmazsa kız esner. Tente rüzgârda dalgalanır, tentenin üstüne arada bir kuş konar
## (FieldBird), meydanda kelebekler gezinir (Butterfly); müşteriye dokunulabilir (Customer).
## Sepet boşsa müşteri gelmez; tezgâhın üstünde tarlayı gösteren bir balon durur, balona dokununca
## tarlaya gidilir. Sepete ürün girince balon kapanır ve müşteri yola çıkar.
## Sıradaki müşterinin kim olduğu ve isteği tamamlanmamış müşteri (görünüşü, isteği, verilmiş yuvaları)
## kayda geçer: müşteri gelince, ona ürün verilince, müşteri gidince, sahneden çıkarken ve SaveGame diske
## yazmadan hemen önce. Paralar Pazar'ın değil Wallet'ın kaydındadır. Açılışta müşteri yürümeden tezgâhın önünde, balonu verilmiş yuvalarıyla belirir. Sepette artık
## bulunmayan istekler (ör. arada fırında kullanıldıysa) istekten çıkarılır; geriye yalnızca verilmişler
## kaldıysa müşteri hemen öder ve gider.

const SECTION: String = "market"
## Esneme zamanı geldiğinde kız başka bir hareketteyse bu kadar sonra yeniden denenir.
const YAWN_RETRY_TIME: float = 2.0
const FIELD_SECTION: StringName = &"field"
## Kızın tezgâha (sağa) bakan kolu.
const GIRL_STALL_ARM: int = 1
## Müşteri ekranın sağ kenarının bu kadar dışından yürümeye başlar ve oraya yürüyüp gider.
const ENTRY_X: float = 2120.0
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_BOB: float = 8.0
const BUBBLE_BOB_PERIOD: float = 1.8
## Son ürün verildikten sonra müşterinin teşekkür etmesine kadar geçen süre.
const THANK_DELAY: float = 0.5
## Teşekkürden ilk paraya ve paralar arası süre.
const COIN_INTERVAL: float = 0.3
## Son para atıldıktan sonra müşterinin yola çıkmasına kadar geçen süre.
const LEAVE_DELAY: float = 0.7

## Sahne açıldıktan ya da sepete ürün girdikten sonra müşterinin yola çıkmasına kadar geçen süre.
@export_range(0.0, 30.0, 0.5, "suffix:s") var customer_delay: float = 1.5
## Bir müşteri gittikten sonra sıradakinin yola çıkmasına kadar geçen süre.
@export_range(0.0, 30.0, 0.5, "suffix:s") var next_customer_delay: float = 3.0
## Bu kadar süre hiç dokunulmazsa kız esner (sonra yine aynı süre beklenir).
@export_range(5.0, 120.0, 1.0, "suffix:s") var idle_yawn_time: float = 25.0

var _next_kind: int = 0
var _idle_time: float = 0.0
var _empty_bubble_scale: Vector2
var _empty_bubble_tween: Tween

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _girl: Girl = $World/Girl
@onready var _customer: Customer = $World/Customer
@onready var _customer_spot: Marker2D = $World/CustomerSpot
@onready var _customer_timer: Timer = $CustomerTimer
@onready var _coin_jar: CoinJar = $World/Stall/CoinJar
@onready var _empty_bubble: Node2D = $World/Stall/EmptyBubble
@onready var _empty_bubble_tap: Tappable = $World/Stall/EmptyBubble/TapArea


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	_next_kind = randi_range(0, _customer.look_count() - 1)
	_customer.arrived.connect(_girl.wave.bind(GIRL_STALL_ARM))
	_customer.item_received.connect(func(_slot: int) -> void: _girl.cheer())
	_customer.order_completed.connect(_pay)
	_customer.left.connect(func() -> void: _refresh(next_customer_delay))
	_customer.arrived.connect(SaveGame.request_save)
	_customer.item_received.connect(func(_slot: int) -> void: SaveGame.request_save())
	_customer.left.connect(SaveGame.request_save)
	_customer_timer.timeout.connect(_send_customer)
	_empty_bubble_scale = _empty_bubble.scale
	_empty_bubble.hide()
	Oscillation.ping_pong(self, _empty_bubble, ^"position:y", _empty_bubble.position.y,
			_empty_bubble.position.y - BUBBLE_BOB, BUBBLE_BOB_PERIOD)
	_empty_bubble_tap.tapped.connect(func(_point: Vector2) -> void: SceneRouter.go_to_section(FIELD_SECTION))
	Basket.changed.connect(func(_item: StringName, _count: int) -> void: _refresh())
	SaveGame.before_save.connect(_store)
	_restore()
	_refresh()


func _process(delta: float) -> void:
	_idle_time += delta
	if _idle_time >= idle_yawn_time:
		_idle_time = 0.0 if _girl.yawn() else idle_yawn_time - YAWN_RETRY_TIME


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_idle_time = 0.0


func _exit_tree() -> void:
	_store()
	SaveGame.save_now()


func _store() -> void:
	SaveGame.set_section(SECTION, {
		"next_kind": _next_kind,
		"customer": _customer.save_state(),
	})


func _restore() -> void:
	var data: Dictionary = SaveGame.get_section(SECTION)
	if data.is_empty():
		return
	_next_kind = posmod(int(data.get("next_kind", _next_kind)), _customer.look_count())
	var customer_data: Variant = data.get("customer")
	if customer_data is Dictionary:
		_restore_customer(customer_data)


## Kayıttaki isteği, verilmemiş ürünleri sepette hâlâ bulunanlarla sınırlayarak kurar.
func _restore_customer(data: Dictionary) -> void:
	var saved_order: Variant = data.get("order")
	var saved_filled: Variant = data.get("filled")
	if not (saved_order is Array and saved_filled is Array):
		return
	if (saved_order as Array).size() != (saved_filled as Array).size():
		return
	var order: Array[StringName] = []
	var filled: Array[bool] = []
	var promised: Dictionary[StringName, int] = {}
	for i: int in (saved_order as Array).size():
		var item: StringName = StringName(str(saved_order[i]))
		if not MarketOrders.ALL.has(item):
			continue
		var given: bool = bool(saved_filled[i])
		if not given:
			if Basket.count(item) - promised.get(item, 0) <= 0:
				continue
			promised[item] = promised.get(item, 0) + 1
		order.append(item)
		filled.append(given)
	if order.is_empty():
		return
	_customer.place(int(data.get("kind", 0)), order, filled, _customer_spot.global_position)
	if _customer.is_complete():
		_pay()

## Müşteri yoksa: sepette ürün varsa müşteriyi delay sonra yola çıkarır, yoksa tarla balonunu açar.
func _refresh(delay: float = customer_delay) -> void:
	if _customer.is_present() or not _customer_timer.is_stopped():
		return
	if MarketOrders.has_anything():
		_set_empty_bubble_visible(false)
		_customer_timer.start(maxf(delay, 0.01))
	else:
		_set_empty_bubble_visible(true)


## Müşteri teşekkür eder, istediği her ürün için kumbaraya bir para atar ve gider.
func _pay() -> void:
	_coin_jar.deposit(_customer.order.size())
	var tween: Tween = create_tween()
	tween.tween_interval(THANK_DELAY)
	tween.tween_callback(_customer.thank)
	for i: int in _customer.order.size():
		tween.tween_interval(COIN_INTERVAL)
		tween.tween_callback(func() -> void: _coin_jar.receive(_customer.hand_point()))
	tween.tween_interval(LEAVE_DELAY)
	tween.tween_callback(func() -> void:
		_customer.leave(Vector2(ENTRY_X, _customer.global_position.y))
		_girl.wave(GIRL_STALL_ARM))


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
