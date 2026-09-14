Editor Console uses GDSh for shell builtins (`builtins`) and gdsh_lib utils for
portable utilities (`utils`); editor-only utilities are under `misc editor_console`.
All are also directly callable hidden root commands; `hidden` lists the namespaces.
Run `help` or `<command> --help` for current metadata.

The console has these commands built in:

## config

```text
config # Adjust configuration of editor console.
	└── alias # Manage aliases in .gdrc file.
	└── command # Manage EditorConsole commands.
		└── new # Create a new command.
	└── open # Open config files:
	└── reload # Reload config from files and default/registered commands.
	└── scope # Adjust scope settings.
		└── dereg # De-register scope or scope set from EditorConsole.
		└── reg # Register scope or scope set.
	└── startup # Manage commands that run when the console starts.
	└── undo # Toggle whether mutating scene commands register on the editor undo stack.
```

## editor

```text
editor # Editor control commands (play, open, scan, …).
	└── open # Open a scene, script or resource in the editor.
	└── play # Run the project.
	└── plugin # Manage plugins in addons folder.
		└── enable # Enable/disable plugin state.
	└── redo # Redo the next action(s) in the edited scene's history, or the global history with --global.
	└── restart # Restart the Godot editor.
	└── reveal # Reveal a path in the FileSystem dock.
	└── scan # Rescan the project filesystem (picks up files added/removed outside the editor).
	└── scene # Edited scene commands (new/save/reload/root/select). For node commands, pipe 'editor scene root' or 'editor scene select' into 'tree'.
		└── new # Create a new scene file with a root node of the given class, and open it.
		└── reload # Reload the currently edited scene from disk, discarding unsaved changes.
		└── root # Print the edited scene root's absolute node path, to start a 'tree' command chain.
		└── save # Save the currently edited scene.
		└── select # Print the selected node paths, or select/deselect the node paths from stdin.
	└── screenshot # Capture the editor to a PNG and print its absolute path (so an agent can read it back).
	└── search # Search file contents across the project.
	└── state # Print a snapshot of the editor's current state (orientation for an agent):
	└── stop # Stop the running project.
	└── undo # Undo the last action(s) in the edited scene's history, or the global history with --global.
```

## misc

```text
misc # Misc commands.
	└── color_picker # Open a color picker in a window, selecting a color copies the html string to clipboard
	└── hide_log # Toggle the output log.
	└── run_gdsh # Run a gdsh script file in a subprocess.
```

## resource

```text
resource # Inspect and manipulate resource files.
	└── deps # List the resource dependencies of a file (one path per line, pipeable).
	└── duplicate # Duplicate a resource file to a new path.
	└── new # Create a new resource of a given class and save it.
	└── reload_script # Reload the passed scripts resources
	└── search # Find project files by name, or by file content with --content.
	└── uid # Convert between a resource path and its uid:// identifier.
```

## script

```text
script # Operates on the current script-editor script. --path=res://file.gd for a file, --class=MyClass for a global class.
	└── call # Call a static function in target script
	└── list # List properties of target script
	└── args # List arguments of method in target script
```

## settings

```text
settings # Get or set editor/project settings.
	└── esetting # Get or set an editor setting (EditorSettings).
	└── mainscene # Get or set the project's main scene.
	└── psetting # Get or set a project setting (ProjectSettings).
```

## tree

```text
tree # Read and change nodes in the SceneTree. Commands take absolute node paths on stdin, one per line,
	└── add # Add a new node under each stdin node and print the new absolute paths.
	└── attach # Attach a script to the stdin nodes.
	└── free # Remove the stdin nodes from the tree (undoable when the host provides undo, otherwise freed).
	└── group # Manage groups on the stdin nodes.
	└── inspect # List the properties of the stdin nodes, or of a resource given by path.
	└── instance # Instance a scene under each stdin node and print the new absolute paths.
	└── nodes # List the children of each stdin node, or all descendants with --recursive, one absolute path per line.
	└── pack # Save the first stdin node's subtree as a PackedScene file and print the file path (pipe into 'open').
	└── prop # Get or set a property on the stdin nodes.
	└── rename # Rename the one stdin node and print its new absolute path.
	└── reparent # Move the stdin nodes under a new parent (keeps global transform) and print their new absolute paths.
	└── root # Print the SceneTree root path (/root), to start a tree command chain.
```

## Builtins

```text
[ # Test/comparison command. Returns exit code.
break # Break out of the current loop. Only valid inside a gdsh loop.
cat # Print the contents of a text file to stdout.
cd # Change directory in console or os mode.
check # Validate that a script or scene loads, reporting 'path: OK' or 'path: ERROR (...)'.
class # Introspect an engine class or a user global class (API reference).
clear # Clear EditorLog
continue # Skip to the next iteration of the current loop. Only valid inside a gdsh loop.
convert_data # Convert data between: json <-> yaml <-> binary
count # Count stdin lines (default), words, or characters.
discard # Discards stdout of previous command.
echo # Echos arguments, similar to standard shell command.
exit # Exit process, propogation stops at current 'sub shell'.
expr # Run expression through Godot's Expression class.
false # Returns ExitCode.FAIL
find # Find files under the current directory by name (one path per line).
gdaddon # Launch a terminal with gdaddon running.
global # Execute command on global script, or on global class data.
	└── registry # Manage classes that show in autocomplete.
	└── print_list # List global classes
grep # Keep stdin lines matching a pattern (substring by default).
head # Output the first N lines of stdin (default 10).
help
ls # List files and directories under a project directory (one path per line).
math # Run expression through Godot's Expression class.
mcp # Commands for the Editor Console MCP server.
	└── add # Add the EditorConsole MCP to a coding agent.
		└── claude # Add mcp exec to Claude Code in the project directory.
		└── kimi # Add mcp exec to Kimi Code in the project directory.
	└── bridge # Control the external command bridge (loopback TCP listener for the Go MCP server / CLI).
	└── exec_path # Set the exec path for the EditorConsole mcp server binary.
	└── generate_command_doc # Generate a markdown command-tree doc (commands.md style) and print it.
	└── list_commands # List all available console commands, with a usage preamble.
	└── remove # Remove the EditorConsole MCP from coding agent
		└── claude # Remove mcp from Claude Code in the project directory.
		└── kimi # Remove mcp from Kimi Code in the project directory.
mkdir # Create a directory (recursively) in the project.
mv # Move or rename a file/directory in the project.
open # Reveal a project directory in the OS file manager.
os # All commands after the 'os' prefix are ran via OS.execute with stdin if piped.
pwd # Print current working directory.
realpath # Convert relative path to full path, globalized or local.
return # Return value code for function.
scan # Search scripts for a pattern, reporting only UNCOMMENTED matches (code that will run).
shift # Drop the first positional argument of the parent command (gdsh argument shifting).
source # Run script in the current process.
strip_edges # Strip edges of stdin.
tail # Output the last N lines of stdin (default 10).
term # Launch an OS terminal in a project directory.
test # Run selected tests in directory. '...' indicates recursive.
trash # Move files/directories to the OS trash (recoverable).
true # Returns ExitCode.OK
xargs # Passes stdin as arguments to the following command(s).
```
