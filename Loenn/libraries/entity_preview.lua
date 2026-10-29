local entities = require("entities")
local tools = require("tools")
local loadedState = require("loaded_state")
local roomStruct = require("structs.room")
local nodeStruct = require("structs.node")
local utils = require("utils")

local entityPreview = {}

local function finite(number)
    return type(number) == "number" and number == number and math.abs(number) < math.huge
end

local function addRectangle(bounds, rectangle)
    if not rectangle or not finite(rectangle.x) or not finite(rectangle.y)
        or not finite(rectangle.width) or not finite(rectangle.height)
        or rectangle.width <= 0 or rectangle.height <= 0 then
        return bounds
    end
    if not bounds then
        return {x = rectangle.x, y = rectangle.y, width = rectangle.width, height = rectangle.height}
    end
    local right = math.max(bounds.x + bounds.width, rectangle.x + rectangle.width)
    local bottom = math.max(bounds.y + bounds.height, rectangle.y + rectangle.height)
    bounds.x, bounds.y = math.min(bounds.x, rectangle.x), math.min(bounds.y, rectangle.y)
    bounds.width, bounds.height = right - bounds.x, bottom - bounds.y
    return bounds
end

local function findPlacement(data)
    for _, placement in ipairs(tools.getMaterials(data.currentTool, "entities") or {}) do
        if placement.name == data.data then return placement end
    end
end

local function prepare(data)
    local placement = assert(findPlacement(data), "Placement unavailable")
    local item = utils.deepcopy(placement.itemTemplate)
    item._type = "entity"
    item.x, item.y = item.x or 0, item.y or 0
    local handler = assert(entities.registeredEntities[item._name], "Entity handler unavailable")
    local sourceRoom = loadedState.getSelectedRoom()
    -- Renderers sometimes modify their arguments. Never give them the live room
    -- or the placement template used by the editor's placement tool.
    local room = sourceRoom and utils.deepcopy(sourceRoom) or
        roomStruct.decode({name = "__LoennVisualPreviews__", width = 320, height = 184})
    local resizeX, resizeY = entities.canResize(room, "entities", item)
    local minWidth, minHeight = entities.warnBelowSize(room, "entities", item)
    if item.width ~= nil or resizeX then item.width = math.max(item.width or 8, minWidth or 8) end
    if item.height ~= nil or resizeY then item.height = math.max(item.height or 8, minHeight or 8) end

    local minimumNodes = entities.nodeLimits(room, "entities", item)
    assert(finite(minimumNodes) and minimumNodes >= 0 and minimumNodes <= 32, "Unsupported node count")
    if minimumNodes > 0 or item.nodes then
        item.nodes = item.nodes or {_type = nodeStruct.nodesType}
        item.nodes._type = nodeStruct.nodesType
        while #item.nodes < minimumNodes do table.insert(item.nodes, {}) end
        for i, node in ipairs(item.nodes) do
            node._type = nodeStruct.nodeType
            node.x = node.x or item.x + (item.width or 0) + i * 16
            node.y = node.y or item.y
        end
    end
    return room, item, handler
end

local function build(data)
    local room, item, handler = prepare(data)
    -- Use the unwrapped entry point inside our own pcall, so a broken preview
    -- becomes an unavailable thumbnail rather than a recursive error fallback.
    local drawable, depth = entities.getDrawableUnsafe(item._name, handler, room, item, nil)
    local drawables, bounds, hasFunction = {}, nil, false
    local function collect(value)
        if type(value) ~= "table" then return end
        if type(value.draw) == "function" then
            assert(#drawables < 4096, "Preview has too many drawables")
            table.insert(drawables, {value = value, depth = tonumber(value.depth or depth) or 0, index = #drawables + 1})
            if value.getRectangle then
                local ok, rectangle = pcall(value.getRectangle, value)
                if ok then bounds = addRectangle(bounds, rectangle) end
            else
                hasFunction = true
            end
        else
            for _, child in ipairs(value) do collect(child) end
        end
    end
    collect(drawable)
    assert(#drawables > 0, "No preview drawable")

    -- Custom draw callbacks do not expose bounds. Reuse the handler's selection
    -- bounds; include node bounds for callbacks that draw the complete path.
    if not bounds or hasFunction then
        local ok, rectangle, nodeRectangles = pcall(entities.getSelectionUnsafe, room, item, nil, handler)
        if ok then
            bounds = addRectangle(bounds, rectangle)
            for _, nodeRectangle in ipairs(nodeRectangles or {}) do
                bounds = addRectangle(bounds, nodeRectangle)
            end
        end
    end
    bounds = bounds or {x = item.x - 8, y = item.y - 8, width = item.width or 16, height = item.height or 16}
    assert(finite(bounds.width) and finite(bounds.height) and bounds.width > 0 and bounds.height > 0, "Invalid preview bounds")
    table.sort(drawables, function(a, b)
        if a.depth ~= b.depth then return a.depth > b.depth end
        return a.index < b.index
    end)
    return drawables, bounds, item._name, handler
end

function entityPreview.create(data)
    local canvas
    local previousCanvas = love.graphics.getCanvas()
    local stackDepth = love.graphics.getStackDepth()
    love.graphics.push("all")
    local success, result = pcall(function()
        local drawables, bounds, entityName, handler = build(data)
        local width, height = math.ceil(bounds.width + 4), math.ceil(bounds.height + 4)
        -- Cap GPU memory even for room-sized entities. The footer retains the
        -- logical dimensions, while the cached image is at most 512x512.
        local scale = math.min(1, 512 / math.max(width, height))
        local canvasWidth, canvasHeight = math.max(1, math.ceil(width * scale)), math.max(1, math.ceil(height * scale))
        canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
        canvas:setFilter("linear", "nearest")
        love.graphics.setCanvas(canvas)
        love.graphics.origin()
        love.graphics.setScissor(0, 0, canvasWidth, canvasHeight)
        love.graphics.setStencilTest()
        love.graphics.setShader()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setBlendMode("alpha", "alphamultiply")
        love.graphics.scale(scale)
        love.graphics.translate(2 - bounds.x, 2 - bounds.y)
        for _, entry in ipairs(drawables) do
            love.graphics.setColor(1, 1, 1, 1)
            entry.value:draw()
        end
        return {
            canvas = canvas, entityName = entityName, handler = handler,
            bounds = {x = 0, y = 0, width = canvasWidth, height = canvasHeight},
            width = math.ceil(bounds.width), height = math.ceil(bounds.height),
            footer = "Default placement"
        }
    end)
    -- Restore graphics state even when a handler throws after pushing a transform.
    love.graphics.setCanvas(previousCanvas)
    while love.graphics.getStackDepth() > stackDepth do love.graphics.pop() end
    if not success then
        if canvas then canvas:release() end
        return {missing = true, footer = "Preview unavailable", error = tostring(result)}
    end
    return result
end

return entityPreview
