local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TEMPLATES = require("widgets/redux/templates")
local PopupDialogScreen = require("screens/redux/popupdialog")
local ModConfig = require("libkxyy_config")
local KeyListener = require("libkxyy_key_listener")
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

local LibKxyyConfigPanel = Class(Widget, function(self, owner)
    Widget._ctor(self, "LibKxyyConfigPanel")

    self.owner = owner
    self.config = ModConfig
    self.optionwidgets = self.config:GetDefinitions()
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
        self.optionwidgets = self.config:GetDefinitions()
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
