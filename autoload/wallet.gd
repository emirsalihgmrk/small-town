extends Node
## Oyun genelinde ortak para (autoload: Wallet). Pazarda müşterilerden kazanılır, Dükkânda harcanır.
## İçerik SaveGame'in "wallet" bölümünde kalıcı tutulur. Paranın görüntüsü kumbaradır (CoinJar).
## Eski kayıtlarda paralar Pazar'ın "market" bölümündeydi ("coins"); ilk açılışta buraya taşınır.

signal changed(count: int)

const SECTION: String = "wallet"
const LEGACY_SECTION: String = "market"
const KEY: String = "coins"

var _count: int = 0


func _ready() -> void:
	var saved: Dictionary = SaveGame.get_section(SECTION)
	if saved.has(KEY):
		_count = maxi(int(saved[KEY]), 0)
	else:
		_migrate()


func count() -> int:
	return _count


func add(amount: int = 1) -> void:
	_count += amount
	_on_changed()


## Yeterince yoksa hiçbir şey almaz ve false döner.
func take(amount: int = 1) -> bool:
	if _count < amount:
		return false
	_count -= amount
	_on_changed()
	return true


func _migrate() -> void:
	var market: Dictionary = SaveGame.get_section(LEGACY_SECTION)
	if not market.has(KEY):
		return
	_count = maxi(int(market[KEY]), 0)
	market.erase(KEY)
	SaveGame.set_section(LEGACY_SECTION, market)
	_on_changed()


func _on_changed() -> void:
	SaveGame.set_section(SECTION, {KEY: _count})
	SaveGame.request_save()
	changed.emit(_count)
