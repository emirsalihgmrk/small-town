@tool
class_name Tappable
extends Node2D
## Dokunulabilir alan. Dokunuşları kendisi dinlemez; TapRouter, üst üste binen alanlar arasından
## en öndekini seçip yalnızca ona tapped sinyalini gönderir. Alan editörde yarı saydam görünür.

signal tapped(global_tap_position: Vector2)

const GROUP: StringName = &"tappable"
const EDITOR_COLOR: Color = Color(1.0, 0.4, 0.7, 0.25)

## Bu düğüme göre yerel dokunma dikdörtgeni.
@export var area: Rect2 = Rect2(-50.0, -50.0, 100.0, 100.0):
	set(value):
		area = value
		queue_redraw()
## Üst üste binmede büyük olan kazanır (karakter/hayvan > ağaç/ev). Eşitlikte ekranda aşağıdaki öndedir.
@export var priority: int = 0
@export var enabled: bool = true


func _enter_tree() -> void:
	add_to_group(GROUP)


func contains(global_point: Vector2) -> bool:
	return enabled and is_visible_in_tree() and area.has_point(to_local(global_point))


## TapRouter tarafından çağrılır.
func tap(global_point: Vector2) -> void:
	tapped.emit(global_point)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(area, EDITOR_COLOR)
