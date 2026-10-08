class_name HayPile
extends Node2D
## Ahırdaki saman yığını. Hiç tükenmez: parmakla çekilen her tutam buradan çıkar (HayHand). Dokununca,
## tutam çekilince ya da tutam geri dönünce hışırdar: hafifçe basılıp kabarır, birkaç saman sapı saçılır.
## Kök noktası yığının tabanının ortasıdır.

const SQUASH: Vector2 = Vector2(1.05, 0.92)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.45
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Parmağın yığına bastığı sayılan alan (kök noktasına göre); küçük parmaklar için cömert.
@export var grab_area: Rect2 = Rect2(-180.0, -210.0, 360.0, 230.0)
@export_file("*.ogg", "*.wav") var rustle_sound_path: String = "res://assets/audio/sfx/hay_rustle.ogg"

var _rustle_sound: AudioStream
var _squash_tween: Tween

@onready var _body: Node2D = $Body
@onready var _top: Marker2D = $Top
@onready var _straws: CPUParticles2D = $Straws


func _ready() -> void:
	if ResourceLoader.exists(rustle_sound_path):
		_rustle_sound = load(rustle_sound_path) as AudioStream


func contains(global_point: Vector2) -> bool:
	return grab_area.has_point(to_local(global_point))


## Tutamın çıktığı ve geri döndüğü yer (yığının tepesi, dünya konumu).
func top() -> Vector2:
	return _top.global_position


func rustle() -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	_body.scale = Vector2.ONE
	_squash_tween = create_tween()
	_squash_tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_straws.restart()
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_rustle_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.92, 1.08), pan)
