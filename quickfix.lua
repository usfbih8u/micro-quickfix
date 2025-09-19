VERSION = "2.1.2"

local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local shell = import("micro/shell")
local strings = import("strings")
local regexp = import("regexp")
local filepath = import("filepath")
local go_os = import("os")

local qfix = {
    paneName = "qfix",
    pane = nil,
    neverJumped = false,
    paneTabIdx = 0,
}

local regexes = {
    "[^:]+:[0-9]+:[0-9]+:?",
    "[^:]+:[0-9]+:?",
    "[^:]+:",
    "[^ \t].*",
}

local function log(...)
    -- micro.Log("[quickfix]", unpack(arg))
end

function execExit(output, _)
    if qfix.pane ~= nil then
        qfix.pane:Quit()
    end

    if output == "" then return end

    local b = buffer.NewBuffer(output, qfix.paneName)
    b.Type.Scratch = true
    b.Type.Readonly = true
    micro.CurPane():HSplitIndex(b, true)
    qfix.pane = micro.CurPane()
    qfix.neverJumped = true
    qfix.paneTabIdx = micro.Tabs():Active()
end

function execCurrentLine(bp)
    local c = bp.Cursor
    local cmd = bp.Buf:Line(c.Y)
    log("quickfix exec: " .. cmd)
    if #cmd == 0 then
        micro.InfoBar():Error("current line is empty")
        return
    end
    local s, err = shell.RunCommand(cmd)
    execExit(s, nil)
    if err ~= nil then
        micro.InfoBar():Error(err:Error())
    else
        micro.InfoBar():Message("")
    end
end

function execArgs(bp, args)
    local c = bp.Cursor
    local cmd = strings.Join(args, " ")

    if strings.Contains(cmd, "{s}") then
        if c:HasSelection() then
            local sel = c:GetSelection()
            cmd = strings.Replace(cmd, "{s}", sel, 1)
        end
    end

    if strings.Contains(cmd, "{w}") then
        if not c:HasSelection() then
            c:SelectWord()
        end
        local sel = c:GetSelection()
        cmd = strings.Replace(cmd, "{w}", sel, 1)
    end

    cmd = strings.Replace(cmd, "{f}", c:Buf().AbsPath, 1)

    local loc = buffer.Loc(c.X, c.Y)
    local offs = buffer.ByteOffset(loc, c:Buf())
    cmd = strings.Replace(cmd, "{o}", tostring(offs), 1)
    cmd = strings.Replace(cmd, "{l}", tostring(c.Y + 1), 1)
    cmd = strings.Replace(cmd, "{c}", tostring(c.X + 1), 1)

    local s, err
    local microShellOpt = "quickfix.shellOpt"
    local shellOpt = config.GetGlobalOption(microShellOpt)
    if type(shellOpt) == "string" and shellOpt ~= "" then --not empty string
        local cmdMsg = ("quickfix exec: (%s) %s"):format(shellOpt, cmd)
        micro.InfoBar():Message(cmdMsg) -- log command before execute
        log(cmdMsg)
        local shellCmd = {}
        for word in shellOpt:gmatch("%S+") do table.insert(shellCmd, word) end
        table.insert(shellCmd, cmd) -- NOTE: exec(unpack(shellCmd), cmd) doesn't work
        s, err = shell.ExecCommand(unpack(shellCmd))

    elseif shellOpt == nil then
        local cmdMsg = "quickfix exec: " .. cmd
        micro.InfoBar():Message(cmdMsg)
        log(cmdMsg)
        s, err = shell.RunCommand(cmd)

    else
        micro.InfoBar()
            :Error(("quickfix: invalid '%s'; MUST be a non-empty string")
            :format(microShellOpt))
        return
    end

    execExit(s, nil)
    if err ~= nil then
        micro.InfoBar():Error("quickfix exec: " .. err:Error())
    else
        micro.InfoBar():Message("quickfix exec: succeed")
    end
end

function execLine(bp, args)
    local name = ""
    local p = micro.CurPane()
    if p ~= nil then
        name = p:Name()
    end
    if name == qfix.paneName then -- close and reset `qfix`
        qfix.pane:Quit()
        qfix.pane = nil
        qfix.neverJumped = false
        return
    end

    if #args > 0 then
        execArgs(bp, args)
    else
        execCurrentLine(bp)
    end
end

