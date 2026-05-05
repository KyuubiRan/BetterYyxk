local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TextEdit = require("widgets/textedit")
local TEMPLATES = require("widgets/redux/templates")

local ROW_PADDING = 12
local CONTROL_GAP = 10
local NUMBER_SPINNER_WIDTH = 122
local BUTTON_WIDTH = 78
local BUTTON_HEIGHT = 34

local function Clamp(min_value, max_value, value)
    if min_value ~= nil then
        value = math.max(min_value, value)
    end
    if max_value ~= nil then
        value = math.min(max_value, value)
    end

    return value
end

local function FormatNumber(value)
    value = tonumber(value) or 0
    if math.floor(value) == value then
        return tostring(value)
    end

    local text = string.format("%.6f", value)
    text = string.gsub(text, "0+$", "")
    text = string.gsub(text, "%.$", "")
    return text
end

local function MakeNumberOptions(definition)
    local options = {}
    local min = definition.min or definition.default or 0
    local max = definition.max or definition.default or min
    local step = definition.step or 1
    local value = min

    while value <= max + step * 0.1 do
        options[#options + 1] = {
            text = FormatNumber(value),
            data = value,
        }
        value = value + step
    end

    return options
end

local function SetLeftAlignedTextRegion(text, left, width, height)
    text:SetRegionSize(width, height)
    text:SetPosition(left + width * 0.5, 0, 0)
end

local function SetWidgetHoverText(widget, text, options)
    if widget == nil then
        return
    end

    if text ~= nil and text ~= "" then
        if widget.SetHoverText ~= nil then
            widget:SetHoverText(text, options)
        end
    elseif widget.ClearHoverText ~= nil then
        widget:ClearHoverText()
    end
end

local function SetWidgetTreeHoverText(widget, text, options)
    SetWidgetHoverText(widget, text, options)

    if widget == nil or widget.children == nil then
        return
    end

    for _, child in pairs(widget.children) do
        SetWidgetTreeHoverText(child, text, options)
    end
end

local LibKxyyDebugItem = Class(Widget, function(self, panel, width, height)
    Widget._ctor(self, "LibKxyyDebugItem")

    self.panel = panel
    self.item_width = width
    self.item_height = height
    self.definition = nil

    self.bg = self:AddChild(TEMPLATES.ListItemBackground(width, height, function()
        if self.definition ~= nil and self.definition.type == "toggle_action" then
            return false
        end

        return self:Execute()
    end))
    self.bg.move_on_click = false

    self.label = self:AddChild(Text(CHATFONT, 22, ""))
    self.label:SetColour(UICOLOURS.GOLD_SELECTED)
    self.label:SetHAlign(ANCHOR_LEFT)

    self.number_spinner = self:AddChild(TEMPLATES.StandardSpinner({}, NUMBER_SPINNER_WIDTH, 34, CHATFONT, 22, function(data)
        if not self.refreshing_number then
            self:SetNumber(data)
        end
    end, UICOLOURS.GOLD_SELECTED))
    self.number_spinner.text:Hide()

    self.number_edit = self.number_spinner:AddChild(TextEdit(CHATFONT, 22, "", UICOLOURS.GOLD_SELECTED))
    self.number_edit:SetForceEdit(true)
    self.number_edit:SetCharacterFilter("-0123456789.")
    self.number_edit:SetRegionSize(NUMBER_SPINNER_WIDTH - 54, 28)
    self.number_edit:SetHAlign(ANCHOR_MIDDLE)
    self.number_edit:SetEditCursorColour(UICOLOURS.GOLD_SELECTED[1], UICOLOURS.GOLD_SELECTED[2], UICOLOURS.GOLD_SELECTED[3], UICOLOURS.GOLD_SELECTED[4])
    self.number_edit.idle_text_color = UICOLOURS.GOLD_SELECTED
    self.number_edit.edit_text_color = UICOLOURS.GOLD_SELECTED
    self.number_edit:SetColour(UICOLOURS.GOLD_SELECTED[1], UICOLOURS.GOLD_SELECTED[2], UICOLOURS.GOLD_SELECTED[3], UICOLOURS.GOLD_SELECTED[4])
    self.number_edit.OnTextEntered = function(text)
        self:SetNumber(text)
    end

    local old_number_lose_focus = self.number_edit.OnLoseFocus
    self.number_edit.OnLoseFocus = function(edit)
        if old_number_lose_focus ~= nil then
            old_number_lose_focus(edit)
        end

        if self.definition ~= nil and self.definition.type == "number_action" then
            self:SetNumber(edit:GetString())
        end
    end

    self.number_spinner.leftimage:SetOnClick(function()
        self:StepNumber(-1)
    end)
    self.number_spinner.rightimage:SetOnClick(function()
        self:StepNumber(1)
    end)

    local old_number_control = self.number_spinner.OnControl
    self.number_spinner.OnControl = function(spinner, control, down)
        if self.definition ~= nil
            and self.definition.type == "number_action"
            and down
            and TheInput ~= nil then
            if control == TheInput:ResolveVirtualControls(spinner.control_prev) then
                self:StepNumber(-1)
                return true
            elseif control == TheInput:ResolveVirtualControls(spinner.control_next) then
                self:StepNumber(1)
                return true
            end
        end

        return old_number_control ~= nil and old_number_control(spinner, control, down) or false
    end

    self.execute_button = self:AddChild(TEMPLATES.StandardButton(function()
        self:Execute()
    end, "执行", {BUTTON_WIDTH, BUTTON_HEIGHT}))

    self.checkbox = self:AddChild(TEMPLATES.StandardCheckbox(function()
        return false
    end, 34, false))
    self.checkbox:SetOnClick(function()
        self:Execute()
    end)

    self:Layout()
end)

