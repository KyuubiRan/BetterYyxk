local json = require("json")

local CONFIG_NAME = "better_yyxk_settings"

local DEFINITIONS = {
    {
        name = "lock_ui",
        type = "checkbox",
        label = "锁定 UI",
        description = "勾选后，将锁定 UI 的位置和大小",
        default = false,
    },
    {
        name = "test_hotkey",
        type = "key",
        label = "测试按键",
        description = "点击后按下一个按键进行绑定，按 Esc 取消并设为 None",
        default = -1,
    },
}

local ModConfig = {
    values = {},
    listeners = {},
    load_started = false,
    load_complete = false,
}

local function CopyDefinitions()
    local copied = {}

    for i, definition in ipairs(DEFINITIONS) do
        copied[i] = definition
    end

    return copied
end

local function NotifyListeners(changed)
    for listener in pairs(ModConfig.listeners) do
        listener(changed)
    end
end

local function NormalizeValue(definition, value)
    if definition == nil then
        return value
    end

    if definition.type == "checkbox" then
        return value == true
    end

    if definition.type == "number" then
        value = tonumber(value)
        if value == nil then
            return definition.default
        end

        if definition.min ~= nil then
            value = math.max(definition.min, value)
        end
        if definition.max ~= nil then
            value = math.min(definition.max, value)
        end

        return value
    end

    if definition.type == "key" then
        value = tonumber(value)
        if value == nil then
            return definition.default
        end

        return value
    end

    return value
end

function ModConfig:GetDefinitions()
    return CopyDefinitions()
end

function ModConfig:GetDefinition(name)
    for _, definition in ipairs(DEFINITIONS) do
        if definition.name == name then
            return definition
        end
    end
end

function ModConfig:Get(name, fallback)
    if self.values[name] ~= nil then
        return self.values[name]
    end

    local definition = self:GetDefinition(name)
    if definition ~= nil then
        return definition.default
    end

    return fallback
end

function ModConfig:AddListener(listener)
    if listener ~= nil then
        self.listeners[listener] = true
    end

    return listener
end

function ModConfig:RemoveListener(listener)
    if listener ~= nil then
        self.listeners[listener] = nil
    end
end

function ModConfig:Load()
    if self.load_started then
        return
    end

    self.load_started = true

    for _, definition in ipairs(DEFINITIONS) do
        self.values[definition.name] = definition.default
    end

    if TheSim == nil then
        self.load_complete = true
        return
    end

    TheSim:GetPersistentString(CONFIG_NAME, function(load_success, str)
        if load_success and str ~= nil and str ~= "" then
            local ok, data = pcall(function()
                return json.decode(str)
            end)

            if ok and type(data) == "table" and type(data.values) == "table" then
                local changed = {}

                for _, definition in ipairs(DEFINITIONS) do
                    local value = NormalizeValue(definition, data.values[definition.name])
                    if value ~= nil and self.values[definition.name] ~= value then
                        self.values[definition.name] = value
                        changed[definition.name] = value
                    end
                end

                if next(changed) ~= nil then
                    NotifyListeners(changed)
                end
            end
        end

        self.load_complete = true
    end)
end

function ModConfig:SaveBatch(entries)
    if entries == nil then
        return
    end

    local changed = {}

    for name, value in pairs(entries) do
        local definition = self:GetDefinition(name)
        if definition ~= nil then
            local normalized = NormalizeValue(definition, value)
            if normalized ~= nil and self.values[name] ~= normalized then
                self.values[name] = normalized
                changed[name] = normalized
            end
        end
    end

    if next(changed) == nil then
        return
    end

    NotifyListeners(changed)

    if TheSim == nil then
        return
    end

    local payload = {
        version = 1,
        values = self.values,
    }
    local encoded = json.encode(payload)

    if SavePersistentString ~= nil then
        SavePersistentString(CONFIG_NAME, encoded, false)
    else
        TheSim:SetPersistentString(CONFIG_NAME, encoded, false, nil)
    end
end

return ModConfig