function jumpToFile(bp, _)
    local name = ""
    local p = micro.CurPane()
    if p ~= nil then name = p:Name() end

    if name ~= qfix.paneName and qfix.pane then
        micro.InfoBar():Message("quickfix jump: back to qfix pane" )
        micro.Tabs():SetActive(qfix.paneTabIdx)
        qfix.pane:SetActive(true)
        return
    end

    local c = bp.Cursor
    local line = bp.Buf:Line(c.Y)
    log("jump to " .. line)

    local arr = strings.Split(line, ":")
    if #arr == 0 then
        micro.InfoBar():Error("no filename at current pos")
        return
    end

    local _, err = go_os.Stat(arr[1])
    if err ~= nil then
        micro.InfoBar():Error("no filename at current pos")
        return
    end

    local fname = ""
    for _, regex in ipairs(regexes) do
        fname = regexp.MustCompile(regex):FindString(line)
        if fname ~= "" then
            fname = strings.TrimSuffix(fname, ":")
            break
        end
    end

    if fname == "" then
        micro.InfoBar():Error("no filename at current pos")
        return
    end

    local plainfname = strings.Split(fname, ":")[1]
    local absfname = filepath.Abs(plainfname)
    local absfnameWithPos = absfname .. strings.TrimPrefix(fname, plainfname)
    log("plainfname:", plainfname, "absfnameWithPos:", absfnameWithPos)
    micro.InfoBar():Message("quickfix jump: " .. fname)

    local tabs = micro.Tabs()
    for i = 1, #tabs.List do
        for j = 1, #tabs.List[i].Panes do
            local panename = tabs.List[i].Panes[j]:Name()
            local absname = tabs.List[i].Panes[j].Buf.AbsPath
            log("tab", i, "pane", i, "absname", absname)
            if absfname == absname then
                log("set active:", panename)
                tabs:SetActive(i - 1)
                tabs.List[i]:SetActive(j - 1)
                tabs.List[i].Panes[j]:SetActive(true)
                tabs.List[i].Panes[j]:HandleCommand("open " .. absfnameWithPos)
                return
            end
        end
    end

    log("fname: " .. absfnameWithPos)
    qfix.neverJumped = false
    bp:HandleCommand("tab " .. absfnameWithPos)
    bp:Center()
end

local DIRECTION = { PREV = -1, NEXT = 1 }

