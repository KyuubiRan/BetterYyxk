local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TextEdit = require("widgets/textedit")
local TEMPLATES = require("widgets/redux/templates")

local KEY_NONE = -1
local LABEL_LEFT = -103
local CHECKBOX_LABEL_WIDTH_OFFSET = 120
local KEY_LABEL_WIDTH_OFFSET = 188
local NUMBER_LABEL_WIDTH_OFFSET = 188
local NUMBER_SPINNER_WIDTH = 112
local KEY_TOOLTIP = "点击设置按键，点击后右键取消设置按键"
local KEY_NAME_MAP = {
    [KEY_NONE] = "None",
}

local function GetGlobalKey(name)
    return rawget(_G, name)
end

for i = 0, 9 do
    local key = GetGlobalKey("KEY_" .. i)
    if key ~= nil then
        KEY_NAME_MAP[key] = tostring(i)
    end
end

for i = 65, 90 do
    local char = string.char(i)
    local key = GetGlobalKey("KEY_" .. char)
    if key ~= nil then
        KEY_NAME_MAP[key] = char
    end
end

for i = 1, 12 do
    local key = GetGlobalKey("KEY_F" .. i)
    if key ~= nil then
        KEY_NAME_MAP[key] = "F" .. i
    end
end

local EXTRA_KEY_NAMES = {
    KEY_SPACE = "Space",
    KEY_ENTER = "Enter",
    KEY_ESCAPE = "Esc",
    KEY_TAB = "Tab",
    KEY_BACKSPACE = "Backspace",
    KEY_SHIFT = "Shift",
    KEY_ALT = "Alt",
    KEY_CTRL = "Ctrl",
    KEY_CAPSLOCK = "CapsLock",
    KEY_MINUS = "-",
    KEY_EQUALS = "=",
    KEY_LEFTBRACKET = "[",
    KEY_RIGHTBRACKET = "]",
    KEY_SEMICOLON = ";",
    KEY_QUOTE = "'",
    KEY_COMMA = ",",
    KEY_PERIOD = ".",
    KEY_SLASH = "/",
    KEY_BACKSLASH = "\\",
    KEY_TILDE = "`",
    KEY_UP = "Up",
    KEY_DOWN = "Down",
    KEY_LEFT = "Left",
    KEY_RIGHT = "Right",
    KEY_INSERT = "Insert",
    KEY_DELETE = "Delete",
    KEY_HOME = "Home",
    KEY_END = "End",
    KEY_PAGEUP = "PageUp",
    KEY_PAGEDOWN = "PageDown",
}

for key_name, display_name in pairs(EXTRA_KEY_NAMES) do
    local key = GetGlobalKey(key_name)
    if key ~= nil then
        KEY_NAME_MAP[key] = display_name
    end
end

local function GetKeyDisplayName(key)
    if key == nil or key == KEY_NONE then
        return KEY_NAME_MAP[KEY_NONE]
    end

    return KEY_NAME_MAP[key] or tostring(key)
end

local function SetLeftAlignedTextRegion(text, left, width, height)
    text:SetRegionSize(width, height)
    text:SetPosition(left + width * 0.5, 0, 0)
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

local function IsClearKeyControl(control, down)
    return not down and CONTROL_SECONDARY ~= nil and control == CONTROL_SECONDARY
end

local function SetWidgetHoverText(widget, text, options)
    if widget ~= nil and widget.SetHoverText ~= nil then
        widget:SetHoverText(text or "", options)
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

