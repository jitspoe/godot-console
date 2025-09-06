# godot-console
Dev console addon for Godot engine.

Simply drop the addons directory into your godot project, go to the project settings, plugins, and enable "Console".

After you've done that, you can add console commands from any class.

Example:

```gdscript
func _ready():
  Console.add_command("hello", my_hello_function)

func my_hello_function():
  Console.print_line("Hello, world!")
```

You can also specify up to 3 parameters, which will be passed in as strings:

```gdscript
  Console.add_command("param_test", param_test_function, 1) # 1 specifies 1 parameter

func param_test_function(param1 : String):
  Console.print_line("Param passed in: %s" % param1)
```

The "quit"/"exit" command is implemented by default.

By default the console does not pause the tree. If this is undesirable behaviour to you, you can change that behaviour by setting the `pause_enabled` variable accordingly.

```gdscript
func _ready():
  Console.pause_enabled = true
  # Console will now pause the tree when being opened
```

You can also specify font size in the console:
```gdscript
# Set font size to 18
Console.font_size = 18 

# Reset to default font size
Console.font_size = -1
```

It's also possible to add autocomplete for a parameter.  Here's an example for how I do autocomplete for a level loading "map" command:

```gdscript
func _ready():
	Console.add_command("map", load_level, ["Level name"])
	# Note that for things to work in exported release builds, we need to use ResourceLoader instead of DirAccess
	var level_file_list := ResourceLoader.list_directory("res://levels")
	for level_file_name in level_file_list:
		var extension := level_file_name.get_extension()
		# For editor builds
		if (extension == "tscn"):
			all_levels.append(level_file_name.get_basename())
	Console.add_command_autocomplete_list("map", all_levels)

var level_instance : Node

func load_level(map_name : String):
	# Do your level loading logic here.  This is just a simplified version of what I do.
	var res : PackedScene = load("res://levels/%s.tscn" % level_name)
	if (res):
		if (level_instance):
			level_instance.queue_free()
		level_instance = res.instantiate()
		add_child(level_instance)
```

Currently, parameter autocomplete only supports 1 parameter.

If you prefer to use C#, you might want to check out the C# console by Moliko here, but it's not currently being maintained: https://github.com/MolikoDeveloper/Csharp-Console-Godot

C# bindings were also contributed to work with this GDScript version, but I don't use C# so I can't vouch for if they work or not.