function LibKxyyDebugItem:SetTooltip(text)
    local options = {
        font = CHATFONT,
        offset_y = -42,
        colour = UICOLOURS.GOLD,
        bg = true,
    }

    SetWidgetTreeHoverText(self.execute_button, text, options)
end

function LibKxyyDebugItem:Layout()
    local row_left = -self.item_width * 0.5 + ROW_PADDING
    local row_right = self.item_width * 0.5 - ROW_PADDING
    local button_x = row_right - BUTTON_WIDTH * 0.5
    local spinner_x = button_x - BUTTON_WIDTH * 0.5 - CONTROL_GAP - NUMBER_SPINNER_WIDTH * 0.5
    local label_right = spinner_x - NUMBER_SPINNER_WIDTH * 0.5 - CONTROL_GAP
    if self.definition ~= nil and self.definition.type == "button_action" then
        label_right = button_x - BUTTON_WIDTH * 0.5 - CONTROL_GAP
    elseif self.definition ~= nil and self.definition.type == "toggle_action" then
        label_right = row_right - 34 - CONTROL_GAP
    end
    local label_width = math.max(80, label_right - row_left)

    SetLeftAlignedTextRegion(self.label, row_left, label_width, 28)
    self.number_spinner:SetPosition(spinner_x, 0, 0)
    self.execute_button:SetPosition(button_x, 0, 0)
    self.checkbox:SetPosition(row_right - 17, 0, 0)
end

function LibKxyyDebugItem:NormalizeNumber(value)
    value = tonumber(value)
    if value == nil then
        value = self.definition.default or 0
    end

    return Clamp(self.definition.min, self.definition.max, value)
end

function LibKxyyDebugItem:RefreshNumberDisplay()
    if self.definition == nil or self.definition.type ~= "number_action" then
        return
    end

    local value = self.panel:GetNumber(self.definition)
    self.refreshing_number = true
    self.number_spinner:SetSelected(value)
    self.number_edit:SetString(FormatNumber(value))
    self:RefreshNumberArrowState(value)
    self.refreshing_number = false
