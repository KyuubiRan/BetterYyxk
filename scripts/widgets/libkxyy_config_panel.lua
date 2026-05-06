local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TEMPLATES = require("widgets/redux/templates")
local PopupDialogScreen = require("screens/redux/popupdialog")
local ModConfig = require("libkxyy_config")
local KeyListener = require("libkxyy_key_listener")
local MagicData = require("libkxyy_magic_data")
local LibKxyyConfigItem = require("widgets/libkxyy_config_item")

local PANEL_WIDTH = 320
local PANEL_HEIGHT = 430
local ITEM_HEIGHT = 40
local ITEM_WIDTH = PANEL_WIDTH - 46
local VISIBLE_ROWS = 9
local CONTENT_ROOT_Y = 20
local OPTIONS_PANEL_Y = -42
local SCROLLBAR_OFFSET = 28
local SCROLLBAR_HEIGHT_OFFSET = -52
local DEFAULT_MAGIC_WHEEL_HOTKEY = rawget(_G, "KEY_G") or 71

local DEFINITIONS = {}

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
    description = "按下快速装备(需要在物品栏内)并开启红叶真伤模式",
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
    name = "right_click_reset_skill_tree",
    type = "checkbox",
    label = "右键重置天赋",
    description = "开启后，允许你在天赋界面右键点击对应天赋进行重置\n注：需要消耗仓库中的 白尾巴x1 和 灰宝石x1",
    default = true,
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
        name = ModConfig:GetMagicEnabledName(option.key),
        type = "checkbox",
        label = option.label,
        description = "勾选后，在魔法轮盘中显示「" .. option.label .. "」",
        default = true,
        magic_key = option.key,
    })
end

ModConfig:SetDefinitions(DEFINITIONS)

local LibKxyyConfigPanel = Class(Widget, function(self, owner)
    Widget._ctor(self, "LibKxyyConfigPanel")

    self.owner = owner
    self.config = ModConfig
    self.optionwidgets = DEFINITIONS
    self.capture_item = nil
    self.capture_transition = false

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
    self.header:SetPosition(0, 188, 0)

    self.title = self.header:AddChild(Text(HEADERFONT, 30, "空心夜雨"))
    self.title:SetColour(UICOLOURS.GOLD_SELECTED)

    self.content_root = self.dialog:InsertWidget(Widget("content_root"))
    self.content_root:SetPosition(0, CONTENT_ROOT_Y, 0)

    self.optionspanel = self.content_root:AddChild(Widget("optionspanel"))
    self.optionspanel:SetPosition(0, OPTIONS_PANEL_Y, 0)

    local function ScrollWidgetsCtor(context, idx)
        return LibKxyyConfigItem(self, ITEM_WIDTH, ITEM_HEIGHT)
    end

    local function ApplyDataToWidget(context, widget, data, idx)
        widget:SetData(data)
    end

    self.options_scroll_list = self.optionspanel:AddChild(TEMPLATES.ScrollingGrid(self.optionwidgets, {
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

    self._config_listener = self.config:AddListener(function(changed)
        self:OnConfigChanged(changed)
    end)

    self:Refresh()
    self.default_focus = self.options_scroll_list

    self:Hide()
end)

function LibKxyyConfigPanel:ToggleCheckbox(name)
    local current = self.config:Get(name, false)
    local next_value = not current
    self.config:SaveBatch({
        [name] = next_value,
    })
    return next_value
end

function LibKxyyConfigPanel:BindKey(name, key)
    self.config:SaveBatch({
        [name] = key,
    })
end

function LibKxyyConfigPanel:SetNumber(name, value)
    self.config:SaveBatch({
        [name] = value,
    })
end

function LibKxyyConfigPanel:RunAction(definition)
    if definition == nil or definition.action == nil then
        return false
    end

    local function execute()
        if definition.action(definition) ~= true
            and self.owner ~= nil
            and self.owner.components ~= nil
            and self.owner.components.talker ~= nil then
            self.owner.components.talker:Say("执行失败")
        end
    end

    if definition.confirm_title ~= nil and TheFrontEnd ~= nil then
        local popup = PopupDialogScreen(
            definition.confirm_title,
            definition.confirm_body or "",
            {
                {
                    text = "确定",
                    cb = function()
                        TheFrontEnd:PopScreen()
                        execute()
                    end,
                },
                {
                    text = "取消",
                    cb = function()
                        TheFrontEnd:PopScreen()
                    end,
                },
            }
        )
        TheFrontEnd:PushScreen(popup)
        return true
    end

    execute()
    return true
end

function LibKxyyConfigPanel:BeginKeyCapture(item)
    if self.capture_item ~= nil and self.capture_item ~= item then
        self.capture_item:RefreshKeyDisplay()
    end

    self.capture_item = item
end

function LibKxyyConfigPanel:EndKeyCapture(item, keep_focus)
    if self.capture_transition then
        return
    end

    self.capture_transition = true
    local should_release = self.capture_item == item
    self.capture_item = nil

    if should_release and TheFrontEnd ~= nil then
        TheFrontEnd:SetForceProcessTextInput(false, item)
    end

    if item ~= nil then
        item:RefreshKeyDisplay()
        if not keep_focus and item.key_button ~= nil then
            item.key_button:ClearFocus()
        end
    end

    self.capture_transition = false
end

function LibKxyyConfigPanel:Refresh()
    if self.options_scroll_list ~= nil then
        self.optionwidgets = DEFINITIONS
        self.options_scroll_list:SetItemsData(self.optionwidgets)
        self.options_scroll_list:RefreshView()
    end
end

function LibKxyyConfigPanel:OnConfigChanged()
    self:Refresh()
end

function LibKxyyConfigPanel:ShowPanel()
    KeyListener:SetSettingsOpen(true)
    self:MoveToFront()
    self:Show()
end

function LibKxyyConfigPanel:HidePanel()
    KeyListener:SetSettingsOpen(false)

    if self.capture_item ~= nil then
        self:EndKeyCapture(self.capture_item, false)
    end

    self:Hide()
end

function LibKxyyConfigPanel:Toggle()
    if self.shown then
        self:HidePanel()
    else
        self:ShowPanel()
    end
end

function LibKxyyConfigPanel:OnRemoveEntity()
    if self.config ~= nil and self._config_listener ~= nil then
        self.config:RemoveListener(self._config_listener)
        self._config_listener = nil
    end
end

return LibKxyyConfigPanel
