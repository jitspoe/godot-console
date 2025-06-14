@tool
extends RichTextEffect
class_name SystemColor

var bbcode : String = "system_color"

func _process_custom_fx(char_fx : CharFXTransform):
	var _system_color = char_fx.env.get("color")

	if not _system_color:
		return false

	if not _system_color in Console:
		return false

	# Convert string to const value
	_system_color = Console.get_script().get_script_constant_map()[_system_color]

	var _color : Color = Console.color_dictionary[_system_color]

	if ProjectSettings.has_setting(_system_color):
		_color = ProjectSettings.get_setting(_system_color)

	if not _color:
		return false

	char_fx.color = _color

	return true
