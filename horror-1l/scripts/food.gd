extends Area3D

func _ready():
	# Подключаем сигнал: когда кто-то входит в зону гриба
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("pick_up_item") and body.mushroom_count < 3:
		body.pick_up_item("mushroom")
		# Прячем гриб, но не удаляем
		hide()
		$CollisionShape3D.set_deferred("disabled", true)
		$Timer.start(20) # Вырастет через 30 секунд

func _on_timer_timeout(): # Подключи сигнал таймера
	show()
	$CollisionShape3D.disabled = false
