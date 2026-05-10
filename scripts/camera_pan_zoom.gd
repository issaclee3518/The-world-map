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

# Touch support (mobile/web)
var _touches: Dictionary = {} # id -> Vector2 (screen pos)
var _pinching: bool = false
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = 1.0
var _pinch_anchor_world: Vector2 = Vector2.ZERO


func _ready() -> void:
	if fit_map_height_in_view:
		_apply_fit_zoom_min()


func _unhandled_input(event: InputEvent) -> void:
	# Touch controls: 1-finger pan, 2-finger pinch zoom.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_update_pinch_state()
		return

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position

		# While pinching, recompute zoom from distance ratio.
		if _pinching and _touches.size() >= 2:
			var pair := _first_two_touches()
			var p0: Vector2 = pair[0]
			var p1: Vector2 = pair[1]
			var dist: float = p0.distance_to(p1)
			if _pinch_start_dist > 0.0 and dist > 0.0:
				var ratio: float = dist / _pinch_start_dist
				var target: float = clamp(_pinch_start_zoom / max(ratio, 0.001), zoom_min, zoom_max)
				_set_zoom_anchored(target, _pinch_anchor_world)
			return

		# 1-finger drag pan.
		if _touches.size() == 1:
			global_position -= sd.relative / zoom.x
			return

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


func _update_pinch_state() -> void:
	if _touches.size() >= 2:
		if not _pinching:
			_pinching = true
			var pair := _first_two_touches()
			var p0: Vector2 = pair[0]
			var p1: Vector2 = pair[1]
			_pinch_start_dist = max(p0.distance_to(p1), 0.001)
			_pinch_start_zoom = zoom.x
			# Anchor zoom at midpoint in world space.
			var mid: Vector2 = (p0 + p1) * 0.5
			_pinch_anchor_world = _screen_to_world(mid)
	else:
		_pinching = false
		_pinch_start_dist = 0.0


func _first_two_touches() -> Array[Vector2]:
	var keys: Array = _touches.keys()
	var p0: Vector2 = _touches[keys[0]]
	var p1: Vector2 = _touches[keys[1]]
	return [p0, p1]


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	# Camera2D: screen = (world - cam_pos) * zoom + viewport_center
	var vp := get_viewport()
	if vp == null:
		return global_position
	var center: Vector2 = vp.get_visible_rect().size * 0.5
	return global_position + (screen_pos - center) / zoom.x


func _set_zoom_anchored(target_zoom: float, anchor_world: Vector2) -> void:
	var before: Vector2 = anchor_world
	zoom = Vector2.ONE * target_zoom
	# Adjust camera so anchor stays under the same screen point.
	var after: Vector2 = anchor_world
	# Recompute global_position so that anchor_world maps to same screen point:
	# We can do it by measuring anchor's screen pos before/after, but anchor_world is constant.
	# Instead keep the current screen position of the anchor by shifting camera proportional to zoom change.
	# Derivation: (anchor - cam) * zoom is invariant => cam' = anchor - (anchor - cam) * (zoom_old/zoom_new)
	# Use zoom values scalar.
	var old_z: float = _pinch_start_zoom if _pinching else zoom.x
	var new_z: float = target_zoom
	if new_z <= 0.0:
		return
	global_position = before - (before - global_position) * (old_z / new_z)
