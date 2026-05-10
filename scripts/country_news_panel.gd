extends Control

const API_PATH := "/news-summary"

const FONT_PATH: String = "res://assets/fonts/NotoSansKR-Regular.otf"

@export var api_base_url: String = "https://newssummerybackend-production.up.railway.app"
@export var world_map_path: NodePath = NodePath("../../MapRoot/WorldMap")

@onready var _title: Label = $NewsCard/Margin/VBox/Header/TitleLabel
@onready var _close: Button = $NewsCard/Margin/VBox/Header/CloseButton
@onready var _status: Label = $NewsCard/Margin/VBox/StatusLabel
@onready var _news_list: VBoxContainer = $NewsCard/Margin/VBox/Scroll/NewsList

var _http: HTTPRequest
var _font_ui: Font


func _ready() -> void:
	_font_ui = load(FONT_PATH) as Font
	if _font_ui != null:
		_title.add_theme_font_override("font", _font_ui)
		_close.add_theme_font_override("font", _font_ui)
		_status.add_theme_font_override("font", _font_ui)

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	_close.pressed.connect(_on_close_pressed)

	var wm: Node = get_node_or_null(world_map_path)
	if wm != null and wm.has_signal("country_selected"):
		wm.country_selected.connect(_on_country_selected)


func _on_close_pressed() -> void:
	visible = false


func _on_country_selected(country_name: String, iso_code: String) -> void:
	visible = true
	_title.text = country_name
	_clear_news()
	if iso_code.is_empty():
		_status.text = "국가 코드(ISO)를 알 수 없어 뉴스를 요청할 수 없습니다."
		return
	_status.text = "뉴스를 불러오는 중…"
	var url: String = "%s%s?country=%s" % [api_base_url, API_PATH, iso_code.uri_encode()]
	var err: Error = _http.request(url)
	if err != OK:
		_status.text = "요청을 시작할 수 없습니다 (%s)" % err


func _clear_news() -> void:
	for c in _news_list.get_children():
		c.queue_free()


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_status.text = "네트워크 오류입니다."
		return
	if response_code != 200:
		_status.text = "서버 오류 (HTTP %s)" % response_code
		return
	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		_status.text = "응답을 해석할 수 없습니다."
		return
	var items: Array = parsed
	if items.is_empty():
		_status.text = "표시할 뉴스가 없습니다."
		return
	_status.text = ""
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		_news_list.add_child(_make_news_block(d))


func _make_news_block(d: Dictionary) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)

	var title_l := Label.new()
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_l.text = str(d.get("title", ""))
	if _font_ui != null:
		title_l.add_theme_font_override("font", _font_ui)
	title_l.add_theme_font_size_override("font_size", 30)
	title_l.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))

	var sum_raw: Variant = d.get("summary", "")
	var sum_s: String = str(sum_raw) if sum_raw != null else ""
	if sum_s.is_empty() or sum_s == "요약 실패":
		sum_s = "(요약 없음)"

	var sum_l := Label.new()
	sum_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sum_l.text = sum_s
	if _font_ui != null:
		sum_l.add_theme_font_override("font", _font_ui)
	sum_l.add_theme_font_size_override("font_size", 28)
	sum_l.add_theme_color_override("font_color", Color(0.28, 0.32, 0.38))

	var src_l := Label.new()
	src_l.text = str(d.get("source", ""))
	if _font_ui != null:
		src_l.add_theme_font_override("font", _font_ui)
	src_l.add_theme_font_size_override("font_size", 24)
	src_l.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58))

	var sep := HSeparator.new()
	block.add_child(title_l)
	block.add_child(sum_l)
	block.add_child(src_l)
	block.add_child(sep)
	return block
