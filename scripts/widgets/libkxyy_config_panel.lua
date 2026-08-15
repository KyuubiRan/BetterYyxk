local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TEMPLATES = require("widgets/redux/templates")
local PopupDialogScreen = require("screens/redux/popupdialog")
local ModConfig = require("libkxyy_config")
local KeyListener = require("libkxyy_key_listener")
local MagicData = require("libkxyy_magic_data")
local UmbrellaRepairData = require("libkxyy_umbrella_repair_data")
local ElementQueue = require("libkxyy_element_queue")
local LibKxyyConfigItem = require("widgets/libkxyy_config_item")
local LibKxyyConfigDetailPanel = require("widgets/libkxyy_config_detail_panel")
local LibKxyyElementQueuePanel = require("widgets/libkxyy_element_queue_panel")

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
local DETAIL_PANEL_GAP = 80
local DETAIL_PANEL_OFFSET = PANEL_WIDTH + DETAIL_PANEL_GAP
local MAIN_PANEL_OPEN_X = -DETAIL_PANEL_OFFSET * 0.5
local PANEL_TRANSITION_TIME = 0.2

local MAIN_DEFINITIONS = {}
local CONFIG_DEFINITIONS = {}
local DETAIL_PANELS = {
    gem_priority = {
        title = "宝石优先级",
        definitions = {},
    },
    magic_wheel = {
        title = "轮盘魔法配置",
        definitions = {},
    },
    element_queue = {
        panel_type = "element_queue",
    },
}

