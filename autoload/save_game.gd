extends Node
## Oyunun kalıcı kaydı (autoload: SaveGame).
## Kayıt, bölümlere ayrılmış tek bir JSON dosyasıdır ("basket", "field"...). Her bölüm kendi verisini
## get_section / set_section ile okuyup yazar. Diske yazmadan hemen önce before_save yayılır: açık
## sahneler güncel durumlarını o an bölümlerine yazar.
## Oyunun açık kaldığı süreyi de (play_time) sayar; uygulama arka plandayken saymaz. Tarla, en son ne
## zaman kaydedildiğini bununla tutar ve dönüldüğünde aradan geçen süre kadar büyümeyi ileri sarar.
## Kayıt bozuksa sessizce sıfırdan başlanır (oyun açılmaya devam etsin).

signal before_save

const SAVE_PATH: String = "user://save.json"
const FORMAT_VERSION: int = 1
## Art arda gelen kayıt istekleri birleştirilir; en geç bu kadar sonra diske yazılır.
const SAVE_DELAY: float = 1.0

var play_time: float = 0.0

var _sections: Dictionary = {}
var _active: bool = true
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)
	_load()


func _process(delta: float) -> void:
	if _active:
		play_time += delta


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_active = false
			save_now()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_active = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_now()


## Bölümün kopyası; bölüm yoksa boş sözlük.
func get_section(section: String) -> Dictionary:
	return (_sections.get(section, {}) as Dictionary).duplicate(true)


func set_section(section: String, data: Dictionary) -> void:
	_sections[section] = data.duplicate(true)


func request_save() -> void:
	if _save_timer.is_stopped():
		_save_timer.start(SAVE_DELAY)


## Önce geçici dosyaya yazar, sonra asıl dosyanın yerine koyar: yazarken kapanırsa eski kayıt bozulmaz.
func save_now() -> void:
	_save_timer.stop()
	before_save.emit()
	var data: Dictionary = {"version": FORMAT_VERSION, "play_time": play_time, "sections": _sections}
	var temp_path: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Kayıt yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err: Error = DirAccess.rename_absolute(temp_path, SAVE_PATH)
	if err != OK:
		push_error("Kayıt yerine konamadı: %s" % error_string(err))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or typeof((data as Dictionary).get("sections")) != TYPE_DICTIONARY:
		push_warning("Kayıt okunamadı, sıfırdan başlanıyor: %s" % SAVE_PATH)
		return
	play_time = float((data as Dictionary).get("play_time", 0.0))
	_sections = (data as Dictionary)["sections"]
