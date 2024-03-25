extends CharacterBody3D




@export var X_SENS = 0.1
@export var Y_SENS = 0.1
@export var SPEED = 7
@export var ACCEL = 40
@export var AIR_ACCEL = 10
@export var DECEL = 60
@export var AIR_DECEL = 0
@export var JUMP_VELOCITY = 20
@export var MIN_JUMP = 10
@export var U_GRAVITY = 50
@export var D_GRAVITY = 50
@export var TURN_SPEED = 60
@export var AIR_CONTROL = 75

# Get the gravity from the project settings to be synced with RigidBody nodes.
var input_dir = Vector2.ZERO
var look_dir = Vector2.ZERO
var my_velocity = Vector2.ZERO

var prev_grounded = false
var target_length = 5

var delta_y = 0

@onready var base = $CamBase
@onready var mount = $CamBase/cam_mount
@onready var cam = $CamBase/cam_mount/Camera3D
@onready var tree = $AnimationTree
@onready var state = tree.get("parameters/playback")
@onready var c_timer = $CoyoteTimer
@onready var b_timer = $BufferTimer
@onready var menu = preload("res://menu.tscn")
@onready var sprite = $Sprite3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion:
		base.rotate_y(-deg_to_rad(event.relative.x * X_SENS))
		mount.rotate_x(-deg_to_rad(event.relative.y * Y_SENS))
		mount.rotation.x = clamp(mount.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					target_length = max(target_length - 1, 0)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_length = min(target_length + 1, 10)
	
	if Input.is_action_just_pressed("menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var menu_instance = menu.instantiate()
		add_child(menu_instance)
		get_tree().paused = true

func _physics_process(delta):
	mount.spring_length = lerp(mount.spring_length, float(target_length), 0.5)
	
	var was_grounded = is_on_floor()
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	input_dir = Input.get_vector("strafe_left", "strafe_right", "walk_forward", "walk_backward")
	#var direction = (transform.basis * Vector2(input_dir.x, input_dir.y)).normalized()
	#var direction = Vector2(transform.basis.x, transform.basis.z)
	var direction = transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized()
	var vec2_direction = Vector2(direction.x, direction.z)
	
	var accel = ACCEL
	var decel = DECEL
	var dir_switch = TURN_SPEED
	if not is_on_floor():
		accel = AIR_ACCEL
		decel = AIR_DECEL
		dir_switch = TURN_SPEED
		
	if direction:
		
		look_dir = input_dir.rotated(deg_to_rad(-90))
		look_dir.y = -look_dir.y
		global_rotation.y = base.global_rotation.y
		base.global_rotation.y = global_rotation.y
		
		var move_type = accel
		if sign(my_velocity.x) != sign(input_dir.x) or sign(my_velocity.y) != sign(input_dir.y):
			move_type = dir_switch
		my_velocity = my_velocity.move_toward(vec2_direction * SPEED, move_type * delta)
		state.travel("Run")
	else:
		my_velocity = my_velocity.move_toward(Vector2.ZERO, decel * delta)
		state.travel("Idle")
	
	# Add the gravity.
	var grav = D_GRAVITY
	if velocity.y > 0:
		grav = U_GRAVITY
	
	if not is_on_floor():
		velocity.y -= grav * delta
		state.travel("Jump")
		
		#sprite.scale.y = abs(velocity.y) - delta_y * delta
		#print(sprite.scale.y)
	
	if velocity.y > 0:
		c_timer.stop()
	
	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		b_timer.start()
	
	if Input.is_action_just_released("jump") && velocity.y > MIN_JUMP:
		velocity.y = MIN_JUMP
	
	if not b_timer.is_stopped() and (is_on_floor() or not c_timer.is_stopped()):
		jump()
	
	if prev_grounded and not is_on_floor():
		c_timer.start()
	
	velocity.x = my_velocity.x
	velocity.z = my_velocity.y
	
	move_and_slide()
	prev_grounded = is_on_floor() != was_grounded
	
	var player_angle = global_position.direction_to(cam.global_position)
	var angle_2d = Vector2(player_angle.x, player_angle.z)
	var final_angle = angle_2d.rotated(global_rotation.y + look_dir.angle())
	tree.set("parameters/Idle/blend_position", final_angle)
	tree.set("parameters/Run/blend_position", final_angle)
	tree.set("parameters/Jump/blend_position", final_angle)
	delta_y = velocity.y

func jump():
	velocity.y = JUMP_VELOCITY