local function AddDefinition(definition)
    MAIN_DEFINITIONS[#MAIN_DEFINITIONS + 1] = definition
    if definition.name ~= nil then
        CONFIG_DEFINITIONS[#CONFIG_DEFINITIONS + 1] = definition
    end
end

local function AddDetailDefinition(detail_id, definition)
    local detail = DETAIL_PANELS[detail_id]
    if detail == nil then
        return
    end

    detail.definitions[#detail.definitions + 1] = definition
    if definition.name ~= nil then
        CONFIG_DEFINITIONS[#CONFIG_DEFINITIONS + 1] = definition
    end
end

local function FocusForController(widget)
    if widget ~= nil
        and widget.SetFocus ~= nil
        and TheInput ~= nil
        and TheInput.ControllerAttached ~= nil
        and TheInput:ControllerAttached() then
        widget:SetFocus()
    end
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
    type = "button",
    label = "轮盘魔法配置",
    label_size = 20,
    description = "打开轮盘中显示的魔法配置",
    button_label = "点击配置",
    detail_panel = "magic_wheel",
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
    name = "nilxin_element_queue_toggle_hotkey",
    type = "key",
    label = "空心元素队列",
    description = "按下切换空心元素队列开关",
    default = -1,
})

AddDefinition({
    name = "nilxin_element_queue_mode",
    type = "choice",
    label = "队列模式",
    description = "目标模式为每个生物分别记录进度，全局模式为所有目标共用进度",
    default = ElementQueue.MODE_TARGET,
    options = ElementQueue.MODE_OPTIONS,
})

AddDefinition({
    type = "button",
    label = "配置队列",
    description = "打开元素队列预设和当前队列配置",
    button_label = "点击配置",
    detail_panel = "element_queue",
})

AddDefinition({
    name = "nilxin_element_queue_panel_hotkey",
    type = "key",
    label = "面板快捷键",
    description = "按下直接显示元素队列配置面板",
    default = -1,
})

AddDefinition({
    name = "nilxin_element_queue_previous_hotkey",
    type = "key",
    label = "切换上一个队列",
    label_size = 18,
    description = "按下切换到上一个元素队列预设",
    default = -1,
})

AddDefinition({
    name = "nilxin_element_queue_next_hotkey",
    type = "key",
    label = "切换下一个队列",
    label_size = 18,
    description = "按下切换到下一个元素队列预设",
    default = -1,
})

AddDefinition({
    type = "section",
    label = "特殊功能",
})

AddDefinition({
    name = "smart_blink",
    type = "checkbox",
    label = "智能闪现",
    description = "开启后，空心装备红叶时使用夜雨突刺，夜雨未装备红叶时使用空心闪现",
    default = false,
})

AddDefinition({
    type = "section",
    label = "伞护修复",
})

AddDefinition({
    name = "umbrella_repair_hotkey",
    type = "key",
    label = "修复按键",
    description = "按下后使用一颗符合配置的宝石修复已装备的伞之护",
    default = -1,
})

AddDefinition({
    name = "umbrella_auto_repair_threshold",
    type = "number",
    label = "自动修复",
    description = "每 3 秒检测一次，已装备的伞之护耐久低于该数值时自动修复，0 为关闭",
    default = 0,
    min = 0,
    max = 99,
    step = 1,
})

AddDefinition({
    name = "umbrella_auto_repair_combat_check",
    type = "checkbox",
    label = "自动修复战斗检测",
    label_size = 18,
    description = "开启后，处于战斗或最近受到攻击时不进行自动修复",
    default = true,
})

AddDefinition({
    name = "umbrella_repair_scope",
    type = "choice",
    label = "允许范围",
    description = "选择修复时允许使用物品栏、伞之护容器或两者中的宝石",
    default = UmbrellaRepairData.SCOPE_ALL,
    options = UmbrellaRepairData.SCOPE_OPTIONS,
})

AddDefinition({
    name = "umbrella_repair_reserve",
    type = "number",
    label = "保留数量",
    description = "每种宝石在允许范围内的总数不高于该值时不使用",
    default = 0,
    min = 0,
    max = 99,
    step = 1,
})

AddDefinition({
    type = "button",
    label = "宝石优先级",
    description = "打开各种宝石的修复优先级配置",
    button_label = "点击配置",
    detail_panel = "gem_priority",
})

for _, gem in ipairs(UmbrellaRepairData.GEMS) do
    AddDetailDefinition("gem_priority", {
        name = UmbrellaRepairData.GetPriorityConfigName(gem.prefab),
        type = "number",
        label = gem.label,
        description = gem.label .. "的修复优先级，0 为关闭，数值越高越优先使用",
        default = gem.default_priority,
        min = 0,
        max = 100,
        step = 1,
    })
end

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

for _, option in ipairs(MagicData) do
    AddDetailDefinition("magic_wheel", {
        name = ModConfig:GetMagicEnabledName(option.key),
        type = "checkbox",
        label = option.label,
        description = "勾选后，在魔法轮盘中显示「" .. option.label .. "」",
        default = true,
        magic_key = option.key,
    })
end

ModConfig:SetDefinitions(CONFIG_DEFINITIONS)

local LibKxyyConfigPanel = Class(Widget, function(self, owner)
    Widget._ctor(self, "LibKxyyConfigPanel")

    self.owner = owner
    self.config = ModConfig
    self.optionwidgets = MAIN_DEFINITIONS
    self.capture_item = nil
    self.capture_transition = false
    self.detail_panel_open = nil
    self.active_detail_panel = nil
    self.standalone_element_queue = false

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

    self.detail_panel = self:AddChild(LibKxyyConfigDetailPanel(self, function()
        self:HideDetailPanel()
    end))
    self.detail_panel:SetPosition(DETAIL_PANEL_OFFSET, 0, 0)

    self.element_queue_panel = self:AddChild(LibKxyyElementQueuePanel(function()
        if self.standalone_element_queue then
            self:HidePanel()
        else
            self:HideDetailPanel()
        end
    end))
    self.element_queue_panel:SetPosition(DETAIL_PANEL_OFFSET, 0, 0)

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

function LibKxyyConfigPanel:SetChoice(name, value)
    self.config:SaveBatch({
        [name] = value,
    })
end

function LibKxyyConfigPanel:RunAction(definition)
    if definition == nil then
        return false
    end

    if definition.detail_panel ~= nil then
        return self:ShowDetailPanel(definition.detail_panel)
    end

    if definition.action == nil then
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
        self.optionwidgets = MAIN_DEFINITIONS
        self.options_scroll_list:SetItemsData(self.optionwidgets)
        self.options_scroll_list:RefreshView()
    end

    if self.detail_panel ~= nil and self.detail_panel.shown then
        self.detail_panel:Refresh()
    end

    if self.element_queue_panel ~= nil and self.element_queue_panel.shown then
        self.element_queue_panel:Refresh()
    end
end

function LibKxyyConfigPanel:OnConfigChanged()
    self:Refresh()
end

function LibKxyyConfigPanel:ShowDetailPanel(detail_id)
    local detail = DETAIL_PANELS[detail_id]
    if detail == nil then
        return false
    end

    local detail_panel = detail.panel_type == "element_queue"
        and self.element_queue_panel
        or self.detail_panel
    if detail_panel == nil then
        return false
    end

    if self.capture_item ~= nil then
        self:EndKeyCapture(self.capture_item, false)
    end

    if self.active_detail_panel ~= nil and self.active_detail_panel ~= detail_panel then
        self.active_detail_panel:HidePanel()
    end

    self.detail_panel_open = detail_id
    self.active_detail_panel = detail_panel
    if detail_panel == self.detail_panel then
        detail_panel:SetDefinitions(detail.title, detail.definitions)
    end
    detail_panel:ShowPanel()
    self.default_focus = detail_panel.default_focus
    FocusForController(self.default_focus)

    self:CancelMoveTo(false)
    self:MoveTo(self:GetPosition(), Vector3(MAIN_PANEL_OPEN_X, 0, 0), PANEL_TRANSITION_TIME)
    return true
end

function LibKxyyConfigPanel:HideDetailPanel()
    if self.detail_panel_open == nil or self.active_detail_panel == nil then
        return false
    end

    self.detail_panel_open = nil
    self.active_detail_panel:HidePanel()
    self.active_detail_panel = nil
    self.default_focus = self.options_scroll_list
    FocusForController(self.default_focus)

    self:CancelMoveTo(false)
    self:MoveTo(self:GetPosition(), Vector3(0, 0, 0), PANEL_TRANSITION_TIME)
    return true
end

function LibKxyyConfigPanel:ResetDetailPanel()
    self:CancelMoveTo(false)
    self:SetPosition(0, 0, 0)
    self.detail_panel_open = nil
    self.active_detail_panel = nil
    self.standalone_element_queue = false
    self.default_focus = self.options_scroll_list

    if self.dialog ~= nil then
        self.dialog:Show()
    end

    if self.detail_panel ~= nil then
        self.detail_panel:HidePanel()
    end
    if self.element_queue_panel ~= nil then
        self.element_queue_panel:SetPosition(DETAIL_PANEL_OFFSET, 0, 0)
        self.element_queue_panel:HidePanel()
    end
end

function LibKxyyConfigPanel:ShowElementQueuePanel()
    if not self.shown or self.standalone_element_queue then
        self:ShowPanel()
    end

    return self:ShowDetailPanel("element_queue")
end

function LibKxyyConfigPanel:ShowElementQueuePanelStandalone()
    KeyListener:SetSettingsOpen(true)

    if self.capture_item ~= nil then
        self:EndKeyCapture(self.capture_item, false)
    end

    self:ResetDetailPanel()
    self.standalone_element_queue = true
    self.detail_panel_open = "element_queue"
    self.active_detail_panel = self.element_queue_panel
    self.dialog:Hide()
    self.element_queue_panel:SetPosition(0, 0, 0)
    self.element_queue_panel:ShowPanel()
    self.default_focus = self.element_queue_panel.default_focus
    self:MoveToFront()
    self:Show()
    FocusForController(self.default_focus)
    return true
end

function LibKxyyConfigPanel:ToggleElementQueuePanelStandalone()
    if self.shown and self.standalone_element_queue then
        self:HidePanel()
        return false
    end

    return self:ShowElementQueuePanelStandalone()
end

function LibKxyyConfigPanel:OnControl(control, down)
    if self.detail_panel_open ~= nil and control == CONTROL_CANCEL and not down then
        if self.standalone_element_queue then
            self:HidePanel()
        else
            self:HideDetailPanel()
        end
        return true
    end

    return LibKxyyConfigPanel._base.OnControl(self, control, down)
end

function LibKxyyConfigPanel:ShowPanel()
    KeyListener:SetSettingsOpen(true)
    self:ResetDetailPanel()
    self:MoveToFront()
    self:Show()
end

function LibKxyyConfigPanel:HidePanel()
    KeyListener:SetSettingsOpen(false)

    if self.capture_item ~= nil then
        self:EndKeyCapture(self.capture_item, false)
    end

    self:Hide()
    self:ResetDetailPanel()
end

function LibKxyyConfigPanel:Toggle()
    if self.shown then
        self:HidePanel()
    else
        self:ShowPanel()
    end
end

function LibKxyyConfigPanel:OnRemoveEntity()
    self:CancelMoveTo(false)

    if self.config ~= nil and self._config_listener ~= nil then
        self.config:RemoveListener(self._config_listener)
        self._config_listener = nil
    end
end

return LibKxyyConfigPanel
