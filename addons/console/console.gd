extends Node

const CONSOLE_THEME : String = &"console/theme"
const CONSOLE_SCALE : String = &"console/scale"
const CONSOLE_HEIGHT : String = &"console/height"
const CONSOLE_COLOR_WARNING : String = &"console/color_warning"
const CONSOLE_COLOR_ERROR : String = &"console/color_error"
const CONSOLE_COLOR_INFO : String = &"console/color_info"
const CONSOLE_COLOR_LITERAL : String = &"console/color_literal"
const CONSOLE_TABSTOP : String = &"console/tabstop"

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

var theme : Theme
var canvas_layer : CanvasLayer = CanvasLayer.new()
var v_box_container : VBoxContainer = VBoxContainer.new()

# If you want to customize the way the console looks, you can direcly modify
# the properties of the rich text and line edit here:
var rich_label : RichTextLabel = RichTextLabel.new()
var panel : Panel = Panel.new()
var line_edit : LineEdit = LineEdit.new()

var console_commands : Dictionary[String, ConsoleCommand] = {}
var command_parameters : Dictionary[String, PackedStringArray] = {}
var console_history : Array[String] = []
var console_history_index : int = 0
var was_paused_already : bool = false

var tab_string : String = "    "
var text_block_cache : Array[String]

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
	command_parameters.erase(command_name)


## Useful if you have a list of possible parameters (ex: level names).
func add_command_autocomplete_list(command_name : String, param_list : PackedStringArray):
	command_parameters[command_name] = param_list


func _enter_tree() -> void:
	var console_history_file := FileAccess.open("user://console_history.txt", FileAccess.READ)
	if (console_history_file):
		while (!console_history_file.eof_reached()):
			var line := console_history_file.get_line()
			if (line.length()):
				add_input_history(line)

	if ProjectSettings.has_setting(CONSOLE_THEME):
		theme = load(ProjectSettings.get_setting(CONSOLE_THEME))
		if theme:
			v_box_container.theme = theme

	if ProjectSettings.has_setting(CONSOLE_TABSTOP):
		tab_string = ""
		for i in range(ProjectSettings.get_setting(CONSOLE_TABSTOP)):
			tab_string += " "

	canvas_layer.layer = 3
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
	rich_label.install_effect(preload("res://addons/console/system_color.gd").new())
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


func _ready() -> void:
	v_box_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # For that retro look.
	add_command("quit", quit, 0, 0, "Quits the game.")
	add_command("exit", quit, 0, 0, "Quits the game.")
	add_command("clear", clear, 0, 0, "Clears the text on the console.")
	add_command("delete_history", delete_history, 0, 0, "Deletes the history of previously entered commands.")
	add_command("help", help, 0, 0, "Displays instructions on how to use the console.")
	add_command("commands_list", commands_list, 0, 0, "Lists all commands and their descriptions.")
	add_command("commands", commands, 0, 0, "Lists commands with no descriptions.")
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
		if (event.get_physical_keycode_with_modifiers() == KEY_QUOTELEFT): # ~ key.
			if (event.pressed):
				toggle_console()
			get_tree().get_root().set_input_as_handled()
		elif (event.physical_keycode == KEY_QUOTELEFT and event.is_command_or_control_pressed()): # Toggles console size or opens big console.
			if (event.pressed):
				if (v_box_container.visible):
					toggle_size()
				else:
					toggle_console()
					toggle_size()
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


var suggestions := []
var current_suggest := 0
var suggesting := false

func autocomplete() -> void:
	if (suggesting):
		for i in range(suggestions.size()):
			if (current_suggest == i):
				line_edit.text = str(suggestions[i])
				line_edit.caret_column = line_edit.text.length()
				if (current_suggest == suggestions.size() - 1):
					current_suggest = 0
				else:
					current_suggest += 1
				return
	else:
		suggesting = true

		if (" " in line_edit.text): # We're searching for a parameter to autocomplete
			var split_text := parse_line_input(line_edit.text)
			if (split_text.size() > 1):
				var command := split_text[0]
				var param_input := split_text[1]
				if (command_parameters.has(command)):
					for param in command_parameters[command]:
						if (param_input in param):
							suggestions.append(str(command, " ", param))
		else:
			var sorted_commands := []
			for command in console_commands:
				if (!console_commands[command].hidden):
					sorted_commands.append(str(command))
			sorted_commands.sort()
			sorted_commands.reverse()

			var prev_index := 0
			for command in sorted_commands:
				if (!line_edit.text || command.contains(line_edit.text)):
					var index : int = command.find(line_edit.text)
					if (index <= prev_index):
						suggestions.push_front(command)
					else:
						suggestions.push_back(command)
					prev_index = index
		autocomplete()


func reset_autocomplete() -> void:
	suggestions.clear()
	current_suggest = 0
	suggesting = false


func toggle_size() -> void:
	console_full_screen = !console_full_screen
	v_box_container.anchor_bottom = _get_console_height()


