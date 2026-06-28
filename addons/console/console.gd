extends Node

const CONSOLE_THEME : String = "console/settings/theme"
const CONSOLE_SCALE : String = "console/settings/scale"
const CONSOLE_HEIGHT : String = "console/settings/height"
const CONSOLE_COLOR_WARNING : String = "console/settings/color_warning"
const CONSOLE_COLOR_ERROR : String = "console/settings/color_error"
const CONSOLE_COLOR_INFO : String = "console/settings/color_info"
const CONSOLE_COLOR_LITERAL : String = "console/settings/color_literal"
const CONSOLE_TABSTOP : String = "console/settings/tabstop"
const CONSOLE_CANVAS_LAYER : String = "console/settings/canvas_layer"
const CONSOLE_LOG_ERRORS : String = "console/settings/log_errors"
const CONSOLE_LOG_MESSAGES: String = "console/settings/log_messages"
const CONSOLE_LOG_WARNINGS: String = "console/settings/log_warnings"
const CONSOLE_AUTOCOMPLETE_IGNORE_CASE : String = "console/settings/autocomplete_ignore_case"

##FIXME: This is here because project settings do no return the default value naturally
##This should be fixed in 4.5
const color_dictionary : Dictionary[String, Color] = {
	CONSOLE_COLOR_ERROR: Color.LIGHT_CORAL,
	CONSOLE_COLOR_INFO: Color.LIGHT_BLUE,
	CONSOLE_COLOR_LITERAL: Color.PALE_GREEN,
	CONSOLE_COLOR_WARNING: Color.LIGHT_GOLDENROD
}

var enabled : bool = true
var enable_on_release_build : bool = false : set = set_enable_on_release_build
var pause_enabled : bool = false
var font_size : int : set = _set_font_size

## What visual scale should the console be
var console_scale : float : set = set_console_scale

## Is the console in full screen or part screen mode
var console_full_screen : bool = false

var _conosle_tween_time : float = 5

signal console_opened
signal console_closed
signal console_unknown_command
signal console_cvar_changed(cvar_name : String, value : Variant)


class ConsoleCommand:
	var function : Callable
	var arguments : PackedStringArray
	var required : int
	var description : String
	var hidden : bool
	func _init(in_function : Callable, in_arguments : PackedStringArray, in_required : int = 0, in_description : String = ""):
		function = in_function
		arguments = in_arguments
		required = in_required
		description = in_description


class ConsoleCvar:
	var name : String
	var description : String
	var type : int
	var save : bool
	var value : Variant
	var object : Object
	var property : String

	func _init(in_name : String, in_type : int, in_description : String = "", in_save : bool = false):
		name = in_name
		type = in_type
		description = in_description
		save = in_save

	func is_reference() -> bool:
		return object != null

	func is_alive() -> bool:
		return object == null or is_instance_valid(object)

	func get_value() -> Variant:
		if object != null:
			return object.get_indexed(property)
		return value

	func set_value(new_value : Variant) -> void:
		if object != null:
			object.set_indexed(property, new_value)
		else:
			value = new_value

class ConsoleLogger extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if is_instance_valid(Console):
			var traces: String = ""
			var time_string: String = Time.get_time_string_from_system()
			for backtrace: ScriptBacktrace in script_backtraces:
				for frame: int in backtrace.get_frame_count():
					var frame_file: String = backtrace.get_frame_file(frame)
					var frame_line: int = backtrace.get_frame_line(frame)
					var frame_function: String = backtrace.get_frame_function(frame)
					var language: String = backtrace.get_language_name()
					## char(0x2022) is the bulletin character '•'
					traces += "\t\t" + char(0x2022) + " %s:%d @ %s::%s() '%s' \n" % [frame_file, frame_line, language, frame_function, code]
			
			var message: String = str("%s\t\tError in Function " % time_string, " '%s' Line %d in file %s" % [function, line, file], " ", "\n\t\tScript Backtrace\n", traces)
			match error_type:
				ERROR_TYPE_ERROR:
					if !ProjectSettings.get_setting("console/log_errors"): return
					var color: String = color_dictionary.get(CONSOLE_COLOR_ERROR, Color.LIGHT_CORAL).to_html()
					Console.print_line("\t\t[color=#%s]%s[/color]" % [color, message], false) 
				
				ERROR_TYPE_WARNING:
					if !ProjectSettings.get_setting("console/log_warnings"): return
					var color: String = color_dictionary.get(CONSOLE_COLOR_WARNING, Color.LIGHT_GOLDENROD).to_html()
					message = str("%s\t\tWarning in Function " % time_string, " '%s' Line %d in file %s" % [function, line, file], " ", "\n\t\tScript Backtrace\n", traces)
					Console.print_line("\t\t[color=#%s]%s[/color]" % [color, message], false) 
				
	
	func _log_message(message: String, error: bool) -> void:
		if is_instance_valid(Console):
			if !ProjectSettings.get_setting("console/log_messages"): return
			if error: Console.print_error(message, false)
			else: Console.print_line(message)

