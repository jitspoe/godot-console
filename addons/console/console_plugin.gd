@tool
extends EditorPlugin

const CONSOLE_THEME : String = &"console/theme"

func _enter_tree():
	if not ProjectSettings.has_setting(CONSOLE_THEME):
		ProjectSettings.set_setting(CONSOLE_THEME, "")

	ProjectSettings.add_property_info({
		"name": CONSOLE_THEME,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres",
	})

	ProjectSettings.set_initial_value(CONSOLE_THEME, "")
	ProjectSettings.set_as_basic(CONSOLE_THEME, true)
	ProjectSettings.save()

	add_autoload_singleton("Console", "res://addons/console/console.gd")

	print("Console plugin activated.")

func _exit_tree():
	remove_autoload_singleton("Console")
