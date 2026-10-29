local mods = require("mods")
local settings = mods.getModSettings("LoennVisualPreviews")

local timing = {defaultDelay = 0.35}

function timing.valid(value)
    return type(value) == "number" and value >= 0 and value < math.huge
end

function timing.getDelay()
    local value = settings.previewDelay
    return timing.valid(value) and value or timing.defaultDelay
end

return timing
