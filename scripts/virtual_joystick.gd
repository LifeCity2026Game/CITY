extends Control
## Touch and mouse virtual joystick for the on-foot character only.
signal vector_changed(value: Vector2)

@export var dead_zone: float = 0.12
var _pointer_id := -1
var _mouse_active := false
var _value := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _pointer_id == -1 and Rect2(Vector2.ZERO, size).has_point(event.position):
			_pointer_id = event.index
			_update_from_position(event.position)
			accept_event()
		elif not event.pressed and event.index == _pointer_id:
			_pointer_id = -1
			_set_value(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == _pointer_id:
		_update_from_position(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_active = event.pressed
		if _mouse_active:
			_update_from_position(event.position)
		else:
			_set_value(Vector2.ZERO)
		accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_from_position(event.position)
		accept_event()

func _update_from_position(point: Vector2) -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var offset := (point - center) / maxf(radius, 1.0)
	# Screen Y grows downward; invert it so dragging the stick upward means forward.
	offset.y = -offset.y
	_set_value(offset.limit_length(1.0))

func _set_value(value: Vector2) -> void:
	_value = Vector2.ZERO if value.length() < dead_zone else value
	vector_changed.emit(_value)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	draw_circle(center, radius + 8.0, Color(0.02, 0.04, 0.07, 0.45))
	draw_circle(center, radius, Color(0.18, 0.22, 0.28, 0.72))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.62, 0.78, 0.95, 0.9), 3.0, true)
	draw_circle(center + _value * radius * 0.72, radius * 0.36, Color(0.16, 0.48, 0.86, 0.94))
	draw_arc(center + _value * radius * 0.72, radius * 0.36, 0.0, TAU, 36, Color(0.78, 0.90, 1.0), 2.0, true)
