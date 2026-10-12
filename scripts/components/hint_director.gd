class_name HintDirector
extends Node
## Bölümün parmak ipucu yöneticisi. Ekrana hiç dokunulmadan bir süre geçince bölümün provider'ına o an
## yapılabilecek işi sorar ve HintHand ile gösterir. Her dokunuş eli hemen gizler ve sayacı sıfırlar;
## parmak ekrandayken (ör. araç tutulurken) sayaç işlemez.
## Çocuk bir işi learned_after kez yapınca (bölüm learned ile bildirir) o iş "öğrenilmiş" sayılır: öğrenilmemiş
## iş first_delay, öğrenilmiş iş learned_delay beklemeden sonra gösterilir. Sayılar SaveGame'in "hints"
## bölümünde, işin kimliğiyle tutulur.

## Bir ipucu gösterilmeye başladı (bölüm, sırayla değişen ipuçlarında sırayı bununla ilerletir).
signal shown(id: StringName)

const SECTION: String = "hints"
const HAND_SCENE: PackedScene = preload("res://scenes/ui/hint_hand.tscn")

@export_range(0.5, 30.0, 0.5, "suffix:s") var first_delay: float = 2.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var learned_delay: float = 10.0
@export_range(1, 10) var learned_after: int = 3

## O an gösterilecek iş: {"id": StringName, "points": PackedVector2Array (ekran), "hold": float (isteğe bağlı),
## "carry": Node2D (isteğe bağlı; elin taşıdığı görünen şeyin örneği)}; gösterilecek iş yoksa boş sözlük.
var provider: Callable

var _hand: HintHand
var _idle: float = 0.0
var _touches: Dictionary[int, bool] = {}
var _counts: Dictionary = {}


func _ready() -> void:
	_counts = SaveGame.get_section(SECTION)
	_hand = HAND_SCENE.instantiate() as HintHand
	add_child(_hand)
	_hand.finished.connect(func() -> void: _idle = 0.0)


func _process(delta: float) -> void:
	if not _touches.is_empty() or _hand.is_playing() or not provider.is_valid():
		return
	_idle += delta
	if _idle < first_delay:
		return
	var hint: Dictionary = provider.call()
	if hint.is_empty():
		return
	if _idle < (learned_delay if is_learned(hint["id"]) else first_delay):
		return
	_hand.play(hint["points"], hint.get("hold", HintHand.DEFAULT_HOLD), hint.get("carry"))
	shown.emit(hint["id"])


func _input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touches[touch.index] = true
		else:
			_touches.erase(touch.index)
	elif not event is InputEventScreenDrag:
		return
	_idle = 0.0
	_hand.stop()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_touches.clear()


## Çocuk bu işi bir kez yaptı.
func learned(id: StringName) -> void:
	var key: String = String(id)
	_counts[key] = int(_counts.get(key, 0)) + 1
	SaveGame.set_section(SECTION, _counts)
	SaveGame.request_save()


func is_learned(id: StringName) -> bool:
	return int(_counts.get(String(id), 0)) >= learned_after
