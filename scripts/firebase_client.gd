extends Node
## Firebase Authentication REST client. Profile/economy writes are intentionally not
## enabled here; those must be protected by server-side authorization rules.
signal auth_result(success: bool, message: String, user_id: String)

const AUTH_BASE := "https://identitytoolkit.googleapis.com/v1/accounts:"
var api_key := ""
var project_id := ""
var database_url := ""
var id_token := ""
var refresh_token := ""
var user_id := ""
var email := ""
var _request: HTTPRequest

func _ready() -> void:
	_request = HTTPRequest.new()
	_request.timeout = 20.0
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	_load_config()

func is_configured() -> bool:
	return not api_key.is_empty() and not project_id.is_empty()

func is_signed_in() -> bool:
	return not id_token.is_empty() and not user_id.is_empty()

func sign_up(address: String, password: String) -> void:
	_authenticate("signUp", address, password)

func sign_in(address: String, password: String) -> void:
	_authenticate("signInWithPassword", address, password)

func sign_out() -> void:
	id_token = ""
	refresh_token = ""
	user_id = ""
	email = ""
	auth_result.emit(true, "از حساب خارج شدی.", "")

func _authenticate(method: String, address: String, password: String) -> void:
	if not is_configured():
		auth_result.emit(false, "تنظیمات Firebase در این نسخه APK موجود نیست.", "")
		return
	if address.strip_edges().is_empty() or not address.contains("@"):
		auth_result.emit(false, "ایمیل معتبر وارد کن.", "")
		return
	if password.length() < 6:
		auth_result.emit(false, "رمز عبور باید حداقل ۶ نویسه باشد.", "")
		return
	var body := JSON.stringify({
		"email": address.strip_edges(),
		"password": password,
		"returnSecureToken": true
	})
	var url := AUTH_BASE + method + "?key=" + api_key.uri_encode()
	var error := _request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		auth_result.emit(false, "ارتباط با Firebase شروع نشد. کد خطا: %d" % error, "")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		auth_result.emit(false, "ارتباط اینترنتی با Firebase ناموفق بود.", "")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		auth_result.emit(false, "پاسخ Firebase قابل خواندن نیست.", "")
		return
	var data: Dictionary = parsed
	if response_code < 200 or response_code >= 300:
		var error_data: Dictionary = data.get("error", {})
		var reason := str(error_data.get("message", "UNKNOWN_ERROR"))
		auth_result.emit(false, _friendly_error(reason), "")
		return
	id_token = str(data.get("idToken", ""))
	refresh_token = str(data.get("refreshToken", ""))
	user_id = str(data.get("localId", ""))
	email = str(data.get("email", ""))
	auth_result.emit(true, "ورود موفق بود: " + email, user_id)

func _friendly_error(code: String) -> String:
	match code:
		"EMAIL_EXISTS": return "این ایمیل قبلاً ثبت شده است."
		"EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS": return "ایمیل یا رمز عبور اشتباه است."
		"WEAK_PASSWORD : Password should be at least 6 characters": return "رمز عبور باید حداقل ۶ نویسه باشد."
		"USER_DISABLED": return "این حساب غیرفعال شده است."
		"OPERATION_NOT_ALLOWED": return "ورود با ایمیل و رمز در Firebase فعال نیست."
		_: return "خطای Firebase: " + code

func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://firebase_config.cfg") != OK:
		return
	api_key = str(cfg.get_value("firebase", "api_key", ""))
	project_id = str(cfg.get_value("firebase", "project_id", ""))
	database_url = str(cfg.get_value("firebase", "database_url", ""))
