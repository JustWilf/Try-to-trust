extends CharacterBody2D


@export_enum("Left", "Right") var direction: int = 1
@export var speed: float = 100.0

@export_group("Camera limits")
@export var minus_x_limit: float = 0.0
@export var minus_y_limit: float = -300.0
@export var x_limit: float = 576.0
@export var y_limit: float = 254.0

@export_group("Gravity")
@export var gravity: float = 600.0
@export var max_fall_speed: float = 1000.0

@export_group("Movement")
@export var walking: bool = false
@export var jumping: bool = false
@export var running: bool = false
@export var dashing: bool = false
@export var sliding: bool = false
@export var dynamic_jump_height: bool = false
@export var double_jump: bool = false
@export var wall_jump: bool = false
@export var god_jump: bool = false

@export_group("Jumping", "jump_")
@export var jump_static_strength: float = 230.0
@export var jump_boost_strength: float = 8.0
@export var jump_boost_time_limit: float = 0.25
@export var jump_cayot_koef: float = 1.0
@export var jump_buffer_time: float = 0.07

@export_group("Dashing", "dash_")
@export var dash_strength: float = 250.0
@export var dash_max_time: float = 0.45
@export var dash_min_time: float = 0.25
@export var dash_coldown: float = 0.35

@export_group("Sliding", "slide_")
@export var slide_strength: float = 250.0
@export var slide_min_time: float = 0.3
@export var slide_max_time: float = 0.45
@export var slide_coldown: float = 1.5

@export_group("Wall Sliding", "wall_slide_")
@export var wall_slide_time: float = 0.6
@export var wall_slide_koef: float = 5.0
@export var wall_slide_auto_time: float = 0.3

@export_group("Wall Jumping", "wall_jump_")
@export_enum("Custom", "Vert", "Hor") var wall_jump_preset: int = 1
@export var wall_jump_static_vert_strength: float = 100.0
@export var wall_jump_static_hor_strength: float = 300.0
@export var wall_jump_boost_vert_strength: float = 1.2
@export var wall_jump_boost_hor_strength: float = 1.1
@export var wall_jump_time_limit: float = 0.4


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_stand: CollisionShape2D = $"CollisionShape2D-stand"
@onready var col_slide: CollisionShape2D = $"CollisionShape2D-slide"
@onready var camera: Camera2D = $Camera2D
@onready var ceiling_checker: Area2D = $Area2D

var move_koeff: float
var cayot_limit: float

var real_direction: float
var wall_jump_direction: float
var real_jump_boost_time: float
var real_dash_coldown: float
var real_slide_coldown: float

var can_dash: bool = false
var can_double_jump: bool = false
var can_wall_slide: bool = false

var jump_buffer_timer: float
var jump_timer: float
var cayot_timer: float
var dash_timer: float
var slide_timer: float
var wall_slide_timer: float
var wall_jump_timer: float
var wall_jump_end_timer: float

var not_dash_and_slide: bool
var is_jump_boosting: bool = false
var is_running: bool = false
var is_dashing: bool = false
var is_sliding: bool = false
var is_crouched: bool = false
var want_to_stand: bool = false
var is_wall_sliding: bool = false
var is_wall_jumping: bool = false
var wall_touching: bool = false
var wall_pressing: bool = false
var not_wall_slide_or_jump: bool = false
var was_jump_pressed_in_frame: bool = false

func _ready() -> void:
	_set_camera_limit(minus_x_limit, minus_y_limit, x_limit, y_limit)
	match wall_jump_preset:
		1:
			wall_jump_static_vert_strength = 100.0
			wall_jump_static_hor_strength = 300.0
			wall_jump_boost_vert_strength = 1.2
			wall_jump_boost_hor_strength = 1.1
			wall_jump_time_limit = 0.4
		2:
			wall_jump_static_vert_strength = 170.0
			wall_jump_static_hor_strength = 200.0
			wall_jump_boost_vert_strength = 1.15
			wall_jump_boost_hor_strength = 1.1
			wall_jump_time_limit = 0.35

