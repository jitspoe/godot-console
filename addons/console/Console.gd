extends Node


signal console_opened
signal console_closed
signal console_unknown_command


class ConsoleCommand:
	var function
	var param_count
	func _init(in_function, in_param_count):
		function = in_function
		param_count = in_param_count


@onready var control := Control.new()
@onready var rich_label := RichTextLabel.new()
@onready var line_edit := LineEdit.new()

var console_commands := {}
var console_history := []
var console_history_index := 0


func _ready():
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
	line_edit.text_submitted.connect(Callable(self, "on_text_entered"))
	control.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_command("quit", self, "quit", 0)
	add_command("exit", self, "quit", 0)


func _input(event : InputEvent):
	if (event is InputEventKey):
		if (event.get_physical_keycode_with_modifiers() == 96): # Reverse-nice.  Also ~ key.
			if (event.pressed):
				toggle_console()
			get_viewport().set_input_as_handled()
		elif (event.get_physical_keycode_with_modifiers() == KEY_ESCAPE && control.visible): # Disable console on ESC
			if (event.pressed):
				toggle_console()
				get_viewport().set_input_as_handled()
	if (control.visible):
		if (Input.is_action_just_pressed("ui_up")):
			get_tree().set_input_as_handled()
			if (console_history_index > 0):
				console_history_index -= 1
				if (console_history_index >= 0):
					line_edit.text = console_history[console_history_index]
					line_edit.caret_position = line_edit.text.length()
		if (Input.is_action_just_pressed("ui_down")):
			if (console_history_index < console_history.size()):
				console_history_index += 1
				if (console_history_index < console_history.size()):
					line_edit.text = console_history[console_history_index]
					line_edit.caret_position = line_edit.text.length()
				else:
					line_edit.text = ""


func toggle_console():
	control.visible = !control.visible
	if (control.visible):
		get_tree().paused = true
		line_edit.clear()
		line_edit.grab_focus()
		emit_signal("console_opened")
	else:
		get_tree().paused = false
		emit_signal("console_closed")


func print_line(text : String):
	if (!rich_label): # Tried to print something before the console was loaded.
		call_deferred("print_line", text)
	else:
		rich_label.add_text(text)
		rich_label.add_text("\n")


func on_text_entered(text : String):
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


func add_command(command_name : String, object : Object, function_name : String, param_count : int = 0):
	console_commands[command_name] = ConsoleCommand.new(Callable(object, function_name), param_count)


func remove_command(command_name : String):
	console_commands.erase(command_name)


func quit():
	get_tree().quit()


func add_input_history(text : String):
	if (!console_history.size() || text != console_history.back()): # Don't add consecutive duplicates
		console_history.append(text)
	console_history_index = console_history.size()


func _enter_tree():
	var console_history_file := File.new()
	if (console_history_file.open("user://console_history.txt", File.READ) == OK):
		while (!console_history_file.eof_reached()):
			var line := console_history_file.get_line()
			if (line.length()):
				add_input_history(line)
		console_history_file.close()


func _exit_tree():
	var console_history_file := File.new()
	if (console_history_file.open("user://console_history.txt", File.WRITE) == OK):
		var write_index := 0
		var start_write_index := console_history.size() - 100 # Max lines to write
		for line in console_history:
			if (write_index >= start_write_index):
				console_history_file.store_line(line)
			write_index += 1
		console_history_file.close()