end

function LibKxyyDebugItem:RefreshNumberArrowState(value)
    value = tonumber(value)

    if self.definition.min ~= nil and value ~= nil and value <= self.definition.min then
        self.number_spinner.leftimage:Disable()
    else
        self.number_spinner.leftimage:Enable()
    end

    if self.definition.max ~= nil and value ~= nil and value >= self.definition.max then
        self.number_spinner.rightimage:Disable()
    else
        self.number_spinner.rightimage:Enable()
    end
end

function LibKxyyDebugItem:SetData(definition)
    self.definition = definition

    if definition == nil then
        self:Hide()
        return
    end

    self:Show()
    self.label:SetString(definition.label or "")
    self:SetTooltip(definition.description)
    self.bg:Show()
    self.label:SetColour(UICOLOURS.GOLD_SELECTED)
    self.label:SetHAlign(ANCHOR_LEFT)
    self:Layout()

    if definition.type == "section" then
        self.bg:Hide()
        self.number_spinner:Hide()
        self.execute_button:Hide()
        self.checkbox:Hide()
        self.label:SetColour(UICOLOURS.GOLD)
        self.label:SetHAlign(ANCHOR_MIDDLE)
        self.label:SetRegionSize(self.item_width, 28)
        self.label:SetPosition(0, 0, 0)
    elseif definition.type == "number_action" then
        self.number_spinner:Show()
        self.execute_button:Show()
        self.checkbox:Hide()
        self.number_spinner:SetOptions(MakeNumberOptions(definition))
        self.execute_button:SetText(definition.button_label or "执行")
        self:RefreshNumberDisplay()
    elseif definition.type == "button_action" then
        self.number_spinner:Hide()
        self.execute_button:Show()
        self.checkbox:Hide()
        self.execute_button:SetText(definition.button_label or "执行")
    elseif definition.type == "toggle_action" then
        self.number_spinner:Hide()
        self.execute_button:Hide()
        self.checkbox:Show()
        self:RefreshToggleDisplay()
    else
        self.number_spinner:Hide()
        self.execute_button:Hide()
        self.checkbox:Hide()
    end
end

function LibKxyyDebugItem:RefreshToggleDisplay()
    if self.definition == nil or self.definition.type ~= "toggle_action" then
        return
    end

    if self.checkbox == nil
        or self.checkbox.inst == nil
        or not self.checkbox.inst:IsValid() then
        return
    end

    local enabled = self.panel:GetToggle(self.definition)
    if enabled then
        self.checkbox:SetTextures("images/global_redux.xml", "checkbox_normal_check.tex", "checkbox_focus_check.tex", "checkbox_normal.tex", nil, nil, {1, 1}, {0, 0})
    else
        self.checkbox:SetTextures("images/global_redux.xml", "checkbox_normal.tex", "checkbox_focus.tex", "checkbox_normal_check.tex", nil, nil, {1, 1}, {0, 0})
    end
end

function LibKxyyDebugItem:SetNumber(value)
    if self.definition == nil or self.definition.type ~= "number_action" then
        return
    end

    self.panel:SetNumber(self.definition, self:NormalizeNumber(value))
    self:RefreshNumberDisplay()
end

function LibKxyyDebugItem:StepNumber(direction)
    if self.definition == nil or self.definition.type ~= "number_action" then
        return
    end

    direction = tonumber(direction) or 0
    if direction == 0 then
        return
    end

    local current = self.panel:GetNumber(self.definition)
    local step = tonumber(self.definition.step) or 1
    self:SetNumber(current + step * direction)
end

function LibKxyyDebugItem:Execute()
    if self.definition == nil
        or (self.definition.type ~= "number_action"
            and self.definition.type ~= "button_action"
            and self.definition.type ~= "toggle_action") then
        return false
    end

    return self.panel:Execute(self.definition)
end

return LibKxyyDebugItem
