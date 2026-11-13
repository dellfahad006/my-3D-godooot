extends ImmediateGeometry

var lines = []

func add_line(p1, p2, color):
	lines.append([p1, p2, color])

func clear_lines():
	lines.clear()

func _process(_delta):
	clear()
	if lines.empty():
		return
	begin(Mesh.PRIMITIVE_LINES)
	for l in lines:
		set_color(l[2])
		add_vertex(to_local(l[0]))
		add_vertex(to_local(l[1]))
	end()
