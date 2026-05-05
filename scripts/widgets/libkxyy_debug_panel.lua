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

local DEFINITIONS = {
    {
        type = "section",
        label = "魔力相关",
    },
    {
        name = "delta_mana",
        type = "number_action",
        label = "恢复魔力",
        default = 100,
        min = -1000,
        max = 1000,
        step = 100,
        button_label = "执行",
        action = function(value)
            return DBGAPI:DeltaMana(value)
        end,
    },
    {
        name = "inf_mana",
        type = "toggle_action",
        label = "无限魔力",
        action = function()
            return DBGAPI:ToggleInfMana()
        end,
    },
}

local LibKxyyDebugPanel = Class(Widget, function(self, owner)
    Widget._ctor(self, "LibKxyyDebugPanel")

    self.owner = owner
    self.values = {}
    self.toggles = {
        inf_mana = false,
    }

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
        self:ApplyStatus(status)
    end)

    self.default_focus = self.options_scroll_list

    self:Hide()
end)

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

function LibKxyyDebugPanel:GetToggle(definition)
    if definition == nil or definition.name == nil then
        return false
    end

    return self.toggles[definition.name] == true
end

function LibKxyyDebugPanel:ApplyStatus(status)
    if type(status) ~= "table" then
        return
    end

    if status.inf_mana ~= nil then
        self.toggles.inf_mana = status.inf_mana == true
    end

    if self.options_scroll_list ~= nil then
        self.options_scroll_list:RefreshView()
    end
end

function LibKxyyDebugPanel:Execute(definition)
    if definition == nil or definition.action == nil then
        return false
    end

    local value = self:GetNumber(definition)
    local ok = definition.action(value)
    if not ok and self.owner ~= nil and self.owner.components ~= nil and self.owner.components.talker ~= nil then
        self.owner.components.talker:Say("调试命令执行失败")
    end

    return ok
end

function LibKxyyDebugPanel:ShowPanel()
    KeyListener:SetSettingsOpen(true)
    self:ApplyStatus(DBGAPI:GetStatus())
    DBGAPI:SyncStatus()
    self:MoveToFront()
    self:Show()
end

function LibKxyyDebugPanel:HidePanel()
    KeyListener:SetSettingsOpen(false)
    self:Hide()
end

function LibKxyyDebugPanel:Toggle()
    if self.shown then
        self:HidePanel()
    else
        self:ShowPanel()
    end
end

function LibKxyyDebugPanel:OnRemoveEntity()
    if self._debug_listener ~= nil then
        DBGAPI:RemoveListener(self._debug_listener)
        self._debug_listener = nil
    end
end

return LibKxyyDebugPanel
