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

To add autocomplete for multiple parameters, call `Console.add_command_autocomplete_list(...)` multiple times with the `param_index` parameter set. Note, that the parameter index starts at 1, meaning the first parameter has the index 1 the second the index 2 and so on.

```gdscript
func _ready() -> void:
	Console.add_command("set_arrow", command_set_arrow, ["direction", "color"], 2)

	# autocomplete for "direction"
	Console.add_command_autocomplete_list("set_arrow", ["up", "down", "left", "right"], 1)

	# autocomplete for "color"
	Console.add_command_autocomplete_list("set_arrow", ["red", "yellow", "green", "blue"], 2)
	
func command_set_arrow(direction: String, color: String) -> void:
	...
```

## C#

If you prefer to use C#, you might want to check out the C# console by Moliko here, but it's not currently being maintained: https://github.com/MolikoDeveloper/Csharp-Console-Godot

C# bindings were also contributed to work with this GDScript version, but I don't use C# so I can't vouch for if they work or not.

## Console variables (cvars)

A cvar is a named value you can read and change from the console. Type the cvar's name and press
enter to print its current value, or type the name followed by a value to set it. The value you type
is coerced to the cvar's type.

There are two ways to register a cvar.

**Auto-managed** — the console stores the value for you. The type is taken from the default value.
Pass `true` as the last argument to persist the value to `user://console_cvars.txt` between sessions:

```gdscript
func _ready():
	# add_cvar(name, default_value, description, save)
	Console.add_cvar("cl_fov", 90.0, "Field of view.", true)

func _process(_delta):
	camera.fov = Console.get_cvar("cl_fov")
```

**Reference** — the cvar reads from and writes to a property on another object. The type is inferred
from the property's current value. The property may be a nested path (ex: `"position:x"`):

```gdscript
func _ready():
	# add_cvar_reference(name, object, property, description, save)
	Console.add_cvar_reference("cl_fov", $Camera3D, "fov", "Camera field of view.")
```

In the console:

```
> cl_fov
cl_fov = 90
> cl_fov 110
cl_fov = 110
```

Supported types are `bool` (`1`/`0`, `true`/`false`, `on`/`off`, `yes`/`no`), `int`, `float`,
`String`, and `StringName`. Other types (ex: `Vector2`) can be set using GDScript literal syntax,
e.g. `cl_offset Vector2(1, 2)`. Invalid input prints an error instead of silently zeroing the value.

Useful helpers:

```gdscript
Console.get_cvar("cl_fov")          # Read the value from code
Console.set_cvar("cl_fov", 100.0)   # Set the value from code (no string coercion)
Console.remove_cvar("cl_fov")       # Unregister (call on _exit_tree for reference cvars)
Console.console_cvar_changed        # signal(cvar_name, value) emitted whenever a cvar changes
```

The `cvars` console command lists every registered cvar with its current value. Cvar names also show
up in tab autocomplete.
