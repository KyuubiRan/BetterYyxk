local Text = require("widgets/text")
local Widget = require("widgets/widget")
local LibKxyyMagicBadge = require("widgets/libkxyy_magic_badge")

local RADIUS = 245
local BASE_WIDTH = 1920
local BASE_HEIGHT = 1080
local CENTER_DEADZONE = 70
local BADGE_HIT_RADIUS = 72
local START_SCALE = 0
local NORMAL_SCALE = 1
local TITLE_COLOUR = { 1, 0.92, 0.62, 1 }
local ACTIVE_LABEL_COLOUR = { 0.45, 1, 0.45, 1 }
local TEXT_SHADOW_COLOUR = { 0, 0, 0, 0.85 }
local TEXT_SHADOW_OFFSET = 2

local function AddShadowedText(parent, font, size, text, colour)
    local root = parent:AddChild(Widget("shadowed_text"))
    root.shadow = root:AddChild(Text(font, size, text or ""))
    root.shadow:SetColour(TEXT_SHADOW_COLOUR)
    root.shadow:SetPosition(TEXT_SHADOW_OFFSET, -TEXT_SHADOW_OFFSET, 0)

    root.text = root:AddChild(Text(font, size, text or ""))
    root.text:SetColour(colour)

    function root:SetString(value)
        self.shadow:SetString(value or "")
        self.text:SetString(value or "")
    end

    return root
end

local LibKxyyMagicWheel = Class(Widget, function(self, options)
    Widget._ctor(self, "LibKxyyMagicWheel")

    self.options = options or {}
    self.badges = {}
    self.active_badge = nil
    self.on_select = nil
    self.update_task = nil
    self.screenscalefactor = 1

    self:SetClickable(false)

    self.root = self:AddChild(Widget("root"))

    self.title = AddShadowedText(self.root, HEADERFONT, 34, "选择魔法", TITLE_COLOUR)

    self.active_label = AddShadowedText(self.root, HEADERFONT, 28, "", ACTIVE_LABEL_COLOUR)
    self.active_label:SetPosition(0, -42, 0)

    self:BuildBadges()
    self:Hide()
end)

local function GetScreenScaleFactor()
    if TheSim == nil then
        return 1
    end

    local screen_width, screen_height = TheSim:GetScreenSize()
    return math.min(screen_width / BASE_WIDTH, screen_height / BASE_HEIGHT)
end

local function GetBadgeScreenDistance(self, badge, mouse)
    local wheel_pos = self:GetPosition()
    local badge_pos = badge:GetPosition() * self.screenscalefactor
    local dx = wheel_pos.x + badge_pos.x - mouse.x
    local dy = wheel_pos.y + badge_pos.y - mouse.y
    return dx * dx + dy * dy
end

local function GetCenterScreenDistance(self, mouse)
    local wheel_pos = self:GetPosition()
    local dx = wheel_pos.x - mouse.x
    local dy = wheel_pos.y - mouse.y
    return dx * dx + dy * dy
end

function LibKxyyMagicWheel:BuildBadges()
    local count = #self.options
    if count <= 0 then
        return
    end

    local angle_step = 2 * math.pi / count
    local angle = 0

    for _, option in ipairs(self.options) do
        local badge = self.root:AddChild(LibKxyyMagicBadge(option))
        badge:SetPosition(RADIUS * math.cos(angle), RADIUS * math.sin(angle), 0)
        self.badges[#self.badges + 1] = badge
        angle = angle + angle_step
    end
end

function LibKxyyMagicWheel:ClearBadges()
    self:ClearSelection()

    for _, badge in ipairs(self.badges) do
        badge:Kill()
    end

    self.badges = {}
end

function LibKxyyMagicWheel:SetOptions(options)
    self.options = options or {}
    self:ClearBadges()
    self:BuildBadges()
end

function LibKxyyMagicWheel:SetOnSelect(fn)
    self.on_select = fn
end

function LibKxyyMagicWheel:ClearSelection()
    if self.active_badge ~= nil then
        self.active_badge:Contract()
        self.active_badge = nil
    end

    self.active_label:SetString("")
end

function LibKxyyMagicWheel:GetSelectedOption()
    return self.active_badge ~= nil and self.active_badge:GetOption() or nil
end

function LibKxyyMagicWheel:RefreshSelection()
    if TheInput == nil then
        self:ClearSelection()
        return
    end

    local mouse = TheInput:GetScreenPosition()
    local min_distance = math.huge
    local selected_badge = nil

    for _, badge in ipairs(self.badges) do
        local distance = GetBadgeScreenDistance(self, badge, mouse)
        if distance < min_distance then
            min_distance = distance
            selected_badge = badge
        end
    end

    local deadzone = CENTER_DEADZONE * self.screenscalefactor
    local hit_radius = BADGE_HIT_RADIUS * self.screenscalefactor
    if selected_badge == nil
        or min_distance > hit_radius * hit_radius
        or GetCenterScreenDistance(self, mouse) <= deadzone * deadzone then
        selected_badge = nil
    end

    if selected_badge == self.active_badge then
        return
    end

    if self.active_badge ~= nil then
        self.active_badge:Contract()
    end

    self.active_badge = selected_badge

    if self.active_badge ~= nil then
        local option = self.active_badge:GetOption()
        self.active_badge:Expand()
        self.active_label:SetString(option.label or option.key or "")
    else
        self.active_label:SetString("")
    end
end

function LibKxyyMagicWheel:ResetTransform()
    local screen_width, screen_height = TheSim:GetScreenSize()
    self.screenscalefactor = GetScreenScaleFactor()
    self:SetPosition(math.floor(screen_width * 0.5 + 0.5), math.floor(screen_height * 0.5 + 0.5), 0)
    self.inst.UITransform:SetScale(START_SCALE, START_SCALE, 1)
end

function LibKxyyMagicWheel:ShowWheel()
    if self.shown then
        return
    end

    self:ResetTransform()
    self:ClearSelection()
    self:MoveToFront()
    self:Show()
    self:ScaleTo(START_SCALE, NORMAL_SCALE * self.screenscalefactor, 0.16)

    if self.update_task == nil then
        self.update_task = self.inst:DoPeriodicTask(0, function()
            self:RefreshSelection()
        end)
    end
end

function LibKxyyMagicWheel:HideWheel(should_select)
    if self.update_task ~= nil then
        self.update_task:Cancel()
        self.update_task = nil
    end

    local selected = should_select and self:GetSelectedOption() or nil
    self:ClearSelection()
    self:Hide()
    self.inst.UITransform:SetScale(START_SCALE, START_SCALE, 1)

    if selected ~= nil and self.on_select ~= nil then
        self.on_select(selected)
    end
end

function LibKxyyMagicWheel:OnRemoveEntity()
    if self.update_task ~= nil then
        self.update_task:Cancel()
        self.update_task = nil
    end
end

return LibKxyyMagicWheel
