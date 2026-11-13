extends RigidBody

const CHECKPOINT_NUM = 13

export(float) var raycastHeightOffset = 0.0
export(float) var springRate = 20.0
export(float) var dampRate = 2.0
export(float) var tractionEase = 2.0
export(float) var maxSpeedKmh = 60.0
export(float) var sidewaysTractionEase = 1.0
export(float) var maxTraction = 30.0
export(float) var tractionForceMult = 10.0
export(float) var sidewaysTractionMult = 1.0
export(NodePath) var engineAudioPath
export(NodePath) var timingPath
export(NodePath) var countdownPath
export(NodePath) var checkpointSoundPath
export(NodePath) var countdownSoundPath
export(NodePath) var finishSoundPath
export(Material) var material
export(NodePath) var bodyNode

var torqueMult = 10.0
var wheelBase = 1.05
var wheelTrack = 0.7
var countdown = 4.0
var sceneStartTime = 0.0

var line
var wheels = []
var wheelRoot
var checkpointSound
var countdownSound
var finishSound
var engineAudio
var timingText
var countdownText

var smoothThrottle = 0.0
var smoothSteer = 0.0
var speedPitch = 0.0
var prevYInput = 0.0
var checkpointPassed = -1
var stageEnded = false
var stageTime = 0.0
var lastCountdownTime = 0
var checkpointTimes = []
var prevBestCheckpointTimes = []

var red = Color(1, 0, 0, 1)
var blue = Color(0, 0, 1, 1)
var darkGreen = Color(0, 0.9, 0, 1)
var black = Color(0, 0, 0, 1)

var drawParticles = true
var drawLines = false
var debugSplits = false

func race_started():
	return stageTime > 0.0

func _ready():
	for i in range(CHECKPOINT_NUM):
		checkpointTimes.append(0.0)
		prevBestCheckpointTimes.append(0.0)
	var pts = [Vector3(-wheelTrack, 0, wheelBase), Vector3(wheelTrack, 0, wheelBase),
		Vector3(-wheelTrack, 0, -wheelBase), Vector3(wheelTrack, 0, -wheelBase)]
	var ids = ["fl", "fr", "rl", "rr"]
	for i in range(4):
		wheels.append({
			"point": pts[i],
			"graphical": get_node("car/RootNode/" + ids[i]),
			"dirt": get_node("dirt_" + ids[i]),
			"wasGrounded": false})
	line = get_node("wheel_debug")
	wheelRoot = wheels[0]["graphical"].get_parent()
	engineAudio = get_node(engineAudioPath)
	timingText = get_node(timingPath)
	countdownText = get_node(countdownPath)
	sceneStartTime = OS.get_ticks_msec() / 1000.0
	checkpointSound = get_node(checkpointSoundPath)
	countdownSound = get_node(countdownSoundPath)
	finishSound = get_node(finishSoundPath)
	get_node(bodyNode).material_override = material
	for w in wheels:
		w["dirt"].emitting = false

	var config = ConfigFile.new()
	if config.load("res://config.ini") == OK:
		springRate = float(str(config.get_value("setup", "spring_rate", 40)))
		dampRate = float(str(config.get_value("setup", "damp_rate", 3)))
		var vol = float(str(config.get_value("audio", "master_volume", 1)))
		AudioServer.set_bus_volume_db(0, log(vol) * 8.685)
		drawParticles = float(str(config.get_value("graphics", "draw_particles", 1))) != 0.0
		drawLines = float(str(config.get_value("debug", "lines", 0))) != 0.0
		debugSplits = float(str(config.get_value("debug", "splits", 0))) != 0.0
	else:
		print("Couldn't load config.ini")

func get_velocity_at_point(point):
	return linear_velocity + angular_velocity.cross(point - global_transform.origin)

func repeat(t, length):
	return clamp(t - floor(t / length) * length, 0.0, length)

func sat(v):
	return clamp(v, 0.0, 1.0)

func get_sector_time(splits, i):
	var prev = 0.0 if i == 0 else splits[i - 1]
	return splits[i] - prev

