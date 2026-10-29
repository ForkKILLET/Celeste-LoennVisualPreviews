local checkRoot = assert(os.getenv("LOENN_CHECK_DIR"))
local originalLoad = love.load
local mouseX, mouseY = 10, 10
local capture, runner
local ui, tools, windows, list, state, settings, provider
local function log(text) print("[CHECK] " .. text) end
local function wait(seconds)
    local elapsed = 0
    repeat elapsed = elapsed + coroutine.yield() until elapsed >= (seconds or 0.4)
end
local function screenshot(name) capture = name; wait(0.1) end
local function refresh()
    list = windows.windowHandlers.tools.materialList
    state = ui._visualPreviewsHover
    assert(state and state.list == list)
    local counts = {}
    for _, el in ipairs(ui.root.all) do
        if el.__type == "checkbox" then counts[el.text] = (counts[el.text] or 0) + 1 end
    end
    for _, text in ipairs({"Tile icons", "Decal previews", "Entity previews"}) do
        assert(not counts[text], "Preview checkbox still occupies sidebar: " .. text)
    end
end
local function findElement(root, predicate)
    if predicate(root) then return root end
    for _, child in ipairs(root.children or {}) do
        local found = findElement(child, predicate)
        if found then return found end
    end
end
local function openSettings()
    mouseX, mouseY = 40, 10
    ui.mousemoved(mouseX, mouseY)
    local createWindow = require("ui.widgets.tabbed_window").createWindow
    local window = windows.windowHandlers.settings.editSettings()
    assert(require("ui.widgets.tabbed_window").createWindow == createWindow, "Window factory not restored")
    assert(window._visualPreviewsSettings and window._visualPreviewsEditorTab)
    wait(0.1)
    local tabs = assert(findElement(window, function(el) return el.__type == "listH" end))
    tabs.children[window._visualPreviewsEditorTab]:onClick(0, 0, 1)
    wait(0.1)
    local counts = {}
    for _, el in ipairs(window._visualPreviewsSettings.children) do
        if el.__type == "checkbox" then counts[el.text] = (counts[el.text] or 0) + 1 end
    end
    for _, text in ipairs({"Tile icons", "Decal previews", "Entity previews"}) do
        assert(counts[text] == 1, "Settings checkbox count: " .. text)
    end
    return window
end
local function checkbox(text, value)
    local window = openSettings()
    local el = findElement(window._visualPreviewsSettings, function(child)
        return child.__type == "checkbox" and child.text == text
    end)
    assert(el, "Checkbox missing: " .. text)
    el.value = value
    el.cb(el, value)
    window:removeSelf()
    wait(0.1)
end

local function verifySettings()
    local window = openSettings()
    for _, pair in ipairs({{"Tile icons", "enabled"}, {"Decal previews", "decalHoverPreviews"}, {"Entity previews", "entityHoverPreviews"}}) do
        local el = findElement(window._visualPreviewsSettings, function(child)
            return child.__type == "checkbox" and child.text == pair[1]
        end)
        assert(el.value == (settings[pair[2]] ~= false), "Setting not preserved: " .. pair[1])
    end
    screenshot("settings-editor")
    local save = assert(findElement(window, function(el)
        return el.__type == "button" and el.text == "Save changes"
    end), "Native Save changes button lost")
    local shrinkToFit = require("configs").ui.lists.shrinkToFit
    save:onClick(0, 0, 1)
    assert(require("configs").ui.lists.shrinkToFit == shrinkToFit, "Native setting changed unexpectedly")
    window:removeSelf()
    wait(0.1)
    refresh()
    log("Settings > Editor controls, saved values, native Save changes, no sidebar controls")
end
local function delayInput(text)
    local window = openSettings()
    local field = assert(window._visualPreviewsSettings._visualPreviewsDelayField)
    field.field:setText(text)
    local valid = field:fieldValid()
    window:removeSelf()
    wait(0.1)
    return valid
end
local function rowWith(id)
    for _, row in ipairs(list.children) do
        if row.itemData and row.itemData.data == id then return row end
    end
    error("No row " .. id)