var theme : Theme
var canvas_layer : CanvasLayer = CanvasLayer.new()
var v_box_container : VBoxContainer = VBoxContainer.new()

# If you want to customize the way the console looks, you can direcly modify
# the properties of the rich text and line edit here:
var rich_label : RichTextLabel = RichTextLabel.new()
var panel : Panel = Panel.new()
var line_edit : LineEdit = LineEdit.new()

var console_commands : Dictionary[String, ConsoleCommand] = {}
var console_cvars : Dictionary[String, ConsoleCvar] = {}
# Pending values are applied when cvars are registered (if loaded from config)
var _pending_cvar_values : Dictionary[String, Variant] = {}
# The key consists of the command name followed by a colon followed by the parameter index (starting at 1)
# e.g.: "change_map:1" and "change_map:2"
var command_parameters : Dictionary[String, PackedStringArray] = {}
var autocomplete_ignore_case : bool = false
var console_history : Array[String] = []
var console_history_index : int = 0
var was_paused_already : bool = false

var tab_string : String = "    "
var text_block_cache : Array[String]

var logger: ConsoleLogger

## Should only be called during plugin initialization
static func _add_project_setting(setting_name: String, property_info: Dictionary, default: Variant) -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default)
	ProjectSettings.add_property_info(property_info)
	ProjectSettings.set_initial_value(setting_name, default)
	ProjectSettings.set_as_basic(setting_name, true)


## Should only be called during plugin initialization
## Will be called by the EditorPlugin in this addon
static func setup_project_settings() -> void:
	if not Engine.is_editor_hint():
		return

	## Configure Console Theme
	_add_project_setting(CONSOLE_THEME, {
		"name": CONSOLE_THEME,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres",
	}, "")

	## Configure Console Scale
	_add_project_setting(CONSOLE_SCALE, {
		"name": CONSOLE_SCALE,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,10,0.1,or_greater"
	}, 1.0)

	## Configure Console Height
	_add_project_setting(CONSOLE_HEIGHT, {
		"name": CONSOLE_HEIGHT,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,1,0.1"
	}, 0.5)

	## Configure Tab Spaces
	_add_project_setting(CONSOLE_TABSTOP, {
		"name": CONSOLE_TABSTOP,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,8,1,or_greater"
	},4)

	## Configure Canvas Layer
	_add_project_setting(CONSOLE_CANVAS_LAYER, {
		"name": CONSOLE_CANVAS_LAYER,
		"type": TYPE_INT,
	}, 3)

	#Configure Colors
	_add_project_setting(CONSOLE_COLOR_ERROR, {
		"name": CONSOLE_COLOR_ERROR,
		"type": TYPE_COLOR,
		"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
	}, color_dictionary[CONSOLE_COLOR_ERROR])

	_add_project_setting(CONSOLE_COLOR_INFO, {
		"name": CONSOLE_COLOR_INFO,
		"type": TYPE_COLOR,
		"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
	}, color_dictionary[CONSOLE_COLOR_INFO])

	_add_project_setting(CONSOLE_COLOR_WARNING, {
		"name": CONSOLE_COLOR_WARNING,
		"type": TYPE_COLOR,
		"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
	}, color_dictionary[CONSOLE_COLOR_WARNING])

	_add_project_setting(CONSOLE_COLOR_LITERAL, {
		"name": CONSOLE_COLOR_LITERAL,
		"type": TYPE_COLOR,
		"hint": PROPERTY_HINT_COLOR_NO_ALPHA
	}, color_dictionary[CONSOLE_COLOR_LITERAL])

	_add_project_setting(CONSOLE_LOG_ERRORS, {
		"name": CONSOLE_LOG_ERRORS,
		"type": TYPE_BOOL,
	}, false)

	_add_project_setting(CONSOLE_LOG_MESSAGES, {
		"name": CONSOLE_LOG_MESSAGES,
		"type": TYPE_BOOL,
	}, false)

	_add_project_setting(CONSOLE_LOG_WARNINGS, {
		"name": CONSOLE_LOG_WARNINGS,
		"type": TYPE_BOOL,
	}, false)

	_add_project_setting(CONSOLE_AUTOCOMPLETE_IGNORE_CASE, {
		"name": CONSOLE_AUTOCOMPLETE_IGNORE_CASE,
		"type": TYPE_BOOL,
	}, false)

	ProjectSettings.save()


