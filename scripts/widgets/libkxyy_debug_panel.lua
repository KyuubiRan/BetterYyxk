local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TEMPLATES = require("widgets/redux/templates")
local KeyListener = require("libkxyy_key_listener")
local DBGAPI = require("yyxk_debug_api")
local LibKxyyDebugItem = require("widgets/libkxyy_debug_item")

local PANEL_WIDTH = 460
local PANEL_HEIGHT = 430
local ITEM_HEIGHT = 40
local ITEM_WIDTH = PANEL_WIDTH - 46
local VISIBLE_ROWS = 9
local CONTENT_ROOT_Y = 20
local OPTIONS_PANEL_Y = -42
local SCROLLBAR_OFFSET = 28
local SCROLLBAR_HEIGHT_OFFSET = -52

local YEYU_SKILLS = {
    { key = "multithrust", label = "连击" },
    { key = "crazy", label = "血咲" },
    { key = "swordqi", label = "破空绝念斩" },
    { key = "sharpblade", label = "利刃" },
    { key = "aoe", label = "涟漪" },
    { key = "draw", label = "嗜血" },
    { key = "kill", label = "魂斩" },
    { key = "agile", label = "踏浪" },
    { key = "yeyu", label = "觉醒" },
}

local NILXIN_SKILLS = {
    { key = "fire", label = "火" },
    { key = "water", label = "水" },
    { key = "ice", label = "冰" },
    { key = "lightning", label = "电" },
    { key = "wind", label = "风" },
    { key = "space", label = "空" },
    { key = "moon", label = "月" },
    { key = "shadow", label = "暗" },
    { key = "nilxin", label = "觉醒" },
}

local GEM_OPTIONS = {
    { key = "nilxin_greygem", label = "灰宝石" },
    { key = "nilxin_cyangem", label = "青宝石" },
    { key = "purplegem", label = "紫宝石" },
    { key = "bluegem", label = "蓝宝石" },
    { key = "redgem", label = "红宝石" },
    { key = "orangegem", label = "橙宝石" },
    { key = "yellowgem", label = "黄宝石" },
    { key = "greengem", label = "绿宝石" },
    { key = "opalpreciousgem", label = "彩虹宝石" },
}

local POTION_BUFF_OPTIONS = {
    { key = "scale", label = "法相天地", default = 1 },
    { key = "qbwh", label = "千变万化", default = 2 },
    { key = "stian", label = "飞天", default = 1 },
    { key = "shenshu", label = "神速", default = 1 },
    { key = "NILXIN_FOXBALL_REDOPALPRECIOUSGEM", label = "月光凄美", default = 1 },
    { key = "NILXIN_FOXBALL_REDORANGEGEM", label = "空间感知", default = 1 },
    { key = "yyxkmp", label = "魔力恢复", default = 1 },
    { key = "mybd", label = "免疫冰冻", default = 1 },
    { key = "mysm", label = "免疫睡眠", default = 1 },
    { key = "smhf", label = "生命恢复", default = 1 },
    { key = "whbe", label = "我还不饿", default = 1 },
    { key = "cydjs", label = "时光凝聚", default = 1 },
    { key = "cantxinao", label = "精神抵抗", default = 1 },
    { key = "picksomething2", label = "双倍采集", default = 1 },
    { key = "NILXIN_FOXBALL_REDBLUEGEM", label = "免热魔法", default = 30 },
    { key = "NILXIN_FOXBALL_REDREDGEM", label = "免冷魔法", default = 30 },
}

local DEFINITIONS = {}

