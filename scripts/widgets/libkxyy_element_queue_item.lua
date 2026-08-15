local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TEMPLATES = require("widgets/redux/templates")
local ElementData = require("libkxyy_element_data")

local PRESET_NAME_LIMIT = 20
local BUTTON_HEIGHT = 30
local ELEMENT_SPINNER_WIDTH = 96
local ELEMENT_OPTIONS = {}

for _, element in ipairs(ElementData.ELEMENTS) do
    ELEMENT_OPTIONS[#ELEMENT_OPTIONS + 1] = {
        text = element.label,
        data = element.key,
    }
end

local function SetButtonTooltip(button, text)
    if button ~= nil and button.SetHoverText ~= nil then
        if button._libkxyy_element_queue_hover_text == text and button.hovertext ~= nil then
            return
        end

        button:SetHoverText(text, {
            font = CHATFONT,
            offset_y = -36,
            colour = UICOLOURS.GOLD,
            bg = true,
        })
        button._libkxyy_element_queue_hover_text = text
    end
end

local LibKxyyElementQueueItem = Class(Widget, function(self, queue, width, height)
    Widget._ctor(self, "LibKxyyElementQueueItem")

    self.queue = queue
    self.item_width = width
    self.item_height = height
    self.data = nil
    self.name_preset_id = nil

    self.bg = self:AddChild(TEMPLATES.ListItemBackground(width, height))
    self.bg.move_on_click = false

    self.section_label = self:AddChild(Text(CHATFONT, 22, ""))
    self.section_label:SetColour(UICOLOURS.GOLD)
    self.section_label:SetRegionSize(width, 28)

    self.index_label = self:AddChild(Text(CHATFONT, 19, ""))
    self.index_label:SetColour(UICOLOURS.GOLD_SELECTED)
    self.index_label:SetRegionSize(30, 28)
    self.index_label:SetPosition(-122, 0, 0)

    self.name_entry = self:AddChild(TEMPLATES.StandardSingleLineTextEntry("", 105, 30, CHATFONT, 22))
    self.name_entry:SetPosition(-52, 0, 0)
    self.name_entry.textbox:SetTextLengthLimit(PRESET_NAME_LIMIT)
    self.name_entry.textbox:EnableRegionSizeLimit(true)
    self.name_entry.textbox.OnTextEntered = function(text)
        self:CommitPresetName(text)
    end

    local old_name_lose_focus = self.name_entry.OnLoseFocus
    self.name_entry.OnLoseFocus = function(entry)
        if old_name_lose_focus ~= nil then
            old_name_lose_focus(entry)
        end
        self:CommitPresetName(entry.textbox:GetString())
        if self.data == nil or self.data.type ~= "preset" then
            self.name_preset_id = nil
        end
    end

    self.enable_button = self:AddChild(TEMPLATES.StandardButton(function()
        if self.data ~= nil then
            self.queue:SelectPreset(self.data.id)
        end
    end, "启用", { 55, BUTTON_HEIGHT }))
    self.enable_button:SetPosition(42, 0, 0)
    SetButtonTooltip(self.enable_button, "设为当前队列")

    self.preset_delete_button = self:AddChild(TEMPLATES.StandardButton(function()
        if self.data ~= nil then
            self.queue:RemovePreset(self.data.id)
        end
    end, "删除", { 50, BUTTON_HEIGHT }))
    self.preset_delete_button:SetPosition(102, 0, 0)
    SetButtonTooltip(self.preset_delete_button, "删除这个队列")

    self.element_spinner = self:AddChild(TEMPLATES.StandardSpinner(
        ELEMENT_OPTIONS,
        ELEMENT_SPINNER_WIDTH,
        BUTTON_HEIGHT,
        CHATFONT,
        22,
        function(key)
            if not self.refreshing_element and self.data ~= nil and self.data.type == "element" then
                self.queue:SetElement(self.data.index, key)
            end
        end,
        UICOLOURS.GOLD_SELECTED
    ))
    self.element_spinner:SetPosition(-58, 0, 0)
    self.element_spinner:SetWrapEnabled(true)
    SetButtonTooltip(self.element_spinner.leftimage, "上一个元素")
    SetButtonTooltip(self.element_spinner.rightimage, "下一个元素")

    self.move_up_button = self:AddChild(TEMPLATES.StandardButton(function()
        if self.data ~= nil then
            self.queue:MoveElement(self.data.index, -1)
        end
    end, "↑", { 30, BUTTON_HEIGHT }))
    self.move_up_button:SetPosition(9, 0, 0)
    SetButtonTooltip(self.move_up_button, "上移")

    self.move_down_button = self:AddChild(TEMPLATES.StandardButton(function()
        if self.data ~= nil then
            self.queue:MoveElement(self.data.index, 1)
        end
    end, "↓", { 30, BUTTON_HEIGHT }))
    self.move_down_button:SetPosition(43, 0, 0)
    SetButtonTooltip(self.move_down_button, "下移")

    self.element_delete_button = self:AddChild(TEMPLATES.StandardButton(function()
        if self.data ~= nil then
            self.queue:RemoveElement(self.data.index)
        end
    end, "删除", { 60, BUTTON_HEIGHT }))
    self.element_delete_button:SetPosition(100, 0, 0)
    SetButtonTooltip(self.element_delete_button, "删除这个元素")

    self.add_label = self:AddChild(Text(CHATFONT, 22, ""))
    self.add_label:SetColour(UICOLOURS.GOLD_SELECTED)
    self.add_label:SetRegionSize(170, 28)
    self.add_label:SetPosition(-36, 0, 0)

    self.add_button = self:AddChild(TEMPLATES.StandardButton(function()
        if self.data == nil then
            return
        end

        if self.data.type == "add_preset" then
            self.queue:AddPreset()
        elseif self.data.type == "add_element" then
            self.queue:AddElement()
        end
    end, "+", { 42, BUTTON_HEIGHT }))
    self.add_button:SetPosition(102, 0, 0)

    self.empty_label = self:AddChild(Text(CHATFONT, 20, "请先新增队列"))
    self.empty_label:SetColour(UICOLOURS.GREY)
    self.empty_label:SetRegionSize(width, 28)

    self:HideControls()
end)