## Usage: Console.add_command("command_name", <function to call>, <number of arguments or array of argument names>, <required number of arguments>, "Help description")
func add_command(command_name : String, function : Callable, arguments = [], required: int = 0, description : String = "") -> void:
	if (arguments is int):
		# Legacy call using an argument number
		var param_array : PackedStringArray
		for i in range(arguments):
			param_array.append("arg_" + str(i + 1))
		console_commands[command_name] = ConsoleCommand.new(function, param_array, required, description)
	elif (arguments is Array):
		# New array argument system
		var str_args : PackedStringArray
		for argument in arguments:
			str_args.append(str(argument))
		console_commands[command_name] = ConsoleCommand.new(function, str_args, required, description)


## Adds a secret command that will not show up in the help or auto-complete.
func add_hidden_command(command_name : String, function : Callable, arguments = [], required : int = 0) -> void:
	add_command(command_name, function, arguments, required)
	console_commands[command_name].hidden = true


## Removes a command from the console.  This should be called on a script's _exit_tree()
## if you have console commands for things that are unloaded before the project closes.
func remove_command(command_name : String) -> void:
	console_commands.erase(command_name)
	for key in command_parameters.keys():
		if key.begins_with(command_name + ":"):
			command_parameters.erase(key)


## Registers an auto-managed cvar that stores its value internally.
## Type the name to print the value, or "name value" to set it.  The value is coerced to the
## type of default_value.  If save is true, the value is persisted to user://console_cvars.txt.
## Usage: Console.add_cvar("cl_fov", 90.0, "Field of view.", true)
func add_cvar(cvar_name : String, default_value : Variant, description : String = "", save : bool = false) -> void:
	var cvar := ConsoleCvar.new(cvar_name, typeof(default_value), description, save)
	cvar.value = default_value
	console_cvars[cvar_name] = cvar
	_apply_pending_cvar_value(cvar)


## Registers a cvar that reads from and writes to a property on another object.
## The cvar type is inferred from the property's current value.  property may be a nested path
## (ex: "position:x").
## Usage: Console.add_cvar_reference("cl_fov", camera, "fov", "Camera field of view.")
func add_cvar_reference(cvar_name : String, object : Object, property : String, description : String = "", save : bool = false) -> void:
	if not is_instance_valid(object):
		print_error("Cannot register cvar \"%s\": invalid object." % cvar_name)
		return
	var cvar := ConsoleCvar.new(cvar_name, typeof(object.get_indexed(property)), description, save)
	cvar.object = object
	cvar.property = property
	console_cvars[cvar_name] = cvar
	_apply_pending_cvar_value(cvar)


## Removes a cvar.  Call this on _exit_tree() for reference cvars whose object is freed early.
func remove_cvar(cvar_name : String) -> void:
	console_cvars.erase(cvar_name)


## Returns the current value of a cvar, or null if it doesn't exist / its object was freed.
func get_cvar(cvar_name : String) -> Variant:
	if console_cvars.has(cvar_name):
		var cvar : ConsoleCvar = console_cvars[cvar_name]
		if cvar.is_alive():
			return cvar.get_value()
	return null


## Sets the value of a cvar programmatically (no string coercion) and emits console_cvar_changed.
func set_cvar(cvar_name : String, value : Variant) -> void:
	if console_cvars.has(cvar_name):
		var cvar : ConsoleCvar = console_cvars[cvar_name]
		if cvar.is_alive():
			cvar.set_value(value)
			console_cvar_changed.emit(cvar_name, value)


func _apply_pending_cvar_value(cvar : ConsoleCvar) -> void:
	if cvar.save and _pending_cvar_values.has(cvar.name):
		var saved_value : Variant = _pending_cvar_values[cvar.name]
		if typeof(saved_value) != cvar.type:
			saved_value = type_convert(saved_value, cvar.type)
		cvar.set_value(saved_value)
		_pending_cvar_values.erase(cvar.name)


## Coerces a string into the given Variant.Type.  Returns [success : bool, value : Variant].
func _coerce_string_to_type(string_value : String, type : int) -> Array:
	match type:
		TYPE_BOOL:
			var lower := string_value.strip_edges().to_lower()
			if lower in ["1", "true", "yes", "on"]:
				return [true, true]
			if lower in ["0", "false", "no", "off"]:
				return [true, false]
			return [false, null]
		TYPE_INT:
			var int_string := string_value.strip_edges()
			if int_string.is_valid_int():
				return [true, int_string.to_int()]
			return [false, null]
		TYPE_FLOAT:
			var float_string := string_value.strip_edges()
			if float_string.is_valid_float():
				return [true, float_string.to_float()]
			return [false, null]
		TYPE_STRING:
			return [true, string_value]
		TYPE_STRING_NAME:
			return [true, StringName(string_value)]
		_:
			# Complex types (Vector2, etc.) require GDScript literal syntax, ex: "Vector2(1, 2)".
			var parsed : Variant = str_to_var(string_value)
			if parsed != null and typeof(parsed) == type:
				return [true, parsed]
			return [false, null]


func _print_cvar_value(cvar : ConsoleCvar) -> void:
	print_line("%s = %s" % [cvar.name, tag_color(str(cvar.get_value()), CONSOLE_COLOR_LITERAL)])


