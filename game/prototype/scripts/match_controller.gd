extends Node3D

const FIELD_WIDTH := 68.0
const FIELD_LENGTH := 105.0
const FIELD_HALF_WIDTH := FIELD_WIDTH * 0.5
const FIELD_HALF_LENGTH := FIELD_LENGTH * 0.5
const PLAYER_SPEED := 7.0
const PLAYER_SPRINT_SPEED := 10.0
const BALL_RADIUS := 0.24

var players: Array[CharacterBody3D] = []
var team_players: Array = [[], []]
var human_player: CharacterBody3D
var ball: RigidBody3D
var holder: CharacterBody3D
var broadcast_camera: Camera3D
var follow_camera: Camera3D
var hud: Label

var match_phase := "pregame"
var phase_before_pause := "first_half"
var half_length_minutes := 6
var half_elapsed_seconds := 0.0
var attack_sign := 1
var home_score := 0
var away_score := 0
var message := ""
var message_time := 0.0
var camera_mode := 0
var skill_push := Vector3.ZERO
var skill_time := 0.0
var action_cooldown := 0.0

func _ready() -> void:
	_create_pitch()
	_create_goals()
	_create_players()
	_create_ball()
	_create_cameras()
	_create_hud()
	_set_message("Press Enter to start · +/- changes half length")

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time = maxf(0.0, message_time - delta)
	if skill_time > 0.0:
		skill_time = maxf(0.0, skill_time - delta)
		if skill_time == 0.0:
			skill_push = Vector3.ZERO
	if action_cooldown > 0.0:
		action_cooldown = maxf(0.0, action_cooldown - delta)
	if match_phase == "first_half" or match_phase == "second_half":
		half_elapsed_seconds += delta
		if half_elapsed_seconds >= float(half_length_minutes * 60):
			if match_phase == "first_half":
				match_phase = "halftime"
				_set_message("Half-time · Press Enter for the second half")
			else:
				match_phase = "full_time"
				_set_message("Full-time · Press Enter to restart")
	_update_camera()
	_update_hud()

func _physics_process(delta: float) -> void:
	if match_phase != "first_half" and match_phase != "second_half":
		return
	_update_human(delta)
	_update_ai(delta)
	_resolve_possession()
	_attach_ball()
	_check_goal_or_out()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event.physical_keycode
	if key == KEY_C:
		camera_mode = 1 - camera_mode
		return
	if key == KEY_ESCAPE:
		_toggle_pause()
		return
	if match_phase == "pregame":
		if key == KEY_EQUAL or key == KEY_KP_ADD:
			half_length_minutes = mini(20, half_length_minutes + 1)
		elif key == KEY_MINUS or key == KEY_KP_SUBTRACT:
			half_length_minutes = maxi(1, half_length_minutes - 1)
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			_start_match()
		return
	if match_phase == "halftime":
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			_start_second_half()
		return
	if match_phase == "full_time":
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			_reset_match()
		return
	if match_phase == "paused":
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			match_phase = phase_before_pause
		return
	if match_phase != "first_half" and match_phase != "second_half":
		return
	_handle_match_action(key)

