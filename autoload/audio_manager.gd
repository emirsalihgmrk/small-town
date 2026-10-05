extends Node
## Global ses yöneticisi (autoload: AudioManager).
## - Müzik ve ortam döngüsü için tekil oynatıcılar: aynı ses tekrar istenirse yeniden başlamaz,
##   böylece sahneye dönüşte çift çalma olmaz.
## - Tek atımlık sesler için sabit boyutlu oynatıcı havuzu (pan destekli). Havuz doluysa ses atlanır.
## - Uygulama arka plana gidince / odak kaybolunca her şey duraklar, dönünce yumuşakça açılır.
## - Ses dosyası null ise (eksik dosya) çağrılar sessizce hiçbir şey yapmaz.

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_SFX: StringName = &"SFX"

const SILENT_DB: float = -60.0
const MIN_FADE_TIME: float = 0.01
const DEFAULT_MUSIC_FADE_IN: float = 2.0
const DEFAULT_AMBIENCE_FADE_IN: float = 1.0
const DEFAULT_FADE_OUT: float = 1.0
const RESUME_FADE_TIME: float = 1.0
const SFX_POOL_SIZE: int = 8
## Havuz oynatıcıları mesafeyle kısılmasın; pan yalnızca yatay konumdan gelsin.
const SFX_MAX_DISTANCE: float = 100000.0
const SFX_ATTENUATION: float = 0.0
const SFX_PANNING_STRENGTH: float = 1.0

var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _loop_fades: Dictionary[AudioStreamPlayer, Tween] = {}
var _sfx_pool: Array[AudioStreamPlayer2D] = []
var _suspended: bool = false
var _master_volume_db: float = 0.0
var _master_fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_master_volume_db = AudioServer.get_bus_volume_db(_bus_index(BUS_MASTER))
	_music = _make_loop_player(&"Music", BUS_MUSIC)
	_ambience = _make_loop_player(&"Ambience", BUS_AMBIENCE)
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "Sfx%d" % i
		player.max_distance = SFX_MAX_DISTANCE
		player.attenuation = SFX_ATTENUATION
		player.panning_strength = SFX_PANNING_STRENGTH
		add_child(player)
		_sfx_pool.append(player)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_suspend()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_resume()


# ------------------------------------------------------------------ müzik / ortam döngüsü

## Müziği döngüde çalar. Aynı müzik zaten çalıyorsa (ya da kapanıyorsa) yeniden başlatmaz, sesini geri açar.
func play_music(stream: AudioStream, volume_db: float = 0.0, fade_in: float = DEFAULT_MUSIC_FADE_IN) -> void:
	_play_loop(_music, stream, volume_db, fade_in)


func stop_music(fade_out: float = DEFAULT_FADE_OUT) -> void:
	_stop_loop(_music, fade_out)


## Ortam döngüsünü (rüzgâr vb.) çalar; davranışı play_music ile aynıdır.
func play_ambience(stream: AudioStream, volume_db: float = 0.0, fade_in: float = DEFAULT_AMBIENCE_FADE_IN) -> void:
	_play_loop(_ambience, stream, volume_db, fade_in)


func stop_ambience(fade_out: float = DEFAULT_FADE_OUT) -> void:
	_stop_loop(_ambience, fade_out)


# ------------------------------------------------------------------ tek atımlık sesler

## Havuzdan boş bir oynatıcıyla tek atımlık ses çalar.
## pan: -1 (sol) .. 1 (sağ). Uygulama duraklatılmışsa veya havuz doluysa ses atlanır.
func play_sfx(stream: AudioStream, bus: StringName = BUS_SFX, volume_db: float = 0.0,
		pitch_scale: float = 1.0, pan: float = 0.0) -> void:
	if stream == null or _suspended:
		return
	var player: AudioStreamPlayer2D = _free_sfx_player()
	if player == null:
		return
	var screen: Rect2 = get_viewport().get_visible_rect()
	player.position = screen.get_center() + Vector2(clampf(pan, -1.0, 1.0) * screen.size.x * 0.5, 0.0)
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


# ------------------------------------------------------------------ kanal aç/kapa

func set_music_enabled(enabled: bool) -> void:
	_set_bus_enabled(BUS_MUSIC, enabled)


func is_music_enabled() -> bool:
	return not AudioServer.is_bus_mute(_bus_index(BUS_MUSIC))


func set_ambience_enabled(enabled: bool) -> void:
	_set_bus_enabled(BUS_AMBIENCE, enabled)


func is_ambience_enabled() -> bool:
	return not AudioServer.is_bus_mute(_bus_index(BUS_AMBIENCE))


func set_sfx_enabled(enabled: bool) -> void:
	_set_bus_enabled(BUS_SFX, enabled)


func is_sfx_enabled() -> bool:
	return not AudioServer.is_bus_mute(_bus_index(BUS_SFX))


# ------------------------------------------------------------------ iç işler

func _make_loop_player(player_name: StringName, bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus
	player.volume_db = SILENT_DB
	add_child(player)
	return player


func _play_loop(player: AudioStreamPlayer, stream: AudioStream, volume_db: float, fade_in: float) -> void:
	if stream == null:
		return
	if player.playing and player.stream == stream:
		_fade(player, volume_db, fade_in)
		return
	_set_looping(stream)
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	player.stream_paused = _suspended
	_fade(player, volume_db, fade_in)


func _stop_loop(player: AudioStreamPlayer, fade_out: float) -> void:
	if not player.playing:
		return
	_fade(player, SILENT_DB, fade_out).tween_callback(player.stop)


func _fade(player: AudioStreamPlayer, target_db: float, duration: float) -> Tween:
	var running: Tween = _loop_fades.get(player)
	if running != null:
		running.kill()
	var tween: Tween = create_tween()
	tween.tween_property(player, ^"volume_db", target_db, maxf(duration, MIN_FADE_TIME))
	_loop_fades[player] = tween
	return tween


func _set_looping(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _free_sfx_player() -> AudioStreamPlayer2D:
	for player: AudioStreamPlayer2D in _sfx_pool:
		if not player.playing:
			return player
	return null


func _suspend() -> void:
	if _suspended:
		return
	_suspended = true
	if _master_fade != null:
		_master_fade.kill()
	AudioServer.set_bus_volume_db(_bus_index(BUS_MASTER), SILENT_DB)
	_set_all_paused(true)


func _resume() -> void:
	if not _suspended:
		return
	_suspended = false
	_set_all_paused(false)
	_master_fade = create_tween()
	_master_fade.tween_method(_set_master_volume, SILENT_DB, _master_volume_db, RESUME_FADE_TIME)


func _set_all_paused(paused: bool) -> void:
	_music.stream_paused = paused
	_ambience.stream_paused = paused
	for player: AudioStreamPlayer2D in _sfx_pool:
		player.stream_paused = paused


func _set_master_volume(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(_bus_index(BUS_MASTER), volume_db)


func _set_bus_enabled(bus: StringName, enabled: bool) -> void:
	var index: int = _bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, not enabled)


func _bus_index(bus: StringName) -> int:
	return AudioServer.get_bus_index(bus)
