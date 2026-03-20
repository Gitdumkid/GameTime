extends CharacterBody3D

# 1. PRELOADS
const GRASS_BLOCK = preload("res://GrassBlock.tscn")
const DIRT_BLOCK = preload("res://DirtBlock.tscn")

# 2. SETTINGS
const SPEED = 8.0
const JUMP_VELOCITY = 6.0
const SENSITIVITY = 0.003

# 3. VARIABLES
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_third_person = false
var inventory = [GRASS_BLOCK, DIRT_BLOCK]
var block_names = ["Grass Block", "Dirt Block"]
var selected_index = 0
var hand_block_instance = null

var mouse_delta := Vector2.ZERO

# 4. NODES
@onready var inventory_label = %InventoryLabel
@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D
@onready var selection_box = get_node("/root/World/SelectionBox")
@onready var viewport_container = $CanvasLayer/SubViewportContainer
@onready var hand_pivot = $SpringArm3D/Camera3D/HandPivot

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Disable all joypad input completely
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	set_character_visible(false)
	update_view_mode()
	spawn_hand_block()

func _on_joy_connection_changed(device, connected):
	pass  # ignore all joypad connections

func _process(_delta):
	pass

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Only read keyboard input — ignore any joypad values
	var move_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_dir.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_dir.x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_dir.z += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_dir.z -= 1

	var direction = (transform.basis * move_dir).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if mouse_delta != Vector2.ZERO:
		rotate_y(-mouse_delta.x * SENSITIVITY)
		spring_arm.rotate_x(-mouse_delta.y * SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		mouse_delta = Vector2.ZERO

	update_selection_box()
	move_and_slide()

func _input(event):
	# Block all joypad events
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		return

	if event.is_action_pressed("toggle_view"):
		is_third_person = !is_third_person
		update_view_mode()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			selected_index = 0
			spawn_hand_block()
			update_hand_visuals()
		if event.keycode == KEY_2:
			selected_index = 1
			spawn_hand_block()
			update_hand_visuals()

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_delta += event.relative

	if Input.is_action_just_pressed("ui_click") or Input.is_action_just_pressed("ui_right_click"):
		var result = get_raycast_result()
		if result:
			if Input.is_action_just_pressed("ui_click"): break_block(result.collider)
			if Input.is_action_just_pressed("ui_right_click"): place_block(result)

# --- HELPERS ---

func spawn_hand_block():
	if hand_block_instance:
		hand_block_instance.queue_free()
		hand_block_instance = null

	hand_block_instance = inventory[selected_index].instantiate()
	hand_pivot.add_child(hand_block_instance)
	hand_block_instance.position = Vector3(0.0, 0.0, 0.0)
	hand_block_instance.rotation_degrees = Vector3(25, -45, 0)
	hand_block_instance.scale = Vector3(0.15, 0.15, 0.15)

	for child in hand_block_instance.get_children():
		if child is StaticBody3D:
			child.queue_free()

func set_character_visible(show: bool):
	$mesh.visible = show
	$mesh2.visible = show
	$mesh3.visible = show
	$mesh4.visible = show
	$mesh5.visible = show
	$mesh6.visible = show
	$mesh7.visible = show
	$mesh8.visible = show
	$mesh9.visible = show
	$mesh10.visible = show
	$mesh11.visible = show
	$mesh12.visible = show

func update_view_mode():
	if is_third_person:
		spring_arm.spring_length = 2.0
		spring_arm.position = Vector3(0.8, 1.8, 0)
		viewport_container.visible = false
		set_character_visible(true)
		if hand_block_instance:
			hand_block_instance.visible = false
	else:
		spring_arm.spring_length = 0.0
		spring_arm.position = Vector3(0, 1.6, 0.0)
		viewport_container.visible = true
		set_character_visible(false)
		if hand_block_instance:
			hand_block_instance.visible = true

func update_hand_visuals():
	if inventory_label:
		inventory_label.text = "HOLDING: " + block_names[selected_index]

func place_block(result):
	var b = inventory[selected_index].instantiate()
	get_parent().add_child(b)
	var spawn_pos = result.position + (result.normal * 0.1)
	b.global_position = spawn_pos.floor() + Vector3(0.5, 0.5, 0.5)

func break_block(hit_node):
	if hit_node != self and hit_node.name != "Floor":
		var to_delete = hit_node
		while to_delete.get_parent() and to_delete.get_parent().name != "World":
			to_delete = to_delete.get_parent()
		to_delete.queue_free()

func get_raycast_result():
	var space_state = get_world_3d().direct_space_state
	var center = get_viewport().get_visible_rect().size / 2
	var origin = camera.project_ray_origin(center)
	var forward = camera.project_ray_normal(center)
	var query = PhysicsRayQueryParameters3D.create(origin + (forward * 1.2), origin + (forward * 8.0))
	query.exclude = [self.get_rid()]
	query.collision_mask = 1
	return space_state.intersect_ray(query)

func update_selection_box():
	var result = get_raycast_result()
	if result:
		selection_box.visible = true
		var target_pos = result.position - result.normal * 0.1
		selection_box.global_position = target_pos.floor() + Vector3(0.5, 0.5, 0.5)
	else:
		selection_box.visible = false
