extends Camera

export(NodePath) var carPath

var car
var camPos = Vector3()
var carPos = Vector3()
var startSmoothing = 1.0
var raceSmoothing = 7.0
var height = 3.0
var distance = 6.0

func _ready():
	car = get_node(carPath)
	camPos = translation
	var cfg = ConfigFile.new()
	if cfg.load("res://config.ini") == OK:
		raceSmoothing = float(str(cfg.get_value("camera", "smoothing_rate", 7)))
		height = float(str(cfg.get_value("camera", "height", 3)))
		distance = float(str(cfg.get_value("camera", "distance", 6)))
	else:
		print("Couldn't load config.ini")

func _physics_process(dt):
	var z = car.transform.basis.z
	carPos = car.translation
	var target = carPos - z * distance
	target.y = carPos.y + height
	var smoothing = raceSmoothing if car.race_started() else startSmoothing
	camPos = camPos.linear_interpolate(target, dt * smoothing)

func _process(_dt):
	translation = camPos
	look_at(carPos, Vector3.UP)
