extends Node


signal console_opened
signal console_closed
signal console_unknown_command


class ConsoleCommand:
	var function : Callable
	var param_count : int
	func _init(in_function : Callable, in_param_count : int):
		function = in_function
		param_count = in_param_count


@onready var control := Control.new()
@onready var rich_label := RichTextLabel.new()
@onready var line_edit := LineEdit.new()

var console_commands := {}
var console_history := []
var console_history_index := 0


func _ready() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 3
	add_child(canvas_layer)
	control.anchor_bottom = 1.0
	control.anchor_right = 1.0
	canvas_layer.add_child(control)
	rich_label.scroll_following = true
	rich_label.anchor_right = 1.0
	rich_label.anchor_bottom = 0.5
	rich_label.add_theme_stylebox_override("normal", load("res://addons/console/console_background.tres"))
	control.add_child(rich_label)
	rich_label.text = "Development console.\n"
	line_edit.anchor_top = 0.5
	line_edit.anchor_right = 1.0
	line_edit.anchor_bottom = 0.5
	control.add_child(line_edit)
	line_edit.text_submitted.connect(on_text_entered)
	line_edit.text_changed.connect(on_line_edit_text_changed)
	control.visible = false
	process_mode = PROCESS_MODE_ALWAYS
	add_command("quit", quit, 0)
	add_command("exit", quit, 0)
	add_command("clear", clear, 0)
	add_command("delete_history", delete_history, 0)
	add_command("help", help, 0)
	add_command("commands_list", commands_list, 0)


func _input(event : InputEvent) -> void:
	if (event is InputEventKey):
		if (event.get_physical_keycode_with_modifiers() == KEY_QUOTELEFT): # ~ key.
			if (event.pressed):
				toggle_console()
			get_tree().get_root().set_input_as_handled()
		elif (event.physical_keycode == KEY_QUOTELEFT and event.is_command_or_control_pressed()): # Toggles console size or opens big console.
			if (event.pressed):
				if (control.visible):
					toggle_size()
				else:
					toggle_console()
					toggle_size()
			get_tree().get_root().set_input_as_handled()
		elif (event.get_physical_keycode_with_modifiers() == KEY_ESCAPE && control.visible): # Disable console on ESC
			if (event.pressed):
				toggle_console()
				get_tree().get_root().set_input_as_handled()
		if (control.visible and event.pressed):
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
				scroll.value -= scroll.page - scroll.page * 0.1
				get_tree().get_root().set_input_as_handled()
			if (event.get_physical_keycode_with_modifiers() == KEY_PAGEDOWN):
				var scroll := rich_label.get_v_scroll_bar()
				scroll.value += scroll.page - scroll.page * 0.1
				get_tree().get_root().set_input_as_handled()
			if (event.get_physical_keycode_with_modifiers() == KEY_TAB):
				autocomplete()
				get_tree().get_root().set_input_as_handled()


var suggestions := []
var current_suggest := 0
var suggesting := false
func autocomplete() -> void:
	if suggesting:
		for i in range(suggestions.size()):
			if current_suggest == i:
				line_edit.text = str(suggestions[i])
				line_edit.caret_column = line_edit.text.length()
				if current_suggest == suggestions.size() - 1:
					current_suggest = 0
				else:
					current_suggest += 1
				return
	else:
		suggesting = true
		
		var sorted_commands := []
		for command in console_commands:
			sorted_commands.append(str(command))
		sorted_commands.sort()
		sorted_commands.reverse()
		
		var prev_index := 0
		for command in sorted_commands:
			if command.contains(line_edit.text):
				var index : int = command.find(line_edit.text)
				if index <= prev_index:
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
	if (control.anchor_bottom == 1.0):
		control.anchor_bottom = 1.9
	else:
		control.anchor_bottom = 1.0


func toggle_console() -> void:
	control.visible = !control.visible
	if (control.visible):
		get_tree().paused = true
		line_edit.grab_focus()
		emit_signal("console_opened")
	else:
		control.anchor_bottom = 1.0
		scroll_to_bottom()
		reset_autocomplete()
		get_tree().paused = false
		emit_signal("console_closed")


func scroll_to_bottom() -> void:
	var scroll: ScrollBar = rich_label.get_v_scroll_bar()
	scroll.value = scroll.max_value - scroll.page


func print_line(text : String) -> void:
	if (!rich_label): # Tried to print something before the console was loaded.
		call_deferred("print_line", text)
	else:
		rich_label.add_text(text)
		rich_label.add_text("\n")


func on_text_entered(text : String) -> void:
	scroll_to_bottom()
	reset_autocomplete()
	line_edit.clear()
	add_input_history(text)
	print_line(text)
	var split_text := text.split(" ", true)
	if (split_text.size() > 0):
		var command_string := split_text[0].to_lower()
		if (console_commands.has(command_string)):
			var command_entry : ConsoleCommand = console_commands[command_string]
			match command_entry.param_count:
				0:
					command_entry.function.call()
				1:
					command_entry.function.call(split_text[1] if split_text.size() > 1 else "")
				2:
					command_entry.function.call(split_text[1] if split_text.size() > 1 else "", split_text[2] if split_text.size() > 2 else "")
				3:
					command_entry.function.call(split_text[1] if split_text.size() > 1 else "", split_text[2] if split_text.size() > 2 else "", split_text[3] if split_text.size() > 3 else "")
				_:
					print_line("Commands with more than 3 parameters not supported.")
		else:
			emit_signal("console_unknown_command")
			print_line("Command not found.")


func on_line_edit_text_changed(new_text : String) -> void:
	reset_autocomplete()


func add_command(command_name : String, function : Callable, param_count : int = 0) -> void:
	console_commands[command_name] = ConsoleCommand.new(function, param_count)


func remove_command(command_name : String) -> void:
	console_commands.erase(command_name)


func quit() -> void:
	get_tree().quit()


func clear() -> void:
	rich_label.clear()


func delete_history() -> void:
	console_history.clear()
	console_history_index = 0
	DirAccess.remove_absolute("user://console_history.txt")


func help() -> void:
	rich_label.add_text("\
	\n\
	Built in commands:\n\
		'clear' : Clears the current registry view\n\
		'commands_list': Shows a list of all the currently registered commands\n\
		'delete_hystory' : Deletes the commands history\n\
		'quit' : Quits the game\n\
	Controls:\n\
		Up and Down arrow keys to navigate commands history\n\
		PageUp and PageDown to navigate registry history\n\
		Ctr+Tilde to change console size between half screen and full creen\n\
		Tilde or Esc to close the console\n\
		Tab for basic autocomplete\n\
	\n")


func commands_list() -> void:
	var commands := []
	for command in console_commands:
		commands.append(str(command))
	commands.sort()
	rich_label.add_text(str(commands) + "\n\n")


func add_input_history(text : String) -> void:
	if (!console_history.size() || text != console_history.back()): # Don't add consecutive duplicates
		console_history.append(text)
	console_history_index = console_history.size()


func _enter_tree() -> void:
	var console_history_file := FileAccess.open("user://console_history.txt", FileAccess.READ)
	if (console_history_file):
		while (!console_history_file.eof_reached()):
			var line := console_history_file.get_line()
			if (line.length()):
				add_input_history(line)


func _exit_tree() -> void:
	var console_history_file := FileAccess.open("user://console_history.txt", FileAccess.WRITE)
	if (console_history_file):
		var write_index := 0
		var start_write_index := console_history.size() - 100 # Max lines to write
		for line in console_history:
			if (write_index >= start_write_index):
				console_history_file.store_line(line)
			write_index += 1