func _handle_cvar(cvar : ConsoleCvar, arguments : PackedStringArray) -> void:
	if not cvar.is_alive():
		print_error("Variable \"%s\" references a freed object." % cvar.name)
		return

	if arguments.is_empty():
		_print_cvar_value(cvar)
		if cvar.description:
			print_line("%s%s" % [tab_string, cvar.description])
		return

	var raw_value := " ".join(arguments)
	var result := _coerce_string_to_type(raw_value, cvar.type)
	if not result[0]:
		print_error("Invalid value \"%s\" for variable \"%s\" (expected %s)." % [raw_value, cvar.name, type_string(cvar.type)])
		return

	cvar.set_value(result[1])
	console_cvar_changed.emit(cvar.name, result[1])
	_print_cvar_value(cvar)


## Returns a string that can be used as a dictionary key for command and parameter autocomplete
func _get_command_autocomplete_key(command_name : String, param_index : int) -> String:
	# We could do a .to_lower() here if we wanted to go even further with autocomplete but that
	# would break commands with mismatched case, e.g. "AddMoney", "addmoney", and "addMoney" would
	# all be the same command.
	return "%s:%s" % [command_name, param_index]


## Useful if you have a list of possible parameters (ex: level names).
func add_command_autocomplete_list(command_name : String, param_list : PackedStringArray, param_index: int = 1):
	command_parameters[_get_command_autocomplete_key(command_name, param_index)] = param_list


func _enter_tree() -> void:
	var console_history_file := FileAccess.open("user://console_history.txt", FileAccess.READ)
	if (console_history_file):
		while (!console_history_file.eof_reached()):
			var line := console_history_file.get_line()
			if (line.length()):
				add_input_history(line)

	# Load persisted cvar values.  They're stashed until the matching cvar is registered.
	var console_cvars_file := FileAccess.open("user://console_cvars.txt", FileAccess.READ)
	if (console_cvars_file):
		while (!console_cvars_file.eof_reached()):
			var line := console_cvars_file.get_line()
			if (line.length()):
				var split := line.split(" ", true, 1) # "name var_to_str(value)"
				if (split.size() == 2):
					_pending_cvar_values[split[0]] = str_to_var(split[1])

	if ProjectSettings.has_setting(CONSOLE_THEME):
		theme = load(ProjectSettings.get_setting(CONSOLE_THEME))
		if theme:
			v_box_container.theme = theme

	if ProjectSettings.has_setting(CONSOLE_TABSTOP):
		tab_string = ""
		for i in range(ProjectSettings.get_setting(CONSOLE_TABSTOP)):
			tab_string += " "

	if ProjectSettings.has_setting(CONSOLE_AUTOCOMPLETE_IGNORE_CASE):
		autocomplete_ignore_case = bool(ProjectSettings.get_setting(CONSOLE_AUTOCOMPLETE_IGNORE_CASE))

	canvas_layer.layer = ProjectSettings.get_setting(CONSOLE_CANVAS_LAYER, 3)
	add_child(canvas_layer)
	console_scale = _get_console_scale_setting()
	v_box_container.offset_bottom = 0
	v_box_container.offset_left = 0
	v_box_container.offset_right = 0
	v_box_container.offset_top = 0
	canvas_layer.add_child(v_box_container)
	panel.size_flags_vertical = Control.SIZE_FILL ^ Control.SIZE_EXPAND
	v_box_container.add_child(panel)
	rich_label.selection_enabled = true
	rich_label.context_menu_enabled = true
	rich_label.bbcode_enabled = true
	rich_label.scroll_following = true
	rich_label.anchor_right = 1.0
	rich_label.anchor_bottom = 1.0
	rich_label.install_effect(preload("res://addons/console/system_color.gd").new()) # Can probably get rid of this, but leaving it for now in case people are using system_color in custom stuff.
	panel.add_child(rich_label)
	rich_label.append_text("Development console.\n")
	line_edit.anchor_right = 1.0
	line_edit.placeholder_text = "Enter \"help\" for instructions"
	if font_size > 0:
		line_edit.add_theme_font_size_override("font_size", font_size)
	v_box_container.add_child(line_edit)
	line_edit.text_submitted.connect(_on_text_entered)
	line_edit.text_changed.connect(_on_line_edit_text_changed)
	v_box_container.visible = false
	process_mode = PROCESS_MODE_ALWAYS
	
	logger = ConsoleLogger.new()
	OS.add_logger(logger)


## Get the scale of the console from the settings -- if this is not in the system settings return a default value
func _get_console_scale_setting() -> float:
	if ProjectSettings.has_setting(CONSOLE_SCALE):
		return ProjectSettings.get_setting(CONSOLE_SCALE)

	return 1.0