func _create_pitch() -> void:
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	add_child(ground_body)
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(FIELD_WIDTH, 0.5, FIELD_LENGTH)
	ground_shape.shape = ground_box
	ground_body.add_child(ground_shape)
	ground_body.position.y = -0.25
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FIELD_WIDTH, FIELD_LENGTH)
	ground_mesh.mesh = plane
	ground_mesh.material_override = _material(Color(0.12, 0.34, 0.19))
	add_child(ground_mesh)
	var line_material := _material(Color(0.82, 0.9, 0.79))
	_add_line(Vector3(-FIELD_HALF_WIDTH, 0.035, -FIELD_HALF_LENGTH), Vector3(FIELD_HALF_WIDTH, 0.035, -FIELD_HALF_LENGTH), 0.12, line_material)
	_add_line(Vector3(-FIELD_HALF_WIDTH, 0.035, FIELD_HALF_LENGTH), Vector3(FIELD_HALF_WIDTH, 0.035, FIELD_HALF_LENGTH), 0.12, line_material)
	_add_line(Vector3(-FIELD_HALF_WIDTH, 0.035, 0), Vector3(FIELD_HALF_WIDTH, 0.035, 0), 0.10, line_material)
	_add_line(Vector3(-FIELD_HALF_WIDTH, 0.035, -FIELD_HALF_LENGTH), Vector3(-FIELD_HALF_WIDTH, 0.035, FIELD_HALF_LENGTH), 0.12, line_material)
	_add_line(Vector3(FIELD_HALF_WIDTH, 0.035, -FIELD_HALF_LENGTH), Vector3(FIELD_HALF_WIDTH, 0.035, FIELD_HALF_LENGTH), 0.12, line_material)
	_add_box(Vector3(0, 0.035, 0), Vector3(18.3, 0.04, 0.14), line_material)
	_add_box(Vector3(0, 0.035, -FIELD_HALF_LENGTH + 16.5), Vector3(40.3, 0.04, 0.14), line_material)
	_add_box(Vector3(0, 0.035, FIELD_HALF_LENGTH - 16.5), Vector3(40.3, 0.04, 0.14), line_material)
	_add_box(Vector3(-20.1, 0.035, -FIELD_HALF_LENGTH + 8.25), Vector3(0.14, 0.04, 16.5), line_material)
	_add_box(Vector3(20.1, 0.035, -FIELD_HALF_LENGTH + 8.25), Vector3(0.14, 0.04, 16.5), line_material)
	_add_box(Vector3(-20.1, 0.035, FIELD_HALF_LENGTH - 8.25), Vector3(0.14, 0.04, 16.5), line_material)
	_add_box(Vector3(20.1, 0.035, FIELD_HALF_LENGTH - 8.25), Vector3(0.14, 0.04, 16.5), line_material)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -24, 0)
	sun.light_energy = 1.0
	add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.07, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.72, 0.68)
	env.ambient_light_energy = 0.55
	environment.environment = env
	add_child(environment)

func _create_goals() -> void:
	var goal_material := _material(Color(0.9, 0.94, 0.88))
	for sign in [-1, 1]:
		var z := float(sign) * (FIELD_HALF_LENGTH + 0.2)
		_add_box(Vector3(-3.66, 1.22, z), Vector3(0.16, 2.44, 0.16), goal_material)
		_add_box(Vector3(3.66, 1.22, z), Vector3(0.16, 2.44, 0.16), goal_material)
		_add_box(Vector3(0, 2.44, z), Vector3(7.32, 0.16, 0.16), goal_material)

func _create_players() -> void:
	var blue := _material(Color(0.12, 0.42, 0.92))
	var red := _material(Color(0.88, 0.2, 0.16))
	var home_positions: Array[Vector2] = [
		Vector2(0, -49), Vector2(-22, -31), Vector2(-7, -34), Vector2(7, -34), Vector2(22, -31),
		Vector2(-20, -13), Vector2(-7, -16), Vector2(7, -16), Vector2(20, -13),
		Vector2(-9, 7), Vector2(9, 7)
	]
	for i in range(home_positions.size()):
		var p := home_positions[i]
		var is_keeper := i == 0
		var home_player := _create_player(0, i, Vector3(p.x, 0.92, p.y), blue, i == 9, is_keeper)
		team_players[0].append(home_player)
		players.append(home_player)
		var away_player := _create_player(1, i, Vector3(-p.x, 0.92, -p.y), red, false, is_keeper)
		team_players[1].append(away_player)
		players.append(away_player)
		human_player = home_player if i == 9 else human_player

func _create_player(team: int, shirt_number: int, spawn: Vector3, material: Material, is_human: bool, is_keeper: bool) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = ("Blue" if team == 0 else "Red") + "Player" + str(shirt_number + 1)
	body.position = spawn
	body.set_meta("start_position", spawn)
	body.set_meta("team", team)
	body.set_meta("shirt_number", shirt_number + 1)
	body.set_meta("is_keeper", is_keeper)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38 if not is_keeper else 0.43
	shape.height = 1.8
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38 if not is_keeper else 0.43
	capsule.height = 1.8
	mesh.mesh = capsule
	mesh.material_override = material
	body.add_child(mesh)
	var marker := MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.58
	marker_mesh.bottom_radius = 0.58
	marker_mesh.height = 0.06
	marker.mesh = marker_mesh
	marker.material_override = _material(Color(0.95, 0.9, 0.28))
	marker.position.y = -0.83
	marker.visible = is_human
	body.add_child(marker)
	add_child(body)
	return body

