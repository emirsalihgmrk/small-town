extends Node2D
## Tarla bölümü. Şimdilik yalnızca ev düğmesiyle ana ekrana dönüşü bağlar.

@onready var _home_button: Button = $UI/Root/HomeButton


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