## Set the console scale
func set_console_scale(scale : float):
	console_scale = scale
	v_box_container.scale = Vector2(console_scale, console_scale)
	v_box_container.anchor_right = _get_console_width()
	v_box_container.anchor_bottom = _get_console_height()


## Get the height of the console - this is related to the scaling of the console
func _get_console_height() -> float:
	if console_full_screen:
		return 1.0 / console_scale

	if ProjectSettings.has_setting(CONSOLE_HEIGHT):
		return ProjectSettings.get_setting(CONSOLE_HEIGHT) / console_scale

	return 0.5 / console_scale

func _get_console_width() -> float:
	return 1.0 / console_scale


func _set_font_size(value: int) -> void:
	font_size = value
	if value > 0:
		line_edit.add_theme_font_size_override("font_size", font_size)
		rich_label.add_theme_font_size_override("normal_font_size", font_size)
		rich_label.add_theme_font_size_override("bold_font_size", font_size)
		rich_label.add_theme_font_size_override("bold_italics_font_size", font_size)
		rich_label.add_theme_font_size_override("italics_font_size", font_size)
		rich_label.add_theme_font_size_override("mono_font_size", font_size)
	else:
		line_edit.remove_theme_font_size_override("font_size")
		rich_label.remove_theme_font_size_override("normal_font_size")
		rich_label.remove_theme_font_size_override("bold_font_size")
		rich_label.remove_theme_font_size_override("bold_italics_font_size")
		rich_label.remove_theme_font_size_override("italics_font_size")
		rich_label.remove_theme_font_size_override("mono_font_size")


func _exit_tree() -> void:
	var console_history_file := FileAccess.open("user://console_history.txt", FileAccess.WRITE)
	if (console_history_file):
		var write_index := 0
		var start_write_index := console_history.size() - 100 # Max lines to write
		for line in console_history:
			if (write_index >= start_write_index):
				console_history_file.store_line(line)
			write_index += 1

	var console_cvars_file := FileAccess.open("user://console_cvars.txt", FileAccess.WRITE)
	if (console_cvars_file):
		for cvar_name in console_cvars:
			var cvar : ConsoleCvar = console_cvars[cvar_name]
			if (cvar.save and cvar.is_alive()):
				console_cvars_file.store_line("%s %s" % [cvar_name, var_to_str(cvar.get_value())])
		for pending_name in _pending_cvar_values:
			if (!console_cvars.has(pending_name)):
				console_cvars_file.store_line("%s %s" % [pending_name, var_to_str(_pending_cvar_values[pending_name])])
	if is_instance_valid(logger):
		OS.remove_logger(logger)


func _ready() -> void:
	v_box_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # For that retro look.
	add_command("quit", quit, 0, 0, "Quits the game.")
	add_command("exit", quit, 0, 0, "Quits the game.")
	add_command("clear", clear, 0, 0, "Clears the text on the console.")
	add_command("delete_history", delete_history, 0, 0, "Deletes the history of previously entered commands.")
	add_command("help", help, 0, 0, "Displays instructions on how to use the console.")
	add_command("commands_list", commands_list, 0, 0, "Lists all commands and their descriptions.")
	add_command("commands", commands, 0, 0, "Lists commands with no descriptions.")
	add_command("cvars", cvars, 0, 0, "Lists all console variables and their values.")
	add_command("calc", calculate, ["mathematical expression to evaluate"], 0, "Evaluates the math passed in for quick arithmetic.")
	add_command("echo", print_line, ["string"], 1, "Prints given string to the console.")
	add_command("echo_warning", print_warning, ["string"], 1, "Prints given string as warning to the console.")
	add_command("echo_info", print_info, ["string"], 1, "Prints given string as info to the console.")
	add_command("echo_error", print_error, ["string"], 1, "Prints given string as an error to the console.")
	add_command("pause", pause, 0, 0, "Pauses node processing.")
	add_command("unpause", unpause, 0, 0, "Unpauses node processing.")
	add_command("exec", exec, 1, 1, "Execute a script.")


