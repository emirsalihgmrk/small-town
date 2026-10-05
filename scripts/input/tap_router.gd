class_name TapRouter
extends Node
## Sahnedeki dokunulabilir ögeler için tek giriş noktası.
## Arayüz (bölüm kartları) dokunuşu önce alır; kalan dokunuşta noktayı içeren Tappable'lardan
## önceliği en yüksek olan, eşitlikte ekranda en aşağıda (en önde) duran seçilir.


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	var point: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * touch.position
	var best: Tappable = null
	for node: Node in get_tree().get_nodes_in_group(Tappable.GROUP):
		var candidate: Tappable = node as Tappable
		if candidate != null and candidate.contains(point) and (best == null or _is_in_front(candidate, best)):
			best = candidate
	if best != null:
		get_viewport().set_input_as_handled()
		best.tap(point)


func _is_in_front(a: Tappable, b: Tappable) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.global_position.y > b.global_position.y
