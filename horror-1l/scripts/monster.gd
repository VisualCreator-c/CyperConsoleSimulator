extends CharacterBody3D

@export_group("Настройки")
@export var detection_range: float = 5.0   # Дистанция
@export var disappear_delay: float = 0.5    # Задержка (1 сек)
@export var fade_duration: float = 1.0      # Время растворения

# Ссылки на узлы - берем их точно по твоему дереву сцены
@onready var visuals_container = $Visuals
@onready var notifier = $VisibleOnScreenNotifier3D
@onready var raycast = $RayCast3D
@onready var timer = $Timer

var mesh: MeshInstance3D # Ссылка на сам меш (найдем его в _ready)
var player_camera: Camera3D
var is_triggered: bool = false

func _ready() -> void:
	player_camera = get_viewport().get_camera_3d()
	
	# Автоматически ищем меш внутри Visuals, чтобы не было ошибки null
	_find_mesh_recursively(visuals_container)
	
	if mesh:
		# Делаем материал уникальным для эффекта прозрачности
		var mat = mesh.get_active_material(0)
		if mat:
			mesh.set_surface_override_material(0, mat.duplicate())
	else:
		print("ОШИБКА: Меш не найден в узле Visuals!")

	# Настройка таймера
	timer.wait_time = disappear_delay
	timer.one_shot = true
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

func _physics_process(_delta: float) -> void:
	if is_triggered or not player_camera or not mesh:
		return

	# 1. Проверка: На экране ли объект
	if not notifier.is_on_screen():
		return

	# 2. Проверка: Расстояние
	var dist = global_position.distance_to(player_camera.global_position)
	if dist > detection_range:
		return

	# 3. Проверка: Прямая видимость
	_check_line_of_sight()

func _check_line_of_sight() -> void:
	raycast.target_position = raycast.to_local(player_camera.global_position)
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		# Проверяем, что луч видит игрока (обычно это CharacterBody3D)
		if collider is CharacterBody3D and collider != self:
			if timer.is_stopped():
				timer.start()

func _on_timer_timeout() -> void:
	_start_fade_out()

func _start_fade_out() -> void:
	is_triggered = true
	var mat = mesh.get_surface_override_material(0)
	
	if mat:
		var tween = create_tween()
		# Плавно убираем прозрачность
		tween.tween_property(mat, "albedo_color:a", 0.0, fade_duration)
		await tween.finished
	
	hide()
	$CollisionShape3D.set_deferred("disabled", true)

# Функция для поиска меша внутри импортированной модели
func _find_mesh_recursively(node: Node):
	if node is MeshInstance3D:
		mesh = node
		return
	for child in node.get_children():
		_find_mesh_recursively(child)
		if mesh: return
