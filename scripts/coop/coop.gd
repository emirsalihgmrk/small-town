extends Node2D
## Kümes bölümü: eve dönüş, sepetten yemliğe buğday, kovayla suluğa su ve kızın tepkileri. Tavuklar
## yemliği ve suluğu kendileri kullanır (Hen). Yemlik ya da suluk dolunca kız sevinir. Sepette buğday
## yokken demet çekilmeye çalışılırsa yemliğin balonu zıplar; balonda tarla görünürken balona dokununca
## tarlaya gidilir. Sepete dokununca sepetin içi açılır.

const FIELD_SECTION: StringName = &"field"

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
