class_name Cow
extends Node2D
## Ahırdaki inek. Şimdilik yalnızca yerinde durur: nefes alır, başını hafifçe sallar, kuyruğu salınır,
## ara sıra kulağını oynatır gibi başını kısa bir an silkeler. Kök noktası ineğin ayaklarının ortasıdır;
## görsel sola (yemliğe) bakar.

const SHAKE_DEGREES: float = 7.0
const SHAKE_TIME: float = 0.12
const SHAKE_COUNT: int = 2

@export_range(0.5, 30.0, 0.5, "suffix:s") var shake_interval_min: float = 4.0
@export_range(0.5, 30.0, 0.5, "suffix:s") var shake_interval_max: float = 9.0

@onready var _head: Node2D = $Body/Neck/Head
@onready var _shake_timer: Timer = $ShakeTimer


func _ready() -> void:
	_shake_timer.timeout.connect(_shake_head)
	_shake_timer.start(randf_range(shake_interval_min, shake_interval_max))


func _shake_head() -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i: int in SHAKE_COUNT:
		tween.tween_property(_head, ^"rotation", deg_to_rad(SHAKE_DEGREES), SHAKE_TIME)
		tween.tween_property(_head, ^"rotation", deg_to_rad(-SHAKE_DEGREES), SHAKE_TIME)
	tween.tween_property(_head, ^"rotation", 0.0, SHAKE_TIME)
	_shake_timer.start(randf_range(shake_interval_min, shake_interval_max))