func _physics_process(dt):
	var now = OS.get_ticks_msec() / 1000.0
	if not stageEnded:
		stageTime = now - sceneStartTime - countdown
	var cd = int(-stageTime) + 1

	# ---- timing text ----
	timingText.clear()
	timingText.push_color(black)
	var t_str = "0.000" if stageTime < 0.0 else "%.3f" % stageTime
	var best_str = "--.---" if Persist.bestTime == 0.0 else "%.3f" % Persist.bestTime
	timingText.append_bbcode("Best: " + best_str + "\n")
	timingText.append_bbcode("Time: " + t_str + "\n")
	if checkpointPassed >= 0:
		var splits = prevBestCheckpointTimes if stageEnded else Persist.bestCheckpointTimes
		for i in range(checkpointPassed + 1):
			var s1 = get_sector_time(checkpointTimes, i)
			var s2 = get_sector_time(splits, i)
			if Persist.bestTime == 0.0 or s1 < s2:
				timingText.push_color(darkGreen)
			else:
				timingText.push_color(red)
			timingText.append_bbcode("#")
		var diff = get_sector_time(checkpointTimes, checkpointPassed) - get_sector_time(splits, checkpointPassed)
		var sign_str = "+" if diff > 0.0 else ""
		timingText.append_bbcode("\nSplit: " + sign_str + "%.3f" % diff)
	if stageEnded:
		timingText.push_color(black)
		timingText.append_bbcode("\nFinished! Press R to restart")

	if stageTime < 0.0:
		if cd != lastCountdownTime:
			countdownSound.play(0.0)
		lastCountdownTime = cd
		countdownText.text = str(cd)
	else:
		countdownText.text = ""

	# ---- input ----
	var steer = 0.0
	if Input.is_key_pressed(KEY_A):
		steer = -1.0
	elif Input.is_key_pressed(KEY_D):
		steer = 1.0
	var throttle = 0.0
	if Input.is_key_pressed(KEY_S):
		throttle = -1.0
	elif Input.is_key_pressed(KEY_W):
		throttle = 1.0
	smoothSteer = lerp(smoothSteer, steer, dt * 10.0)
	smoothThrottle = lerp(smoothThrottle, throttle, dt * 3.0)
	if stageTime < 0.0:
		throttle = 0.0

	# ---- suspension / wheels ----
	var speed = linear_velocity.length()
	var space = get_world().direct_space_state
	var up = transform.basis.y
	var fwd = transform.basis.z
	var right = transform.basis.x
	var side_speed = right.dot(linear_velocity)
	line.clear_lines()
	var grounded_count = 0
	var ray_len = 0.6
	var avg = Vector3.ZERO
	var idx = 0
	for w in wheels:
		var ray_from = to_global(w["point"]) + up * raycastHeightOffset
		var ray_to = ray_from - up * ray_len
		var hit = space.intersect_ray(ray_from, ray_to, [], 2147483647, true, false)
		var wheel_pos = ray_to
		var grounded = not hit.empty()
		if grounded:
			var hit_pos = hit["position"]
			var hit_normal = hit["normal"]
			if drawLines:
				line.add_line(ray_from, hit_pos, red)
			var compress = (ray_to - hit_pos).length()
			var spring = springRate * compress
			var pv = get_velocity_at_point(ray_from)
			var damp = -up.dot(pv) * dampRate
			add_force(hit_normal * (spring + damp), hit_pos - transform.origin)
			grounded_count += 1
			wheel_pos = hit_pos
			avg += hit_pos
		elif drawLines:
			line.add_line(ray_from, ray_to, blue)

		if drawParticles and (grounded != w["wasGrounded"] or prevYInput != throttle):
			w["dirt"].emitting = grounded and throttle > 0.0

		var side_off = 0.1 if idx % 2 == 0 else -0.1
		w["graphical"].translation = wheelRoot.to_local(wheel_pos + up * 0.3) + Vector3.RIGHT * side_off
		w["graphical"].rotation = Vector3(0.0, deg2rad(180.0) if idx % 2 == 0 else 0.0, 0.0)
		if idx < 2:
			w["graphical"].rotate(Vector3.UP, -smoothSteer * deg2rad(30.0))
		if drawParticles:
			var ps = -smoothSteer if idx < 2 else 0.0
			w["dirt"].rotation = Vector3(deg2rad(20.0), atan(-side_speed * 0.1 + ps), 0.0)
		w["wasGrounded"] = grounded
		idx += 1

	var dbg = translation + up * 1.1
	if drawLines:
		line.add_line(dbg, dbg + linear_velocity, Color(1, 1, 0, 1))
		line.add_line(dbg, dbg + right * side_speed, red)

	# ---- engine sound ----
	var fwd_speed = fwd.dot(linear_velocity)
	var phase = repeat(fwd_speed, 8.0) / 8.0
	speedPitch = lerp(speedPitch, speed * 0.1 * phase, dt * 10.0)
	engineAudio.pitch_scale = clamp(lerp(speedPitch, smoothThrottle * 3.0, 0.5), 0.3, 10.0)

	# ---- steering / drive / sideways grip ----
	if grounded_count > 0:
		var contact_frac = grounded_count / 4.0
		var cp = avg / float(grounded_count)
		if drawLines:
			line.add_line(cp, cp + up, red)
			line.add_line(cp, cp + Vector3.RIGHT, red)
			line.add_line(cp, cp + Vector3.FORWARD, red)
		var speed_fac = clamp(inverse_lerp(0.0, 5.0, speed), 0.0, 1.0)
		add_torque(-transform.basis.y * steer * torqueMult * speed_fac)
		var max_ms = maxSpeedKmh / 3.6
		var drive = 1.0 - ease(abs(fwd_speed) / max_ms, tractionEase)
		var drive_force = drive * throttle * tractionForceMult * contact_frac
		if drawLines:
			line.add_line(Vector3.ZERO, Vector3.UP * drive, red)
		var ss = abs(side_speed)
		var sgn = -1.0 if side_speed < 0.0 else 1.0
		var side = (sat(ss * 2.0) * sat(1.0 - ss / 20.0) * 10.0 + ease(abs(side_speed) / maxTraction, sidewaysTractionEase) * maxTraction) * sgn
		var side_force = -right * sidewaysTractionMult * side
		add_force(fwd * drive_force + side_force, cp - transform.origin)
	prevYInput = throttle

	if debugSplits:
		var s = ""
		for k in range(CHECKPOINT_NUM):
			s += str(checkpointTimes[k]) + ", " + str(Persist.bestCheckpointTimes[k]) + "\n"
		countdownText.text = s

func BodyEntered(body, i):
	if body == self:
		if checkpointPassed + 1 == i:
			_check(i)
		if checkpointPassed == 12 and i == 0:
			_end()

func _check(i):
	checkpointPassed = i
	checkpointSound.play(0.0)
	checkpointTimes[i] = stageTime

func _end():
	stageEnded = true
	finishSound.play(0.0)
	if Persist.bestTime == 0.0 or stageTime < Persist.bestTime:
		Persist.bestTime = stageTime
		for i in range(CHECKPOINT_NUM):
			prevBestCheckpointTimes[i] = Persist.bestCheckpointTimes[i]
			Persist.bestCheckpointTimes[i] = checkpointTimes[i]
