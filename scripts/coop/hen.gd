class_name Hen
extends Node2D
## Kümesteki tavuk. Şimdilik yalnızca yerinde durur: nefes alır, başını hafifçe sallar, ara sıra
## yere iki kez gagalar. Kök noktası tavuğun ayaklarıdır; görsel sağa bakar, sola baksın diye kök aynalanır.

const PECK_DEGREES: float = 38.0
const PECK_TIME: float = 0.11
const PECK_COUNT: int = 2

@export_range(0.5, 30.0, 0.5, "suffix:s") var peck_interval_min: float = 2.5
@export_range(0.5, 30.0, 0.5, "suffix:s") var peck_interval_max: float = 6.0

@onready var _head: Node2D = $Body/Neck/Head
@onready var _peck_timer: Timer = $PeckTimer


func _ready() -> void:
	_peck_timer.timeout.connect(_peck)
	_peck_timer.start(randf_range(peck_interval_min, peck_interval_max))


func _peck() -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i: int in PECK_COUNT:
		tween.tween_property(_head, ^"rotation", deg_to_rad(PECK_DEGREES), PECK_TIME)
		tween.tween_property(_head, ^"rotation", 0.0, PECK_TIME)
	_peck_timer.start(randf_range(peck_interval_min, peck_interval_max))
