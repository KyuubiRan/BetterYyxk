local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TEMPLATES = require("widgets/redux/templates")

local KEY_NONE = -1
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

local LibKxxyConfigItem = Class(Widget, function(self, panel, width, height)
    Widget._ctor(self, "LibKxxyConfigItem")

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
        if self.panel.capture_item == self and control == CONTROL_CANCEL and not down then
            self:CompleteKeyCapture(KEY_NONE)
            return true
        end

        return old_control ~= nil and old_control(button, control, down) or false
    end
end)

function LibKxxyConfigItem:OnRawKey(key, down)
    if self.panel.capture_item ~= self then
        return LibKxxyConfigItem._base.OnRawKey(self, key, down)
    end

    if down then
        return true
    end

    self:CompleteKeyCapture(key)
    return true
end

function LibKxxyConfigItem:OnControl(control, down)
    if self.panel.capture_item == self then
        if control == CONTROL_CANCEL and not down then
            self:CompleteKeyCapture(KEY_NONE)
        end
        return true
    end

    return LibKxxyConfigItem._base.OnControl(self, control, down)
end

function LibKxxyConfigItem:OnStopForceProcessTextInput()
    if not self.panel.capture_transition and self.panel.capture_item == self then
        self.panel:EndKeyCapture(self, false)
    end
end

function LibKxxyConfigItem:SetChecked(value)
    if value then
        self.checkbox:SetTextures("images/global_redux.xml", "checkbox_normal_check.tex", "checkbox_focus_check.tex", "checkbox_normal.tex", nil, nil, {1, 1}, {0, 0})
    else
        self.checkbox:SetTextures("images/global_redux.xml", "checkbox_normal.tex", "checkbox_focus.tex", "checkbox_normal_check.tex", nil, nil, {1, 1}, {0, 0})
    end
end

function LibKxxyConfigItem:SetTooltip(text)
    local options = {
        font = CHATFONT,
        offset_y = -42,
        colour = UICOLOURS.GOLD,
        bg = true,
    }

    self.bg:SetHoverText(text or "", options)
    self.checkbox:SetHoverText(text or "", options)
    self.key_button:SetHoverText(text or "", options)
end

function LibKxxyConfigItem:RefreshKeyDisplay()
    if self.definition == nil or self.definition.type ~= "key" then
        return
    end

    if self.panel.capture_item == self then
        self.key_button:SetText("按键...")
    else
        self.key_button:SetText(GetKeyDisplayName(self.panel.config:Get(self.definition.name, self.definition.default)))
    end
end

function LibKxxyConfigItem:SetData(definition)
    self.definition = definition

    if definition == nil then
        self:Hide()
        return
    end

    self:Show()
    self.label:SetString(definition.label or definition.name or "未命名配置")
    self:SetTooltip(definition.description)

    if definition.type == "checkbox" then
        self.checkbox:Show()
        self.key_button:Hide()
        self.label:SetRegionSize(self.item_width - 120, 28)
        self.label:SetPosition(-26, 0, 0)
        self:SetChecked(self.panel.config:Get(definition.name, definition.default))
    elseif definition.type == "key" then
        self.checkbox:Hide()
        self.key_button:Show()
        self.label:SetRegionSize(self.item_width - 188, 28)
        self.label:SetPosition(-28, 0, 0)
        self:RefreshKeyDisplay()
    else
        self.checkbox:Hide()
        self.key_button:Hide()
    end
end

function LibKxxyConfigItem:ToggleCheckbox()
    if self.definition == nil or self.definition.type ~= "checkbox" then
        return false
    end

    local next_value = self.panel:ToggleCheckbox(self.definition.name)
    self:SetChecked(next_value)
    return next_value
end

function LibKxxyConfigItem:BeginKeyCapture()
    if self.definition == nil or self.definition.type ~= "key" then
        return
    end

    self.panel:BeginKeyCapture(self)
    if TheFrontEnd ~= nil then
        TheFrontEnd:SetForceProcessTextInput(true, self)
    end
    self:RefreshKeyDisplay()
end

function LibKxxyConfigItem:CompleteKeyCapture(key)
    if self.definition == nil or self.definition.type ~= "key" then
        return
    end

    local escape_key = KEY_ESCAPE or 27
    if key == escape_key then
        key = KEY_NONE
    end

    self.panel:BindKey(self.definition.name, key)
    self.panel:EndKeyCapture(self, true)
end

function LibKxxyConfigItem:Activate()
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

return LibKxxyConfigItem