func _create_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "Football"
	ball.mass = 0.43
	ball.linear_damp = 0.55
	ball.angular_damp = 0.8
	ball.position = Vector3(0, BALL_RADIUS + 0.04, 0)
	var shape_node := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BALL_RADIUS
	shape_node.shape = sphere_shape
	ball.add_child(shape_node)
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = BALL_RADIUS
	sphere_mesh.height = BALL_RADIUS * 2.0
	mesh.mesh = sphere_mesh
	mesh.material_override = _material(Color(0.94, 0.94, 0.86))
	ball.add_child(mesh)
	add_child(ball)

func _create_cameras() -> void:
	broadcast_camera = Camera3D.new()
	broadcast_camera.name = "BroadcastCamera"
	broadcast_camera.position = Vector3(0, 74, -27)
	broadcast_camera.current = true
	broadcast_camera.fov = 48
	add_child(broadcast_camera)
	broadcast_camera.look_at(Vector3.ZERO, Vector3.UP)
	follow_camera = Camera3D.new()
	follow_camera.name = "PlayerFollowCamera"
	follow_camera.fov = 62
	follow_camera.current = false
	add_child(follow_camera)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 14)
	hud.size = Vector2(1240, 200)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_color", Color(0.96, 0.98, 0.94))
	hud.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.02, 0.9))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)

func _update_human(delta: float) -> void:
	var input_x := 0.0
	var input_forward := 0.0
	if Input.is_physical_key_pressed(KEY_A): input_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input_x += 1.0
	if Input.is_physical_key_pressed(KEY_W): input_forward += 1.0
	if Input.is_physical_key_pressed(KEY_S): input_forward -= 1.0
	var direction := _relative_direction(input_x, input_forward, 0)
	var speed := PLAYER_SPRINT_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else PLAYER_SPEED
	if Input.is_physical_key_pressed(KEY_Q): speed *= 0.58
	if skill_time > 0.0:
		direction += skill_push
	if direction.length() > 1.0:
		direction = direction.normalized()
	human_player.velocity.x = direction.x * speed
	human_player.velocity.z = direction.z * speed
	human_player.velocity.y = 0.0
	human_player.move_and_slide()
	_human_ball_action(delta)

func _human_ball_action(_delta: float) -> void:
	if holder == human_player and Input.is_physical_key_pressed(KEY_SHIFT):
		# Sprinting keeps the touch slightly farther ahead than close control.
		pass

func _update_ai(delta: float) -> void:
	for p in players:
		if p == human_player:
			continue
		var team := int(p.get_meta("team"))
		var dir_sign := _team_attack_sign(team)
		var target := p.global_position
		var speed := 5.0
		if p == holder:
			var goal := Vector3(0, 0.92, dir_sign * (FIELD_HALF_LENGTH - 2.0))
			var to_goal := goal - p.global_position
			to_goal.y = 0.0
			if to_goal.length() < 24.0 and action_cooldown == 0.0:
				_shoot_from(p, dir_sign)
				action_cooldown = 1.0
			else:
				target = p.global_position + Vector3(0, 0, dir_sign * 12.0)
				speed = 5.4
		elif holder != null:
			if int(holder.get_meta("team")) != team:
				var opponent_distance := p.global_position.distance_to(holder.global_position)
				if opponent_distance < 20.0:
					target = holder.global_position
					speed = 5.8
				else:
					target = _home_position_for(p)
			else:
				var lane := float(int(p.get_meta("shirt_number")) % 3 - 1) * 9.0
				target = holder.global_position + Vector3(lane, 0, dir_sign * 12.0)
		else:
			var closest := _closest_player_to_ball(team)
			if p == closest:
				target = ball.global_position
				speed = 5.8
			else:
				target = _home_position_for(p)
		_move_ai_player(p, target, speed, delta)

