extends CharacterBody3D

# --- Настройки персонажа ---
const SPEED = 2.0
const JUMP_VELOCITY = 2.5
const SENSITIVITY = 0.002

# --- Настройки физики предметов ---
const PUSH_FORCE = 0.5
const PULL_POWER = 20.0
const THROW_FORCE = 5.0
const ROTATION_POWER = 0.05
const MAX_DISTANCE = 2.5

# --- Ссылки на узлы ---
@onready var slots = [
	$CanvasLayer/InventoryUI/HBoxContainer/Slot0,
	$CanvasLayer/InventoryUI/HBoxContainer/Slot1,
	$CanvasLayer/InventoryUI/HBoxContainer/Slot2,
	$CanvasLayer/InventoryUI/HBoxContainer/Slot3
]
@onready var cigarette_model = $Head/Camera3D/Hand/CigaretteModel # Создай этот узел!
@onready var cigarette_particles = $Head/Camera3D/Hand/CigaretteModel/SmokeParticles
@onready var stick = $CSGBox3D
@onready var effect_rect = $EffectsLayer/ColorRect # Путь к твоему ColorRect
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var ray = $Head/InteractionRay
@onready var hand = $Head/HandPos
@onready var prompt_label = $CanvasLayer1/UI/Prompt

@onready var mushroom_in_hand = $Head/Camera3D/Hand/MushroomModel
@onready var flashlight = $Head/HandPos/Flashlight
# Вторичные источники света (если они есть в сцене)
@onready var flashlight_light = $CSGBox3D/Node3D/OmniLight3D
@onready var stick_light = $CSGBox3D/Node3D/CSGBox3D

# --- Состояния ---
# Инвентарь на 3 предмета (фонарик не считаем, он встроенный)
var inventory: Array = [null, null, null] 
var active_slot = 0 # 0 - фонарик, 1-3 - предметы
# --- В начало скрипта (новые переменные) ---
var mushroom_scene = preload("res://scens/food.tscn")
var cigarette_scene = preload("res://scens/sig.tscn")
const MAX_SLOTS = 3
var active_inventory_index = -1 # Какой предмет из инвентаря сейчас в руках (-1 — никакой)
var mushroom_count: int = 0
const MAX_MUSHROOMS = 3
var health: int = 100
var is_flashlight_on = false
var has_mushroom: bool = false
var current_item: int = 1 # 1 - Фонарик, 2 - Гриб

var held_object: RigidBody3D = null
var is_rotating_object = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	cigarette_particles.hide()
	
	# Инициализация света
	if flashlight: flashlight.light_energy = 0.0
	if flashlight_light: flashlight_light.light_energy = 0.0
	
	mushroom_in_hand.hide()
	_update_items()
	_update_ui()

func _unhandled_input(event):
	# Вращение камеры и предметов
	if event is InputEventMouseMotion:
		if is_rotating_object and held_object:
			rotate_held_object(event)
		else:
			rotate_camera(event)
	
	# Взаимодействие (Взять/Бросить)
	if event.is_action_pressed("interact"):
		if held_object: drop_object()
		else: pick_object()
		
	# Взаимодействие с миром (Двери)
	if event.is_action_pressed("interact_alt"):
		if ray.is_colliding():
			var target = ray.get_collider()
			if target.has_method("interact"):
				target.interact()



func _select_slot(index: int):
	active_slot = index
	_update_items()
	_update_ui()

# --- Логика подбора ---
func pick_up_item(item_name: String):
	for i in range(inventory.size()):
		if inventory[i] == null:
			inventory[i] = item_name
			_update_ui()
			return
	
# --- Обновление визуального состояния ---
func _update_ui():
	for i in range(4):
		if i == active_slot:
			slots[i].modulate = Color(0.708, 0.708, 0.708, 1.0) # Яркий
		else:
			slots[i].modulate = Color(0.447, 0.447, 0.447, 1.0) # Темный

		if i > 0:
			var icon = slots[i].get_node("TextureRect")
			# Безопасная проверка: берем предмет только если индекс существует
			var item = inventory[i-1] 
			
			if item == null:
				icon.texture = null
			else:
				if item == "mushroom": icon.texture = load("res://icons/mushroom.png")
				if item == "cigarette": icon.texture = load("res://icons/cig.png")
			
