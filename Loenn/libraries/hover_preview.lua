-- Shared popup presentation for decals and default entity placements.
local ui = require("ui")
local atlases = require("atlases")
local elements = require("ui.elements")
local sprite = require("structs.drawable_sprite")
local mods = require("mods")
local loadedState = require("loaded_state")
local entities = require("entities")
local celesteRender = require("celeste_render")
local entityPreview = mods.requireFromPlugin("libraries.entity_preview", "LoennVisualPreviews")
local timing = mods.requireFromPlugin("libraries.preview_timing", "LoennVisualPreviews")

local hoverPreview = {}

local function reset(state)
    if state.preview and state.preview.canvas then state.preview.canvas:release() end
    state.target = nil
    state.texture = nil
    state.age = 0
    state.preview = nil
    state.popup = nil
end

local function hoveredPlacement(state)
    if ui.dragging or not love.window.hasFocus()
        or not love.window.hasMouseFocus() then
        return
    end

    local row = ui.hovering
    while row do
        local data = row.itemData
        if row.parent == state.list and data and row.isRooted
            and state.list.data[row._magicIndex] == data
            and (data.currentLayer == "entities" or data.currentLayer == "decalsFg" or data.currentLayer == "decalsBg")
            and state.isEnabled(data.currentLayer) then
            local x, y = love.mouse.getPosition()
            -- Reject stale hover references after filtering, scrolling or recycling.
            local box = state.list.scrolledList
            if x >= row.screenX and x < row.screenX + row.width
                and y >= row.screenY and y < row.screenY + row.height
                and x >= box.screenX and x < box.screenX + box.width
                and y >= box.screenY and y < box.screenY + box.height
                and type(data.data) == "string" then
                return row, data
            end
            return
        end
        row = row.parent
    end
end

local function getDecalPreview(texture)
    -- Atlas lookup also supports lazily loaded mod decals. Do this only after
    -- the hover delay rather than loading textures for the entire material list.
    local success, result = pcall(function()
        local meta = atlases.gameplay[texture]
        if not meta then return {missing = true} end
        local drawable = sprite.fromMeta(meta)
        local bounds = drawable:getRectangle()
        if bounds.width <= 0 or bounds.height <= 0 then return {missing = true} end
        return {
            drawable = drawable,
            bounds = bounds,
            width = meta.realWidth,
            height = meta.realHeight
        }
    end)
    return success and result or {missing = true}
end

local function layoutPopup(state)
    local font = elements.__label.__default.style.font
    local scale = math.max(1, font:getHeight() / 14)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local margin = math.ceil(8 * scale)
    local padding = math.ceil(8 * scale)
    local gap = math.ceil(6 * scale)
    local width = math.min(math.floor(200 * scale), screenWidth - margin * 2)
    local innerWidth = width - padding * 2
    local _, lines = font:getWrap(state.title, innerWidth)
    if #lines > 3 then
        lines = {lines[1], lines[2], "..."}
    end
    local title = table.concat(lines, "\n")
    local titleHeight = #lines * font:getHeight() * font:getLineHeight()
    local preview = state.preview
    local footer = preview.missing and (preview.footer or "Texture unavailable") or
        string.format("%d x %d px", preview.width, preview.height)
    if not preview.missing and preview.footer then footer = footer .. "\n" .. preview.footer end
    if type(state.description) == "string" and state.description ~= "" then
        footer = footer .. "\n" .. state.description
    end
    local _, footerLines = font:getWrap(footer, innerWidth)
    if #footerLines > 4 then footerLines = {footerLines[1], footerLines[2], footerLines[3], "..."} end
    local footerHeight = #footerLines * font:getHeight() * font:getLineHeight()
    local imageHeight = math.max(1, math.min(math.floor(150 * scale),
        screenHeight - margin * 2 - padding * 2 - titleHeight - footerHeight - gap * 2))
    local height = padding * 2 + titleHeight + gap * 2 + imageHeight + footerHeight

    local x = state.target.screenX - width - margin
    if x < margin then x = state.target.screenX + state.target.width + margin end
    x = math.max(margin, math.min(x, screenWidth - width - margin))
    local y = math.max(margin, math.min(state.target.screenY, screenHeight - height - margin))

    state.popup = {
        x = math.floor(x), y = math.floor(y), width = width, height = math.ceil(height),
        padding = padding, gap = gap, font = font, title = title,
        titleHeight = titleHeight, footer = table.concat(footerLines, "\n"),
        imageWidth = innerWidth, imageHeight = imageHeight, uiScale = scale
    }
end

