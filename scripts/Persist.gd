# Autoload. Replaces the C# `static` best-time fields so they survive scene reloads (R key).
extends Node

var bestTime = 0.0
var bestCheckpointTimes = []

func _ready():
	for i in range(13):
		bestCheckpointTimes.append(0.0)