end
local function hover(row)
    mouseX = math.floor(math.max(list.scrolledList.screenX + 12,
        math.min(row.screenX + row.width - 32, love.graphics.getWidth() - 48)))
    mouseY = math.floor(row.screenY + row.height / 2)
    -- Native hit testing ignores zero-distance moves, even when filtering has
    -- recycled the row at that pixel. Model an actual pointer movement.
    ui.mousemoved(mouseX - 1, mouseY)
    ui.mousemoved(mouseX, mouseY)
end
local function popup(id)
    if not state.popup then
        local row = ui.hovering
        log(string.format("Popup diagnostics: id=%s hover=%s layer=%s mouse=%s,%s age=%s enabled=%s root=%s parent=%s",
            id, tostring(row and row.itemData and row.itemData.data),
            tostring(row and row.itemData and row.itemData.currentLayer), mouseX, mouseY,
            tostring(state.age), tostring(settings.entityHoverPreviews),
            tostring(row and row.isRooted), tostring(row and row.parent == list)))
        local target = rowWith(id)
        log(string.format("Target bounds %s,%s,%s,%s; clip %s,%s,%s,%s",
            target.screenX,target.screenY,target.width,target.height,
            list.scrolledList.screenX,list.scrolledList.screenY,list.scrolledList.width,list.scrolledList.height))
        screenshot("missing-popup")
    end
    assert(state.popup, "No preview for " .. id)
    assert(state.texture == id, "Wrong preview: " .. tostring(state.texture))
    local p = state.popup
    assert(p.x >= 0 and p.y >= 0 and p.x + p.width <= love.graphics.getWidth()
        and p.y + p.height <= love.graphics.getHeight(), "Preview outside window")
