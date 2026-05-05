local json = require("json")
local MagicData = require("libkxyy_magic_data")

local CONFIG_NAME = "libkxyy_config"
local DEFAULT_MAGIC_WHEEL_HOTKEY = rawget(_G, "KEY_G") or 71
local MAGIC_ENABLED_PREFIX = "magic_wheel_enabled_"

local DEFINITIONS = {}

local function GetMagicEnabledName(key)
    return MAGIC_ENABLED_PREFIX .. key
end

local function AddDefinition(definition)
    DEFINITIONS[#DEFINITIONS + 1] = definition
end

AddDefinition({
    type = "section",
    label = "基本配置",
})

AddDefinition({
    name = "lock_ui",
    type = "checkbox",
    label = "锁定 UI",
    description = "勾选后，将锁定 UI 的位置和大小\n非锁定状态下，右键拖拽，滚轮缩放",
    default = false,
})

AddDefinition({
    name = "fixed_magic_wheel",
    type = "checkbox",
    label = "固定轮盘",
    description = "开启后，轮盘始终在中心展开，否则在鼠标的位置展开",
    default = true,
})

AddDefinition({
    name = "magic_wheel_hotkey",
    type = "key",
    label = "轮盘按键",
    description = "按住打开魔法轮盘，松开选择当前指向的魔法",
    default = DEFAULT_MAGIC_WHEEL_HOTKEY,
})

AddDefinition({
    name = "quick_switch_previous_magic",
    type = "checkbox",
    label = "短按切换魔法",
    description = "开启后，短按轮盘按键会在当前魔法和上一个魔法之间切换",
    default = true,
})

AddDefinition({
    name = "debug_panel_hotkey",
    type = "key",
    label = "调试面板",
    description = "按下开关调试面板，需要管理员权限",
    default = -1,
})

AddDefinition({
    type = "section",
    label = "战斗辅助",
})

AddDefinition({
    name = "repeat_nilxin_skill_hotkey",
    type = "key",
    label = "快捷重复施法",
    description = "按下重复释放上次选择的魔法",
    default = -1,
})

AddDefinition({
    name = "locked_repeat_nilxin_skill_hotkey",
    type = "key",
    label = "锁定重复施法",
    description = "按下锁定重复释放上次选择的魔法，再按取消锁定",
    default = -1,
})

AddDefinition({
    name = "hongye_true_damage_hotkey",
    type = "key",
    label = "红叶真伤",
    description = "按下快速装备并开启红叶真伤模式",
    default = -1,
})

AddDefinition({
    name = "yeyu_lunge_attraction_toggle_hotkey",
    type = "key",
    label = "夜雨突刺吸附",
    description = "按下切换夜雨突刺吸附开关，使你不需要精确地瞄准敌人\n注：对快速移动中的目标可能不准确",
    default = -1,
})

AddDefinition({
    name = "yeyu_lunge_attraction_range",
    type = "number",
    label = "吸附范围",
    description = "夜雨突刺吸附的搜索范围",
    default = 2,
    min = 1,
    max = 10,
    step = 0.5,
})

AddDefinition({
    type = "section",
    label = "其他辅助",
})

AddDefinition({
    name = "wanda_teleport_ui_hotkey",
    type = "key",
    label = "一时之间",
    description = "按下快速开关一时之间 UI",
    default = -1,
})

AddDefinition({
    name = "summon_shadow_chest_hotkey",
    type = "key",
    label = "召唤小影",
    description = "按下快速召唤小影",
    default = -1,
})

AddDefinition({
    type = "section",
    label = "轮盘魔法配置",
})

for _, option in ipairs(MagicData) do
    AddDefinition({
        name = GetMagicEnabledName(option.key),
        type = "checkbox",
        label = option.label,
        description = "勾选后，在魔法轮盘中显示「" .. option.label .. "」",
        default = true,
        magic_key = option.key,
    })
end

-- AddDefinition({
--     type = "section",
--     label = "其他功能",
-- })

-- AddDefinition({
--     name = "reset_skill_tree",
--     type = "button",
--     label = "重置技能树",
--     button_label = "执行",
--     confirm_title = "确认重置技能树",
--     confirm_body = "确定要重置技能树吗？",
--     action = function()
--         local API = require("yyxk_api")
--         local player_api = API:GetCurrent()
--         return player_api ~= nil and player_api:ResetSkillTree()
--     end,
-- })

local ModConfig = {
    values = {},
    ui = {},
    listeners = {},
    load_listeners = {},
    load_started = false,
    load_complete = false,
}

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

    return value
end

function ModConfig:GetDefinitions()
    return CopyDefinitions()
end

function ModConfig:GetDefinition(name)
    if name == nil then
        return nil
    end

    for _, definition in ipairs(DEFINITIONS) do
        if definition.name == name then
            return definition
        end
    end
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