# --- Логика Сигареты ---
func _smoke_cigarette():
	var slot_idx = active_slot - 1
	if inventory[slot_idx] == "cigarette":
		
		# 1. Получаем ссылки
		var smoke = cigarette_model.get_node_or_null("SmokeParticles")
		
		# Если ты сделал Шаг 1 и 2, то этот узел теперь доступен!
		# Если не переименовывал, впиши сюда то имя, которое открылось через Editable Children
		var mesh_visuals = cigarette_model.get_node_or_null("Mesh") 
		
		# 2. Запускаем дым
		if smoke:
			smoke.emitting = true
			print("Дым пошел!")
		
		# 3. Прячем ТОЛЬКО визуальную часть
		if mesh_visuals:
			mesh_visuals.hide() # Прячем "тело", но "душа" (дым) остается!
		else:
			print("ОШИБКА: Не нашел узел Mesh внутри сигареты! Сделай Editable Children.")

		# 4. Убираем из инвентаря UI
		inventory[slot_idx] = null
		_update_ui()
		
		# 5. Ждем, пока дым рассеется
		await get_tree().create_timer(2.0).timeout
		
		# 6. Теперь убираем всё окончательно
		_update_items()
		
		# Возвращаем видимость мешу (чтобы следующая сигарета была видна)
		if mesh_visuals:
			mesh_visuals.show()
# --- Логика предметов ---

# --- Обновление предметов в руках ---
func _update_items():
# Прячем всё
	flashlight.hide()
	mushroom_in_hand.hide()
	cigarette_model.hide()
	_silence_flashlight()

	if active_slot == 0:
		flashlight.show()
		_apply_flashlight_state()
	else:
		var current_item = inventory[active_slot - 1]
		if current_item == "mushroom": mushroom_in_hand.show()
		if current_item == "cigarette": cigarette_model.show()
		
func _use_item():
	if active_slot == 0:
		toggle_flashlight_light() # Фонарик на ЛКМ
	else:
		var item = inventory[active_slot - 1]
		if item == "mushroom":
			_eat_mushroom()
			inventory[active_slot - 1] = null # Очищаем слот после еды
		elif item == "cigarette":
			_smoke_cigarette()
			
			inventory[active_slot - 1] = null
		_update_ui()
		_update_items()
			
# --- Выбрасывание предмета ---
func drop_item():
	if current_item == 2 and inventory.size() > 0:
		var item_to_drop = inventory[active_inventory_index]
		
		inventory.remove_at(active_inventory_index)
		active_inventory_index = -1 # Сбрасываем индекс
		_update_items()

# --- Логика поедания ---
func _eat_mushroom():
	mushroom_count -= 1
	
	add_health(25)
	# Тоже заменяем на null
	inventory[active_slot - 1] = null 
	_start_hallucinations()
	_update_items()
	_update_ui()
		
# --- Эффект гриба (Мышь остается рабочей!) ---
func _start_hallucinations():
	if not effect_rect: return
	
	effect_rect.show()
	var tween = create_tween()
	
	# Плавное появление (мышь при этом работает в обычном режиме)
	effect_rect.modulate.a = 0
	tween.tween_property(effect_rect, "modulate:a", 10.0, 10.5)
	tween.tween_interval(8.0) # Длительность эффекта
	tween.tween_property(effect_rect, "modulate:a", 0.0, 4.0)
	
	await tween.finished
	effect_rect.hide()
	
# --- Измененная логика ввода (кнопка 2) ---
func _input(event):
# Переключение на Фонарик
# Выбор слотов цифрами
	if event.is_action_pressed("slot_1"): _select_slot(0)
	if event.is_action_pressed("slot_2"): _select_slot(1)
	if event.is_action_pressed("slot_3"): _select_slot(2)
	if event.is_action_pressed("slot_4"): _select_slot(3)

	if event.is_action_pressed("attack"):
		_use_item()
		
	if event.is_action_pressed("drop_item"):
		drop_item()
	
