local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TEMPLATES = require("widgets/redux/templates")
local ElementQueue = require("libkxyy_element_queue")
local LibKxyyElementQueueItem = require("widgets/libkxyy_element_queue_item")

local PANEL_WIDTH = 320
local PANEL_HEIGHT = 430
local ITEM_HEIGHT = 40
local ITEM_WIDTH = PANEL_WIDTH - 46
local VISIBLE_ROWS = 9
local CONTENT_ROOT_Y = 20
local OPTIONS_PANEL_Y = -42
local SCROLLBAR_OFFSET = 28
local SCROLLBAR_HEIGHT_OFFSET = -52

local LibKxyyElementQueuePanel = Class(Widget, function(self, on_close)
    Widget._ctor(self, "LibKxyyElementQueuePanel")

    self.queue = ElementQueue
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

    self.title = self.header:AddChild(Text(HEADERFONT, 30, "元素队列配置"))
    self.title:SetColour(UICOLOURS.GOLD_SELECTED)

    self.content_root = self.dialog:InsertWidget(Widget("content_root"))
    self.content_root:SetPosition(0, CONTENT_ROOT_Y, 0)

    self.optionspanel = self.content_root:AddChild(Widget("optionspanel"))
    self.optionspanel:SetPosition(0, OPTIONS_PANEL_Y, 0)

    local function ScrollWidgetsCtor(context, idx)
        return LibKxyyElementQueueItem(self.queue, ITEM_WIDTH, ITEM_HEIGHT)
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
    self._queue_listener = self.queue:AddListener(function()
        self:Refresh()
    end)

    self:Refresh()
    self:Hide()
end)

function LibKxyyElementQueuePanel:BuildItems()
    local items = {
        {
            type = "section",
            label = "队列预设",
        },
    }
    local state = self.queue:EnsureState()

    for index, preset in ipairs(state.presets) do
        items[#items + 1] = {
            type = "preset",
            index = index,
            id = preset.id,
            name = preset.name,
            current = preset.id == state.current_id,
        }
    end

    items[#items + 1] = {
        type = "add_preset",
        label = "新增队列",
        description = "新增一个空队列并自动切换过去",
    }
    items[#items + 1] = {
        type = "section",
        label = "当前队列",
    }

    local current = self.queue:GetCurrentPreset()
    if current == nil then
        items[#items + 1] = {
            type = "empty",
        }
    else
        for index, key in ipairs(current.elements) do
            items[#items + 1] = {
                type = "element",
                index = index,
                count = #current.elements,
                key = key,
            }
        end
    end

    items[#items + 1] = {
        type = "add_element",
        label = "新增元素",
        description = "在当前队列末尾新增风元素",
        enabled = current ~= nil,
    }
    return items
end

function LibKxyyElementQueuePanel:Refresh()
    self.optionwidgets = self:BuildItems()
    if self.options_scroll_list ~= nil then
        self.options_scroll_list:SetItemsData(self.optionwidgets)
        self.options_scroll_list:RefreshView()
    end
end

function LibKxyyElementQueuePanel:ShowPanel()
    self:Refresh()
    self:MoveToFront()
    self:Show()
end

function LibKxyyElementQueuePanel:HidePanel()
    self:Hide()
end

function LibKxyyElementQueuePanel:OnRemoveEntity()
    if self._queue_listener ~= nil then
        self.queue:RemoveListener(self._queue_listener)
        self._queue_listener = nil
    end
end

return LibKxyyElementQueuePanel
