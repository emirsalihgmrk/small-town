class_name WaterTarget
extends Node2D
## Kovayla su dökülebilen şey (kümesteki suluk, ahırdaki suluk). WaterHand yalnızca bu üç işi bilir;
## nasıl dolduğu ve kimin içtiği alt sınıfa kalır.


## Kovanın ucu bu noktadayken su buraya dökülür.
func contains(_global_point: Vector2) -> bool:
	return false


func needs_water() -> bool:
	return false


## Kova bunun üstünde delta saniye su döktü.
func water(_delta: float) -> void:
	pass
