extends Node
## Oyunun kalıcı kaydı (autoload: SaveGame).
## Kayıt, bölümlere ayrılmış tek bir JSON dosyasıdır ("basket", "field"...). Her bölüm kendi verisini
## get_section / set_section ile okuyup yazar. Diske yazmadan hemen önce before_save yayılır: açık
## sahneler güncel durumlarını o an bölümlerine yazar.
## Oyunun açık kaldığı süreyi de (play_time) sayar; uygulama arka plandayken saymaz. Tarla, en son ne
## zaman kaydedildiğini bununla tutar ve dönüldüğünde aradan geçen süre kadar büyümeyi ileri sarar.
## Her yazışta bir önceki kayıt save.json.bak olarak saklanır. Kayıt okunamazsa yedekten açılır; bozuk
## dosya silinmez, save.json.corrupt adıyla kenara konur. İkisi de okunamazsa sıfırdan başlanır (oyun
## açılmaya devam etsin).
## Kayıt biçimi değişirse FORMAT_VERSION artırılır ve _migrate'e eski sürümden geçiş adımı eklenir.

signal before_save

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = SAVE_PATH + ".tmp"
const BACKUP_PATH: String = SAVE_PATH + ".bak"
const CORRUPT_PATH: String = SAVE_PATH + ".corrupt"
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


## Önce geçici dosyaya yazar; yazma başarılıysa eski kaydı yedeğe çevirip yenisini yerine koyar.
## Yazarken kapanır ya da yazamazsa (ör. disk dolu) eski kayıt bozulmaz.
func save_now() -> void:
	_save_timer.stop()
	before_save.emit()
	var data: Dictionary = {"version": FORMAT_VERSION, "play_time": play_time, "sections": _sections}
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Kayıt yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	var write_err: Error = file.get_error()
	file.close()
	if write_err != OK:
		push_error("Kayıt yazılamadı: %s" % error_string(write_err))
		return
	if FileAccess.file_exists(SAVE_PATH):
		var backup_err: Error = DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
		if backup_err != OK:
			push_warning("Kayıt yedeklenemedi: %s" % error_string(backup_err))
	var err: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("Kayıt yerine konamadı: %s" % error_string(err))


## Önce asıl kaydı, okunamazsa yedeği açar. Okunamayan asıl kayıt CORRUPT_PATH'e taşınır ki sonraki
## yazış yedeği onunla ezmesin.
func _load() -> void:
	var data: Dictionary = _read(SAVE_PATH)
	if data.is_empty() and FileAccess.file_exists(SAVE_PATH):
		push_warning("Kayıt okunamadı, yedeğe bakılıyor: %s" % SAVE_PATH)
		DirAccess.rename_absolute(SAVE_PATH, CORRUPT_PATH)
	if data.is_empty():
		data = _read(BACKUP_PATH)
		if data.is_empty():
			if FileAccess.file_exists(BACKUP_PATH):
				push_warning("Yedek de okunamadı, sıfırdan başlanıyor: %s" % BACKUP_PATH)
			return
	data = _migrate(data)
	play_time = float(data.get("play_time", 0.0))
	_sections = data["sections"]


## Dosya yoksa ya da geçerli bir kayıt değilse boş sözlük döner.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or typeof((data as Dictionary).get("sections")) != TYPE_DICTIONARY:
		return {}
	return data


## Eski sürümlerin kaydını bugünkü biçime getirir. Biçim değiştiğinde FORMAT_VERSION'ı artır ve buraya
## bir önceki sürümden geçiren adımı ekle, ör.:
##     if version < 2:
##         (data["sections"] as Dictionary)["basket"] = ...
## Tanınmayan bölümlere dokunulmaz; daha yeni bir sürümün kaydı da olduğu gibi açılır.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 1))
	if version > FORMAT_VERSION:
		push_warning("Kayıt bu oyundan yeni bir sürümle yazılmış (%d > %d)." % [version, FORMAT_VERSION])
	return data
