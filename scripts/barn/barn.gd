extends Node2D
## Ahır bölümü: şimdilik yalnızca sahne, eve dönüş ve sepete dokununca sepetin içini açma.

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
