local Image = require("widgets/image")
local Text = require("widgets/text")
local Widget = require("widgets/widget")

local SMALL_SCALE = 1
local LARGE_SCALE = 1.28
local ICON_SIZE = 86
local LABEL_WIDTH = 132
local LABEL_HEIGHT = 34
local LABEL_Y_WITH_ICON = -54
local TEXT_SHADOW_COLOUR = { 0, 0, 0, 0.85 }
local TEXT_SHADOW_OFFSET = 2

local NORMAL_COLOUR = UICOLOURS.GOLD_SELECTED
local SELECTED_COLOUR = PLAYERCOLOURS.GREEN

local function SetTextColour(text_root, colour)
    text_root.text:SetColour(colour)
end

local function SetTextString(text_root, value)
    text_root.shadow:SetString(value or "")
    text_root.text:SetString(value or "")
end

local function AddShadowedText(parent, font, size, text, colour)
    local root = parent:AddChild(Widget("shadowed_text"))
    root.shadow = root:AddChild(Text(font, size, text or ""))
    root.shadow:SetColour(TEXT_SHADOW_COLOUR)
    root.shadow:SetPosition(TEXT_SHADOW_OFFSET, -TEXT_SHADOW_OFFSET, 0)
    root.shadow:SetHAlign(ANCHOR_MIDDLE)
    root.shadow:SetRegionSize(LABEL_WIDTH, LABEL_HEIGHT)

    root.text = root:AddChild(Text(font, size, text or ""))
    root.text:SetColour(colour)
    root.text:SetHAlign(ANCHOR_MIDDLE)
    root.text:SetRegionSize(LABEL_WIDTH, LABEL_HEIGHT)

    root.SetString = SetTextString
    root.SetTextColour = SetTextColour

    return root
end

local LibKxyyMagicBadge = Class(Widget, function(self, option)
    Widget._ctor(self, "LibKxyyMagicBadge")

    self.option = option
    self.expanded = false

    self:SetClickable(false)

    self.root = self:AddChild(Widget("root"))
    self.icon_root = self.root:AddChild(Widget("icon_root"))

    if option.atlas ~= nil and option.tex ~= nil then
        self.icon = self.icon_root:AddChild(Image(option.atlas, option.tex))
        self.icon:SetSize(ICON_SIZE, ICON_SIZE)
    else
        self.icon_root:Hide()
    end

    self.label = AddShadowedText(self.root, HEADERFONT, 24, option.label or option.key or "", NORMAL_COLOUR)

    if self.icon ~= nil then
        self.label:SetPosition(0, LABEL_Y_WITH_ICON, 0)
    end
end)

function LibKxyyMagicBadge:GetOption()
    return self.option
end

function LibKxyyMagicBadge:Expand()
    if self.expanded then
        return
    end

    self.expanded = true
    self.root:ScaleTo(SMALL_SCALE, LARGE_SCALE, 0.12)
    self.label:SetTextColour(SELECTED_COLOUR)
    self:MoveToFront()
end

function LibKxyyMagicBadge:Contract()
    if not self.expanded then
        return
    end

    self.expanded = false
    self.root:ScaleTo(LARGE_SCALE, SMALL_SCALE, 0.12)
    self.label:SetTextColour(NORMAL_COLOUR)
    self:MoveToBack()
end

return LibKxyyMagicBadge
