Below will be an example of the command flow and some functions that you can overide in the Command object.

Consider the input `my_command --flag arg`. The `my_command` object would consume itself, then start checking the rest of the unconsumed tokens. If `--flag` is recognized as a command, the corresponding command object would be instanced and receive `--flag arg` tokens to process. In this case, it is recognized as a flag, the token is consumed and the flag is sent to `_process_flag` where it may set a variable or something. `arg` is not recognized as a flag or command, the rest of the unconsumed tokens are appended to `positional_args` and `_execute` is called.

The console will continue to iterate over the tokens until it can't any more, then call `_execute` in the final object it can reach.

By using the recommended folder structure, you really don't need to overide much to get a functioning tree of commands. The only necessary functions to overide are `get_command_name`, ``
`get_self_command_data`, and/or `_execute`. Even these are not strictly necessary if the command is just a passthrough node with no execution, but the base class will print messages if they aren't defined. See below:

### variables available from the base class
```
## the base class can be found in EditorConsoleSingleton
extends EditorConsoleSingleton.CommandBase

## Positional args are populated once tokens cannot be consumed anymore
var positional_args = []

## Current positional arg the caret is on. Can be used for completion 
var positional_arg_index = -1

## Some functions receive a CompletionContext object as an argument. This stores data such as, unconsumed tokens, raw input text, caret column. It also has a dictionary, 'data', that can be used to send non-String variables from command to command.
ctx:CompletionContext
```
### standard overides - these should be overidden in every class
```
## How you will call the command
static func get_command_name() -> String:
	return "command"


## Return a dictionary with some assorted parameters. These are used by the base class to display help when needed, check positional arg count, etc.
## Using the _command_data function will structure the params to be used with the autocomplete system, as well as provide autocompletion for the paramater keys if you use my "CodeCompletions" plugin.

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": "Help for this command",
		&"positional_count": 1,
	})


## This is optional if the command doesn't actually execute code. For example a top-level command that just has 3 subcommands.
## This will be called once all consumable tokens have been processed.

func _execute(ctx:CompletionContext):
	var my_arg = positional_args[0]
	# your command logic here

```
### optional overides
```
## Called by 'get_flags', overide to provide flags. Base logic provides none.
## Example below, Options object processes data in the same way as 'get_self_command_data'.

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--my_flag", {
		&"help": "What does it do?"
	})
	return options.get_options() # returns a processed dictionary


## Flags from '_get_flags' will be sent here so that they can manipulate anything needed.
func _process_flag(flag:String)


## Called by 'get_commands', overide this to provide custom commands. Base logic will call '_get_commands_in_dir' and provide the next level of commands in the directory tree.
# This can use the same 'Options' object as above
func _get_commands() -> Dictionary


## Overide this to provide completions beyond just flags and commands.
## This is the base logic for this function. When passing 'true' through 'get_flags', any flags already typed will be excluded.

func _get_completions(ctx:CompletionContext):
	if not _positional_arg_index_valid():
		return {}
	var options = get_flags(true)
	options.merge(get_commands(true))
	return options


## If a command's 'get_command' param is not set, it will send the token here to attempt to get it. Commands populated via 'get_commands_in_dir' have the param set automatically. This should return an instance of the target command object.
func _get_command(command:String)


## If 'help' param is not set, the token will be passed here to attempt to get a help message.
func _get_help(what:String)


## This won't be overidden in 99% of cases
## Can be used to handle more advanced tokens, for example 'script' command can take a path. 'script.InnerClass' This function would be were that would be processed
func _consume_self(ctx:CompletionContext) -> ExitCode
```
### utility functions
```
## Get all commands in the current files children directories
func _get_commands_in_dir(sort_priority:=true)


## Before '_execute' is called, the positional arg count will be checked against the amount provided by 'get_self_command_data'. If none is provided it expects 0 arguments.
## Overide to change this based on flags
func _get_target_positional_count() -> int


## Prints commands returned by 'get_commands'
func print_available_commands()


## Calls a GDScript callable. This is used by the 'call' command. Arguments passed as String will attempt to be converted to the function argument type ie. "true" -> bool, "1" -> int, etc. If 'create_default_args' is true, any args missing will be passed as default values.
static func _call_method(callable:Callable, args:Array, create_default_args:=false)

```