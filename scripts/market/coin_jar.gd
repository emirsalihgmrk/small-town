class_name CoinJar
extends Node2D
## Tezgâhtaki cam kumbara: ortak paranın (Wallet) görüntüsü. Müşterinin bıraktığı bozuk para kavis çizerek
## kumbaranın kapağındaki deliğe uçar, içine düşer; tın sesi çalar, kumbara esner ve içindeki para yığını bir
## para büyür. Sayı gösterilmez, kumbaranın dolması yeter. Yığında en fazla capacity() kadar para görünür;
## fazlası sayılır ama kumbara dolu görünür.
## Gelecek paralar deposit ile hemen Wallet'a geçer (sahne aniden kapansa da kaybolmaz), ama yığında ancak
## receive ile uçup içine düştüklerinde görünür. Wallet başka yerden değişirse yığın hemen ona uyar.
## Dükkânda parmakla para çekilebilir: take_out yığından bir para gizler (Wallet değişmez), para etikete
## konunca Wallet'tan düşer, geri dönerse put_back ile yığına döner.
## Paralar camın arkası (Back) ile önü (Front) arasında çizilir.
## Kök noktası kumbaranın tabanının ortasıdır.

signal coin_landed

## Kapaktaki deliğin yeri (kök noktasına göre); para bunun biraz üstünden içine düşer.
const SLOT: Vector2 = Vector2(0.0, -134.0)
const SLOT_ABOVE: float = 40.0
const POP_RISE: float = 90.0
const POP_TIME: float = 0.25
const FLIGHT_TIME: float = 0.55
const ARC_HEIGHT: float = 160.0
const DROP_TIME: float = 0.1
const FLIGHT_SCALE: float = 1.0
const DROP_SCALE: float = 0.6
const SPIN_DEGREES: float = 540.0
## Yığın satır satır, alttan yukarı dolar.
const PILE_COLUMNS: Array[float] = [-28.0, -9.5, 9.5, 28.0]
const PILE_BOTTOM: float = -10.0
const PILE_ROW_HEIGHT: float = 8.5
const PILE_ROWS: int = 9
const PILE_JITTER: float = 4.0
## Parmakla para çekilebilen alan (kök noktasına göre).
const GRAB_AREA: Rect2 = Rect2(-70.0, -160.0, 140.0, 175.0)
## Yığının her açılışta aynı görünmesi için sabit tohum.
const PILE_SEED: int = 23
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.07
const SETTLE_TIME: float = 0.35
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var coin_texture: Texture2D
@export var coin_flat_texture: Texture2D
## Uçan paralar burada çizilir; tezgâhın ve müşterinin üstünde olmalı.
@export var flights: Node2D
@export_file("*.ogg", "*.wav") var clink_sound_path: String = "res://assets/audio/sfx/coin_clink.ogg"

## Henüz kumbaraya düşmemiş, ama Wallet'a geçmiş paralar.
var _in_flight: int = 0
## Parmakla çekilmiş, henüz etikete konmamış ya da geri dönmemiş paralar.
var _out: int = 0
var _clink_sound: AudioStream
var _pile: Array[Sprite2D] = []

@onready var _body: Node2D = $Body
@onready var _coins: Node2D = $Body/Coins


func _ready() -> void:
	if ResourceLoader.exists(clink_sound_path):
		_clink_sound = load(clink_sound_path) as AudioStream
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = PILE_SEED
	for row: int in PILE_ROWS:
		for column: float in PILE_COLUMNS:
			var coin: Sprite2D = Sprite2D.new()
			coin.texture = coin_flat_texture
			var shift: float = PILE_JITTER if row % 2 == 1 else 0.0
			coin.position = Vector2(column + shift + rng.randf_range(-PILE_JITTER, PILE_JITTER),
					PILE_BOTTOM - row * PILE_ROW_HEIGHT + rng.randf_range(-1.5, 1.5))
			coin.rotation = deg_to_rad(rng.randf_range(-8.0, 8.0))
			coin.hide()
			_coins.add_child(coin)
			_pile.append(coin)
	Wallet.changed.connect(func(_count: int) -> void: _refresh())
	_refresh()


func capacity() -> int:
	return _pile.size()


## amount kadar parayı hemen Wallet'a ekler; her biri ayrıca receive ile kumbaraya uçurulmalıdır.
func deposit(amount: int) -> void:
	_in_flight += amount
	Wallet.add(amount)


func contains(global_point: Vector2) -> bool:
	return GRAB_AREA.has_point(to_local(global_point))


## Kapaktaki delik (dünya konumu); çekilen para buradan çıkar, buraya döner.
func mouth() -> Vector2:
	return to_global(SLOT)


## Çekilebilecek para var mı (yoldakiler ve çekilmişler sayılmaz).
func has_coin() -> bool:
	return Wallet.count() - _in_flight - _out > 0


## Yığından bir para gizler; çekilecek para yoksa false döner.
func take_out() -> bool:
	if not has_coin():
		return false
	_out += 1
	_refresh()
	return true


## Çekilen para kumbaraya geri düştü.
func put_back() -> void:
	_out = maxi(_out - 1, 0)
	_squash()
	_refresh()


## Çekilen para harcandı (Wallet'tan zaten düştü).
func spend() -> void:
	_out = maxi(_out - 1, 0)
	_refresh()


## Dikkat çekmek için esner.
func bounce() -> void:
	_squash()


## deposit edilmiş bir para from_global'den (dünya konumu) havalanıp kumbaraya uçar.
func receive(from_global: Vector2) -> void:
	var coin: Sprite2D = Sprite2D.new()
	coin.texture = coin_texture
	flights.add_child(coin)
	coin.global_position = from_global
	coin.scale = Vector2.ZERO
	var start: Vector2 = coin.position + Vector2(0.0, -POP_RISE)
	var above: Vector2 = flights.to_local(to_global(SLOT + Vector2(0.0, -SLOT_ABOVE)))
	var end: Vector2 = flights.to_local(to_global(SLOT))
	var tween: Tween = create_tween().set_parallel()
	# Müşterinin elinden parlayarak havalanır...
	tween.tween_property(coin, ^"position", start, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(coin, ^"scale", Vector2.ONE * FLIGHT_SCALE, POP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	# ...dönerek kavisle deliğin üstüne uçar...
	tween.chain().tween_method(_fly.bind(coin, start, above), 0.0, 1.0, FLIGHT_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(coin, ^"rotation", deg_to_rad(SPIN_DEGREES), FLIGHT_TIME)
	# ...ve küçülüp içine düşer.
	tween.chain().tween_property(coin, ^"position", end, DROP_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(coin, ^"scale", Vector2.ONE * DROP_SCALE, DROP_TIME)
	tween.tween_property(coin, ^"modulate:a", 0.0, DROP_TIME)
	tween.chain().tween_callback(_land.bind(coin))


## İkinci dereceden Bezier: başlangıç ve varışın ortasının ARC_HEIGHT üstünden geçer.
func _fly(t: float, coin: Node2D, start: Vector2, end: Vector2) -> void:
	var control: Vector2 = (start + end) * 0.5 + Vector2(0.0, -ARC_HEIGHT)
	coin.position = start.lerp(control, t).lerp(control.lerp(end, t), t)


func _land(coin: Node2D) -> void:
	coin.queue_free()
	_in_flight = maxi(_in_flight - 1, 0)
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_clink_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.94, 1.08), pan)
	_squash()
	_refresh()
	coin_landed.emit()


func _squash() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	var shown: int = Wallet.count() - _in_flight - _out
	for i: int in _pile.size():
		_pile[i].visible = i < shown