func disable():
	enabled = false
	toggle_console() # Ensure hidden if opened


func enable():
	enabled = true


func toggle_console() -> void:
	if (enabled):
		v_box_container.visible = !v_box_container.visible
	else:
		v_box_container.visible = false

	if (v_box_container.visible):
		was_paused_already = get_tree().paused
		get_tree().paused = was_paused_already || pause_enabled
		line_edit.grab_focus()
		console_opened.emit()
	else:
		scroll_to_bottom()
		reset_autocomplete()
		if (pause_enabled && !was_paused_already):
			get_tree().paused = false
		console_closed.emit()


func is_visible():
	return v_box_container.visible


func scroll_to_bottom() -> void:
	var scroll: ScrollBar = rich_label.get_v_scroll_bar()
	scroll.value = scroll.max_value - scroll.page


func print_error(text : Variant, print_godot := false) -> void:
	var _color : Color = Color.LIGHT_CORAL
	if not text is String:
		text = str(text)

	print_line("%s[system_color color=CONSOLE_COLOR_ERROR]ERROR:[/system_color] %s" % [tab_string, text], print_godot)


func print_info(text : Variant, print_godot := false) -> void:
	var _color : Color = Color.LIGHT_BLUE
	if not text is String:
		text = str(text)

	print_line("%s[system_color color=CONSOLE_COLOR_INFO]INFO:[/system_color] %s" % [tab_string, text], print_godot)


func print_warning(text : Variant, print_godot := false) -> void:
	var _color : Color = Color.LIGHT_GOLDENROD
	if not text is String:
		text = str(text)

	print_line("%s[system_color color=CONSOLE_COLOR_WARNING]WARNING:[/system_color] %s" % [tab_string, text], print_godot)

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
		else:
			console_unknown_command.emit(text_command)
			print_error("Command not found.")


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
	rich_label.append_text("	Built in commands:
		[system_color color=CONSOLE_COLOR_LITERAL]calc[/system_color]: Calculates a given expresion
		[system_color color=CONSOLE_COLOR_LITERAL]clear[/system_color]: Clears the registry view
		[system_color color=CONSOLE_COLOR_LITERAL]commands[/system_color]: Shows a reduced list of all the currently registered commands
		[system_color color=CONSOLE_COLOR_LITERAL]commands_list[/system_color]: Shows a detailed list of all the currently registered commands
		[system_color color=CONSOLE_COLOR_LITERAL]delete_history[/system_color]: Deletes the commands history
		[system_color color=CONSOLE_COLOR_LITERAL]echo[/system_color]: Prints a given string to the console
		[system_color color=CONSOLE_COLOR_LITERAL]echo_error[/system_color]: Prints a given string as an error to the console
		[system_color color=CONSOLE_COLOR_LITERAL]echo_info[/system_color]: Prints a given string as info to the console
		[system_color color=CONSOLE_COLOR_LITERAL]echo_warning[/system_color]: Prints a given string as warning to the console
		[system_color color=CONSOLE_COLOR_LITERAL]pause[/system_color]: Pauses node processing
		[system_color color=CONSOLE_COLOR_LITERAL]unpause[/system_color]: Unpauses node processing
		[system_color color=CONSOLE_COLOR_LITERAL]quit[/system_color]: Quits the game
	Controls:
		[system_color color=CONSOLE_COLOR_INFO]Up[/system_color] and [system_color color=CONSOLE_COLOR_INFO]Down[/system_color] arrow keys to navigate commands history
		[system_color color=CONSOLE_COLOR_INFO]PageUp[/system_color] and [system_color color=CONSOLE_COLOR_INFO]PageDown[/system_color] to scroll registry
		[[system_color color=CONSOLE_COLOR_INFO]Ctrl[/system_color] + [system_color color=CONSOLE_COLOR_INFO]~[/system_color]] to change console size between half screen and full screen
		[[system_color color=CONSOLE_COLOR_INFO]Ctrl[/system_color] + [system_color color=CONSOLE_COLOR_INFO]Mouse Wheel[/system_color]] up/down to change console font size
		[system_color color=CONSOLE_COLOR_INFO]~[/system_color] or [system_color color=CONSOLE_COLOR_INFO]Esc[/system_color] key to close the console
		[system_color color=CONSOLE_COLOR_INFO]Tab[/system_color] key to autocomplete, [system_color system_color=CONSOLE_COLOR_INFO]Tab[/system_color] again to cycle between matching suggestions\n\n")


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
				arguments_string += "  [system_color color=CONSOLE_COLOR_ERROR]<" + console_commands[command].arguments[i] + ">[/system_color]"
			else:
				arguments_string += "  [system_color color=CONSOLE_COLOR_INFO]<" + console_commands[command].arguments[i] + ">[/system_color]"
		rich_label.append_text("	[system_color color=CONSOLE_COLOR_LITERAL]%s[/system_color]%s:   %s\n" % [command, arguments_string, description])
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