func _input(event : InputEvent) -> void:
	if (event is InputEventKey):
		if (event.physical_keycode == KEY_QUOTELEFT): # ~ key.
			if (event.physical_keycode == KEY_QUOTELEFT and event.is_command_or_control_pressed()): # Toggles console size or opens big console.
				if (event.pressed):
					if (v_box_container.visible):
						toggle_size()
					else:
						toggle_console()
						toggle_size()
				get_tree().get_root().set_input_as_handled()
			else:
				if (event.pressed):
					toggle_console()
				get_tree().get_root().set_input_as_handled()
		elif (event.get_physical_keycode_with_modifiers() == KEY_ESCAPE && v_box_container.visible): # Disable console on ESC
			if (event.pressed):
				toggle_console()
				get_tree().get_root().set_input_as_handled()
		if (v_box_container.visible and event.pressed):
			if (event.get_physical_keycode_with_modifiers() == KEY_UP):
				get_tree().get_root().set_input_as_handled()
				if (console_history_index > 0):
					console_history_index -= 1
					if (console_history_index >= 0):
						line_edit.text = console_history[console_history_index]
						line_edit.caret_column = line_edit.text.length()
						reset_autocomplete()
			if (event.get_physical_keycode_with_modifiers() == KEY_DOWN):
				get_tree().get_root().set_input_as_handled()
				if (console_history_index < console_history.size()):
					console_history_index += 1
					if (console_history_index < console_history.size()):
						line_edit.text = console_history[console_history_index]
						line_edit.caret_column = line_edit.text.length()
						reset_autocomplete()
					else:
						line_edit.text = ""
						reset_autocomplete()
			if (event.get_physical_keycode_with_modifiers() == KEY_PAGEUP):
				var scroll := rich_label.get_v_scroll_bar()
				var tween := create_tween()
				tween.tween_property(scroll, "value",  scroll.value - (scroll.page - scroll.page * 0.1), 0.1)
				get_tree().get_root().set_input_as_handled()
			if (event.get_physical_keycode_with_modifiers() == KEY_PAGEDOWN):
				var scroll := rich_label.get_v_scroll_bar()
				var tween := create_tween()
				tween.tween_property(scroll, "value",  scroll.value + (scroll.page - scroll.page * 0.1), 0.1)
				get_tree().get_root().set_input_as_handled()
			if (event.get_physical_keycode_with_modifiers() == KEY_TAB):
				autocomplete()
				get_tree().get_root().set_input_as_handled()

	elif event is InputEventMouseButton:
		if (v_box_container.visible):
			if (event.is_command_or_control_pressed()):
				if event.button_index == MOUSE_BUTTON_WHEEL_UP: # Increase font size with ctrl+mouse wheel up
					font_size = min(128, font_size + 2) # Limit to max of 128
					get_tree().get_root().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: # Decrease font size with ctrl+mouse wheel down
					font_size = max(8, font_size - 2) # Limit to minimum of 8
					get_tree().get_root().set_input_as_handled()


func is_autocomplete_match(input: String, param: String) -> bool:
	return input.is_empty() or (param.containsn(input) if autocomplete_ignore_case else param.contains(input))


var suggestions := []
var current_suggest := 0
var suggesting := false

func autocomplete() -> void:
	if suggesting:
		if suggestions:
			current_suggest = mini(current_suggest, suggestions.size() - 1)
			line_edit.text = str(suggestions[current_suggest])
			line_edit.caret_column = line_edit.text.length()
			current_suggest = wrapi(current_suggest + 1, 0, suggestions.size())
		return

	suggesting = true

	if " " in line_edit.text:
		var split_text: = parse_line_input(line_edit.text)
		if split_text.size() > 1:
			var param_index: = split_text.size() - 1
			var input_command: = split_text[0]
			var input_param: = split_text[param_index]
			var autocomplete_key: = _get_command_autocomplete_key(input_command, param_index)

			# We assume that input_command (and thus autocomplete_key) matches autocomplete key
			# _exactly_ as we don't do a case insensitive search through the dictionary. It will be
			# correct as long as we've either typed in the command name correctly or autocompleted
			# the command name.
			if command_parameters.has(autocomplete_key):
				var ready_text: = " ".join(split_text.slice(0, -1))
				for param: String in command_parameters[autocomplete_key]:
					if is_autocomplete_match(input_param, param):
						suggestions.append(str(ready_text, " ", param))

	else:
		var query: = line_edit.text.strip_edges()

		var matches: Array[String] = []
		for command_name: String in console_commands:
			if console_commands[command_name].hidden:
				continue
			matches.append(command_name)
		matches.append_array(console_cvars.keys())

		matches.assign(matches.filter(func (x: String) -> bool: return is_autocomplete_match(query, x)))

		matches.sort_custom(func (a: String, b: String) -> bool:
			var ai: = a.findn(query) if autocomplete_ignore_case else a.find(query)
			var bi: = b.findn(query) if autocomplete_ignore_case else b.find(query)
			if ai != bi:
				return ai < bi
			var cmp: = a.naturalnocasecmp_to(b) if autocomplete_ignore_case else a.naturalcasecmp_to(b)
			return cmp < 0
		)

		suggestions = matches

	autocomplete()


func reset_autocomplete() -> void:
	suggestions.clear()
	current_suggest = 0
	suggesting = false


func toggle_size() -> void:
	console_full_screen = !console_full_screen
	v_box_container.anchor_bottom = _get_console_height()


func disable() -> void:
	enabled = false
	toggle_console() # Ensure hidden if opened


func enable() -> void:
	enabled = true