func _move_ai_player(p: CharacterBody3D, target: Vector3, speed: float, delta: float) -> void:
	var move := target - p.global_position
	move.y = 0.0
	if move.length() > 0.55:
		move = move.normalized()
		p.velocity.x = move.x * speed
		p.velocity.z = move.z * speed
	else:
		p.velocity.x = move_toward(p.velocity.x, 0.0, speed * delta * 4.0)
		p.velocity.z = move_toward(p.velocity.z, 0.0, speed * delta * 4.0)
	p.velocity.y = 0.0
	p.move_and_slide()

func _handle_match_action(key: Key) -> void:
	if key == KEY_J:
		_pass_ball(0)
	elif key == KEY_K:
		_pass_ball(1)
	elif key == KEY_I:
		_pass_ball(2)
	elif key == KEY_L:
		if Input.is_physical_key_pressed(KEY_F):
			_fake_shot()
		else:
			_shoot_from(human_player, _team_attack_sign(0))
	elif key == KEY_E:
		_tackle()
	elif key == KEY_SPACE:
		_head_ball()
	elif key == KEY_A and Input.is_physical_key_pressed(KEY_F):
		_do_skill(-1.0, 0.0)
	elif key == KEY_D and Input.is_physical_key_pressed(KEY_F):
		_do_skill(1.0, 0.0)
	elif key == KEY_W and Input.is_physical_key_pressed(KEY_F):
		_do_skill(0.0, 1.0)
	elif key == KEY_S and Input.is_physical_key_pressed(KEY_F):
		_do_skill(0.0, -1.0)

func _pass_ball(pass_type: int) -> void:
	if holder != human_player or action_cooldown > 0.0:
		return
	var target := _choose_receiver(pass_type)
	var attack := _team_attack_sign(0)
	var aim := Vector3(0.0, 0.0, float(attack))
	if target != null:
		aim = target.global_position - ball.global_position
		if pass_type == 1:
			aim += Vector3(0, 0, float(attack) * 7.0)
		elif pass_type == 2:
			aim += Vector3(0, 0, float(attack) * 3.0)
	if aim.length() < 0.01:
		return
	var power := 13.0 if pass_type == 0 else (19.0 if pass_type == 1 else 24.0)
	_release_ball(aim.normalized() * power + Vector3.UP * (1.8 if pass_type == 2 else 0.25))
	_set_message("Pass")
	action_cooldown = 0.28

func _choose_receiver(pass_type: int) -> CharacterBody3D:
	var best: CharacterBody3D
	var best_score := INF
	var attack := _team_attack_sign(0)
	for teammate in team_players[0]:
		if teammate == human_player:
			continue
		var delta := teammate.global_position - human_player.global_position
		var forward := delta.z * float(attack)
		if pass_type == 1 and forward < 2.0:
			continue
		var distance := delta.length()
		var score := distance
		if pass_type == 0 and distance > 24.0:
			score += 100.0
		elif pass_type == 2:
			score -= minf(forward, 30.0) * 0.2
		if score < best_score:
			best_score = score
			best = teammate
	return best

func _shoot_from(shooter: CharacterBody3D, direction_sign: int) -> void:
	if holder != shooter or action_cooldown > 0.0:
		return
	var goal := Vector3(0, 1.25, float(direction_sign) * (FIELD_HALF_LENGTH + 2.0))
	var aim := goal - ball.global_position
	_release_ball(aim.normalized() * 26.0 + Vector3.UP * 3.5)
	_set_message("Shot")
	action_cooldown = 0.45

func _fake_shot() -> void:
	if holder != human_player or action_cooldown > 0.0:
		return
	var side := _relative_direction(1.0, 0.0, 0)
	var push := side * 2.0 + Vector3(0, 0, float(_team_attack_sign(0)) * 1.0)
	_release_ball(push)
	_set_message("Fake shot")
	action_cooldown = 0.55

