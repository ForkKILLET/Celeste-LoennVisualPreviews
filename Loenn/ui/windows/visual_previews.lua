-- Editor-only extension for Lonn 1.0.10 / OlympUI.
local ui = require("ui")
local elements = require("ui.elements")
local windows = require("ui.windows")
local mods = require("mods")
local matrix = require("utils.matrix")
local celesteRender = require("celeste_render")
local logging = require("logging")
local hoverPreview = mods.requireFromPlugin("libraries.hover_preview", "LoennVisualPreviews")
local settingsWindow = mods.requireFromPlugin("libraries.settings_window", "LoennVisualPreviews")

local plugin = {visible = false}
local settings = mods.getModSettings("LoennVisualPreviews")
local previews = {}
local cachedFg, cachedBg, cachedQuads

local function enabled()
    return settings.enabled ~= false
end

local function getPreview(layer, material)
    local fg = celesteRender.tilesMetaFg
    local bg = celesteRender.tilesMetaBg
    local quads = celesteRender.tilesSpriteMetaCache

    -- Both changing maps/tilesets and reloading textures invalidate previews.
    if fg ~= cachedFg or bg ~= cachedBg or quads ~= cachedQuads then
        previews = {}
        cachedFg, cachedBg, cachedQuads = fg, bg, quads
    end

    local key = layer .. ":" .. tostring(material)
    if previews[key] ~= nil then
        return previews[key]
    end

    if material == "0" then
        previews[key] = {air = true}
        return previews[key]
    end

    local tileMeta = layer == "tilesFg" and fg or bg
    local success, batch, missing = pcall(function()
        -- A 3x3 block surrounded by air shows corners, edges and the center.
        -- Fixed randomness keeps the thumbnail stable without touching map data.
        local sample = matrix.filled("0", 7, 7)
        for x = 3, 5 do
            for y = 3, 5 do
                sample:setInbounds(x, y, material)
            end
        end

        return celesteRender.getTilesBatch(nil, {matrix = sample}, tileMeta,
            nil, layer == "tilesFg", matrix.filled(0, 7, 7), "table", false)
    end)

    if success and #batch > 0 and #missing == 0 then
        previews[key] = {batch = batch}
    else
        previews[key] = false
        if not success then
            logging.warning("[LoennVisualPreviews] Cannot preview " .. key .. ": " .. tostring(batch))
        end
    end

    return previews[key]
end

local function drawPreview(self)
    local preview = getPreview(self.tileLayer, self.tileMaterial)
    local size = self.width
    local x = self.screenX
    local y = self.screenY + math.floor((self.height - size) / 2)

    love.graphics.push("all")
    love.graphics.translate(x, y)
    love.graphics.setColor(0.12, 0.12, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, size, size)
    love.graphics.setColor(0.22, 0.22, 0.22, 1)
    love.graphics.rectangle("fill", 0, 0, size / 2, size / 2)
    love.graphics.rectangle("fill", size / 2, size / 2, size / 2, size / 2)

    if preview and preview.batch then
        love.graphics.setColor(1, 1, 1, 1)
        local scale = size / 24
        for _, tile in ipairs(preview.batch) do
            local meta, quad = tile[1], tile[2]
            local drawX, drawY = (tile[3] - 16) * scale, (tile[4] - 16) * scale
            if meta.layer then
                love.graphics.drawLayer(meta.image, meta.layer, quad, drawX, drawY, 0, scale, scale)
            else
                love.graphics.draw(meta.image, quad, drawX, drawY, 0, scale, scale)
            end
        end
    elseif not preview then
        -- Missing textures remain usable list items rather than crashing the UI.
        love.graphics.setColor(1, 0.35, 0.65, 1)
        love.graphics.line(2, 2, size - 2, size - 2)
        love.graphics.line(size - 2, 2, 2, size - 2)
    end

    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.rectangle("line", 0.5, 0.5, size - 1, size - 1)
    love.graphics.pop()
end

local function decorate(list, data, element)
    -- Magic lists recycle rows between materials and between FG/BG/entity lists.
    -- Remove only our own child; preserve the original label and favorite icon.
    for i = #element.children, 1, -1 do
        if element.children[i]._visualPreviewsTileIcon then
            table.remove(element.children, i)
        end
    end

    if enabled() and data and (data.currentLayer == "tilesFg" or data.currentLayer == "tilesBg") then
        local height = math.max(16, element.label.style.font:getHeight())
        local size = math.max(16, math.floor(height / 8) * 8)
        local icon = elements.panel({}):with({
            _visualPreviewsTileIcon = true,
            interactive = 0,
            cacheable = false,
            tileLayer = data.currentLayer,
            tileMaterial = data.data,
            width = size,
            height = height,
            style = {padding = 0, bg = {}, border = {}},
            draw = drawPreview
        })

        -- Favorite stars have an absolute position at the left edge. Keep that
        -- slot first so their thumbnail sits beside the star rather than under it.
        table.insert(element.children, math.max(1, #element.children), icon)
    end

    -- Preserve descriptions in the preview popup and avoid a second native
    -- tooltip obscuring it. Disabling a preview restores the normal tooltip.
    if data and ((data.currentLayer == "entities" and settings.entityHoverPreviews ~= false)
        or ((data.currentLayer == "decalsFg" or data.currentLayer == "decalsBg") and settings.decalHoverPreviews ~= false)) then
        element.tooltipText = nil
    end
    element:reflow()
    return element
end

local function extendToolsWindow(toolsWindow)
    local list = toolsWindow.materialList
    if not list or list._visualPreviewsInstalled then
        return
    end
    list._visualPreviewsInstalled = true

    local original = list.dataToElement
    list.dataToElement = function(self, data, recycled)
        return decorate(self, data, original(self, data, recycled))
    end
    list._dummy = false
    list:invalidate()

    hoverPreview.install(list, function(layer)
        return layer == "entities" and settings.entityHoverPreviews ~= false
            or layer ~= "entities" and settings.decalHoverPreviews ~= false
    end)
end

local function refreshList()
    local hover = ui._visualPreviewsHover
    if hover then hover.reset() end
    local handler = windows.windowHandlers.tools
    local list = handler and handler.materialList
    if list then
        list._dummy = false
        list:invalidate()
        list:repaint()
    end
    if ui.root then
        ui.root:reflow()
        ui.root:recollect()
    end
end

-- External windows load after internal windows. Wrapping this handler keeps the
-- extension local to the Tools window and works when the UI is reloaded.
local toolsWindow = windows.windowHandlers.tools
if toolsWindow and toolsWindow.getWindow and not toolsWindow._visualPreviewsWrapped then
    toolsWindow._visualPreviewsWrapped = true
    local original = toolsWindow.getWindow
    toolsWindow.getWindow = function(...)
        local window = original(...)
        extendToolsWindow(toolsWindow)
        return window
    end
elseif not toolsWindow or not toolsWindow.getWindow then
    logging.warning("[LoennVisualPreviews] Tools window unavailable.")
end

settingsWindow.install(windows.windowHandlers.settings, refreshList)

return plugin
