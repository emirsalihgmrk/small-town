class_name PauseWhenInactive
extends Node
## Ebeveyn düğümü (ve altındaki tüm Tween, Timer ve _process'leri) ebeveyn gizlendiğinde ya da
## uygulama arka plana geçtiğinde / odağını kaybettiğinde durdurur; geri gelince kaldığı yerden sürdürür.

var _target: Node
var _app_active: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target = get_parent()
	var canvas_item: CanvasItem = _target as CanvasItem
	if canvas_item != null:
		canvas_item.visibility_changed.connect(_refresh)
	_refresh()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_app_active = false
			_refresh()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_active = true
			_refresh()


func _refresh() -> void:
	if _target == null:
		return
	var canvas_item: CanvasItem = _target as CanvasItem
	var visible: bool = canvas_item == null or canvas_item.is_visible_in_tree()
	_target.process_mode = Node.PROCESS_MODE_INHERIT if _app_active and visible else Node.PROCESS_MODE_DISABLED
