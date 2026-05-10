extends Camera2D

@export var zoom_min: float = 0.25
@export var zoom_max: float = 6.0
@export var zoom_step: float = 0.10
@export var pan_speed: float = 900.0

@export var map_node_path: NodePath = NodePath("../MapRoot/WorldMap")
@export var fit_map_height_in_view: bool = true

@export var drag_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var also_allow_middle_mouse: bool = true

var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	if fit_map_height_in_view:
		_apply_fit_zoom_min()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(1.0 + zoom_step, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(1.0 - zoom_step, mb.position)
		elif mb.button_index == drag_button or (also_allow_middle_mouse and mb.button_index == MOUSE_BUTTON_MIDDLE):
			_dragging = mb.pressed
			_last_mouse_pos = mb.position

	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		# Move camera opposite of mouse motion (pan)
		global_position -= mm.relative / zoom.x


func _process(delta: float) -> void:
	if fit_map_height_in_view:
		_apply_fit_zoom_min()

	var x: float = float(Input.get_axis("ui_left", "ui_right"))
	var y: float = float(Input.get_axis("ui_up", "ui_down"))
	var dir: Vector2 = Vector2(x, y)
	if dir.length_squared() > 0.0:
		global_position += dir.normalized() * pan_speed * delta / zoom.x


func _apply_zoom(multiplier: float, _screen_pos: Vector2) -> void:
	var old_zoom: float = zoom.x
	var target: float = clamp(old_zoom * multiplier, zoom_min, zoom_max)
	if is_equal_approx(target, old_zoom):
		return

	# Zoom towards cursor: keep the world point under cursor stable.
	var before := get_global_mouse_position()
	zoom = Vector2.ONE * target
	var after := get_global_mouse_position()
	global_position += (before - after)


func _apply_fit_zoom_min() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var map_node: Node = get_node_or_null(map_node_path)
	if map_node == null:
		return
	var ms: Variant = map_node.get("map_size")
	if typeof(ms) != TYPE_VECTOR2:
		return

	var map_h: float = float(ms.y)
	if map_h <= 0.0:
		return

	var screen_h: float = vp.get_visible_rect().size.y
	if screen_h <= 0.0:
		return

	# Visible world height = screen_h / zoom. To show exactly map_h, need zoom = screen_h / map_h.
	var fit: float = screen_h / map_h
	zoom_min = max(zoom_min, fit)
	if zoom.x < zoom_min:
		zoom = Vector2.ONE * zoom_min
