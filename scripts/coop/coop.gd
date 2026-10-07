extends Node2D
## Kümes bölümü: eve dönüş, sepetten yemliğe buğday, kovayla suluğa su, folluktan sepete yumurta ve
## kızın tepkileri. Tavuklar yemliği, suluğu ve folluklarını kendileri kullanır (Hen).
## Yemlik ya da suluk dolunca ve yumurta toplanınca kız sevinir; bir tavuk yumurtlayınca kümese el
## sallar. Folluğa dokununca içindeki yumurtalar ortak sepete eklenir ve sepete uçar.
## Sepette buğday yokken demet çekilmeye çalışılırsa yemliğin balonu zıplar; balonda tarla görünürken
## balona dokununca tarlaya gidilir. Sepete dokununca sepetin içi açılır.

const FIELD_SECTION: StringName = &"field"
## Kızın kümese (sağa) bakan kolu.
const GIRL_COOP_ARM: int = 1
## Bir folluktan birden çok yumurta toplanınca üst üste binmesinler diye yan yana havalanırlar.
const EGG_SPREAD: float = 26.0

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _feeder: Feeder = $World/Farmyard/Feeder
@onready var _waterer: Waterer = $World/Farmyard/Waterer
@onready var _girl: Girl = $World/Girl
@onready var _feed_hand: FeedHand = $FeedHand
@onready var _basket_menu: BasketMenu = $BasketMenu


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	_feeder.filled.connect(_girl.cheer)
	_waterer.filled.connect(_girl.cheer)
	_feeder.bubble_tapped.connect(SceneRouter.go_to_section.bind(FIELD_SECTION))
	_feed_hand.no_wheat.connect(_feeder.nudge_bubble)
	for nest: Nest in $World/House/Nests.get_children():
		nest.laid.connect(_girl.wave.bind(GIRL_COOP_ARM))
		nest.collected.connect(_on_eggs_collected)


## Yumurtalar ortak sepete hemen eklenir (sahne kapansa da kaybolmaz); uçuş yalnızca görünüştür.
func _on_eggs_collected(count: int, global_point: Vector2) -> void:
	Basket.add(Items.EGG, count)
	for i: int in count:
		_basket.receive(Items.EGG, global_point + Vector2((i - (count - 1) * 0.5) * EGG_SPREAD, 0.0))
	_girl.cheer()