func toggle_console() -> void:
	var was_visible := v_box_container.visible
	if (enabled):
		v_box_container.visible = !v_box_container.visible
	else:
		v_box_container.visible = false

	if (v_box_container.visible):
		was_paused_already = get_tree().paused
		get_tree().paused = was_paused_already || pause_enabled
		line_edit.grab_focus()
		if was_visible != v_box_container.visible:
			console_opened.emit()
	else:
		scroll_to_bottom()
		reset_autocomplete()
		if (pause_enabled && !was_paused_already):
			get_tree().paused = false
		if was_visible != v_box_container.visible:
			console_closed.emit()


func is_visible() -> bool:
	return v_box_container.visible


func scroll_to_bottom() -> void:
	var scroll: ScrollBar = rich_label.get_v_scroll_bar()
	scroll.value = scroll.max_value - scroll.page


func get_console_color_html(color_type : String) -> String:
	var color : Color = Console.color_dictionary[color_type]
	if ProjectSettings.has_setting(color_type):
		color = ProjectSettings.get_setting(color_type)
	return color.to_html()


func tag_color(text : String, color_type : String) -> String:
	return str("[color=", get_console_color_html(color_type), "]", text, "[/color]")


func print_error(text : Variant, print_godot := false) -> void:
	if !(text is String):
		text = str(text)
	print_line(str(tab_string, tag_color(tr("ERROR: "), CONSOLE_COLOR_ERROR), text), print_godot)


func print_info(text : Variant, print_godot := false) -> void:
	if !(text is String):
		text = str(text)
	print_line(str(tab_string, tag_color(tr("INFO: "), CONSOLE_COLOR_INFO), text), print_godot)


func print_warning(text : Variant, print_godot := false) -> void:
	if not text is String:
		text = str(text)
	print_line(str(tab_string, tag_color(tr("WARNING: "), CONSOLE_COLOR_WARNING), text), print_godot)


func print_line(text : Variant, print_godot := false) -> void:
	if not text is String:
		text = str(text)
	if (!rich_label): # Tried to print something before the console was loaded.
		call_deferred("print_line", text)
	else:
		rich_label.append_text(text)
		rich_label.append_text("\n")
		if (print_godot):
			print_rich(text.dedent())


func parse_line_input(text : String) -> PackedStringArray:
	var out_array : PackedStringArray
	var first_char := true
	var in_quotes := false
	var escaped := false
	var token : String
	for c in text:
		if (c == '\\'):
			escaped = true
			continue
		elif (escaped):
			if (c == 'n'):
				c = '\n'
			elif (c == 't'):
				c = '\t'
			elif (c == 'r'):
				c = '\r'
			elif (c == 'a'):
				c = '\a'
			elif (c == 'b'):
				c = '\b'
			elif (c == 'f'):
				c = '\f'
			escaped = false
		elif (c == '\"'):
			in_quotes = !in_quotes
			continue
		elif (c == ' ' || c == '\t'):
			if (!in_quotes):
				out_array.push_back(token)
				token = ""
				continue
		token += c
	out_array.push_back(token)
	return out_array


func _on_text_entered(new_text : String) -> void:
	scroll_to_bottom()
	reset_autocomplete()
	line_edit.clear()
	if (line_edit.has_method(&"edit")):
		line_edit.call_deferred(&"edit")

	if not new_text.strip_edges().is_empty():
		add_input_history(new_text)
		print_line("[i]> " + new_text + "[/i]")
		var text_split := parse_line_input(new_text)
		var text_command := text_split[0]

		if console_commands.has(text_command):
			var arguments := text_split.slice(1)
			var console_command : ConsoleCommand = console_commands[text_command]

			# calc is a especial command that needs special treatment
			if (text_command.match("calc")):
				var expression := ""
				for word in arguments:
					expression += word
				console_command.function.callv([expression])
				return

			if (arguments.size() < console_command.required):
				print_error("Too few arguments! Required < %d >" % console_command.required)
				return
			elif (arguments.size() > console_command.arguments.size()):
				arguments.resize(console_command.arguments.size())

			# Functions fail to call if passed the incorrect number of arguments, so fill out with blank strings.
			while (arguments.size() < console_command.arguments.size()):
				arguments.append("")

			console_command.function.callv(arguments)
		elif console_cvars.has(text_command):
			_handle_cvar(console_cvars[text_command], text_split.slice(1))
		else:
			console_unknown_command.emit(text_command)
			print_error("Unknown command or variable.")


func _on_line_edit_text_changed(new_text : String) -> void:
	reset_autocomplete()


func quit() -> void:
	get_tree().quit()


func clear() -> void:
	rich_label.clear()


func delete_history() -> void:
	console_history.clear()
	console_history_index = 0
	DirAccess.remove_absolute("user://console_history.txt")


