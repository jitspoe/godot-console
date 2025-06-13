@tool
extends EditorPlugin

##FIXME: These should be maintained in one place.
const CONSOLE_THEME : String = &"console/theme"
const CONSOLE_SCALE : String = &"console/scale"
const CONSOLE_HEIGHT : String = &"console/height"

func _enter_tree():
	add_autoload_singleton("Console", "res://addons/console/console.gd")

	## Configure Console Theme
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

	## Configure Console Scale
	if not ProjectSettings.has_setting(CONSOLE_SCALE):
		ProjectSettings.set_setting(CONSOLE_SCALE, 1.0)

	ProjectSettings.add_property_info({
		"name": CONSOLE_SCALE,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,10,0.1,or_greater"
	})

	ProjectSettings.set_initial_value(CONSOLE_SCALE, 1.0)
	ProjectSettings.set_as_basic(CONSOLE_SCALE, true)

	## Configure Console Height
	if not ProjectSettings.has_setting(CONSOLE_HEIGHT):
		ProjectSettings.set_setting(CONSOLE_HEIGHT, 0.5)

	ProjectSettings.add_property_info({
		"name": CONSOLE_HEIGHT,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,1,0.1"
	})

	ProjectSettings.set_initial_value(CONSOLE_HEIGHT, 0.5)
	ProjectSettings.set_as_basic(CONSOLE_HEIGHT, true)

	ProjectSettings.save()

	print("Console plugin activated.")

func _exit_tree():
	remove_autoload_singleton("Console")
