-- @noindex
-- @author Ben 'Talagan' Babut
-- @license MIT
-- @description This file is part of MaCCLane

local os                            = reaper.GetOS()
local is_windows                    = os:match('Win')
local is_linux                      = os:match('Other')

local PerfContext = {
    refdate      = reaper.time_precise(),
    accum = {
        frames  = 0,
        time    = 0,
        skipped = 0,
        forced_redraws = 0
    },
    sec1        = {}
}

local function perf_accum()
    return PerfContext.accum
end

local function perf_ms(func)
    local t1 = reaper.time_precise()
    func()
    local t2 = reaper.time_precise()
    -- Time diff in ms
    local delta = 1000 * (t2 - t1)

    PerfContext.accum.time      = PerfContext.accum.time + delta
    PerfContext.accum.frames    = PerfContext.accum.frames + 1

    if (t2 - PerfContext.refdate) >= 1.0 then
        -- Save last second stats
        PerfContext.sec1.total_ms       = PerfContext.accum.time
        PerfContext.sec1.usage_perc     = PerfContext.sec1.total_ms * 0.1 -- / 1000 (s) * 100 (perc)

        PerfContext.sec1.frames         = PerfContext.accum.frames
        PerfContext.sec1.frame_avg_ms   = PerfContext.accum.time / PerfContext.accum.frames
        PerfContext.sec1.skipped        = PerfContext.accum.skipped
        PerfContext.sec1.forced_redraws = PerfContext.accum.forced_redraws

        -- Reset counters
        PerfContext.refdate         = t2
        PerfContext.accum.frames    = 0
        PerfContext.accum.time      = 0
        PerfContext.accum.skipped   = 0
        PerfContext.accum.forced_redraws = 0
    end

    return PerfContext
end

local function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function drawUUID()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and  math.random(0, 0xf) or  math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function screenCoordinatesToLocal(parentBounds, globalx, globaly)
    local  localx = globalx - parentBounds.l
    local  localy = globaly - parentBounds.b

    if is_windows or is_linux then
        localy = -localy
    end

    return localx, localy
end

local function JS_Window_GetBounds(hwnd, full_window)

    local func = (full_window and reaper.JS_Window_GetRect or reaper.JS_Window_GetClientRect)

    local _, left, top, right, bottom = func( hwnd )

    local h   = top - bottom

    -- Under windows, vertical coordinates are flipped
    -- Vertical ccordinates start with 0 at the top and the axis is vertical
    if is_windows or is_linux then
        h = bottom - top
    end

    return {
        hwnd = hwnd,
        l = left,
        t = top,
        r = right,
        b = bottom,
        w = (right-left),
        h = h
    }
end

local function JS_Window_TopParent(hwnd)
    local top    = hwnd
    local parent = reaper.JS_Window_GetParent(hwnd)

    while parent do
        top = parent
        parent = reaper.JS_Window_GetParent(top)
    end

    return top
end

local function JS_FindMidiEditorPianoRollSubWindow(me)
    return reaper.JS_Window_FindChildByID(me, 1001)
end
local function utf8sub(str, utf8_start, utf8_len)
    local s = utf8.offset(str, utf8_start)
    local e = utf8.offset(str, utf8_start + utf8_len) - 1
    return string.sub(str, s, e)
end

return {
    perf_ms                         = perf_ms,
    perf_accum                      = perf_accum,
    deepcopy                        = deepcopy,
    drawUUID                        = drawUUID,
    screenCoordinatesToLocal        = screenCoordinatesToLocal,
    JS_Window_GetBounds             = JS_Window_GetBounds,
    JS_Window_TopParent             = JS_Window_TopParent,
    JS_FindMidiEditorPianoRollSubWindow  = JS_FindMidiEditorPianoRollSubWindow,
    utf8sub                         = utf8sub
}
