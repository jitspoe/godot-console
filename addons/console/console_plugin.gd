@tool
extends EditorPlugin

##FIXME: These should be maintained in one place.
const CONSOLE_THEME : String = &"console/theme"
const CONSOLE_SCALE : String = &"console/scale"
const CONSOLE_HEIGHT : String = &"console/height"
const CONSOLE_COLOR_WARNING : String = &"console/color_warning"
const CONSOLE_COLOR_ERROR : String = &"console/color_error"
const CONSOLE_COLOR_INFO : String = &"console/color_info"
const CONSOLE_COLOR_LITERAL : String = &"console/color_literal"
const CONSOLE_TABSTOP : String = &"console/tabstop"

func add_setting(setting_name: String, property_info: Dictionary, default: Variant) -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default)
	ProjectSettings.add_property_info(property_info)
	ProjectSettings.set_initial_value(setting_name, default)
	ProjectSettings.set_as_basic(setting_name, true)

func _setup_project_settings() -> void:
	## Configure Console Theme
	add_setting(CONSOLE_THEME, {
		"name": CONSOLE_THEME,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres",
	}, "")

	## Configure Console Scale
	add_setting(CONSOLE_SCALE, {
		"name": CONSOLE_SCALE,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,10,0.1,or_greater"
	}, 1.0)

	## Configure Console Height
	add_setting(CONSOLE_HEIGHT, {
		"name": CONSOLE_HEIGHT,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,1,0.1"
	}, 0.5)

	## Configure Tab Spaces
	add_setting(CONSOLE_TABSTOP, {
		"name": CONSOLE_TABSTOP,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,8,1,or_greater"
	},4)

	#Configure Colors
	add_setting(CONSOLE_COLOR_ERROR, {
		"name": CONSOLE_COLOR_ERROR,
		"type": TYPE_COLOR,
		"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
	}, Color.LIGHT_CORAL)

	add_setting(CONSOLE_COLOR_INFO, {
		"name": CONSOLE_COLOR_INFO,
		"type": TYPE_COLOR,
		"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
	}, Color.LIGHT_BLUE)

	add_setting(CONSOLE_COLOR_WARNING, {
		"name": CONSOLE_COLOR_WARNING,
		"type": TYPE_COLOR,
		"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
	}, Color.LIGHT_GOLDENROD)

	add_setting(CONSOLE_COLOR_LITERAL, {
		"name": CONSOLE_COLOR_LITERAL,
		"type": TYPE_COLOR,
		"hint": PROPERTY_HINT_COLOR_NO_ALPHA
	}, Color.PALE_GREEN)

	ProjectSettings.save()

func _enter_tree() -> void:
	add_autoload_singleton("Console", "res://addons/console/console.gd")
	_setup_project_settings()
	print("Console plugin activated.")

func _exit_tree() -> void:
	remove_autoload_singleton("Console")
