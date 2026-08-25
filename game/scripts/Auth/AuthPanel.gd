extends Panel
class_name AuthPanel

signal credentials_submitted(username: String, password: String)
signal input_field_changed(field: String)

const REMEMBERED_FILE := "user://auth_usernames.json"
const MAX_REMEMBERED := 8

enum Field { USERNAME, PASSWORD }

var _username := ""
var _password := ""
var _active_field: Field = Field.USERNAME
var _busy := false

@onready var _status := $Margin/VBox/StatusLabel as Label
@onready var _username_value := $Margin/VBox/UsernameRow/UsernameValue as Label
@onready var _password_value := $Margin/VBox/PasswordRow/PasswordValue as Label
@onready var _username_button := $Margin/VBox/UsernameRow/UsernameButton as Button
@onready var _password_button := $Margin/VBox/PasswordRow/PasswordButton as Button
@onready var _continue_button := $Margin/VBox/ContinueButton as Button
@onready var _name_row := $Margin/VBox/Remembered/NameRow as HBoxContainer


func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	_load_remembered_names()
	_refresh_fields()
	set_status("Enter a player name, then a password.")
	_focus_field(Field.USERNAME)


func reset_for_prompt() -> void:
	_busy = false
	_continue_button.disabled = false
	_username_button.disabled = false
	_password_button.disabled = false
	if _username.is_empty():
		_focus_field(Field.USERNAME)
		set_status("Enter a player name, then a password.")
	else:
		_focus_field(Field.PASSWORD)
		set_status("Welcome back. Enter your password, or pick a saved name.")


func apply_keyboard_text(text: String) -> void:
	if _busy:
		return

	var trimmed := text.strip_edges()
	if _active_field == Field.USERNAME:
		if trimmed.length() < 2:
			set_status("Player name must be at least 2 characters.")
			return
		_username = trimmed
		_refresh_fields()
		_focus_field(Field.PASSWORD)
		set_status("Now enter a password (6+ characters), then Register / Login.")
		return

	if trimmed.length() < 6:
		set_status("Password must be at least 6 characters.")
		return
	_password = trimmed
	_refresh_fields()
	set_status("Password set. Press Register / Login.")


func preview_keyboard_text(text: String) -> void:
	if _busy:
		return
	if _active_field == Field.USERNAME:
		_username_value.text = text if not text.is_empty() else "(empty)"
	else:
		_password_value.text = "*".repeat(text.length()) if not text.is_empty() else "(empty)"


func set_status(message: String) -> void:
	_status.text = message


func set_busy(is_busy: bool) -> void:
	_busy = is_busy
	_continue_button.disabled = is_busy
	_username_button.disabled = is_busy
	_password_button.disabled = is_busy
	if is_busy:
		set_status("Contacting Supabase...")


func remember_username(username: String) -> void:
	var names := _read_remembered()
	@warning_ignore("return_value_discarded")
	names.erase(username)
	names.push_front(username)
	if names.size() > MAX_REMEMBERED:
		names.resize(MAX_REMEMBERED)
	_write_remembered(names)
	_rebuild_name_buttons(names)


func _try_submit() -> void:
	if _busy:
		return
	if _username.strip_edges().length() < 2:
		set_status("Tap Player Name and type your name.")
		_focus_field(Field.USERNAME)
		return
	if _password.length() < 6:
		set_status("Tap Password and type at least 6 characters.")
		_focus_field(Field.PASSWORD)
		return

	set_busy(true)
	credentials_submitted.emit(_username.strip_edges(), _password)


func _focus_field(field: Field) -> void:
	_active_field = field
	_refresh_fields()
	if field == Field.USERNAME:
		input_field_changed.emit("username")
	else:
		input_field_changed.emit("password")


func _refresh_fields() -> void:
	_username_value.text = _username if not _username.is_empty() else "(empty)"
	if _password.is_empty():
		_password_value.text = "(empty)"
	else:
		_password_value.text = "*".repeat(_password.length())

	_username_button.modulate = Color(1.2, 1.2, 1.0) if _active_field == Field.USERNAME else Color.WHITE
	_password_button.modulate = Color(1.2, 1.2, 1.0) if _active_field == Field.PASSWORD else Color.WHITE


func _on_username_button_pressed() -> void:
	_focus_field(Field.USERNAME)


func _on_password_button_pressed() -> void:
	_focus_field(Field.PASSWORD)


func _on_continue_button_pressed() -> void:
	_try_submit()


func _on_remembered_name_pressed(name: String) -> void:
	if _busy:
		return
	_username = name
	_password = ""
	_refresh_fields()
	_focus_field(Field.PASSWORD)
	set_status("Password for %s:" % name)


func _load_remembered_names() -> void:
	var names := _read_remembered()
	_rebuild_name_buttons(names)
	if not names.is_empty() and _username.is_empty():
		_username = str(names[0])
		_refresh_fields()


func _rebuild_name_buttons(names: Array) -> void:
	for child in _name_row.get_children():
		child.queue_free()

	for name in names:
		var button := Button.new()
		button.text = str(name)
		button.pressed.connect(_on_remembered_name_pressed.bind(str(name)))
		_name_row.add_child(button)
		UI_AudioEngine.attach_button(button)


func _read_remembered() -> Array:
	if not FileAccess.file_exists(REMEMBERED_FILE):
		return []
	var file := FileAccess.open(REMEMBERED_FILE, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		return parsed
	return []


func _write_remembered(names: Array) -> void:
	var file := FileAccess.open(REMEMBERED_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(names))
	file.close()
