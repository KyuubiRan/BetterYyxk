local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TEMPLATES = require("widgets/redux/templates")
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

local LibKxyyConfigDetailPanel = Class(Widget, function(self, parent_panel, on_close)
    Widget._ctor(self, "LibKxyyConfigDetailPanel")

    self.parent_panel = parent_panel
    self.optionwidgets = {}

    local buttons = {
        {
            text = "关闭",
            cb = function()
                if on_close ~= nil then
                    on_close()
                end
            end,
        },
    }

    self.dialog = self:AddChild(TEMPLATES.RectangleWindow(PANEL_WIDTH, PANEL_HEIGHT, nil, buttons))

    self.header = self.dialog:AddChild(Widget("header"))
    self.header:SetPosition(0, 188, 0)

    self.title = self.header:AddChild(Text(HEADERFONT, 30, ""))
    self.title:SetColour(UICOLOURS.GOLD_SELECTED)

    self.content_root = self.dialog:InsertWidget(Widget("content_root"))
    self.content_root:SetPosition(0, CONTENT_ROOT_Y, 0)

    self.optionspanel = self.content_root:AddChild(Widget("optionspanel"))
    self.optionspanel:SetPosition(0, OPTIONS_PANEL_Y, 0)

    local function ScrollWidgetsCtor(context, idx)
        return LibKxyyConfigItem(self.parent_panel, ITEM_WIDTH, ITEM_HEIGHT)
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

    self.default_focus = self.options_scroll_list
    self:Hide()
end)

function LibKxyyConfigDetailPanel:SetDefinitions(title, definitions)
    self.title:SetString(title or "详细配置")
    self.optionwidgets = definitions or {}
    self:Refresh()

    if self.options_scroll_list ~= nil and self.options_scroll_list.ScrollToDataIndex ~= nil then
        self.options_scroll_list:ScrollToDataIndex(1)
    end
end

function LibKxyyConfigDetailPanel:Refresh()
    if self.options_scroll_list ~= nil then
        self.options_scroll_list:SetItemsData(self.optionwidgets)
        self.options_scroll_list:RefreshView()
    end
end

function LibKxyyConfigDetailPanel:ShowPanel()
    self:MoveToFront()
    self:Show()
end

function LibKxyyConfigDetailPanel:HidePanel()
    self:Hide()
end

return LibKxyyConfigDetailPanel