end
local function pick(prefix)
    local match
    for _, placement in ipairs(tools.getMaterials("placement")) do
        if placement.name:sub(1, #prefix) == prefix then match = placement; break end
    end
    assert(match, "No placement " .. prefix)
    list.searchField:setText(match.displayNameNoMods or match.displayName)
    wait()
    hover(rowWith(match.name))
    wait(0.5)
    popup(match.name)
    assert(not state.preview.missing, state.preview.error or "Missing " .. match.name)
    assert(state.preview.canvas, "Expected entity canvas")
    return match
end
local function verifyDelay(id)
    local timing = require("mods").requireFromPlugin("libraries.preview_timing", "LoennVisualPreviews")
    assert(timing.getDelay() == 0.35, "Default preview delay changed")
    assert(delayInput("0"))
    assert(settings.previewDelay == 0 and timing.getDelay() == 0)
    hover(rowWith(id))
    state.reset()
    state.update(0)
    popup(id)
    log("Zero delay: preview appears on first hover update")

    assert(delayInput("0.8"))
    hover(rowWith(id))
    state.reset()
    state.update(0.2)
    assert(not state.popup, "Preview appeared before custom delay")
    state.update(0.5)
    assert(not state.popup, "Preview appeared before 0.8 seconds")
    state.update(0.11)
    popup(id)
    local window = openSettings()
    assert(window._visualPreviewsSettings._visualPreviewsDelayField:getValue() == 0.8, "Delay not retained after reopening Settings")
    window:removeSelf(); wait(0.1)

    for _, text in ipairs({"", "-1", "abc", "1e309", "nan"}) do
        assert(not delayInput(text), "Invalid input accepted: " .. text)
        assert(settings.previewDelay == 0.8 and timing.getDelay() == 0.8, "Invalid input overwrote previous delay")
    end
    local config = require("utils.config")
    local saved = config.readConfigData(rawget(settings, "filename"))
    assert(saved.previewDelay == 0.8, "Delay not saved to disk")
    assert(delayInput("12.5"))
    assert(timing.getDelay() == 12.5, "Long finite delay unexpectedly rejected")
    assert(delayInput("0.35"))
    assert(timing.getDelay() == 0.35)
    log("Decimal delay, persistence, invalid-input rejection and default restoration")
end
local function fixture(name, handler, template)
    local entityName = "VisualPreviewsFixture/" .. name
    require("entities").registeredEntities[entityName] = handler
    template = template or {x = 0, y = 0, width = 16, height = 16}
    template._name, template._id = entityName, 0
    local placement = {name = entityName .. "#normal", itemTemplate = template}
    local data = {text = "Fixture " .. name, textNoMods = "Fixture " .. name,
        tooltip = "Fixture description", data = placement.name, currentLayer = "entities",
        currentTool = {getMaterials = function() return {placement} end}, currentToolName = "placement",
        itemFavorited = false}
    return data, template
end

local function checks()
    wait(0.8)
    ui, tools, windows = require("ui"), require("tools"), require("ui.windows")
    settings = require("mods").getModSettings("LoennVisualPreviews")
    provider = require("mods").requireFromPlugin("libraries.entity_preview", "LoennVisualPreviews")
    refresh()
    assert(settings.enabled == false, "Saved tile setting not loaded")
    assert(settings.decalHoverPreviews == true, "Saved decal setting not loaded")
    assert(settings.entityHoverPreviews ~= false)
    verifySettings()
    checkbox("Tile icons", true)
    log("Saved settings and independent controls")
    tools.selectTool("placement"); wait()
    tools.setLayer("entities"); wait()

    local bonfire = pick("bonfire#")
    verifyDelay(bonfire.name)
    hover(rowWith(bonfire.name)); wait(0.5); popup(bonfire.name)
    screenshot("entity-bonfire")
    list.listItemDoubleClicked(rowWith(bonfire.name), 1); wait()
    assert(rowWith(bonfire.name).itemFavorited)
    checkbox("Entity previews", false); wait(0.5)
    assert(not state.popup and settings.entityHoverPreviews == false)
    verifySettings()
    checkbox("Entity previews", true); wait()
    hover(rowWith(bonfire.name)); wait(0.5); popup(bonfire.name)
    log("Native sprite, favorite, independent entity toggle")

    pick("zipMover#normal"); screenshot("entity-zip-mover")
    pick("water#"); screenshot("entity-water")
    pick("infiniteStar#"); screenshot("entity-custom-draw")
    pick("templeEye#"); screenshot("entity-context-draw")
    log("Multi-sprite nodes, translucent rectangle, custom draw and room context")

    local loaded = require("loaded_state")
    local liveRoom = loaded.map.rooms[1]
    loaded.selectItem(liveRoom)
    local utils = require("utils")
    local before = utils.deepcopy(liveRoom)
    local seenNodes
    local mutation, template = fixture("mutation", {
        nodeLimits = {2, 2},
        sprite = function(room, entity)
            seenNodes = #entity.nodes
            assert(entity.nodes[1]._type == "node")
            room.x = 99999
            room.tilesFg.matrix:setInbounds(1, 1, "9")
            table.insert(room.entities, {_name = "mutated"})
            entity.width = 99
            return require("structs.drawable_rectangle").fromRectangle("fill", 0, 0, 24, 16, {1,0.2,0.2,0.7})
        end
    })
    local result = provider.create(mutation)
    assert(result.canvas and not result.missing, result.error)
    assert(seenNodes == 2 and template.width == 16 and template.nodes == nil, "Placement mutated")
    assert(utils.equals(before, liveRoom), "Live room mutated")
    result.canvas:release()
    log("Required nodes populated; room and template mutations contained")

    local broken = fixture("broken", {
        draw = function()
            love.graphics.push("all")
            love.graphics.translate(123, 456)
            love.graphics.setColor(0, 0, 0, 0)
            error("Fixture draw failure")
        end,
        selection = function() return {x = 0, y = 0, width = 16, height = 16} end
    })
    local depth = love.graphics.getStackDepth()
    local canvas = love.graphics.getCanvas()
    result = provider.create(broken)
    assert(result.missing and result.error:find("Fixture draw failure", 1, true))
    assert(love.graphics.getStackDepth() == depth and love.graphics.getCanvas() == canvas, "Graphics state leaked")
    list.searchField:setText(""); wait()
    list:updateItems({broken}); wait()
    hover(rowWith(broken.data)); wait(0.5)
    popup(broken.data)
    assert(state.preview.missing and rowWith(broken.data).tooltipText == nil)
    assert(state.popup.footer:find("Fixture description", 1, true))
    screenshot("entity-unavailable")
    checkbox("Entity previews", false); wait()
    assert(rowWith(broken.data).tooltipText == "Fixture description", "Native tooltip not restored")
    checkbox("Entity previews", true); wait()
    log("Throwing custom renderer: fallback, graphics recovery and description preservation")

    local huge = fixture("huge", {
        sprite = function() return require("structs.drawable_rectangle").fromRectangle("fill", 0, 0, 4096, 2048, {0.2,0.7,1,1}) end
    })
    result = provider.create(huge)
    assert(result.canvas and result.canvas:getWidth() <= 512 and result.canvas:getHeight() <= 512)
    assert(result.width == 4096 and result.height == 2048)
    result.canvas:release()
    log("Canvas allocation bounded for large entities")

    local originalUpdate, originalDraw = ui.update, ui.draw
    require("debug_utils").reloadUI(); wait()
    refresh()
    assert(ui.update == originalUpdate and ui.draw == originalDraw, "Duplicate hooks after reload")
    verifySettings()
    tools.setLayer("entities"); wait()

    local passed, failed, failures = 0, 0, {}
    local placements = tools.getMaterials("placement")
    for i, placement in ipairs(placements) do
        local data = {data = placement.name, currentTool = tools.currentTool}
        local preview = provider.create(data)
        if preview.canvas then
            passed = passed + 1; preview.canvas:release()
        else
            failed = failed + 1
            table.insert(failures, placement.name .. ": " .. tostring(preview.error))
        end
        if i % 20 == 0 then wait(0.01) end
    end
    local f = assert(io.open(checkRoot .. "/entity-coverage.txt", "w"))
    f:write(string.format("%d passed; %d failed\n", passed, failed), table.concat(failures, "\n")); f:close()
    log(string.format("Vanilla placements: %d passed; %d unavailable", passed, failed))
    assert(passed > 100 and passed / (passed + failed) > 0.9, "Insufficient vanilla preview coverage")

    require("configs").ui.theme.defaultFontSize = 12
    require("debug_utils").reloadUI(); wait(); refresh()
    tools.setLayer("entities"); wait(); pick("zipMover#normal"); screenshot("entity-font-12")
    require("configs").ui.theme.defaultFontSize = 24
    require("debug_utils").reloadUI(); wait(); refresh()
    tools.setLayer("entities"); wait()
    love.window.setMode(1280, 720, {resizable = true}); wait()
    pick("bonfire#"); screenshot("entity-small-window")
    log("Fonts 12/24, small window and UI reload")

    tools.setLayer("decalsFg"); wait()
    list.searchField:setText("0-prologue/house"); wait()
    hover(rowWith("decals/0-prologue/house")); wait(0.5)
    popup("decals/0-prologue/house")
    assert(state.preview.drawable and not state.preview.missing)
    verifyDelay("decals/0-prologue/house")
    hover(rowWith("decals/0-prologue/house")); wait(0.5)
    popup("decals/0-prologue/house")
    screenshot("decal-regression")
    tools.selectTool("brush"); wait()
    assert(not state.popup)
    local icons = 0
    for _, row in ipairs(list.children) do
        for _, child in ipairs(row.children or {}) do
            if child._visualPreviewsTileIcon then icons = icons + 1 end
        end
    end
    assert(icons > 0, "Tile icons regressed")
    assert(not require("history").madeChanges, "Map history changed")
    log("Decal and tile regressions; no map edits")
    log("PASS")
    love.event.quit()
end

function love.load(...)
    io.stdout:setvbuf("no")
    originalLoad(...)
    love.mouse.getPosition = function() return mouseX, mouseY end
    love.window.hasFocus = function() return true end
    love.window.hasMouseFocus = function() return true end
    local update, draw = love.update, love.draw
    local total = 0
    love.update = function(dt)
        update(dt)
        total = total + dt
        assert(total < 120, "Check timed out")
        if require("scene_handler").currentScene ~= "Editor" then return end
        runner = runner or coroutine.create(checks)
        local ok, message = coroutine.resume(runner, dt)
        assert(ok, message)
    end
    love.draw = function(...)
        draw(...)
        if capture then
            local filename = checkRoot .. "/" .. capture .. ".png"; capture = nil
            love.graphics.captureScreenshot(function(data)
                local f = assert(io.open(filename, "wb")); f:write(data:encode("png"):getString()); f:close()
            end)
        end
    end
end

function love.errorhandler(message)
    io.stderr:write(debug.traceback(tostring(message)), "\n")
    return function() return 1 end
end
