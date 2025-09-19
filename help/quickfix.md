# Quickfix plugin

Executes external command and shows the command output in qfix pane.
qfix pane allows to jump to the file location.

qfix pane has incremental search as you type. Use backtick to reset the search.

You can delete the search with `Backspace` or reset it completely with `DeleteWordLeft`.

## Options

quickfix exec [args]

    If args is not empty executes the arguments.
    Otherwise executes the current line.

Placeholders:

    {w} -- current word
    {s} -- current selection
    {o} -- byte offset
    {f} -- current file
    {l} -- current line
    {c} -- current position

quickfix jump

    Jumps between qfix pane and file locations.

quickfix prev

    Jumps to the location of the previous entry in the qfix pane.

quickfix next

    Jumps to the location of the next entry in the qfix pane.

quickfix help

    Opens **this** document in a horizontal split.

## Plugin Settings

quickfix.shellOpt (string)

    Allows you to declare the shell for executing the commands in `execArgs()`.
    By default, the command passed to the plugin is executed as it is provided;
    therefore, shell expansions, for example, are not performed. However, if
    "bash -c" is set as the option, the command will be executed as
    "bash -c [cmd]".

    Example: > quickfix exec grep -Hn {w} *.go
    By default, "*" will not be expanded, but if you use "bash -c" as `shellOpt`,
    it will.

## Example bindings

Jump to the file and back to qfix pane:

	"F3": "command:quickfix jump"

Exec current line:

	"F9": "command:quickfix exec"

Grep for the word under the cursor (requires [shellOpt](#plugin-settings) to enable shell expansion):

	"Alt-i": "command:quickfix exec grep -Hn {w} *.go"
