extends Node
class_name SupabaseAuth


signal auth_succeeded(user_id: String, username: String, access_token: String)
signal auth_failed(message: String)


# ============================================================
# SUPABASE CONFIG
# ============================================================



const BUCKET := "OpenSaberFiles"
const FOLDER := "TestFolder"


# ============================================================
# VARIABLES
# ============================================================

var http: HTTPRequest
var busy := false

var _pending_username := ""
var _pending_password := ""
var _phase := ""


# ============================================================
# SETUP
# ============================================================

func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.timeout = 30
	http.request_completed.connect(_on_request_completed)


# ============================================================
# PUBLIC AUTH FUNCTION
# ============================================================

func register_or_login(username: String, password: String) -> void:
	if busy:
		return

	var trimmed_name := username.strip_edges()

	if trimmed_name.length() < 2:
		auth_failed.emit("Player name must be at least 2 characters.")
		return

	if password.length() < 6:
		auth_failed.emit("Password must be at least 6 characters.")
		return

	if SUPABASE_URL.is_empty() or ANON_KEY.is_empty():
		auth_failed.emit("Supabase is not configured.")
		return

	_pending_username = trimmed_name
	_pending_password = password

	# Supabase Auth requires an email internally.
	# We generate a hidden internal email from the username.
	# The player never needs to enter an email.
	_signup()


# ============================================================
# USERNAME -> INTERNAL EMAIL
# ============================================================

func username_to_email(username: String) -> String:
	var trimmed := username.strip_edges().to_lower()

	var slug := ""

	for i in trimmed.length():
		var ch := trimmed.substr(i, 1)
		var code := ch.unicode_at(0)

		if (
			(code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
			or ch == "_"
			or ch == "."
			or ch == "-"
		):
			slug += ch

		elif ch == " ":
			slug += "_"

	if slug.is_empty():
		slug = "player"

	return "%s@opensaber.app" % slug


# ============================================================
# HTTP HEADERS
# ============================================================

func _auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % ANON_KEY,
		"Authorization: Bearer %s" % ANON_KEY,
		"Content-Type: application/json"
	])


# ============================================================
# SIGN UP
# ============================================================

func _signup() -> void:
	_phase = "signup"
	busy = true

	var payload := {
		"email": username_to_email(_pending_username),
		"password": _pending_password,
		"data": {
			"username": _pending_username,
			"display_name": _pending_username
		}
	}

	var url := "%s/auth/v1/signup" % SUPABASE_URL

	var err := http.request(
		url,
		_auth_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		busy = false
		_phase = ""
		auth_failed.emit("Could not start registration request.")


# ============================================================
# LOGIN
# ============================================================

func _login() -> void:
	_phase = "login"
	busy = true

	var payload := {
		"email": username_to_email(_pending_username),
		"password": _pending_password
	}

	var url := "%s/auth/v1/token?grant_type=password" % SUPABASE_URL

	var err := http.request(
		url,
		_auth_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		busy = false
		_phase = ""
		auth_failed.emit("Could not start login request.")


# ============================================================
# HTTP RESPONSE HANDLER
# ============================================================

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)

	var data: Dictionary = {}

	if parsed is Dictionary:
		data = parsed

	if _phase == "signup":
		_handle_signup_response(
			result,
			response_code,
			data,
			text
		)

	elif _phase == "login":
		_handle_login_response(
			result,
			response_code,
			data,
			text
		)

	else:
		busy = false


# ============================================================
# SIGNUP RESPONSE
# ============================================================

func _handle_signup_response(
	result: int,
	response_code: int,
	data: Dictionary,
	raw: String
) -> void:

	if result != HTTPRequest.RESULT_SUCCESS:
		busy = false
		_phase = ""
		auth_failed.emit("Network error during registration.")
		return

	# Username already exists.
	# Try logging in instead.
	if _is_existing_user_error(response_code, data):
		_login()
		return

	if response_code >= 200 and response_code < 300:

		var token := str(data.get("access_token", ""))

		var user: Dictionary = {}

		var received_user = data.get("user", {})

		if received_user is Dictionary:
			user = received_user

		# If Supabase returned no token, try logging in.
		if token.is_empty():
			_login()
			return

		_finish_success(user, token)
		return

	busy = false
	_phase = ""

	auth_failed.emit(
		_error_message(
			data,
			raw,
			"Registration failed."
		)
	)


# ============================================================
# LOGIN RESPONSE
# ============================================================

func _handle_login_response(
	result: int,
	response_code: int,
	data: Dictionary,
	raw: String
) -> void:

	busy = false
	_phase = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		auth_failed.emit("Network error during login.")
		return

	if response_code >= 200 and response_code < 300:

		var token := str(data.get("access_token", ""))

		var user: Dictionary = {}

		var received_user = data.get("user", {})

		if received_user is Dictionary:
			user = received_user

		if token.is_empty() or user.is_empty():
			auth_failed.emit(
				"Login succeeded but no user session was returned."
			)
			return

		_finish_success(user, token)
		return

	auth_failed.emit(
		_error_message(
			data,
			raw,
			"Login failed. Check the player name and password."
		)
	)


# ============================================================
# AUTH SUCCESS
# ============================================================

func _finish_success(
	user: Dictionary,
	access_token: String
) -> void:

	busy = false
	_phase = ""

	var user_id := str(user.get("id", ""))

	if user_id.is_empty():
		auth_failed.emit(
			"Supabase did not return a user id."
		)
		return

	var username := _pending_username

	var metadata_value = user.get("user_metadata", {})

	if metadata_value is Dictionary:

		var metadata: Dictionary = metadata_value

		username = str(
			metadata.get(
				"username",
				metadata.get(
					"display_name",
					_pending_username
				)
			)
		)

	if username.is_empty():
		username = _pending_username

	auth_succeeded.emit(
		user_id,
		username,
		access_token
	)


# ============================================================
# CHECK IF USER ALREADY EXISTS
# ============================================================

func _is_existing_user_error(
	response_code: int,
	data: Dictionary
) -> bool:

	if response_code == 422:
		return true

	var error_code := str(
		data.get("error_code", "")
	).to_lower()

	if error_code == "user_already_exists":
		return true

	var combined := "%s %s %s %s" % [
		str(data.get("msg", "")),
		str(data.get("message", "")),
		str(data.get("error_description", "")),
		str(data.get("error", ""))
	]

	return combined.to_lower().contains("already")


# ============================================================
# GET ERROR MESSAGE
# ============================================================

func _error_message(
	data: Dictionary,
	raw: String,
	fallback: String
) -> String:

	for key in [
		"msg",
		"message",
		"error_description",
		"error"
	]:

		var value := str(
			data.get(key, "")
		).strip_edges()

		if not value.is_empty() and value != "null":
			return value

	return fallback
