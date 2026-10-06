extends CanvasLayer
## Sahneler arası geçiş (autoload: SceneRouter).
## Ekranı yumuşakça bir perdeyle kapatır, sahneyi değiştirir, yeni sahne hazır olunca perdeyi açar.
## Geçiş sürerken gelen istekler ve dokunuşlar yok sayılır; çift basma iki geçiş başlatmaz.

const HOME_SCENE: String = "res://scenes/main/home.tscn"
## Henüz yapılmamış bölümler burada yoktur; kartları basılınca hiçbir şey olmaz.
const SECTION_SCENES: Dictionary[StringName, String] = {
	&"field": "res://scenes/field/field.tscn",
}
## Her şeyin, ana ekrandaki kartlar dahil, üstünde kalsın.
const CURTAIN_LAYER: int = 100

@export_range(0.05, 2.0, 0.05, "suffix:s") var close_time: float = 0.3
@export_range(0.05, 2.0, 0.05, "suffix:s") var open_time: float = 0.35
@export var curtain_color: Color = Color(1.0, 0.973, 0.906)

var _curtain: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CURTAIN_LAYER
	_curtain = ColorRect.new()
	_curtain.name = "Curtain"
	_curtain.color = Color(curtain_color, 0.0)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)


func _input(_event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()


func has_section(section_id: StringName) -> bool:
	return SECTION_SCENES.has(section_id)


## Bölümün sahnesi yoksa sessizce hiçbir şey yapmaz.
func go_to_section(section_id: StringName) -> void:
	if has_section(section_id):
		_go(SECTION_SCENES[section_id])


func go_home() -> void:
	_go(HOME_SCENE)


func _go(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_curtain(1.0, close_time)
	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err == OK:
		await get_tree().scene_changed
	else:
		push_error("Sahneye geçilemedi: %s (%s)" % [scene_path, error_string(err)])
	await _fade_curtain(0.0, open_time)
	_busy = false


func _fade_curtain(alpha: float, duration: float) -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_curtain, ^"color:a", alpha, duration)
	await tween.finished