function jumpToEntry(bp, direction)
    if qfix.pane == nil then
        micro.InfoBar():Error("quickfix: no qfix pane")
        return
    end

    local limit
    if     direction == DIRECTION.PREV then limit = -1
    elseif direction == DIRECTION.NEXT then limit = qfix.pane.Buf:LinesNum()
    else error("quickfix: invalid direction for jumpToEntry") end

    local cursor = qfix.pane.Cursor
    local neverJumped = qfix.neverJumped
    local startingLine = qfix.neverJumped == true and cursor.Y or cursor.Y + direction
    qfix.neverJumped = false -- set to false now in case we return early.

    if startingLine == limit then
        micro.InfoBar():Error(
            ("quickfix: no %s entry in quickfix list"):format(
                direction == DIRECTION.PREV and "previous" or "next"
        ))
        return
    end

    -- Search new valid line in the 'direction'
    local fname = ""
    for i = startingLine, limit, direction do
        cursor.Y = i -- always update
        local line = qfix.pane.Buf:Line(i)
        local splits = strings.SplitN(line, ":", 2)

        if #splits > 0 then -- line candidate
            local _, err = go_os.Stat(splits[1])
            if not err then -- 1st split is a file
                -- NOTE: (-2) Ignore the last 2 regexes to avoid to stop in
                -- errors/warnings without row and column
                for j = 1, #regexes - 2 do
                    local rex = regexp.MustCompile(regexes[j])
                    fname = rex:FindString(line)
                    if fname ~= "" then
                        fname = strings.TrimSuffix(fname, ":")
                        break
                    end
                end
                if fname ~= "" then break end
            end
        end
    end

    if fname == "" then -- No file was found inside the loop
        micro.InfoBar():Error(
            ("quickfix: no %s entry in quickfix list"):format(
                direction == DIRECTION.PREV and "previous" or "next"
        ))
        return
    end

    local plainfname = strings.Split(fname, ":")[1]
    local plainfnameWithPos = plainfname .. strings.TrimPrefix(fname, plainfname)
    log("plainfname:", plainfname, "plainfnameWithPos:", plainfnameWithPos)
    micro.InfoBar():Message(
        ("quickfix %s: %s"):format(direction == DIRECTION.PREV and "prev" or "next", fname)
    )

    -- NOTE: If we are in the same tab as `qfixPane` and `fjump_next` or `fjump_prev` are
    -- used, then another tab is created to open the necessary buffers there. This way,
    -- the panes in the same tab as `qfix.pane` are not modified.
    log("fname: " .. plainfnameWithPos)
    if qfix.pane == micro.CurPane() or neverJumped then --same tab as `qfix.pane`
        bp:HandleCommand("tab "..plainfnameWithPos)
    elseif not neverJumped then
        if bp.Buf.Path == plainfname then
            local linenum = plainfnameWithPos:sub(#plainfname + 2, #plainfnameWithPos)
            bp:HandleCommand("goto " .. linenum)
        else
            bp:HandleCommand("open " .. plainfnameWithPos)
        end
    end
    bp:Center()
end

function jumpToPrevEntry(bp, _) jumpToEntry(bp, DIRECTION.PREV) end
function jumpToNextEntry(bp, _) jumpToEntry(bp, DIRECTION.NEXT) end

function onQuit(p)
    if p == qfix.pane then
        qfix.pane = nil
        qfix.neverJumped = false
    end
end

local pattern = ""

function preBackspace(bp)
    if bp ~= qfix.pane then return true end
    pattern = pattern:sub(1, -2)
    micro.InfoBar():Message("search (backtick to cancel): " .. pattern)
    return false
end

-- Resets the pattern directly; it does not perform `DeleteWordLeft`.
function preDeleteWordLeft(bp)
    if bp ~= qfix.pane then return true end
    pattern = ""
    micro.InfoBar():Message("search (backtick to cancel): ")
    return false
end

function preInsertNewline(bp)
    if bp ~= qfix.pane then return true end
    jumpToFile(bp)
    return false
end

function onRune(bp, r)
    if bp ~= qfix.pane then return end
    -- This maintains qfix as qfix, solving issues with buffer replacements
    if qfix.pane:Name() ~= qfix.paneName then
        qfix.pane = nil
        return
    end

    local s = tostring(r)
    if s == "`" then -- reset pattern
        qfix.pane.Buf.HighlightSearch = false
        pattern = ""
        micro.InfoBar():Message("")
        return
    end

    pattern = pattern .. s
    log("pattern: " .. pattern)
    micro.InfoBar():Message("search (backtick to cancel): " .. pattern)

    local cursor = qfix.pane.Cursor
    local from = buffer.Loc(cursor.X, cursor.Y)
    local buf = qfix.pane.Buf
    local match, found, _ = buf:FindNext(
        pattern, buf:Start(), buf:End(), from, --[[down]]true, --[[useRegex]] false
    )
    if not found then return end

    buf.LastSearch = pattern
    buf.LastSearchRegex = false
    buf.HighlightSearch = true

    cursor:GotoLoc(buffer.Loc(0, match[1].Y))
    qfix.pane:Relocate()
end

local qfixCmds = {
    ["exec"] = execLine,
    ["jump"] = jumpToFile,
    ["next"] = jumpToNextEntry,
    ["prev"] = jumpToPrevEntry,
    ["help"] = function (bp, _)
        assert(bp, "bp MUST NOT be nil")
        bp:HandleCommand("help quickfix")
    end,
}

local function qfixCompleter(buf)
    local opts = {}

    --Do NOT autocomplete after first argument
    local args = strings.Split(buf:Line(0), " ")
    if #args > 2 then return nil, nil end

    for k, _ in pairs(qfixCmds) do table.insert(opts, k) end

    local suggestions = {}
    local completions = {}
    local lastArg = args[#args]

    for i = 1, #opts do
        local opt = opts[i]
        local startIdx, endIdx = string.find(opt, lastArg, 1, true)
        if endIdx and startIdx == 1 then
            local completion = string.sub(opt, endIdx + 1, #opt)
            table.insert(completions, completion)
            table.insert(suggestions, opt)
        end
    end

    return completions, suggestions
end

function quickfixEntry(bp, argsUserdata)
    if #argsUserdata == 0 then
        local prompt = "quickfix execute> "
        micro.InfoBar():Prompt(prompt, "", "quickfix-exec", nil, function(input, canceled)
            if not canceled then
                -- if input == "" then execLine() else execArgs()
                bp:HandleCommand("quickfix exec " .. input)
            end
        end)
        return
    end

    local opt = argsUserdata[1]
    local cmd = qfixCmds[opt]
    if not cmd then
        micro.InfoBar():Error("quickfix: unknown option: " .. opt)
        return
    end

    local args = {}
    if opt == "exec" then -- args is only used with `exec`
        for i = 2, #argsUserdata do table.insert(args, argsUserdata[i]) end
    end
    cmd(bp, args)
end

function init()
    config.MakeCommand("quickfix", quickfixEntry, qfixCompleter)
    config.AddRuntimeFile("quickfix", config.RTHelp, "help/quickfix.md")
    config.AddRuntimeFile("quickfix", config.RTSyntax, "syntax/quickfix.yaml")
end
