local M = {}
M.stopRequested = false
M.appName = "Recopie de l’iPhone" -- TODO: Auto detect correct app name depending on language ?
M.lastScript = nil
M.mouseDown = false

local function getWindow()
	local app = hs.application.find(M.appName)
    if not app then
        hs.alert.show("App not found: " .. M.appName)
        return nil
    end
	local win = app:mainWindow()
    if not win then
        hs.alert.show("No window found for " .. M.appName)
        return nil
    end
	return win
end

local function getTargetWindow()
    local app = hs.application.find(M.appName)
    if not app then
        hs.alert.show("App not found: " .. M.appName)
        return nil
    end
	app:unhide()
	app:activate(true)
    local win = app:mainWindow()
    if not win then
        hs.alert.show("No window found for " .. M.appName)
        return nil
    end
	if win:isMinimized() then
        win:unminimize()
    end
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
    local win = getTargetWindow()
    if not win then return nil end

    local f = win:frame()
    local ax = f.x + x
    local ay = f.y + y

    if ax < f.x or ay < f.y or ax > f.x + f.w or ay > f.y + f.h then return nil end

    return { x = ax, y = ay }
end

-- Mouse functions

function M.MouseDown(x, y)
	local point = {x=x, y=y}
	hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, point):post()
	M.mouseDown = true
end

function M.MouseUp()
	local pos = hs.mouse.getAbsolutePosition()
	hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, pos):post()
	M.mouseDown = false
end

function M.Move(x, y, time)
	local pos = hs.mouse.getAbsolutePosition()
	local target = {x=x, y=y}
	time = time or 0
	if time > 0 then
		local steps = math.ceil(time / 0.01)
		for i=1,steps do
			local nx = pos.x + (target.x - pos.x) * i / steps
			local ny = pos.y + (target.y - pos.y) * i / steps
			hs.mouse.absolutePosition()({x=nx, y=ny})
			hs.timer.usleep(10000) -- 0.01s per step
		end
	else
		hs.mouse.absolutePosition(target)
	end
end

function M.Click(x, y, time)
	M.MouseDown(x, y)
	if time and time > 0 then
		hs.timer.usleep(time * 1e6)
	end
	M.MouseUp()
end

-- Click sequence runner

function M.start(sequence)
	local win = getTargetWindow()
	if not win then return end

	M.stopRequested = false
	if sequence == nil then
		sequence = M.lastScript
	else
		M.lastScript = sequence
	end

	hs.alert.show("Click sequence started.")

	local function loop(index)
		if M.stopRequested then
			hs.alert.show("Click sequence stopped.")
			return
		end

		local step = sequence[index]
		if not step then
			loop(1)
			return
		end

		if step.command == "MouseDown" then
			local relativePoint = toAbsolute(step.x, step.y)
			if relativePoint then M.MouseDown(relativePoint.x, relativePoint.y) end
		elseif step.command == "MouseUp" then
			M.MouseUp()
		elseif step.command == "Move" then
			local relativePoint = toAbsolute(step.x, step.y)
			if relativePoint then M.Move(relativePoint.x, relativePoint.y, step.time) end
		elseif step.command == "Click" then
			local relativePoint = toAbsolute(step.x, step.y)
			if relativePoint then M.Click(relativePoint.x, relativePoint.y, step.time) end
		end

		local delay = step.delay or 0.1
		hs.timer.doAfter(delay, function() loop(index + 1) end)
	end

	loop(1)
end

function M.stop()
    M.stopRequested = true
end

M.trackerDrawing = nil

local function showRelativeMousePosition()
    local win = getWindow()
    if not win then return end

    local mouse = hs.mouse.absolutePosition()
    local f = win:frame()

    local rx = math.floor(mouse.x - f.x)
    local ry = math.floor(mouse.y - f.y)

    -- Out of window check.
    if rx < 0 or ry < 0 or rx > f.w or ry > f.h then
        if M.trackerDrawing then
            M.trackerDrawing:hide()
        end
        return
    end

    local text = "x=" .. rx .. "   y=" .. ry

    if not M.trackerDrawing then
        M.trackerDrawing = hs.drawing.text(
            hs.geometry.rect(f.x + 20, f.y + 20, 160, 40),
            text
        )
        M.trackerDrawing:setTextSize(18)
        M.trackerDrawing:setLevel(hs.drawing.windowLevels.overlay)
        M.trackerDrawing:setBehavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
        M.trackerDrawing:show()
    else
        M.trackerDrawing:setText(text)
        M.trackerDrawing:show()
    end
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

        if M.trackerDrawing then
            M.trackerDrawing:delete()
            M.trackerDrawing = nil
        end
    end
end


-- Hotkeys
hs.hotkey.bind({"cmd","alt","ctrl"}, "S", function() M.start(nil) end)
hs.hotkey.bind({"cmd","alt","ctrl"}, "C", function() M.stop(nil) end)

hs.hotkey.bind({"cmd","alt","ctrl"}, "P", function() M.toggleMouseTracker() end)
return M
