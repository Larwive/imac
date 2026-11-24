math.randomseed(os.time())

local M = {}
M.appName = "Recopie de l’iPhone" -- TODO: Auto detect correct app name depending on language ?
M.lastScript = nil
M.mouseDown = false
M.loopTimer = nil
M.runId = 0
M.running = false
M.app = nil

function M.isRunning() return M.running end

local function randomBetween(min, max)
    return min + math.random() * (max - min)
end

local function getApp()
    if not M.app or not M.app:isRunning() then
        M.app = hs.application.find(M.appName)
    end
    if not M.app then
        hs.alert.show("App not found: " .. M.appName)
    end
    return M.app
end

local function getWindow()
    local app = getApp()
    if not app then return nil end
    local win = app:mainWindow()
    if not win then
        hs.alert.show("No window found for " .. M.appName)
        return nil
    end
    return win
end

local function getTargetWindow()
    local app = getApp()
    if not app then return nil end

    app:unhide()
    app:activate(true)

    local win = app:mainWindow()
    if not win then
        hs.alert.show("No window found for " .. M.appName)
        return nil
    end

    if win:isMinimized() then win:unminimize() end
    win:raise()
    win:focus()

    local screenFrame = win:screen():frame()
    local f = win:frame()

    if f.w > screenFrame.w then f.w = screenFrame.w end
    if f.h > screenFrame.h then f.h = screenFrame.h end

    if f.x < screenFrame.x then f.x = screenFrame.x end
    if f.y < screenFrame.y then f.y = screenFrame.y end
    if f.x + f.w > screenFrame.x + screenFrame.w then
        f.x = screenFrame.x + screenFrame.w - f.w
    end
    if f.y + f.h > screenFrame.y + screenFrame.h then
        f.y = screenFrame.y + screenFrame.h - f.h
    end

    win:setFrame(f)
    return win
end

local function toAbsolute(x, y)
    local win = getWindow()
    if not win then return nil end

    if not M.app:isFrontmost() then
        win = getTargetWindow()
        if not win then return nil end
    end

    local f = win:frame()
    if x < 0 or y < 0 or x > f.w or y > f.h then return nil end
    return { x = f.x + x, y = f.y + y }
end

-- Mouse functions

function M.MouseDown(x, y)
    local point = { x = x, y = y }
	hs.mouse.absolutePosition({x=x, y=y})
	hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, point):post()
	M.mouseDown = true
end

function M.MouseUp()
	local pos = hs.mouse.absolutePosition()
	hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, pos):post()
	M.mouseDown = false
end

function M.Move(x, y, duration, done)
    local from = hs.mouse.absolutePosition()
    duration = duration or 0

    local function setPos(p)
        hs.mouse.absolutePosition(p)
        if M.mouseDown then
            hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDragged, p):post()
        end
    end

    if duration <= 0 then
        setPos({ x = x, y = y })
        if done then done() end
        return
    end

    local t0 = hs.timer.secondsSinceEpoch()
    M.loopTimer = hs.timer.doEvery(0.01, function()
        local k = (hs.timer.secondsSinceEpoch() - t0) / duration
        if k >= 1 then
            M.loopTimer:stop()
            M.loopTimer = nil
            setPos({ x = x, y = y })
            if done then done() end
        else
            setPos({ x = from.x + (x - from.x) * k, y = from.y + (y - from.y) * k })
        end
    end)
end

function M.Click(x, y, duration, done)
    M.MouseDown(x, y)
    M.loopTimer = hs.timer.doAfter(math.max(duration or 0, 0.001), function() -- Each click lasts at least 1 ms.
        M.loopTimer = nil
        M.MouseUp()
        if done then done() end
    end)
end

-- Click sequence runner

