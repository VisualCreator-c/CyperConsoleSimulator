extends AnimatableBody3D # Теперь это AnimatableBody3D

var is_open = false

func interact():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if not is_open:
		# Поворачиваем САМ узел Hinge
		tween.tween_property(self, "rotation_degrees:y", 90, 0.6)
		is_open = true
	else:
		tween.tween_property(self, "rotation_degrees:y", 0, 0.6)
		is_open = false
