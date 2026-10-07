extends Node2D
## Kümes bölümü: şimdilik yalnızca sahne ve eve dönüş.

@onready var _home_button: Button = $UI/Root/HomeButton


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
