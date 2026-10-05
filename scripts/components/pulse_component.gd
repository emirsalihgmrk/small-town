class_name PulseComponent
extends Node
## Ebeveyn Node2D'nin ölçeğini kendi pivotu etrafında sonsuz, yumuşak bir "nefes" gibi büyütüp küçültür.
## Pivotu ebeveynin orijini belirler (ör. karakterde ayak noktası).

## Dinlenme ölçeğine eklenecek en büyük oran (0.02 = %2).
@export var scale_amount: Vector2 = Vector2(0.0, 0.02)
## Tam bir büyüme-küçülme döngüsünün süresi.
@export_range(0.1, 30.0, 0.1, "suffix:s") var period: float = 2.4
@export_range(0.0, 1.0, 0.01) var period_randomness: float = 0.0
@export var random_phase: bool = true


func _ready() -> void:
	var target: Node2D = get_parent() as Node2D
	if target == null:
		push_warning("PulseComponent bir Node2D'nin altında olmalı: %s" % get_path())
		return
	Oscillation.ping_pong(self, target, ^"scale", target.scale, target.scale * (Vector2.ONE + scale_amount),
			period, period_randomness, random_phase)