local function AddDefinition(definition)
    DEFINITIONS[#DEFINITIONS + 1] = definition
end

local function AddSkillSection(label, group, skills)
    AddDefinition({
        type = "section",
        label = label,
    })

    for _, skill in ipairs(skills) do
        local key = skill.key
        local skill_label = skill.label
        AddDefinition({
            name = group .. "_" .. key,
            type = "toggle_action",
            label = skill_label,
            group = group,
            key = key,
            action = function(definition, enabled)
                return DBGAPI:SetSkillUnlocked(definition.group, definition.key, enabled)
            end,
        })
    end
end

local function AddGemSection()
    AddDefinition({
        type = "section",
        label = "元素相关",
    })

    for _, gem in ipairs(GEM_OPTIONS) do
        AddDefinition({
            name = "gem_" .. gem.key,
            type = "number_action",
            label = gem.label,
            default = 1,
            step = 100,
            button_label = "执行",
            gem_key = gem.key,
            action = function(definition, value)
                return DBGAPI:SetGemValue(definition.gem_key, value)
            end,
        })
    end
end

local function AddPotionSection()
    AddDefinition({
        type = "section",
        label = "药剂相关",
    })
    AddDefinition({
        name = "create_potion",
        type = "number_action",
        label = "生成药剂",
        default = 9,
        min = 1,
        max = 9,
        step = 1,
        button_label = "执行",
        action = function(definition, value)
            return DBGAPI:CreatePotion(value, definition.panel:GetPotionBuffs())
        end,
    })

    for _, buff in ipairs(POTION_BUFF_OPTIONS) do
        AddDefinition({
            name = "potion_buff_" .. buff.key,
            type = "potion_buff",
            label = buff.label,
            default = buff.default,
            step = 1,
            potion_buff_key = buff.key,
        })
    end
end

local function AddEquipmentSection()
    AddDefinition({
        type = "section",
        label = "装备相关",
    })
    AddDefinition({
        name = "yyxk_amulet",
        type = "toggle_action",
        label = "满级伞护",
        action = function(_, enabled)
            return DBGAPI:SetYyxkAmulet(enabled)
        end,
    })
    AddDefinition({
        name = "wand_decompose",
        type = "number_action",
        label = "魔杖分解",
        description = "需要装备魔杖",
        default = 0,
        min = 0,
        step = 1000,
        button_label = "执行",
        action = function(_, value)
            return DBGAPI:SetWandDecompose(value)
        end,
    })
    AddDefinition({
        name = "yeyu_foxfire",
        type = "number_action",
        label = "红叶狐火",
        description = "需要装备红叶",
        default = 0,
        min = 0,
        step = 1,
        button_label = "执行",
        action = function(_, value)
            return DBGAPI:SetYeyuFoxfire(value)
        end,
    })
end

AddDefinition({
    type = "section",
    label = "人物相关",
})
AddDefinition({
    name = "set_skill_points",
    type = "number_action",
    label = "设置技能点",
    default = 972,
    min = 0,
    max = 999,
    step = 1,
    button_label = "执行",
    action = function(_, value)
        return DBGAPI:SetSkillPoints(value)
    end,
})
AddDefinition({
    name = "set_huxin_level",
    type = "number_action",
    label = "狐心等级",
    default = 100,
    min = 0,
    max = 100,
    step = 1,
    button_label = "执行",
    action = function(_, value)
        return DBGAPI:SetHuxinLevel(value)
    end,
})
AddDefinition({
    name = "unlock_skill_tree",
    type = "button_action",
    label = "技能树全开",
    button_label = "执行",
    description = "执行前请确保有足够的技能点数",
    action = function()
        return DBGAPI:UnlockSkillTree()
    end,
})
AddDefinition({
    name = "unlock_movement_fox",
    type = "button_action",
    label = "解锁身法 & 大狐狸",
    button_label = "执行",
    action = function()
        return DBGAPI:UnlockMovementFox()
    end,
})
AddDefinition({
    type = "section",
    label = "魔力相关",
})
AddDefinition({
    name = "delta_mana",
    type = "number_action",
    label = "恢复魔力",
    default = 100,
    min = -1000,
    max = 1000,
    step = 100,
    button_label = "执行",
    action = function(_, value)
        return DBGAPI:DeltaMana(value)
    end,
})
AddDefinition({
    name = "inf_mana",
    type = "toggle_action",
    label = "无限魔力",
    action = function()
        return DBGAPI:ToggleInfMana()
    end,
})
AddDefinition({
    type = "section",
    label = "姐妹相关",
})
AddDefinition({
    name = "yeyunilxin",
    type = "toggle_action",
    label = "解锁",
    action = function(_, enabled)
        return DBGAPI:SetJiemeiUnlocked(enabled)
    end,
})
AddDefinition({
    name = "jiemei_xin",
    type = "number_action",
    label = "心情",
    default = 100,
    min = -99,
    max = 100,
    step = 10,
    button_label = "执行",
    action = function(_, value)
        return DBGAPI:SetJiemeiXin(value)
    end,
})
AddDefinition({
    name = "jiemei_love",
    type = "number_action",
    label = "好感",
    default = 100,
    min = 0,
    max = 99999,
    step = 100,
    button_label = "执行",
    action = function(_, value)
        return DBGAPI:SetJiemeiLove(value)
    end,
})
AddEquipmentSection()
AddGemSection()
AddPotionSection()
AddSkillSection("夜雨技能", "yeyuup", YEYU_SKILLS)
AddSkillSection("空心技能", "nilxinup", NILXIN_SKILLS)

local LibKxyyDebugPanel = Class(Widget, function(self, owner)
    Widget._ctor(self, "LibKxyyDebugPanel")

    self.owner = owner
    self.values = {}
    self.toggles = {
        inf_mana = false,
        yeyunilxin = false,
        yyxk_amulet = false,
        yeyuup = {},
        nilxinup = {},
    }

    for _, buff in ipairs(POTION_BUFF_OPTIONS) do
        self.toggles["potion_buff_" .. buff.key] = false
    end

    for _, definition in ipairs(DEFINITIONS) do
        definition.panel = self
    end

    self:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self:SetHAnchor(ANCHOR_MIDDLE)
    self:SetVAnchor(ANCHOR_MIDDLE)
    self:SetPosition(0, 0, 0)

    local buttons = {
        {
            text = "关闭",
            cb = function()
                self:HidePanel()
            end,
        },
    }

    self.dialog = self:AddChild(TEMPLATES.RectangleWindow(PANEL_WIDTH, PANEL_HEIGHT, nil, buttons))

    self.header = self.dialog:AddChild(Widget("header"))
    self.header:SetPosition(0, 184, 0)

    self.title = self.header:AddChild(Text(HEADERFONT, 28, "空心夜雨-调试面板"))
    self.title:SetColour(UICOLOURS.GOLD_SELECTED)
    self.title:SetRegionSize(PANEL_WIDTH - 96, 36)

    self.content_root = self.dialog:InsertWidget(Widget("content_root"))
    self.content_root:SetPosition(0, CONTENT_ROOT_Y, 0)

    self.optionspanel = self.content_root:AddChild(Widget("optionspanel"))
    self.optionspanel:SetPosition(0, OPTIONS_PANEL_Y, 0)

    local function ScrollWidgetsCtor(context, idx)
        return LibKxyyDebugItem(self, ITEM_WIDTH, ITEM_HEIGHT)
    end

    local function ApplyDataToWidget(context, widget, data, idx)
        widget:SetData(data)
    end

    self.options_scroll_list = self.optionspanel:AddChild(TEMPLATES.ScrollingGrid(DEFINITIONS, {
        scroll_context = {},
        widget_width = ITEM_WIDTH,
        widget_height = ITEM_HEIGHT,
        num_visible_rows = VISIBLE_ROWS,
        num_columns = 1,
        item_ctor_fn = ScrollWidgetsCtor,
        apply_fn = ApplyDataToWidget,
        scrollbar_offset = SCROLLBAR_OFFSET,
        scrollbar_height_offset = SCROLLBAR_HEIGHT_OFFSET,
    }))
    self.options_scroll_list:SetPosition(-2, -4, 0)

    self._debug_listener = DBGAPI:AddListener(function(status)
        if self.inst ~= nil
            and self.inst:IsValid()
            and self.owner ~= nil
            and self.owner:IsValid()
            and ThePlayer == self.owner then
            self:ApplyStatus(status)
        else
            self:RemoveDebugListener()
        end
    end)
    self._equipment_sync_fn = function()
        if self.shown then
            DBGAPI:SyncStatus()
        end
    end
    if self.owner ~= nil and self.owner.ListenForEvent ~= nil then
        self.owner:ListenForEvent("equip", self._equipment_sync_fn)
        self.owner:ListenForEvent("unequip", self._equipment_sync_fn)
    end

    self.default_focus = self.options_scroll_list

    self:Hide()
end)

function LibKxyyDebugPanel:RemoveDebugListener()
    if self._debug_listener ~= nil then
        DBGAPI:RemoveListener(self._debug_listener)
        self._debug_listener = nil
    end

    if self._equipment_sync_fn ~= nil
        and self.owner ~= nil
        and self.owner.RemoveEventCallback ~= nil then
        self.owner:RemoveEventCallback("equip", self._equipment_sync_fn)
        self.owner:RemoveEventCallback("unequip", self._equipment_sync_fn)
        self._equipment_sync_fn = nil
    end
end

function LibKxyyDebugPanel:GetNumber(definition)
    if definition == nil then
        return 0
    end

    if self.values[definition.name] == nil then
        self.values[definition.name] = definition.default or 0
    end

    return self.values[definition.name]
end

function LibKxyyDebugPanel:SetNumber(definition, value)
    if definition == nil or definition.name == nil then
        return
    end

    self.values[definition.name] = value
end

function LibKxyyDebugPanel:GetPotionBuffs()
    local buffs = {}
    for _, buff in ipairs(POTION_BUFF_OPTIONS) do
        local definition = {
            name = "potion_buff_" .. buff.key,
            default = buff.default,
        }
        if self:GetToggle(definition) then
            buffs[#buffs + 1] = {
                key = buff.key,
                value = self:GetNumber(definition),
            }
        end
    end

    return buffs
end

function LibKxyyDebugPanel:GetToggle(definition)
    if definition == nil or definition.name == nil then
        return false
    end

    if definition.group ~= nil and definition.key ~= nil then
        local group = self.toggles[definition.group]
        return type(group) == "table" and group[definition.key] == true
    end

    return self.toggles[definition.name] == true
end

function LibKxyyDebugPanel:SetToggle(definition, enabled)
    if definition == nil then
        return
    end

    if definition.group ~= nil and definition.key ~= nil then
        local group = self.toggles[definition.group]
        if type(group) == "table" then
            group[definition.key] = enabled == true
        end
    elseif definition.name ~= nil then
        self.toggles[definition.name] = enabled == true
    end
end

function LibKxyyDebugPanel:ApplyStatus(status)
    if type(status) ~= "table" then
        return
    end

    if status.inf_mana ~= nil then
        self.toggles.inf_mana = status.inf_mana == true
    end
    if status.yeyunilxin ~= nil then
        self.toggles.yeyunilxin = status.yeyunilxin == true
    end
    if status.yyxk_amulet ~= nil then
        self.toggles.yyxk_amulet = status.yyxk_amulet == true
    end
    if status.xin ~= nil then
        self.values.jiemei_xin = tonumber(status.xin) or 0
    end
    if status.love ~= nil then
        self.values.jiemei_love = tonumber(status.love) or 0
    end
    if status.wand_decompose ~= nil then
        self.values.wand_decompose = tonumber(status.wand_decompose) or 0
    end
    if status.yeyu_foxfire ~= nil then
        self.values.yeyu_foxfire = tonumber(status.yeyu_foxfire) or 0
    end
    if type(status.gem) == "table" then
        for _, gem in ipairs(GEM_OPTIONS) do
            local value = status.gem[gem.key]
            if value ~= nil then
                self.values["gem_" .. gem.key] = tonumber(value) or 0
            end
        end
    end

    if type(status.yeyuup) == "table" then
        for k in pairs(self.toggles.yeyuup) do
            self.toggles.yeyuup[k] = nil
        end
        for k, v in pairs(status.yeyuup) do
            self.toggles.yeyuup[k] = v == true
        end
    end

    if type(status.nilxinup) == "table" then
        for k in pairs(self.toggles.nilxinup) do
            self.toggles.nilxinup[k] = nil
        end
        for k, v in pairs(status.nilxinup) do
            self.toggles.nilxinup[k] = v == true
        end
    end

    if self.options_scroll_list ~= nil then
        self.options_scroll_list:RefreshView()
    end
end

function LibKxyyDebugPanel:Execute(definition)
    if definition == nil or definition.action == nil then
        if definition ~= nil and definition.type == "potion_buff" then
            local value = not self:GetToggle(definition)
            self:SetToggle(definition, value)
            if self.options_scroll_list ~= nil then
                self.options_scroll_list:RefreshView()
            end
            return value
        end

        return false
    end

    local is_toggle = definition.type == "toggle_action"
        or definition.type == "potion_buff"
    local current = is_toggle and self:GetToggle(definition) or nil
    local value = is_toggle and not current or (definition.type == "number_action" and self:GetNumber(definition) or nil)
    local ok = definition.action(definition, value)
    if not ok and self.owner ~= nil and self.owner.components ~= nil and self.owner.components.talker ~= nil then
        self.owner.components.talker:Say("调试命令执行失败")
    end

    if is_toggle then
        if ok then
            self:SetToggle(definition, value)
            if self.options_scroll_list ~= nil then
                self.options_scroll_list:RefreshView()
            end
            return value
        end

        return current
    end

    return ok
end

function LibKxyyDebugPanel:ShowPanel()
    if not DBGAPI:IsAdmin() then
        if self.owner ~= nil
            and self.owner.components ~= nil
            and self.owner.components.talker ~= nil then
            self.owner.components.talker:Say("需要管理员权限")
        end
        return false
    end

    KeyListener:SetSettingsOpen(true)
    self:ApplyStatus(DBGAPI:GetStatus())
    DBGAPI:SyncStatus()
    self:MoveToFront()
    self:Show()
    return true
end

function LibKxyyDebugPanel:HidePanel()
    KeyListener:SetSettingsOpen(false)
    self:Hide()
    return true
end

function LibKxyyDebugPanel:Toggle()
    if self.shown then
        return self:HidePanel()
    else
        return self:ShowPanel()
    end
end

function LibKxyyDebugPanel:OnRemoveEntity()
    self:RemoveDebugListener()
end

function LibKxyyDebugPanel:Kill()
    self:RemoveDebugListener()
    Widget.Kill(self)
end

return LibKxyyDebugPanel
