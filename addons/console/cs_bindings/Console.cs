using Godot;
using Godot.Collections;

public partial class Console : Node{
    static GodotObject console = (GodotObject)GD.Load<GDScript>("uid://ouiu5xh1cs8n").New();

    public static bool Enabled{ get{return console.Get("enabled").AsBool();} }
    public static bool EnabledOnReleaseBuild{ get{return console.Get("enabled_on_release_build").AsBool();} }
    public static bool PauseEnabled{ get{return console.Get("pause_enabled").AsBool();} set{console.Set("pause_enabled", value);} }
    public static int FontSize{ get{return console.Get("font_size").AsInt32();} set{console.Set("font_size", value);} }

    public static RichTextLabel RichLabel{ get{return (RichTextLabel)console.Get("rich_label").AsGodotObject();} set{console.Set("rich_label", value);} }
    public static LineEdit LineEdit{ get{return (LineEdit)console.Get("line_edit").AsGodotObject();} set{console.Set("line_edit", value);} }

    public override void _Ready(){
        AddChild((Node)console);
    }

    public static void ConnectConsoleOpened(Callable callable) => console.Connect("console_opened", callable);
    public static void DisconnectConsoleOpened(Callable callable) => console.Disconnect("console_opened", callable);
    public static void ConnectConsoleClosed(Callable callable) => console.Connect("console_closed", callable);
    public static void DisconnectConsoleClosed(Callable callable) => console.Disconnect("console_closed", callable);
    public static void ConnectConsoleUnknownCommand(Callable callable) => console.Connect("console_unknown_command", callable);
    public static void DisconnectConsoleUnknownCommand(Callable callable) => console.Disconnect("console_unknown_command", callable);

    public static void AddCommand(string commandName, Callable function, Array<string> arguments, int required = 0, string description = "") => console.Call("add_command", commandName, function, arguments, required, description);
    public static void AddHiddenCommand(string commandName, Callable function, Array<string> arguments, int required) => console.Call("add_hidden_command", commandName, function, arguments, required);
    public static void RemoveCommand(string commandName) => console.Call("remove_command", commandName);
    public static void AddCommandAutocompleteList(string commandName, string[] paramList) => console.Call("add_command_autocomplete_list", commandName, paramList);
    public static void Disable() => console.Call("disable");
    public static void Enable() =>console.Call("enable");
    public static void ToggleConsole() => console.Call("toggle_console");
    public static void IsVisible() => console.Call("is_visible");
    public static void ScrollToBottom() => console.Call("scroll_to_bottom");
    public static void PrintError(Variant text, bool printGodot = false) => console.Call("print_error", text, printGodot);
    public static void PrintInfo(Variant text, bool printGodot = false) => console.Call("print_info", text, printGodot);
    public static void PrintWarning(Variant text, bool printGodot = false) => console.Call("print_warning", text, printGodot);
    public static void PrintLine(Variant text, bool printGodot = false) => console.Call("print_line", text, printGodot);
    public static void SetEnableOnReleaseBuild(bool enable) => console.Call("set_enable_on_release_build", enable);

    /*
    public static void Autocomplete() => console.Call("autocomplete");
    public static void ResetAutocomplete() => console.Call("reset_autocomplete");
    public static void ToggleSize() => console.Call("toggle_size");
    public static string[] ParseLineInput(string text){ return console.Call("parse_line_input", text).AsStringArray(); }
    public static void Quit() => console.Call("quit");
    public static void Clear() => console.Call("clear");
    public static void DeleteHistory() => console.Call("delete_history");
    public static void Help() => console.Call("help");
    public static void Calculate() => console.Call("calculate");
    public static void Commands() => console.Call("commands");
    public static void CommandsList() => console.Call("commands_list");
    public static void Pause() => console.Call("pause");
    public static void Unpause() => console.Call("unpause");
    public static void Exec(string fileName) => console.Call("exec", filename);
    */
}