local LibKxyyConfigItem = Class(Widget, function(self, panel, width, height)
    Widget._ctor(self, "LibKxyyConfigItem")

    self.panel = panel
    self.item_width = width
    self.item_height = height
    self.definition = nil

    self.bg = self:AddChild(TEMPLATES.ListItemBackground(width, height, function()
        return self:Activate()
    end))
    self.bg.move_on_click = false

    self.checkbox = self:AddChild(TEMPLATES.StandardCheckbox(function()
        return self:ToggleCheckbox()
    end, 34, false))
    self.checkbox:SetPosition(width * 0.5 - 58, 0, 0)
    self.checkbox:Hide()

    self.label = self:AddChild(Text(CHATFONT, 22, ""))
    self.label:SetColour(UICOLOURS.GOLD_SELECTED)
    self.label:SetHAlign(ANCHOR_LEFT)
    self.label:SetRegionSize(width - 120, 28)
    self.label:SetPosition(-26, 0, 0)

    self.key_button = self:AddChild(TEMPLATES.StandardButton(function()
        self:BeginKeyCapture()
    end, "None", {92, 34}))
    self.key_button:SetPosition(width * 0.5 - 58, 0, 0)
    self.key_button:Hide()

    self.number_spinner = self:AddChild(TEMPLATES.StandardSpinner({}, NUMBER_SPINNER_WIDTH, 34, CHATFONT, 22, function(data)
        if not self.refreshing_number then
            self:SetNumber(data)
        end
    end, UICOLOURS.GOLD_SELECTED))
    self.number_spinner.text:Hide()
    self.number_edit = self.number_spinner:AddChild(TextEdit(CHATFONT, 22, "", UICOLOURS.GOLD_SELECTED))
    self.number_edit:SetForceEdit(true)
    self.number_edit:SetCharacterFilter("0123456789.")
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

        if self.definition ~= nil and self.definition.type == "number" then
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
            and self.definition.type == "number"
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

    self.number_spinner:SetPosition(width * 0.5 - 58, 0, 0)
    self.number_spinner:Hide()

    local old_lose_focus = self.key_button.OnLoseFocus
    self.key_button.OnLoseFocus = function(button)
        if old_lose_focus ~= nil then
            old_lose_focus(button)
        end

        if not self.panel.capture_transition and self.panel.capture_item == self then
            self.panel:EndKeyCapture(self, false)
        end
    end

    local old_control = self.key_button.OnControl
    self.key_button.OnControl = function(button, control, down)
        if self.panel.capture_item == self and IsClearKeyControl(control, down) then
            self:CompleteKeyCapture(KEY_NONE)
            return true
        end

        return old_control ~= nil and old_control(button, control, down) or false
    end
end)

function LibKxyyConfigItem:OnRawKey(key, down)
    if self.panel.capture_item ~= self then
        return LibKxyyConfigItem._base.OnRawKey(self, key, down)
    end

    if down then
        return true
    end

    self:CompleteKeyCapture(key)
    return true
end

function LibKxyyConfigItem:OnControl(control, down)
    if self.panel.capture_item == self then
        if IsClearKeyControl(control, down) then
            self:CompleteKeyCapture(KEY_NONE)
        end
        return true
    end

    return LibKxyyConfigItem._base.OnControl(self, control, down)
end

function LibKxyyConfigItem:OnStopForceProcessTextInput()
    if not self.panel.capture_transition and self.panel.capture_item == self then
        self.panel:EndKeyCapture(self, false)
    end
end

function LibKxyyConfigItem:SetChecked(value)
    if value then
        self.checkbox:SetTextures("images/global_redux.xml", "checkbox_normal_check.tex", "checkbox_focus_check.tex", "checkbox_normal.tex", nil, nil, {1, 1}, {0, 0})
    else
        self.checkbox:SetTextures("images/global_redux.xml", "checkbox_normal.tex", "checkbox_focus.tex", "checkbox_normal_check.tex", nil, nil, {1, 1}, {0, 0})
    end
end

function LibKxyyConfigItem:SetTooltip(text)
    local options = {
        font = CHATFONT,
        offset_y = -42,
        colour = UICOLOURS.GOLD,
        bg = true,
    }

    SetWidgetHoverText(self.bg, text, options)
end

function LibKxyyConfigItem:SetRightControlTooltip(text)
    local options = {
        font = CHATFONT,
        offset_y = -42,
        colour = UICOLOURS.GOLD,
        bg = true,
    }

    SetWidgetTreeHoverText(self.checkbox, "", options)
    SetWidgetTreeHoverText(self.key_button, text, options)
    SetWidgetTreeHoverText(self.number_spinner, text, options)
end

function LibKxyyConfigItem:RefreshKeyDisplay()
    if self.definition == nil or self.definition.type ~= "key" then
        return
    end

    if self.panel.capture_item == self then
        self.key_button:SetText("按键...")
    else
        self.key_button:SetText(GetKeyDisplayName(self.panel.config:Get(self.definition.name, self.definition.default)))
    end
end

function LibKxyyConfigItem:RefreshNumberDisplay()
    if self.definition == nil or self.definition.type ~= "number" then
        return
    end

    local value = self.panel.config:Get(self.definition.name, self.definition.default)
    self.refreshing_number = true
    self.number_spinner:SetSelected(value)
    self.number_edit:SetString(FormatNumber(value))
    self:RefreshNumberArrowState(value)
    self.refreshing_number = false
end