func _do_skill(side_input: float, forward_input: float) -> void:
	if holder != human_player or action_cooldown > 0.0:
		return
	var direction := _relative_direction(side_input, forward_input, 0).normalized()
	skill_push = direction * 7.0
	skill_time = 0.22
	var ball_target := human_player.global_position + direction * 1.35 + Vector3(0, -0.55, 0)
	ball.global_position = ball_target
	_set_message("Dribble move")
	action_cooldown = 0.35

func _tackle() -> void:
	if holder == null or int(holder.get_meta("team")) == 0 or action_cooldown > 0.0:
		return
	if human_player.global_position.distance_to(holder.global_position) <= 2.7:
		_set_holder(human_player)
		_set_message("Tackle won")
	else:
		_set_message("Move closer to tackle")
	action_cooldown = 0.55

func _head_ball() -> void:
	if ball.global_position.y < 0.85 or human_player.global_position.distance_to(ball.global_position) > 2.7:
		return
	var goal := Vector3(0, 1.8, float(_team_attack_sign(0)) * (FIELD_HALF_LENGTH + 2.0))
	var aim := goal - ball.global_position
	_set_holder(null)
	ball.linear_velocity = aim.normalized() * 16.0 + Vector3.UP * 2.0
	_set_message("Header")

func _release_ball(velocity: Vector3) -> void:
	_set_holder(null)
	ball.global_position.y = maxf(ball.global_position.y, BALL_RADIUS + 0.12)
	ball.linear_velocity = velocity
	ball.angular_velocity = Vector3(0, 5.0, 0)

func _set_holder(new_holder) -> void:
	holder = new_holder
	ball.freeze = holder != null
	if holder != null:
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO

func _attach_ball() -> void:
	if holder == null:
		return
	var team := int(holder.get_meta("team"))
	var attack := _team_attack_sign(team)
	var offset := Vector3(0, -0.55, float(attack) * (1.05 if holder == human_player and Input.is_physical_key_pressed(KEY_SHIFT) else 0.72))
	ball.global_position = holder.global_position + offset

func _resolve_possession() -> void:
	if holder != null:
		var opponents: Array = team_players[1] if int(holder.get_meta("team")) == 0 else team_players[0]
		for opponent in opponents:
			if opponent.global_position.distance_to(ball.global_position) < 0.82:
				_set_holder(opponent)
				return
		return
	if ball.global_position.y > 1.2:
		return
	var nearest: CharacterBody3D
	var nearest_distance := 1.45
	for p in players:
		var distance := p.global_position.distance_to(ball.global_position)
		if distance < nearest_distance:
			nearest = p
			nearest_distance = distance
	if nearest != null:
		_set_holder(nearest)

func _check_goal_or_out() -> void:
	var z := ball.global_position.z
	if absf(ball.global_position.x) < 3.66 and absf(ball.global_position.y) < 2.45:
		if z > FIELD_HALF_LENGTH:
			_register_goal(0 if attack_sign > 0 else 1)
		elif z < -FIELD_HALF_LENGTH:
			_register_goal(1 if attack_sign > 0 else 0)
	elif absf(z) > FIELD_HALF_LENGTH or absf(ball.global_position.x) > FIELD_HALF_WIDTH:
		_reset_ball_to_center()

func _register_goal(scoring_team: int) -> void:
	if scoring_team == 0:
		home_score += 1
	else:
		away_score += 1
	_set_message("GOAL · Blue" if scoring_team == 0 else "GOAL · Red")
	_reset_ball_to_center()

