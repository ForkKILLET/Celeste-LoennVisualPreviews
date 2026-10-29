local elements = require("ui.elements")
local tabbedWindow = require("ui.widgets.tabbed_window")
local mods = require("mods")
local settings = mods.getModSettings("LoennVisualPreviews")
local timing = mods.requireFromPlugin("libraries.preview_timing", "LoennVisualPreviews")
local numberField = require("ui.forms.fields.number")

local settingsWindow = {}
local options = {
    {key = "enabled", text = "Tile icons", tooltip = "Show previews before foreground/background tile names."},
    {key = "decalHoverPreviews", text = "Decal previews", tooltip = "Hover foreground/background decals to preview their texture."},
    {key = "entityHoverPreviews", text = "Entity previews", tooltip = "Hover entities to preview their default placement."}
}

local function extendEditor(tabs, onChanged)
    for index, tab in ipairs(tabs) do
        -- Identify the native Editor form by its fields, independently of locale.
        for _, fieldName in ipairs(tab.fieldNames or {}) do
            if fieldName == "ui.theme.themeName" then
                local body = tab.content.children[1].inner
                local title = elements.lineSeparator("Visual previews", 16, true)
                title:addBottomPadding()
                local children = {}
                for _, option in ipairs(options) do
                    local key = option.key
                    local checkbox = elements.checkbox(option.text, settings[key] ~= false, function(_, value)
                        settings[key] = value
                        onChanged()
                    end):with({tooltipText = option.tooltip})
                    table.insert(children, checkbox)
                end
                local delayField = numberField.getElement("previewDelay", timing.getDelay(), {
                    displayName = "Preview delay (seconds)",
                    tooltipText = "Delay before decal/entity previews. Use 0 for no delay. Default: 0.35 seconds.",
                    minimumValue = 0,
                    allowEmpty = false
                })
                local validator = delayField.validator
                delayField.validator = function(value, raw)
                    return timing.valid(value) and validator(value, raw)
                end
                delayField.notifyFieldChanged = function(self)
                    if self:fieldValid() then
                        settings.previewDelay = self:getValue()
                        onChanged()
                    end
                end
                table.insert(children, elements.row(delayField.elements))
                local controls = elements.column(children):with({style = {padding = 0, spacing = 8}})
                controls._visualPreviewsDelayField = delayField
                -- Place previews after Interface, inside the existing scrollable body.
                body:addChild(title, math.min(3, #body.children + 1))
                body:addChild(controls, math.min(4, #body.children + 1))
                return controls, index
            end
        end
    end
end

function settingsWindow.install(handler, onChanged)
    if not handler or not handler.editSettings or handler._visualPreviewsSettingsWrapped then return end
    handler._visualPreviewsSettingsWrapped = true
    local original = handler.editSettings
    handler.editSettings = function(...)
        local createWindow = tabbedWindow.createWindow
        local controls, editorIndex
        -- The native settings form keeps its tab definitions private. Intercept
        -- only this synchronous construction, restoring the public factory even
        -- if another part of the settings window raises an error.
        tabbedWindow.createWindow = function(title, tabs, ...)
            controls, editorIndex = extendEditor(tabs, onChanged)
            return createWindow(title, tabs, ...)
        end
        local ok, window = pcall(original, ...)
        tabbedWindow.createWindow = createWindow
        if not ok then error(window, 0) end
        window._visualPreviewsSettings = controls
        window._visualPreviewsEditorTab = editorIndex
        return window
    end
end

return settingsWindow