function LibKxyyElementQueueItem:HideControls()
    self.section_label:Hide()
    self.index_label:Hide()
    self.name_entry:Hide()
    self.enable_button:Hide()
    self.preset_delete_button:Hide()
    self.element_spinner:Hide()
    self.move_up_button:Hide()
    self.move_down_button:Hide()
    self.element_delete_button:Hide()
    self.add_label:Hide()
    self.add_button:Hide()
    self.empty_label:Hide()
end

function LibKxyyElementQueueItem:CommitPresetName(name)
    if self.name_preset_id == nil then
        return
    end

    local saved_name = self.queue:RenamePreset(self.name_preset_id, name)
    if saved_name ~= nil and self.name_entry.textbox:GetString() ~= saved_name then
        self.name_entry.textbox:SetString(saved_name)
    end
end

function LibKxyyElementQueueItem:SetData(data)
    self.data = data
    self:HideControls()

    if data == nil then
        self:Hide()
        return
    end

    self:Show()
    self.bg:Show()

    if data.type == "section" then
        self.bg:Hide()
        self.section_label:SetString(data.label or "")
        self.section_label:Show()
        return
    end

    if data.type == "preset" then
        self.index_label:SetString("#" .. tostring(data.index))
        self.index_label:Show()
        if not self.name_entry.textbox.editing then
            self.name_preset_id = data.id
            self.name_entry.textbox:SetString(data.name or "")
        end
        self.name_entry:Show()
        self.enable_button:SetText(data.current and "已启用" or "启用")
        if data.current then
            self.enable_button:Disable()
        else
            self.enable_button:Enable()
        end
        self.enable_button:Show()
        self.preset_delete_button:Show()
        return
    end

    if data.type == "element" then
        if not self.name_entry.textbox.editing then
            self.name_preset_id = nil
        end
        self.index_label:SetString("#" .. tostring(data.index))
        self.index_label:Show()
        self.refreshing_element = true
        self.element_spinner:SetSelected(data.key)
        self.refreshing_element = false
        self.element_spinner:Show()
        self.move_up_button:Show()
        self.move_down_button:Show()
        self.element_delete_button:Show()

        if data.index <= 1 then
            self.move_up_button:Disable()
        else
            self.move_up_button:Enable()
        end
        if data.index >= data.count then
            self.move_down_button:Disable()
        else
            self.move_down_button:Enable()
        end
        return
    end

    if data.type == "add_preset" or data.type == "add_element" then
        if not self.name_entry.textbox.editing then
            self.name_preset_id = nil
        end
        self.add_label:SetString(data.label or "")
        self.add_label:Show()
        SetButtonTooltip(self.add_button, data.description)
        if data.enabled == false then
            self.add_button:Disable()
        else
            self.add_button:Enable()
        end
        self.add_button:Show()
        return
    end

    if data.type == "empty" then
        if not self.name_entry.textbox.editing then
            self.name_preset_id = nil
        end
        self.bg:Hide()
        self.empty_label:Show()
    end
end

return LibKxyyElementQueueItem
