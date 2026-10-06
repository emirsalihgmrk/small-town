class_name SpinComponent
extends Node
## Ebeveyn Node2D'yi kendi pivotu etrafında sürekli, sabit hızla döndürür (yel değirmeni kanadı...).

## Pozitif saat yönü.
@export_range(-720.0, 720.0, 1.0, "suffix:°/s") var degrees_per_second: float = 20.0

var _target: Node2D


func _ready() -> void:
	_target = get_parent() as Node2D
	if _target == null:
		push_warning("SpinComponent bir Node2D'nin altında olmalı: %s" % get_path())
		set_process(false)


func _process(delta: float) -> void:
	_target.rotation = wrapf(_target.rotation + deg_to_rad(degrees_per_second) * delta, -PI, PI)
