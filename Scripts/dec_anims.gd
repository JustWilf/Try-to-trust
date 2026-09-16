extends AnimatedSprite2D


@export var enable: bool = false

func _process(delta: float) -> void:
	if enable:
		play("default")