func add_health(amount: int) -> void:
	health -= amount # Исправлено с -= на +=
	health = clamp(health, 0, 100)

func toggle_flashlight_light():
	is_flashlight_on = !is_flashlight_on
	_apply_flashlight_state()

func _apply_flashlight_state():
	var energy = 20.0 if is_flashlight_on else 0.0
	if flashlight: flashlight.light_energy = energy
	if flashlight_light: flashlight_light.light_energy = energy

func _silence_flashlight():
	if flashlight: flashlight.light_energy = 0.0
	if flashlight_light: flashlight_light.light_energy = 0.0

# --- Физика и Движение ---

func spawn_dropped_item(item_name):
	var item_instance
	if item_name == "mushroom": item_instance = mushroom_scene.instantiate()
	if item_name == "cigarette": item_instance = cigarette_scene.instantiate()
	
	if item_instance:
		get_parent().add_child(item_instance) # Добавляем на карту
		item_instance.global_position = hand.global_position # Появляется в руках
		# Можно добавить небольшой импульс, чтобы предмет отлетал

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * (2.0 if velocity.y < 0 else 1.0) * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("a", "d", "w", "s")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	handle_pushing()
	update_interaction_ui()
	
	if held_object:
		move_held_object(delta)
		is_rotating_object = Input.is_action_pressed("rotate_mode")

func handle_pushing():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D and collision.get_normal().y < 0.5:
			var push_dir = -collision.get_normal()
			push_dir.y = 0
			collider.apply_impulse(push_dir * SPEED * PUSH_FORCE, collision.get_position() - collider.global_position)

func update_interaction_ui():
	if not prompt_label: return
	if held_object:
		prompt_label.text = "[F] Бросить\n[R] Вращать"
		prompt_label.visible = true
		return

	if not ray.is_colliding():
		prompt_label.visible = false
		return

	var collider = ray.get_collider()
	if collider is RigidBody3D:
		prompt_label.text = "[F] Взять"
		prompt_label.visible = true
	elif collider.has_method("interact"):
		prompt_label.text = "[E] Использовать"
		prompt_label.visible = true
	else:
		prompt_label.visible = false

func pick_object():
	if ray.is_colliding():
		var collider = ray.get_collider()
		if collider is RigidBody3D:
			held_object = collider
			held_object.gravity_scale = 0.0
			held_object.linear_damp = 5.0
			held_object.angular_damp = 5.0

func drop_object():
	if held_object:
		held_object.gravity_scale = 1.0
		held_object.linear_damp = 0.0
		held_object.angular_damp = 0.0
		var throw_dir = -camera.global_transform.basis.z
		held_object.apply_central_impulse(throw_dir * THROW_FORCE)
		held_object = null

func move_held_object(delta):
	var target_pos = hand.global_position
	var object_pos = held_object.global_position
	var distance = object_pos.distance_to(target_pos)
	var velocity_diff = ((target_pos - object_pos) * PULL_POWER) - held_object.linear_velocity
	held_object.apply_central_impulse(velocity_diff * delta * 15.0)
	if distance > MAX_DISTANCE: drop_object()

func rotate_camera(event):
	rotate_y(-event.relative.x * SENSITIVITY)
	head.rotate_x(-event.relative.y * SENSITIVITY)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	
	var sensitivity_mod = 0.6
	
	# Если эффект активен (ColorRect виден), делаем управление "пьяным"
	if effect_rect and effect_rect.visible:
		sensitivity_mod = 0.5 + (sin(Time.get_ticks_msec() * 0.002) * 0.5)
		# Мышь будет то медленной, то быстрой
	
	rotate_y(-event.relative.x * SENSITIVITY * sensitivity_mod)
	head.rotate_x(-event.relative.y * SENSITIVITY * sensitivity_mod)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

func rotate_held_object(event):
	var x_axis = camera.global_transform.basis.x
	var y_axis = camera.global_transform.basis.y
	held_object.rotate(y_axis, event.relative.x * ROTATION_POWER)
	held_object.rotate(x_axis, event.relative.y * ROTATION_POWER)
