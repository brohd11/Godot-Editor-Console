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
	└── stream # Toggle whether command output appears in the console as it is produced.
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

## format

```text
format # Formatting tools for the script open in the editor.
	└── bundle # Load preloads into the current script.
	└── infer # Attempt to infer the variable type of all variables declared in the open script.
	└── text # Write the open script-editor buffer to stdout, including unsaved edits.
```

## misc

```text
misc # Misc commands.
	└── color_picker # Open a color picker in a window, selecting a color copies the html string to clipboard
	└── convert_data # Convert data between: json <-> yaml <-> binary
	└── editor_console # Utility commands, all subcommands also accessible directly by name.
		└── gdaddon # Launch a terminal with gdaddon running.
		└── hide_log # Toggle the output log.
		└── mcp # Commands for the Editor Console MCP server.
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
		└── os # Run an OS command. $name/$(...) expand in GDSh; $$name/$$(...) pass to the shell. Bare os toggles interactive OS mode.
		└── term # Launch an OS terminal in a project directory.
		└── test # Run selected tests in directory. '...' indicates recursive. Relative paths fall back to
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
	└── duplicate # Duplicate the stdin nodes next to themselves and print the new absolute paths.
	└── free # Remove the stdin nodes from the tree (undoable when the host provides undo, otherwise freed).
	└── group # Manage groups on the stdin nodes.
	└── index # Print the child index of each stdin node, or move the nodes to an index within their parent.
	└── inspect # List the properties of the stdin nodes, or of a resource given by path.
	└── instance # Instance a scene under each stdin node and print the new absolute paths.
	└── nodes # List the children of each stdin node, or all descendants with --recursive, one absolute path per line.
	└── pack # Save the first stdin node's subtree as a PackedScene file and print the file path (pipe into 'open').
	└── parent # Get the node's parent's path.
	└── prop # Get or set a property on the stdin nodes, printing each node's value one per line.
	└── rename # Rename the one stdin node and print its new absolute path.
	└── reparent # Move the stdin nodes under a new parent (keeps global transform) and print their new absolute paths.
	└── root # Print the SceneTree root path (/root), to start a tree command chain.
```

## Builtins

```text
[ # Test/comparison command. Returns exit code.
break # Break out of the current loop. Only valid inside a gdsh loop.
cat # Print the contents of a text file to stdout.
cd # Change the GDSh context working directory.
check # Validate that a script or scene loads, reporting 'path: OK' or 'path: ERROR (...)'.
class # Introspect an engine class or a user global class (API reference).
clear # Clear the console output.
cn # Change the GDSh working node, the base for relative node paths (as cd is for file paths).
continue # Skip to the next iteration of the current loop. Only valid inside a gdsh loop.
count # Count stdin lines (default), words, or characters.
echo # Echos arguments, similar to standard shell command.
exit # Exit process, propogation stops at current 'sub shell'.
expr # Run expression through Godot's Expression class.
false # Returns ExitCode.FAIL
find # Find files under the current directory by name (one path per line).
gdaddon # Launch a terminal with gdaddon running.
gdsh # Run a .gdsh script in a subshell, with its own $0, $1 and $#.
grep # Keep stdin lines matching a pattern (substring by default).
head # Output the first N lines of stdin (default 10).
help # List available visible and hidden GDSh commands.
hide_log # Toggle the output log.
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
new_ctx # Reset the console session (variables, functions, aliases, cwd).
node # Target a node in the SceneTree. Paths are absolute, or relative to the working node (see cn).
	└── call # Call a static script method or a method on a live node
	└── list # List members of the target script or live node
	└── args # List the arguments of a method on the target script or node
	└── get_path # Print a script's resource path or a live node's absolute path.
open # Reveal a project directory in the OS file manager. Desktop platforms only.
os # Run an OS command. $name/$(...) expand in GDSh; $$name/$$(...) pass to the shell. Bare os toggles interactive OS mode.
pwd # Print current working directory.
realpath # Convert relative path to full path, globalized or local.
return # Return value code for function.
scan # Search scripts for a pattern, reporting only UNCOMMENTED matches (code that will run).
script # Target a GDScript: a global class name, a res:// / user:// / absolute path, or a path relative
	└── args # List the arguments of a method on the target script or node
	└── call # Call a static script method or a method on a live node
	└── get_path # Print a script's resource path or a live node's absolute path.
	└── list # List members of the target script or live node
shift # Drop the first positional argument of the parent command (gdsh argument shifting).
source # Run script in the current process.
str # String ops on one text argument or on each stdin line.
	└── basedir # Directory part of a path (String.get_base_dir).
	└── basename # Path without its extension; the directory is kept (String.get_basename).
	└── begins_with # Keep inputs that begin with a prefix; -b only sets the exit code.
	└── contains # Keep inputs that contain a substring; -b only sets the exit code.
	└── ends_with # Keep inputs that end with a suffix; -b only sets the exit code.
	└── extension # Extension of a path, without the dot (String.get_extension).
	└── file # File name of a path, with extension (String.get_file).
	└── join # Append a path segment (String.path_join).
	└── length # Character count of each input (String.length). For whole-stdin counts use 'count'.
	└── lower # Lowercase (String.to_lower).
	└── replace # Replace every occurrence of a substring (String.replace).
	└── slice # Field of a string split by a delimiter.
	└── strip_edges # Strip whitespace from both ends of each input (String.strip_edges).
	└── trim_prefix # Remove a prefix if present (String.trim_prefix).
	└── trim_suffix # Remove a suffix if present (String.trim_suffix).
	└── upper # Uppercase (String.to_upper).
tail # Output the last N lines of stdin (default 10).
term # Launch an OS terminal in a project directory.
test # Run selected tests in directory. '...' indicates recursive. Relative paths fall back to
trash # Move files/directories to the OS trash (recoverable). Desktop platforms only.
true # Returns ExitCode.OK
undoredo # Group the undoable changes of several commands into one undo entry.
xargs # Passes stdin as arguments to the following command(s).
```
