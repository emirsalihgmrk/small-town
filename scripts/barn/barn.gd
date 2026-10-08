extends Node2D
## Ahır bölümü: eve dönüş, sepete dokununca sepetin içini açma, saman yığınından yemliğe saman (HayHand),
## kovayla suluğa su (WaterHand), süt kovasıyla sağma (MilkHand) ve kızın tepkileri. İnek yemliği ve
## suluğu kendisi kullanır (Cow). Yemlik ya da suluk dolunca ve inek sağılınca kız sevinir; ineğin sütü
## hazır olunca ahıra el sallar.

## Kızın ahıra (sağa) bakan kolu.
const GIRL_BARN_ARM: int = 1

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _manger: Manger = $World/Manger
@onready var _trough: Trough = $World/Trough
@onready var _cow: Cow = $World/Cow
@onready var _girl: Girl = $World/Girl
@onready var _milk_hand: MilkHand = $MilkHand


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	_manger.filled.connect(_girl.cheer)
	_trough.filled.connect(_girl.cheer)
	_cow.milk_ready.connect(_girl.wave.bind(GIRL_BARN_ARM))
	_milk_hand.milked.connect(_girl.cheer)