func _physics_process(delta: float) -> void:
	_direction()
	_update_fields(delta)
	
	not_wall_slide_or_jump = not (is_wall_sliding or is_wall_jumping)
	if not (is_dashing or is_sliding) and not_wall_slide_or_jump:
		if walking:
			_walk_and_run()
		if jumping:
			_jumping(delta)
			if double_jump and wall_jump_end_timer <= 0.0:
				_double_jump()
	if not is_dashing and (not is_sliding or (is_sliding and not is_on_floor())) and wall_jump:
		_wall_jump(delta)
	if not is_sliding and not_wall_slide_or_jump and dashing:
		_dashing(delta)
	if not is_dashing and not is_wall_sliding:
		if sliding and not is_wall_jumping:
			_crouch_update()
			_sliding(delta)
		_gravity(delta)
	move_and_slide()
	
	_update_animation()

func _direction() -> void:
	direction = 0 if velocity.x > 0.0 else 1 if velocity.x < 0.0 else direction
	sprite.flip_h = direction
	col_stand.position.x = -0.5 if direction else 1.5
	col_slide.position.x = 5.5 if direction else -5.5
	ceiling_checker.position.x = -0.5 if direction else 1.5

func _update_fields(delta: float) -> void:
	real_jump_boost_time = jump_boost_time_limit / 1.5 if is_running else jump_boost_time_limit
	real_direction = -1.0 if direction else 1.0
	cayot_limit = (0.1 if is_running else 0.07) * jump_cayot_koef
	move_koeff = 1.0
	
	was_jump_pressed_in_frame = false
	is_jump_boosting = false
	is_running = false
	
	real_dash_coldown -= delta
	real_slide_coldown -= delta
	wall_jump_end_timer -= delta
	
	if is_on_floor():
		cayot_timer = 0.0
		can_dash = true
		can_double_jump = true
		can_wall_slide = true
	else:
		cayot_timer += delta
		jump_buffer_timer -= delta
	
	if not Input.get_axis("left", "right"):
		velocity.x = 0.0
	
	if is_dashing:
		dash_timer += delta
	else:
		dash_timer = 0.0
	
	if is_sliding:
		slide_timer += delta
	else:
		slide_timer = 0.0
	
	if is_wall_sliding:
		wall_slide_timer += delta
	else:
		wall_slide_timer = 0.0

func _walk_and_run() -> void:
	if Input.is_action_pressed("run") and running:
		is_running = true
		move_koeff = 1.5 if velocity.y <= 0.0 else 1.2
	
	velocity.x = speed * move_koeff * Input.get_axis("left", "right")

