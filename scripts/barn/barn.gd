extends Node2D
## Ahır bölümü: eve dönüş, sepete dokununca sepetin içini açma, saman yığınından yemliğe saman (HayHand)
## ve kızın tepkileri: yemlik dolunca kız sevinir.

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _manger: Manger = $World/Manger
@onready var _girl: Girl = $World/Girl


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	_manger.filled.connect(_girl.cheer)