local function update(state, dt)
    local row, data = hoveredPlacement(state)
    if not row then reset(state); return end

    local room = loadedState.getSelectedRoom()
    local staleHandler = state.preview and state.preview.entityName and
        state.preview.handler ~= entities.registeredEntities[state.preview.entityName]
    if row ~= state.target or data.data ~= state.texture or data.currentLayer ~= state.layer
        or atlases.gameplay ~= state.atlas or room ~= state.room
        or entities.registeredEntities ~= state.entityRegistry or staleHandler
        or celesteRender.tilesMetaFg ~= state.tilesFg or celesteRender.tilesMetaBg ~= state.tilesBg then
        reset(state)
        state.target, state.texture, state.atlas = row, data.data, atlases.gameplay
        state.layer, state.room, state.entityRegistry = data.currentLayer, room, entities.registeredEntities
        state.tilesFg, state.tilesBg = celesteRender.tilesMetaFg, celesteRender.tilesMetaBg
        state.title = data.currentLayer == "entities" and (data.textNoMods or data.text) or data.data:sub(8)
        state.description = data.tooltip
    end

    state.age = state.age + dt
    if state.age >= timing.getDelay() then
        if not state.preview then
            state.preview = data.currentLayer == "entities" and entityPreview.create(data) or getDecalPreview(data.data)
        end
        layoutPopup(state)
    end
end

local function draw(state)
    local popup = state.popup
    if not popup then return end
    local preview = state.preview
    local x, y, padding = popup.x, popup.y, popup.padding
    local imageX = x + padding
    local imageY = y + padding + popup.titleHeight + popup.gap
    local width, height = popup.imageWidth, popup.imageHeight

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setFont(popup.font)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x + 4, y + 4, popup.width, popup.height)
    love.graphics.setColor(0.08, 0.08, 0.09, 1)
    love.graphics.rectangle("fill", x, y, popup.width, popup.height)
    love.graphics.setColor(0.55, 0.55, 0.6, 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, popup.width - 1, popup.height - 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(popup.title, x + padding, y + padding)

    love.graphics.setScissor(imageX, imageY, width, height)
    local cell = math.ceil(8 * popup.uiScale)
    for cx = 0, math.ceil(width / cell) - 1 do
        for cy = 0, math.ceil(height / cell) - 1 do
            local shade = (cx + cy) % 2 == 0 and 0.17 or 0.23
            love.graphics.setColor(shade, shade, shade, 1)
            love.graphics.rectangle("fill", imageX + cx * cell, imageY + cy * cell, cell, cell)
        end
    end

    if preview.drawable or preview.canvas then
        local bounds = preview.bounds
        local scale = math.min(width / bounds.width, height / bounds.height, 4 * popup.uiScale)
        -- Integer upscaling preserves pixel edges; larger decals fit the popup.
        if scale >= 1 then scale = math.max(1, math.floor(scale)) end
        local drawX = math.floor(imageX + (width - bounds.width * scale) / 2)
        local drawY = math.floor(imageY + (height - bounds.height * scale) / 2)
        love.graphics.translate(drawX, drawY)
        love.graphics.scale(scale)
        love.graphics.translate(-bounds.x, -bounds.y)
        love.graphics.setColor(1, 1, 1, 1)
        if preview.canvas then
            love.graphics.setBlendMode("alpha", "premultiplied")
            love.graphics.draw(preview.canvas)
            love.graphics.setBlendMode("alpha", "alphamultiply")
        else
            local image = preview.drawable.meta.image
            local minFilter, magFilter, anisotropy = image:getFilter()
            image:setFilter("linear", "nearest", anisotropy)
            preview.drawable:draw()
            -- Filtering belongs to the shared texture, not the graphics state stack.
            image:setFilter(minFilter, magFilter, anisotropy)
        end
        love.graphics.origin()
    else
        love.graphics.setColor(1, 0.35, 0.65, 1)
        love.graphics.line(imageX + padding, imageY + padding,
            imageX + width - padding, imageY + height - padding)
        love.graphics.line(imageX + width - padding, imageY + padding,
            imageX + padding, imageY + height - padding)
    end

    love.graphics.setScissor()
    love.graphics.setColor(0.78, 0.78, 0.82, 1)
    love.graphics.print(popup.footer, x + padding, imageY + height + popup.gap)
    love.graphics.pop()
end

function hoverPreview.install(list, isEnabled)
    local state = ui._visualPreviewsHover
    if not state then
        state = {}
        local originalUpdate, originalDraw = ui.update, ui.draw
        ui.update = function(...)
            local result = originalUpdate(...)
            state.update(love.timer.getDelta())
            return result
        end
        -- Draw after the UI, outside all list and panel clipping rectangles.
        -- The popup has no input element, so it never steals hover or clicks.
        ui.draw = function(...)
            local result = originalDraw(...)
            state.draw()
            return result
        end
    end

    ui._visualPreviewsHover = state
    state.list, state.isEnabled = list, isEnabled
    state.update = function(dt) update(state, dt) end
    state.draw = function() draw(state) end
    state.reset = function() reset(state) end
    reset(state)
    return state
end

return hoverPreview