func _reset_ball_to_center() -> void:
	_set_holder(null)
	ball.global_position = Vector3(0, BALL_RADIUS + 0.05, 0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

func _start_match() -> void:
	home_score = 0
	away_score = 0
	attack_sign = 1
	half_elapsed_seconds = 0.0
	_reset_ball_to_center()
	match_phase = "first_half"
	_set_message("Kick-off")

func _start_second_half() -> void:
	attack_sign = -1
	half_elapsed_seconds = 0.0
	for p in players:
		p.global_position = _home_position_for(p)
		p.velocity = Vector3.ZERO
	_reset_ball_to_center()
	match_phase = "second_half"
	_set_message("Second half")

func _reset_match() -> void:
	for i in range(team_players[0].size()):
		var p: CharacterBody3D = team_players[0][i]
		var a := p.get_meta("start_position")
		p.global_position = a
		var opponent: CharacterBody3D = team_players[1][i]
		opponent.global_position = opponent.get_meta("start_position")
	_start_match()
	_set_message("Kick-off")

func _toggle_pause() -> void:
	if match_phase == "first_half" or match_phase == "second_half":
		phase_before_pause = match_phase
		match_phase = "paused"
		_set_message("Paused · Esc to continue")
	elif match_phase == "paused":
		match_phase = phase_before_pause
		_set_message("Play")

func _relative_direction(side_input: float, forward_input: float, team: int) -> Vector3:
	var sign := _team_attack_sign(team)
	var right := Vector3(float(sign), 0, 0)
	var forward := Vector3(0, 0, float(sign))
	return right * side_input + forward * forward_input

func _team_attack_sign(team: int) -> int:
	return attack_sign if team == 0 else -attack_sign

func _home_position_for(p: CharacterBody3D) -> Vector3:
	var initial: Vector3 = p.get_meta("start_position")
	return Vector3(initial.x * float(attack_sign), 0.92, initial.z * float(attack_sign))

func _closest_player_to_ball(team: int) -> CharacterBody3D:
	var nearest: CharacterBody3D
	var distance := INF
	for p in team_players[team]:
		var d := p.global_position.distance_to(ball.global_position)
		if d < distance:
			distance = d
			nearest = p
	return nearest

func _update_camera() -> void:
	broadcast_camera.current = camera_mode == 0
	follow_camera.current = camera_mode == 1
	if camera_mode == 1 and human_player != null:
		var sign := _team_attack_sign(0)
		follow_camera.global_position = human_player.global_position + Vector3(0, 8.0, -float(sign) * 11.0)
		follow_camera.look_at(human_player.global_position + Vector3(0, 1.2, float(sign) * 5.0), Vector3.UP)

func _update_hud() -> void:
	var phase_label := "PRE-MATCH"
	var clock := "00:00"
	if match_phase == "first_half" or match_phase == "second_half" or match_phase == "paused":
		var current_half := phase_before_pause if match_phase == "paused" else match_phase
		phase_label = "1ST HALF" if current_half == "first_half" else "2ND HALF"
		var minutes := int(minf(45.0, half_elapsed_seconds / float(half_length_minutes * 60) * 45.0))
		clock = "%02d:00" % minutes
	elif match_phase == "halftime":
		phase_label = "HALF-TIME"
		clock = "45:00"
	elif match_phase == "full_time":
		phase_label = "FULL-TIME"
		clock = "90:00"
	elif match_phase == "pregame":
		phase_label = "PRE-MATCH · %d MIN / HALF" % half_length_minutes
	var controls := "WASD Move · Shift Sprint · Q Close Control · J Pass · K Through · I Lofted · L Shoot · C Camera · Esc Pause"
	if match_phase == "pregame":
		controls += "\n+/- Set match length (1–20 min per half) · Enter Kick-off"
	elif match_phase == "halftime":
		controls = "Enter to start second half"
	elif match_phase == "full_time":
		controls = "Enter to play again"
	elif match_phase == "paused":
		controls = "Paused · Enter or Esc to continue"
	else:
		controls += "\nF + WASD Dribble move · F+L Fake shot · Space Header · E Tackle"
	var status := message if message_time > 0.0 else controls
	hud.text = "%s     BLUE  %d  -  %d  RED     %s\n%s" % [phase_label, home_score, away_score, clock, status]

func _set_message(text: String) -> void:
	message = text
	message_time = 2.6

func _add_line(start: Vector3, finish: Vector3, thickness: float, material: Material) -> void:
	var middle := (start + finish) * 0.5
	var size := finish - start
	var box_size := Vector3(maxf(absf(size.x), thickness), 0.035, maxf(absf(size.z), thickness))
	_add_box(middle, box_size, material)

func _add_box(at: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = at
	add_child(mesh_instance)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result
