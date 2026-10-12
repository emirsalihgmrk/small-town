class_name ParentMenu
extends CanvasLayer
## Ebeveyn köşesi: yetişkinler için ayarlar ve lisanslar. Ana ekrandaki ParentGateButton basılı
## tutulunca açılır. Açıkken arkadaki her şey kararır ve dokunuşları yutar.
## İki sayfası var: ana sayfa ve lisanslar. Geri düğmesi ya da Android geri tuşu lisanslardan ana sayfaya,
## ana sayfadan oyuna döner; çarpı ya da karartılmış arka plan her zaman kapatır.
## Lisans metni Godot'nun kendisinden (Engine.get_license_text/get_copyright_info/get_license_info)
## alınır; motor güncellenince liste kendiliğinden güncel kalır. Uzun olduğu için ilk açılışta doldurulur.

const DIM_ALPHA: float = 0.4
const FADE_TIME: float = 0.2
const POP_START_SCALE: float = 0.6
const POP_TIME: float = 0.35
const CLOSE_SCALE: float = 0.85
const CLOSE_TIME: float = 0.15
const HEADING_SIZE: int = 40
const SUBHEADING_SIZE: int = 30

var is_open: bool = false

var _licenses_filled: bool = false
var _tween: Tween

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _panel: Control = $Root/Panel
@onready var _title: Label = %Title
@onready var _back_button: Button = %BackButton
@onready var _close_button: Button = %CloseButton
@onready var _main_page: Control = %MainPage
@onready var _licenses_page: ScrollContainer = %LicensesPage
@onready var _licenses_text: RichTextLabel = %LicensesText
@onready var _licenses_button: Button = %LicensesButton


func _ready() -> void:
	add_to_group(SceneRouter.BACK_HANDLERS)
	_root.hide()
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)
	_dim.gui_input.connect(_on_dim_input)
	_close_button.pressed.connect(close)
	_back_button.pressed.connect(_show_main)
	_licenses_button.pressed.connect(_show_licenses)


func open() -> void:
	if is_open:
		return
	is_open = true
	_show_main()
	_root.show()
	_panel.scale = Vector2.ONE * POP_START_SCALE
	_panel.modulate.a = 0.0
	_dim.color.a = 0.0
	_restart_tween()
	_tween.tween_property(_dim, ^"color:a", DIM_ALPHA, FADE_TIME)
	_tween.tween_property(_panel, ^"modulate:a", 1.0, FADE_TIME)
	_tween.tween_property(_panel, ^"scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_restart_tween()
	_tween.tween_property(_dim, ^"color:a", 0.0, CLOSE_TIME)
	_tween.tween_property(_panel, ^"modulate:a", 0.0, CLOSE_TIME)
	_tween.tween_property(_panel, ^"scale", Vector2.ONE * CLOSE_SCALE, CLOSE_TIME).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_root.hide)


## SceneRouter geri tuşunda çağırır: lisanslardan ana sayfaya, ana sayfadan oyuna döner.
func go_back() -> bool:
	if not is_open:
		return false
	if _licenses_page.visible:
		_show_main()
	else:
		close()
	return true


func _show_main() -> void:
	_title.text = "Ebeveyn Köşesi"
	_back_button.hide()
	_licenses_page.hide()
	_main_page.show()


func _show_licenses() -> void:
	_fill_licenses()
	_title.text = "Lisanslar"
	_back_button.show()
	_main_page.hide()
	_licenses_page.show()
	_licenses_page.scroll_vertical = 0


func _fill_licenses() -> void:
	if _licenses_filled:
		return
	_licenses_filled = true
	var text: RichTextLabel = _licenses_text
	text.clear()
	_heading(text, String(ProjectSettings.get_setting("application/config/name")), HEADING_SIZE)
	_paragraph(text, "Oyundaki bütün çizimler ve sesler bu oyun için yapıldı.")
	_heading(text, "Godot Engine", HEADING_SIZE)
	_paragraph(text, "Bu oyun Godot Engine ile yapıldı (godotengine.org).")
	_paragraph(text, Engine.get_license_text())
	_heading(text, "Üçüncü taraf bileşenler", HEADING_SIZE)
	_paragraph(text, "Godot Engine aşağıdaki bileşenleri içerir.")
	for component: Dictionary in Engine.get_copyright_info():
		if component["name"] == "Godot Engine":
			continue
		_heading(text, component["name"], SUBHEADING_SIZE)
		var lines: PackedStringArray = []
		for part: Dictionary in component["parts"]:
			for holder: String in part["copyright"]:
				lines.append("© " + holder)
			lines.append("Lisans: " + part["license"])
		_paragraph(text, "\n".join(lines))
	_heading(text, "Lisans metinleri", HEADING_SIZE)
	var licenses: Dictionary = Engine.get_license_info()
	for license_name: String in licenses:
		_heading(text, license_name, SUBHEADING_SIZE)
		_paragraph(text, licenses[license_name])


## BBCode kullanılmaz: lisans metinlerindeki köşeli parantezler etiket sanılmasın.
func _heading(text: RichTextLabel, title: String, font_size: int) -> void:
	text.push_font_size(font_size)
	text.push_bold()
	text.add_text(title + "\n")
	text.pop()
	text.pop()


func _paragraph(text: RichTextLabel, body: String) -> void:
	text.add_text(body.strip_edges() + "\n\n")


func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()


func _on_dim_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null and touch.pressed:
		close()
