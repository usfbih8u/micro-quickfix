# Quickfix plugin for micro editor

> ❗ Fork from [original plugin](https://github.com/serge-v/micro-quickfix) by @serge-v.

Quickfix is a plugin to speedup edit-make-edit development cycle.
It is similar to quickfix window in VIM editor.

You can execute an external command, examine the output in qfix pane
and toggle between list of positions and file locations.

qfix pane supports incremental search and jumps to the first match as you type.
Use backtick to cancel the search.

You can delete the search with `Backspace` or reset it completely with `DeleteWordLeft`.

Plugin added to the micro plugin channel:
https://github.com/micro-editor/plugin-channel

## Installation

In micro editor press Ctrl+E and run command:

	plugin install quickfix

## Commands

### quickfix exec [args]

If args list is empty `quickfix exec` executes the current line.
Otherwise `quickfix exec` replaces argument placeholders and executes the arguments.

Placeholders:

	{w} -- current word
	{s} -- current selection
	{o} -- byte offset
	{f} -- current file
    {l} -- current line
    {c} -- current position

Binding examples:

Run make:

	"F8": "command:quickfix exec make"

Grep for word under cursor:

	"F7": "command:quickfix exec grep -n {w} *.go"

Show go doc for selected pkgname.Entity:

	"F8": "command:quickfix exec go doc {s}"

List all declarations in go file:

	"Alt-t": "command:quickfix exec motion -file {f} -mode decls -include func -format text",

### quickfix jump

**Set parsecursor=true in config to enable jumping to the file location.**

Jumps to the file under cursor and back.

### quickfix prev

Jumps to the location of the previous entry in the qfix pane.

### quickfix next

Jumps to the location of the next entry in the qfix pane.