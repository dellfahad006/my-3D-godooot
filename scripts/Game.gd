extends Node

export(NodePath) var hoodCameraPath
export(NodePath) var wingmanCameraPath

var hoodCamera
var wingmanCamera
var hoodCameraIsActive = false

func _ready():
	wingmanCamera = get_node(wingmanCameraPath)
	hoodCamera = get_node(hoodCameraPath)
	# The restored track.glb carries its collider in a glTF physics extension that
	# Godot 3.3 ignores, so build the collider from the road mesh here.
	var road_mat = load("res://track/dirtroad.material")
	_setup_track(get_node("../track"), road_mat)

func _setup_track(n, road_mat):
	for c in n.get_children():
		if c is MeshInstance:
			c.create_trimesh_collision()
			if road_mat != null:
				c.material_override = road_mat
		_setup_track(c, road_mat)

func _input(e):
	if e is InputEventKey and e.pressed:
		if e.scancode == KEY_R:
			get_tree().reload_current_scene()
		elif e.scancode == KEY_C:
			hoodCameraIsActive = not hoodCameraIsActive
			if hoodCameraIsActive:
				hoodCamera.make_current()
			else:
				wingmanCamera.make_current()