function M.start(sequence)
	local win = getTargetWindow()
	if not win then return end

    if sequence == nil then
        sequence = M.lastScript
    else
        M.lastScript = sequence
    end
	if not sequence then hs.alert.show("No script loaded") return end

    hs.alert.show("Click sequence started.")
    M.stop()                    -- coupe un éventuel run précédent
    M.runId = M.runId + 1
    local myRun = M.runId
    M.running = true
    local stack = {}

    local function loop(index)
        if myRun ~= M.runId then return end

        local step = sequence[index]
        if not step then
            M.running = false
            hs.alert.show("Click sequence finished.")
            return
        end

        -- Appelé quand le geste est fini.
        local function advance(nextIndex)
            if myRun ~= M.runId then return end
            M.loopTimer = hs.timer.doAfter(step.delay or 0, function() loop(nextIndex or index + 1) end)
        end

        local cmd = step.command

        if cmd == "Repeat" then
            table.insert(stack, { start = index, remaining = step.count })
            advance()
        elseif cmd == "End" then
            local top = stack[#stack]
            if top.remaining == 0 then
                advance(top.start + 1)
            else
                top.remaining = top.remaining - 1
                if top.remaining > 0 then
                    advance(top.start + 1)
                else
                    table.remove(stack)
                    advance()
                end
            end
        elseif cmd == "MouseUp" then
            M.MouseUp()
            advance()
        elseif cmd == "Click" or cmd == "Move" or cmd == "MouseDown" then
            local p = toAbsolute(step.x, step.y)
            if not p then
                if not getApp() then M.stop() return end 
                advance()
            elseif cmd == "Click" then
                M.Click(p.x, p.y, step.time, advance)
            elseif cmd == "Move" then
                M.Move(p.x, p.y, step.time, advance)
            else
                M.MouseDown(p.x, p.y)
                advance()
            end
        else
            advance()
        end
    end

	loop(1)
end

function M.stop()
    M.runId = M.runId + 1       -- invalidate any pending callback
    M.running = false
    if M.loopTimer then
        M.loopTimer:stop()
        M.loopTimer = nil
    end
    if M.mouseDown then
        M.MouseUp()
    end
    hs.alert.show("Click sequence stopped.")
end

M.tracker = nil

local function ensureTracker(f)
    if not M.tracker then
        M.tracker = hs.canvas.new({ x = f.x + 20, y = f.y + 20, w = 160, h = 40 })
        M.tracker:level(hs.canvas.windowLevels.overlay)
        M.tracker:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
        M.tracker:appendElements(
            { type = "rectangle", action = "fill", fillColor = { white = 0, alpha = 0.6 },
              roundedRectRadii = { xRadius = 6, yRadius = 6 } },
            { type = "text", text = "", textSize = 18, textColor = { white = 1 },
              frame = { x = 8, y = 6, w = 144, h = 28 } }
        )
    end
    M.tracker:topLeft({ x = f.x + 20, y = f.y + 20 })  -- Follows the window if it moves.
    return M.tracker
end

local function showRelativeMousePosition()
    local win = getWindow()
    if not win then return end

    local mouse = hs.mouse.absolutePosition()
    local f = win:frame()
    local rx, ry = math.floor(mouse.x - f.x), math.floor(mouse.y - f.y)

    if rx < 0 or ry < 0 or rx > f.w or ry > f.h then
        if M.tracker then M.tracker:hide() end
        return
    end

    local c = ensureTracker(f)
    c:elementAttribute(2, "text", "x=" .. rx .. "   y=" .. ry)
    c:show()
end

function M.toggleMouseTracker()
    M.trackerEnabled = not M.trackerEnabled

    if M.trackerEnabled then
        hs.alert.show("Mouse tracker ON", 0.5)
        M.trackerTimer = hs.timer.doEvery(0.1, showRelativeMousePosition)
    else
        hs.alert.show("Mouse tracker OFF", 0.5)

        if M.trackerTimer then
            M.trackerTimer:stop()
            M.trackerTimer = nil
        end

        if M.tracker then
            M.tracker:delete()
            M.tracker = nil
        end
    end
end


-- Hotkeys
hs.hotkey.bind({"cmd","alt","ctrl"}, "S", function() M.start(nil) end)
hs.hotkey.bind({"cmd","alt","ctrl"}, "X", function() M.stop() end)
hs.hotkey.bind({"cmd","alt","ctrl"}, "P", function() M.toggleMouseTracker() end)
return M