func help() -> void:
	rich_label.append_text(str("	Built in commands:
		", tag_color("calc", CONSOLE_COLOR_LITERAL), ": Calculates a given expresion
		", tag_color("clear", CONSOLE_COLOR_LITERAL), ": Clears the registry view
		", tag_color("commands", CONSOLE_COLOR_LITERAL), ": Shows a reduced list of all the currently registered commands
		", tag_color("commands_list", CONSOLE_COLOR_LITERAL), ": Shows a detailed list of all the currently registered commands
		", tag_color("cvars", CONSOLE_COLOR_LITERAL), ": Lists all console variables and their values
		", tag_color("delete_history", CONSOLE_COLOR_LITERAL), ": Deletes the commands history
		", tag_color("echo", CONSOLE_COLOR_LITERAL), ": Prints a given string to the console
		", tag_color("echo_error", CONSOLE_COLOR_LITERAL), ": Prints a given string as an error to the console
		", tag_color("echo_info", CONSOLE_COLOR_LITERAL), ": Prints a given string as info to the console
		", tag_color("echo_warning", CONSOLE_COLOR_LITERAL), ": Prints a given string as warning to the console
		", tag_color("pause", CONSOLE_COLOR_LITERAL), ": Pauses node processing
		", tag_color("unpause", CONSOLE_COLOR_LITERAL), ": Unpauses node processing
		", tag_color("quit", CONSOLE_COLOR_LITERAL), ": Quits the game
	Controls:
		", tag_color("Up", CONSOLE_COLOR_INFO), " and ", tag_color("Down", CONSOLE_COLOR_INFO), " arrow keys to navigate commands history
		", tag_color("PageUp", CONSOLE_COLOR_INFO), " and ", tag_color("PageDown", CONSOLE_COLOR_INFO), " to scroll registry
		", tag_color("Ctrl", CONSOLE_COLOR_INFO), " + ", tag_color("~", CONSOLE_COLOR_INFO), " to change console size between half screen and full screen
		", tag_color("Ctrl", CONSOLE_COLOR_INFO), " + ", tag_color("Mouse Wheel", CONSOLE_COLOR_INFO), " up/down to change console font size
		", tag_color("~", CONSOLE_COLOR_INFO), " or ", tag_color("Esc", CONSOLE_COLOR_INFO), " key to close the console
		", tag_color("Tab", CONSOLE_COLOR_INFO), " key to autocomplete, ", tag_color("Tab", CONSOLE_COLOR_INFO), " again to cycle between matching suggestions\n\n"))


func calculate(command : String) -> void:
	var expression := Expression.new()
	var error = expression.parse(command)
	if error:
		print_error("%s" % expression.get_error_text())
		return
	var result = expression.execute()
	if not expression.has_execute_failed():
		print_line(str(result))
	else:
		print_error("%s" % expression.get_error_text())


func commands() -> void:
	var commands := []
	for command in console_commands:
		if (!console_commands[command].hidden):
			commands.append(str(command))
	commands.sort()
	rich_label.append_text("	")
	rich_label.append_text(str(commands) + "\n\n")


func commands_list() -> void:
	var commands := []
	for command in console_commands:
		if (!console_commands[command].hidden):
			commands.append(str(command))
	commands.sort()

	for command in commands:
		var arguments_string := ""
		var description : String = console_commands[command].description
		for i in range(console_commands[command].arguments.size()):
			if i < console_commands[command].required:
				arguments_string += tag_color(str("  <", console_commands[command].arguments[i], ">"), CONSOLE_COLOR_ERROR)
			else:
				arguments_string += tag_color(str("  <", console_commands[command].arguments[i], ">"), CONSOLE_COLOR_INFO)
		rich_label.append_text("	%s%s:   %s\n" % [tag_color(command, CONSOLE_COLOR_LITERAL), arguments_string, description])
	rich_label.append_text("\n")


func cvars() -> void:
	var names := console_cvars.keys()
	names.sort()
	for cvar_name in names:
		var cvar : ConsoleCvar = console_cvars[cvar_name]
		var value_string := "<invalid>"
		if (cvar.is_alive()):
			value_string = str(cvar.get_value())
		rich_label.append_text("	%s = %s   %s\n" % [tag_color(cvar_name, CONSOLE_COLOR_LITERAL), tag_color(value_string, CONSOLE_COLOR_INFO), cvar.description])
	rich_label.append_text("\n")


func add_input_history(text : String) -> void:
	if (!console_history.size() || text != console_history.back()): # Don't add consecutive duplicates
		console_history.append(text)
	console_history_index = console_history.size()


func set_enable_on_release_build(enable : bool):
	enable_on_release_build = enable
	if (!enable_on_release_build):
		if (!OS.is_debug_build()):
			disable()


func pause() -> void:
	get_tree().paused = true


func unpause() -> void:
	get_tree().paused = false


func exec(filename : String) -> void:
	var path := "user://%s.txt" % [filename]
	var script := FileAccess.open(path, FileAccess.READ)
	if (script):
		while (!script.eof_reached()):
			_on_text_entered(script.get_line())
	else:
		print_error("File %s not found." % [path])
