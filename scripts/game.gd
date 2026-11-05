extends Node3D
## Tector — a self-contained first playable mission. Distances are metres.
const SPEED = 7.0
const FIRE_INTERVAL = 0.075
var player: Node3D
var camera: Camera3D
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var obstacles: Array[AABB] = []
var health = 100.0
var ammo = 260
var weapon = false
var power = false
var alarm = false
var remaining = 100.0
var cooldown = 0.0
var spawn_timer = 5.0
var ended = false
var started = false
var paused = false
var kills = 0
var hud: Label
var objective: Label
var center: Label
var overlay: ColorRect
var audio: AudioStreamPlayer
var sounds: Dictionary = {}
var rng = RandomNumberGenerator.new()
var ship: Node3D
var reactor: Node3D
var alarm_lights: Array[OmniLight3D] = []
var elapsed = 0.0

func material(color: Color, glow = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow = 0.0) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color, glow)
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func orb(parent: Node3D, pos: Vector3, radius: float, color: Color, stretch = Vector3.ONE) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = pos
	mesh.scale = stretch
	return mesh

func lamp(pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light = OmniLight3D.new()
	add_child(light)
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	return light

func _ready():
	rng.seed = 19912026
	build_world()
	build_ui()
	build_audio()
	if "--smoke-test" in OS.get_cmdline_user_args():
		smoke_test.call_deferred()

func build_world():
	var env = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("10192c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8aa2c4")
	settings.ambient_light_energy = 0.55
	env.environment = settings
	add_child(env)
	var sun = DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("95a4cc")
	sun.light_energy = 0.8
	box(self, Vector3(0, -0.7, 0), Vector3(95, 1, 110), Color("382f3d"))
	for x in range(-4, 5):
		for z in range(-5, 6):
			box(self, Vector3(x * 5, -0.12, z * 5), Vector3(4.94, 0.24, 4.94), Color("263342") if (x + z) % 2 == 0 else Color("2b3948"))
	# Two partitions create a winding route: east passage, then west passage.
	wall(Vector3(-5, 1.3, 9), Vector3(35, 2.6, 1.4))
	wall(Vector3(6, 1.3, -9), Vector3(33, 2.6, 1.4))
	for x in [-23.0, 23.0]:
		wall(Vector3(x, 1.3, 0), Vector3(1.5, 2.6, 56))
	for z in [-28.0, 28.0]:
		wall(Vector3(0, 1.3, z), Vector3(47, 2.6, 1.5))
	for pos in [Vector3(-12, 0, 19), Vector3(4, 0, 17), Vector3(13, 0, 0), Vector3(-3, 0, -1), Vector3(-14, 0, -19)]:
		wall(pos + Vector3(0, 0.9, 0), Vector3(3, 1.8, 3))
		box(self, pos + Vector3(0, 1.85, 0), Vector3(2.8, 0.12, 2.8), Color("667c87"))
	for z in range(-24, 27, 6):
		for x in [-21, 21]:
			box(self, Vector3(x, 0.08, z), Vector3(0.2, 0.1, 2.5), Color("25d9dc"), 3)
			lamp(Vector3(x, 2, z), Color("36b7d7"), 1.5, 6)
	for z in [9, -9]:
		for x in [-15, 0, 15]:
			var light = lamp(Vector3(x, 3, z), Color("ff3b38"), 0, 10)
			alarm_lights.append(light)
	# Planet terrain and angular rock formations outside the base.
	for i in range(65):
		var x = rng.randf_range(-44, 44)
		var z = rng.randf_range(-48, 48)
		if abs(x) < 25 and abs(z) < 31:
			continue
		var rock = box(self, Vector3(x, 0, z), Vector3(rng.randf_range(1, 5), rng.randf_range(1, 7), 3), Color("5b465b"))
		rock.rotation_degrees = Vector3(12, rng.randf_range(0, 180), 15)
	player = Node3D.new()
	add_child(player)
	player.position = Vector3(-17, 0, 23)
	make_soldier(player)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 29
	camera.current = true
	update_camera(1.0)
	reactor = Node3D.new()
	add_child(reactor)
	reactor.position = Vector3(17, 0, 16)
	box(reactor, Vector3(0, 0.8, 0), Vector3(2.5, 1.6, 1.5), Color("152536"))
	box(reactor, Vector3(0, 1.7, 0), Vector3(2, 0.2, 1.2), Color("ffc85c"), 3)
	lamp(reactor.position + Vector3(0, 2, 0), Color("ffc85c"), 2, 7)
	ship = Node3D.new()
	add_child(ship)
	ship.position = Vector3(13, 0, -23)
	orb(ship, Vector3(0, 1.2, 0), 2, Color("bccad5"), Vector3(1, 0.6, 2))
	orb(ship, Vector3(0, 1.8, -1), 1, Color("1683a8"), Vector3(0.8, 0.5, 1.5))
	box(ship, Vector3(0, 0.7, 0), Vector3(8, 0.3, 2), Color("526c83"))
	for x in [-1.5, 1.5]:
		box(ship, Vector3(x, 0.7, 2.6), Vector3(0.9, 0.9, 2), Color("1c2838"))
		box(ship, Vector3(x, 0.7, 3.65), Vector3(0.7, 0.7, 0.1), Color("40bfff"), 4)
	for p in [Vector3(-7, 0, 22), Vector3(18, 0, 5), Vector3(-16, 0, -5), Vector3(4, 0, -19)]:
		add_pickup(p, "ammo")
	add_pickup(Vector3(10, 0, 15), "weapon")
	add_pickup(Vector3(-17, 0, 0), "health")
	add_pickup(Vector3(-15, 0, -15), "health")
	for p in [Vector3(12, 0, 21), Vector3(18, 0, -3), Vector3(2, 0, 3), Vector3(-15, 0, -3), Vector3(-17, 0, -18), Vector3(1, 0, -22), Vector3(17, 0, -17)]:
		spawn_enemy(p)

func wall(pos: Vector3, size: Vector3):
	box(self, pos, size, Color("435365"))
	box(self, pos + Vector3(0, size.y / 2, 0), Vector3(size.x, 0.1, size.z), Color("718896"))
	obstacles.append(AABB(pos - size / 2, size))

func make_soldier(root: Node3D):
	orb(root, Vector3(0, 0.95, 0), 0.5, Color("7098a7"), Vector3(1, 1.3, 0.75))
	orb(root, Vector3(0, 1.65, -0.05), 0.34, Color("b3c4ca"))
	box(root, Vector3(0, 1.65, -0.32), Vector3(0.45, 0.13, 0.1), Color("54f5e6"), 2)
	for x in [-0.32, 0.32]:
		box(root, Vector3(x, 0.35, 0), Vector3(0.3, 0.7, 0.4), Color("293b4b"))
		orb(root, Vector3(x * 1.65, 1.1, -0.1), 0.24, Color("98acb2"))
	box(root, Vector3(0.45, 1.05, -0.65), Vector3(0.22, 0.25, 1.2), Color("18232c"))
	box(root, Vector3(0.45, 1.05, -1.25), Vector3(0.15, 0.15, 0.15), Color("64e7ff"), 2)

func spawn_enemy(pos: Vector3):
	var root = Node3D.new()
	add_child(root)
	root.position = pos
	orb(root, Vector3(0, 0.65, 0), 0.7, Color("543955"), Vector3(1, 0.7, 1.3))
	orb(root, Vector3(0, 0.7, -0.7), 0.43, Color("867387"))
	for x in [-0.22, 0.22]:
		box(root, Vector3(x, 0.8, -1.05), Vector3(0.12, 0.1, 0.1), Color("ff644c"), 3)
	for side in [-1, 1]:
		for z in [-0.5, 0.1, 0.65]:
			var leg = box(root, Vector3(side * 0.7, 0.3, z), Vector3(0.8, 0.16, 0.17), Color("b7a39b"))
			leg.rotation.z = side * 0.5
	enemies.append({"node": root, "hp": 65.0, "phase": rng.randf() * TAU})

func add_pickup(pos: Vector3, kind: String):
	var root = Node3D.new()
	add_child(root)
	root.position = pos
	var color = Color("59eaa1") if kind == "health" else Color("f4bc59")
	if kind == "weapon":
		color = Color("bd8bff")
	box(root, Vector3(0, 0.55, 0), Vector3(0.8, 0.5, 0.65), color, 1.5)
	pickups.append({"node": root, "kind": kind})

func build_ui():
	var layer = CanvasLayer.new()
	add_child(layer)
	var top = ColorRect.new()
	top.color = Color(0.025, 0.045, 0.07, 0.92)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 106
	layer.add_child(top)
	hud = Label.new()
	hud.position = Vector2(30, 15)
	hud.add_theme_font_size_override("font_size", 25)
	top.add_child(hud)
	objective = Label.new()
	objective.position = Vector2(30, 57)
	objective.add_theme_color_override("font_color", Color("6ae2ed"))
	objective.add_theme_font_size_override("font_size", 20)
	top.add_child(objective)
	var radar = Control.new()
	radar.set_script(load("res://scripts/radar.gd"))
	radar.game = self
	radar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -240
	radar.offset_right = -24
	radar.offset_top = 128
	radar.offset_bottom = 376
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(radar)
	var controls = Label.new()
	controls.text = "WASD  Förflytta dig     MUS  Sikta     VÄNSTERKLICK  Eld     E  Interagera     ESC  Paus"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -40
	controls.offset_left = 30
	layer.add_child(controls)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.025, 0.045, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	center = Label.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center.add_theme_font_size_override("font_size", 27)
	center.text = "T E C T O R\n\nOPERATION: SISTA SKYTTELN\nKEPLER-186f / UTPOST 07\n\nBasen är förlorad. Du är kvar.\nStarta reservströmmen vid den gula terminalen.\nTa dig sedan till skytteln i basens norra del.\n\nWASD • Mus + vänsterklick • E för terminal och skepp\n\nTryck ENTER för att landa"
	layer.add_child(center)

func build_audio():
	audio = AudioStreamPlayer.new()
	add_child(audio)
	# Original stereo effects synthesized at 48 kHz, with smooth envelopes.
	for kind in ["shot", "ammo", "health", "weapon", "alarm", "hit"]:
		var duration = 0.18 if kind == "shot" else 0.65
		if kind == "alarm":
			duration = 1.2
		var frames = int(duration * 48000)
		var bytes = PackedByteArray()
		bytes.resize(frames * 4)
		for i in range(frames):
			var t = float(i) / 48000
			var fade = minf(t * 500, 1) * pow(1 - t / duration, 2)
			var value = 0.0
			match kind:
				"shot": value = (rng.randf_range(-1, 1) * exp(-t * 45) + sin(TAU * (105 * t - 55 * t * t)) * exp(-t * 25)) * 0.65
				"hit": value = rng.randf_range(-1, 1) * exp(-t * 15) * 0.45
				"alarm": value = sin(TAU * (600 * t - 160 * cos(t * TAU) / TAU)) * 0.22
				"ammo": value = (sin(TAU * 1800 * t) * exp(-fmod(t, 0.12) * 80) + rng.randf_range(-0.15, 0.15)) * 0.3
				"health": value = sin(TAU * (450 * t + 550 * t * t)) * 0.35
				"weapon": value = (sin(TAU * 110 * t) + sin(TAU * (550 * t + 400 * t * t))) * 0.23
			var sample = int(clampf(value * fade, -1, 1) * 32767)
			bytes.encode_s16(i * 4, sample)
			bytes.encode_s16(i * 4 + 2, int(sample * 0.94))
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 48000
		stream.stereo = true
		stream.data = bytes
		sounds[kind] = stream

func sound(kind: String):
	var voice = AudioStreamPlayer.new()
	add_child(voice)
	voice.stream = sounds[kind]
	voice.volume_db = -9 if kind == "shot" else -3
	voice.finished.connect(voice.queue_free)
	voice.play()

func blocked(pos: Vector3, radius = 0.5) -> bool:
	for bounds in obstacles:
		if pos.x > bounds.position.x - radius and pos.x < bounds.end.x + radius and pos.z > bounds.position.z - radius and pos.z < bounds.end.z + radius:
			return true
	return false

func move_actor(actor: Node3D, motion: Vector3):
	var next = actor.position + Vector3(motion.x, 0, 0)
	if not blocked(next): actor.position = next
	next = actor.position + Vector3(0, 0, motion.z)
	if not blocked(next): actor.position = next

func update_camera(delta: float):
	camera.position = camera.position.lerp(player.position + Vector3(0, 26, 19), minf(delta * 8, 1))
	camera.rotation_degrees = Vector3(-54, 0, 0)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and not started:
			started = true
			overlay.hide()
			center.hide()
		elif event.keycode == KEY_R and ended:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE and started and not ended:
			paused = not paused
			overlay.visible = paused
			center.visible = paused
			center.text = "PAUS\n\nESC för att fortsätta"
		elif event.keycode == KEY_E and started and not paused and not ended:
			interact()

func interact():
	if not power and player.position.distance_to(reactor.position) < 3.5:
		power = true
		alarm = true
		sound("alarm")
	elif power and player.position.distance_to(ship.position) < 4.5:
		finish(true)

func fire():
	if ammo <= 0: return
	ammo -= 1
	sound("shot")
	var direction = -player.global_transform.basis.z
	var node = box(self, player.position + Vector3(0, 1, 0) + direction, Vector3(0.1, 0.1, 0.8), Color("ffe8a2"), 4)
	node.rotation.y = player.rotation.y
	bullets.append({"node": node, "direction": direction, "life": 0.8})

func _process(delta):
	if not started or ended or paused: return
	delta = minf(delta, 0.05)
	elapsed += delta
	var direction = Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	move_actor(player, direction.normalized() * SPEED * delta)
	update_camera(delta)
	var mouse = get_viewport().get_mouse_position()
	var aim = Plane(Vector3.UP, 1).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if aim != null and player.position.distance_to(aim) > 0.1:
		player.look_at(Vector3(aim.x, 0, aim.z))
	cooldown -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and cooldown <= 0:
		fire()
		cooldown = FIRE_INTERVAL if weapon else 0.11
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		b.life -= delta
		var step = b.direction * 48 * delta / 4
		for substep in range(4):
			b.node.position += step
			if blocked(b.node.position, 0.05):
				b.life = 0
				break
			for enemy in enemies:
				if enemy.hp > 0 and b.node.position.distance_to(enemy.node.position + Vector3(0, 1, 0)) < 1.0:
					enemy.hp -= 34 if weapon else 24
					b.life = 0
					break
			if b.life <= 0: break
		if b.life <= 0:
			b.node.queue_free()
			bullets.remove_at(i)
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		if enemy.hp <= 0:
			kills += 1
			enemy.node.queue_free()
			enemies.remove_at(i)
			continue
		var offset = player.position - enemy.node.position
		if offset.length() < 19:
			# Route through the two partition openings before pursuing the player.
			var target = player.position
			for partition in [9.0, -9.0]:
				if (enemy.node.position.z - partition) * (player.position.z - partition) < 0:
					var opening = 18.5 if partition > 0 else -17.5
					if abs(enemy.node.position.x - opening) > 1.5:
						target = Vector3(opening, 0, enemy.node.position.z)
					else:
						target = Vector3(opening, 0, partition + signf(player.position.z - partition) * 3)
					break
			var movement = target - enemy.node.position
			if movement.length() > 0.1:
				enemy.node.look_at(enemy.node.position + movement)
				move_actor(enemy.node, movement.normalized() * (3.1 if alarm else 2.5) * delta)
			enemy.node.position.y = sin(elapsed * 12 + enemy.phase) * 0.06
		if offset.length() < 1.4:
			health -= 22 * delta
	for i in range(pickups.size() - 1, -1, -1):
		var item = pickups[i]
		item.node.rotation.y += delta
		if player.position.distance_to(item.node.position) < 1.4:
			if item.kind == "health" and health >= 100: continue
			match item.kind:
				"health": health = minf(100, health + 50)
				"ammo": ammo += 120
				"weapon":
					weapon = true
					ammo += 180
			sound(item.kind)
			item.node.queue_free()
			pickups.remove_at(i)
	if alarm:
		remaining -= delta
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_timer = 7
			if enemies.size() < 18: spawn_enemy(Vector3(18, 0, 4))
		for light in alarm_lights:
			light.light_energy = 2.0 if fmod(elapsed, 1) < 0.5 else 0.1
		if int(elapsed * 10) % 32 == 0 and not audio.playing:
			audio.stream = sounds.alarm
			audio.play()
	if health <= 0 or remaining <= 0: finish(false)
	hud.text = "TECTOR   /   UTPOST 07           LIV %03d     AMMO %03d     %s" % [maxi(0, int(health)), ammo, "STORMGEVÄR" if weapon else "KARBIN"]
	objective.text = "01 / Starta reservströmmen vid den GULA terminalen i sydost [E]" if not power else "02 / EVAKUERA  %02d:%02d   •   Nå skeppet i nordost och tryck E" % [int(remaining) / 60, int(remaining) % 60]
	if player.position.distance_to(reactor.position) < 3.5 and not power:
		objective.text = "[E] STARTA RESERVSTRÖM • Evakueringssekvensen startar direkt"
	elif player.position.distance_to(ship.position) < 4.5:
		objective.text = "[E] LYFT OCH FLY PLANETEN" if power else "Skeppet saknar ström. Aktivera den gula terminalen först."

func finish(won: bool):
	ended = true
	overlay.show()
	center.show()
	center.text = ("PLANETEN LÄMNAD\n\nDu nådde den sista skytteln.\nUtpost 07 är förlorad. Du överlevde.\n\n" if won else "SIGNALEN FÖRLORAD\n\n" + ("Evakueringstiden tog slut.\n\n" if remaining <= 0 else "Du föll i strid.\n\n")) + "Fiender besegrade: %d\n\nR för att spela igen" % kills

func _exit_tree():
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	sounds.clear()

func smoke_test():
	assert(enemies.size() == 7)
	assert(pickups.size() == 7)
	assert(not blocked(player.position))
	assert(blocked(Vector3(0, 0, 9)))
	# Walk the real collision route, rather than teleporting through partitions.
	for target in [Vector3(17, 0, 23), Vector3(17, 0, 16)]:
		test_walk(target)
	interact()
	assert(power and alarm)
	started = true
	var old_time = remaining
	_process(0.02)
	assert(remaining < old_time)
	# A projectile must damage a creature through the normal update loop.
	player.position = Vector3(17, 0, 16)
	player.rotation = Vector3.ZERO
	spawn_enemy(Vector3(17, 0, 12))
	var victim = enemies.back()
	var before = ammo
	fire()
	assert(ammo == before - 1 and bullets.size() == 1)
	for i in range(8):
		_process(0.016)
	assert(victim.hp < 65)
	# Pickups use the real proximity handling.
	health = 30
	player.position = Vector3(-17, 0, 0)
	_process(0.016)
	assert(health >= 79)
	player.position = Vector3(10, 0, 15)
	_process(0.016)
	assert(weapon)
	# Continue along both openings to the extraction area.
	player.position = Vector3(17, 0, 16)
	for target in [Vector3(19, 0, 16), Vector3(19, 0, 5), Vector3(18, 0, -5), Vector3(-18, 0, -5), Vector3(-18, 0, -13), Vector3(-8, 0, -13), Vector3(-8, 0, -23), Vector3(13, 0, -23)]:
		test_walk(target)
	interact()
	assert(ended and center.text.contains("PLANETEN LÄMNAD"))
	ended = false
	remaining = 0.001
	_process(0.02)
	assert(ended and center.text.contains("Evakueringstiden"))
	print("TECTOR SMOKE PASS: traversable mission, collision, projectile damage, pickups, reactor, countdown, escape and timeout")
	paused = true
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()

func test_walk(target: Vector3):
	for i in range(2000):
		var offset = target - player.position
		if offset.length() < 0.08:
			return
		move_actor(player, offset.normalized() * minf(0.07, offset.length()))
	assert(false, "Blocked mission route toward " + str(target))
