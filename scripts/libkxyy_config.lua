local json = require("json")

local CONFIG_NAME = "libkxyy_config"
local MAGIC_ENABLED_PREFIX = "magic_wheel_enabled_"

local DEFINITIONS = {}
local DEFINITION_MAP = {}

local function GetMagicEnabledName(key)
    return MAGIC_ENABLED_PREFIX .. key
end

local ModConfig = {
    values = {},
    ui = {},
    listeners = {},
    load_listeners = {},
    load_started = false,
    load_complete = false,
}

local function RebuildDefinitionMap()
    DEFINITION_MAP = {}

    for _, definition in ipairs(DEFINITIONS) do
        if definition.name ~= nil then
            DEFINITION_MAP[definition.name] = definition
        end
    end
end

local function CopyDefinitions()
    local copied = {}

    for i, definition in ipairs(DEFINITIONS) do
        if not definition.hidden then
            copied[#copied + 1] = definition
        end
    end

    return copied
end

local function NotifyListeners(changed)
    for listener in pairs(ModConfig.listeners) do
        listener(changed)
    end
end

local function NotifyLoadListeners()
    for listener in pairs(ModConfig.load_listeners) do
        listener(ModConfig)
    end
end

local function SavePersistent()
    if TheSim == nil then
        return
    end

    local payload = {
        version = 1,
        values = ModConfig.values,
        ui = ModConfig.ui,
    }
    local encoded = json.encode(payload)

    if SavePersistentString ~= nil then
        SavePersistentString(CONFIG_NAME, encoded, false)
    else
        TheSim:SetPersistentString(CONFIG_NAME, encoded, false, nil)
    end
end

local function NormalizeValue(definition, value)
    if definition == nil then
        return value
    end

    if definition.type == "checkbox" then
        if value == nil then
            return definition.default
        end

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

    if definition.type == "choice" then
        for _, option in ipairs(definition.options or {}) do
            if option.data == value then
                return value
            end
        end

        return definition.default
    end

    return value
end

function ModConfig:SetDefinitions(definitions)
    DEFINITIONS = definitions or {}
    RebuildDefinitionMap()

    for _, definition in ipairs(DEFINITIONS) do
        if definition.name ~= nil and self.values[definition.name] == nil then
            self.values[definition.name] = definition.default
        end
    end
end

function ModConfig:GetDefinitions()
    return CopyDefinitions()
end

function ModConfig:GetDefinition(name)
    if name == nil then
        return nil
    end

    return DEFINITION_MAP[name]
end

function ModConfig:GetMagicEnabledName(key)
    return GetMagicEnabledName(key)
end

function ModConfig:IsMagicEnabled(key)
    return self:Get(GetMagicEnabledName(key), true) == true
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

function ModConfig:AddLoadListener(listener)
    if listener ~= nil then
        self.load_listeners[listener] = true

        if self.load_complete then
            listener(self)
        end
    end

    return listener
end

function ModConfig:RemoveLoadListener(listener)
    if listener ~= nil then
        self.load_listeners[listener] = nil
    end
end

function ModConfig:Load()
    if self.load_started then
        return
    end

    self.load_started = true

    for _, definition in ipairs(DEFINITIONS) do
        if definition.name ~= nil then
            self.values[definition.name] = definition.default
        end
    end

    if TheSim == nil then
        self.load_complete = true
        NotifyLoadListeners()
        return
    end

    TheSim:GetPersistentString(CONFIG_NAME, function(load_success, str)
        if load_success and str ~= nil and str ~= "" then
            local ok, data = pcall(function()
                return json.decode(str)
            end)

            if ok and type(data) == "table" then
                local changed = {}

                if type(data.values) == "table" then
                    for _, definition in ipairs(DEFINITIONS) do
                        if definition.name ~= nil then
                            local value = NormalizeValue(definition, data.values[definition.name])
                            if value ~= nil and self.values[definition.name] ~= value then
                                self.values[definition.name] = value
                                changed[definition.name] = value
                            end
                        end
                    end
                end

                if type(data.ui) == "table" then
                    self.ui = data.ui
                end

                if next(changed) ~= nil then
                    NotifyListeners(changed)
                end
            end
        end

        self.load_complete = true
        NotifyLoadListeners()
    end)
end

function ModConfig:GetUIState(name)
    if name == nil or type(self.ui) ~= "table" then
        return nil
    end

    return self.ui[name]
end

function ModConfig:SaveUIState(name, state)
    if name == nil or type(state) ~= "table" then
        return
    end

    if type(self.ui) ~= "table" then
        self.ui = {}
    end

    self.ui[name] = state
    SavePersistent()
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
    SavePersistent()
end

return ModConfig