function LibKxyyConfigItem:RefreshNumberArrowState(value)
    if self.number_spinner == nil then
        return
    end

    value = tonumber(value)
    local min = self.definition ~= nil and tonumber(self.definition.min) or nil
    local max = self.definition ~= nil and tonumber(self.definition.max) or nil

    if min ~= nil and value ~= nil and value <= min then
        self.number_spinner.leftimage:Disable()
    else
        self.number_spinner.leftimage:Enable()
    end

    if max ~= nil and value ~= nil and value >= max then
        self.number_spinner.rightimage:Disable()
    else
        self.number_spinner.rightimage:Enable()
    end
end

function LibKxyyConfigItem:SetData(definition)
    self.definition = definition

    if definition == nil then
        self:Hide()
        return
    end

    self:Show()
    self.label:SetString(definition.label or definition.name or "未命名配置")
    self:SetTooltip(definition.description)
    self:SetRightControlTooltip(nil)
    self.bg:Show()
    self.label:SetColour(UICOLOURS.GOLD_SELECTED)
    self.label:SetHAlign(ANCHOR_LEFT)

    if definition.type == "checkbox" then
        self.checkbox:Show()
        self.key_button:Hide()
        self.number_spinner:Hide()
        SetLeftAlignedTextRegion(self.label, LABEL_LEFT, self.item_width - CHECKBOX_LABEL_WIDTH_OFFSET, 28)
        self:SetChecked(self.panel.config:Get(definition.name, definition.default))
    elseif definition.type == "key" then
        self.checkbox:Hide()
        self.key_button:Show()
        self.number_spinner:Hide()
        self:SetRightControlTooltip(KEY_TOOLTIP)
        SetLeftAlignedTextRegion(self.label, LABEL_LEFT, self.item_width - KEY_LABEL_WIDTH_OFFSET, 28)
        self:RefreshKeyDisplay()
    elseif definition.type == "number" then
        self.checkbox:Hide()
        self.key_button:Hide()
        self.number_spinner:Show()
        self.number_spinner:SetOptions(MakeNumberOptions(definition))
        self:SetRightControlTooltip(definition.description)
        SetLeftAlignedTextRegion(self.label, LABEL_LEFT, self.item_width - NUMBER_LABEL_WIDTH_OFFSET, 28)
        self:RefreshNumberDisplay()
    elseif definition.type == "section" then
        self.bg:Hide()
        self.checkbox:Hide()
        self.key_button:Hide()
        self.number_spinner:Hide()
        self.label:SetColour(UICOLOURS.GOLD)
        self.label:SetHAlign(ANCHOR_MIDDLE)
        self.label:SetRegionSize(self.item_width, 28)
        self.label:SetPosition(0, 0, 0)
    else
        self.checkbox:Hide()
        self.key_button:Hide()
        self.number_spinner:Hide()
    end
end

function LibKxyyConfigItem:ToggleCheckbox()
    if self.definition == nil or self.definition.type ~= "checkbox" then
        return false
    end

    local next_value = self.panel:ToggleCheckbox(self.definition.name)
    self:SetChecked(next_value)
    return next_value
end

function LibKxyyConfigItem:BeginKeyCapture()
    if self.definition == nil or self.definition.type ~= "key" then
        return
    end

    self.panel:BeginKeyCapture(self)
    if TheFrontEnd ~= nil then
        TheFrontEnd:SetForceProcessTextInput(true, self)
    end
    self:RefreshKeyDisplay()
end

function LibKxyyConfigItem:CompleteKeyCapture(key)
    if self.definition == nil or self.definition.type ~= "key" then
        return
    end

    self.panel:BindKey(self.definition.name, key)
    self.panel:EndKeyCapture(self, true)
end

function LibKxyyConfigItem:SetNumber(value)
    if self.definition == nil or self.definition.type ~= "number" then
        return
    end

    self.panel:SetNumber(self.definition.name, value)
    self:RefreshNumberDisplay()
end

function LibKxyyConfigItem:StepNumber(direction)
    if self.definition == nil or self.definition.type ~= "number" then
        return
    end

    direction = tonumber(direction) or 0
    if direction == 0 then
        return
    end

    local current = tonumber(self.panel.config:Get(self.definition.name, self.definition.default))
        or tonumber(self.definition.default)
        or tonumber(self.definition.min)
        or 0
    local step = tonumber(self.definition.step) or 1

    self.panel:SetNumber(self.definition.name, current + step * direction)
    self:RefreshNumberDisplay()
end

function LibKxyyConfigItem:Activate()
    if self.definition == nil then
        return false
    end

    if self.definition.type == "checkbox" then
        return self:ToggleCheckbox()
    elseif self.definition.type == "key" then
        self:BeginKeyCapture()
        return true
    end

    return false
end

return LibKxyyConfigItem
