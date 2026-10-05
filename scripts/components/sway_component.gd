class_name SwayComponent
extends Node
## Ebeveyn Node2D'yi kendi pivotu etrafında sonsuz, yumuşak bir salınımla sağa sola döndürür
## (gövde sallanması, rüzgârdaki ağaç...). Pivotu ebeveynin orijini belirler.

@export_range(0.0, 30.0, 0.1, "suffix:°") var amplitude_degrees: float = 1.0
## Tam bir sağ-sol-sağ salınımının süresi.
@export_range(0.1, 30.0, 0.1, "suffix:s") var period: float = 3.0
## Süreye eklenen rastgele ±oran; aynı bileşeni taşıyan ögeler senkron görünmesin.
@export_range(0.0, 1.0, 0.01) var period_randomness: float = 0.0
## Açıksa salınım rastgele bir fazdan başlar.
@export var random_phase: bool = true


func _ready() -> void:
	var target: Node2D = get_parent() as Node2D
	if target == null:
		push_warning("SwayComponent bir Node2D'nin altında olmalı: %s" % get_path())
		return
	var amplitude: float = deg_to_rad(amplitude_degrees)
	Oscillation.ping_pong(self, target, ^"rotation", target.rotation - amplitude, target.rotation + amplitude,
			period, period_randomness, random_phase)