func _jumping(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	if cayot_timer <= cayot_limit and jump_buffer_timer >= 0.0:
		was_jump_pressed_in_frame = true
		cayot_timer += 1.0
		jump_buffer_timer -= 1.0
		jump_timer = 0.0
		velocity.y = -jump_static_strength
	elif Input.is_action_just_pressed("jump") and god_jump:
		velocity.y = -jump_static_strength + gravity*0.8 * delta
	
	elif Input.is_action_pressed("jump") and dynamic_jump_height and can_double_jump:
		jump_timer += delta
		if jump_timer >= 0.117 and jump_timer <= real_jump_boost_time and velocity.y < 0.0:
			is_jump_boosting = true
			velocity.y -= (1.0 - clamp(jump_timer / real_jump_boost_time, 0.0, 1.0)) * jump_boost_strength * gravity * delta
	
	elif Input.is_action_just_released("jump") and dynamic_jump_height and can_double_jump:
		if jump_timer >= 0.117 and velocity.y < 0.0:
			velocity.y *= 0.8
		jump_timer += 1.0

func _dashing(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and can_dash and real_dash_coldown <= 0.0:
		is_dashing = true
		can_dash = false
		real_dash_coldown = dash_coldown
		velocity.y = 0.0
		velocity.x = dash_strength * real_direction
	
	if is_dashing and ((dash_timer >= dash_max_time or (not Input.is_action_pressed("dash") and dash_timer >= dash_min_time)) or is_on_wall()):
		is_dashing = false

func _double_jump() -> void:
	if Input.is_action_just_pressed("jump") and can_double_jump and not was_jump_pressed_in_frame:
		jump_buffer_timer = jump_buffer_time
		can_double_jump = false
		velocity.y = -jump_static_strength

func _sliding(delta: float) -> void:
	if Input.is_action_just_pressed("slide") and is_on_floor() and is_running and velocity.x != 0.0 and not is_sliding and real_slide_coldown <= 0.0:
		is_sliding = true
		real_slide_coldown = slide_coldown
		_set_slide_col(true)
		velocity.x = slide_strength * real_direction
	
	want_to_stand = slide_timer >= slide_max_time or (not Input.is_action_pressed("slide") and slide_timer >= slide_min_time)
	if is_crouched and want_to_stand:
		velocity.x = slide_strength * real_direction
	if is_sliding and is_on_floor() and not is_crouched and want_to_stand:
		is_sliding = false
		_set_slide_col(false)

func _crouch_update() -> void:
	is_crouched = false
	if is_sliding:
		for body in ceiling_checker.get_overlapping_bodies():
			if body == self or is_ancestor_of(body):
				continue
			is_crouched = true
			break

func _wall_jump(delta: float) -> void:
	wall_touching = is_on_wall() and not is_on_floor()
	wall_pressing = ((get_wall_normal().x < 0.0 and Input.is_action_pressed("right")) or (get_wall_normal().x > 0.0 and Input.is_action_pressed("left")))
	if ((wall_pressing and velocity.y >= 0.0 and can_wall_slide) or wall_jump_end_timer > 0.0) and wall_touching and not is_wall_sliding:
		is_wall_sliding = true
		can_wall_slide = false
		wall_jump_end_timer = 0.0
		velocity.x = 0.0
		velocity.y = 0.0
	if is_wall_sliding:
		velocity.y = gravity * wall_slide_koef * delta
		if wall_slide_timer >= wall_slide_time or is_on_floor() or not is_on_wall():
			is_wall_sliding = false
		if Input.is_action_pressed("jump"):
			is_wall_sliding = false
			is_wall_jumping = true
			can_wall_slide = true
			wall_jump_direction = -real_direction
			velocity.x = wall_jump_static_vert_strength * wall_jump_direction
			velocity.y = -wall_jump_static_hor_strength
	if is_wall_jumping:
		if wall_jump_timer <= wall_jump_time_limit:
			velocity.x += wall_jump_boost_vert_strength * wall_jump_direction
			velocity.y -= wall_jump_boost_hor_strength
			wall_jump_timer += delta
		else:
			wall_jump_end_timer = wall_slide_auto_time
			is_wall_jumping = false
			wall_jump_timer = 0.0

func _gravity(delta: float) -> void:
	velocity.y += gravity * delta
	velocity.y = minf(velocity.y, max_fall_speed)

func _update_animation() -> void:
	if is_wall_jumping:
		sprite.play("wall_jump")
	elif is_wall_sliding:
		sprite.play("wall_slide")
	elif is_dashing:
		sprite.play("dash")
	elif is_sliding or is_crouched:
		sprite.play("slide")
	elif not is_on_floor():
		if velocity.y < 0.0:
			sprite.play("jump_boost" if is_jump_boosting else "jump_static")
		elif velocity.y != 0.0:
			sprite.play("fall")
	elif velocity.x != 0.0:
		sprite.play("run" if is_running else "walk")
	else:
		sprite.play("idle")

func _set_camera_limit(left: int, top: int, right: int, bottom: int) -> void:
	camera.limit_left = left
	camera.limit_top = top
	camera.limit_right = right
	camera.limit_bottom = bottom
	camera.reset_smoothing()

func _set_slide_col(enable: bool) -> void:
	col_slide.disabled = not enable
	col_stand.disabled = enable
