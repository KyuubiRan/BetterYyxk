local Widget = require("widgets/widget")
local Image = require("widgets/image")

local FRAME_COUNT = 15
local FRAME_TIME = 0.08
local FRAME_WIDTH = 372
local FRAME_HEIGHT = 439

local BASE_SCALE = 0.4
local MIN_SCALE_RATIO = 0.25
local MAX_SCALE_RATIO = 2.0
local SCALE_STEP = 0.05
local SCREEN_MARGIN = 10

local ATLAS_PATH = "images/uiwidget_anim.xml"
local UI_STATE_NAME = "intro"

local function Clamp(min_value, max_value, value)
    return math.max(min_value, math.min(max_value, value))
end

local function GetTopRootMousePosition(x, y)
    if x == nil or y == nil then
        local mouse_pos = TheInput:GetScreenPosition()
        x = mouse_pos.x
        y = mouse_pos.y
    end

    return x, y
end

local function BuildFrames()
    local frames = {}

    for i = 0, FRAME_COUNT - 1 do
        local frame_name = string.format("uiwidget_%02d", i)
        frames[#frames + 1] = {
            atlas = ATLAS_PATH,
            tex = frame_name .. ".tex",
        }
    end

    return frames
end

local LibKxyyIntro = Class(Widget, function(self, owner)
    Widget._ctor(self, "LibKxyyIntro")

    self.owner = owner
    self.config = require("libkxyy_config")
    self.frames = BuildFrames()
    self.current_frame = 1
    self.hovered = false
    self.dragging = false
    self.scale_ratio = 1
    self.drag_offset_x = 0
    self.drag_offset_y = 0

    self:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self:SetHAnchor(ANCHOR_LEFT)
    self:SetVAnchor(ANCHOR_BOTTOM)

    local first_frame = self.frames[self.current_frame]
    self.image = self:AddChild(Image(first_frame.atlas, first_frame.tex))
    self.image:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    self.image:SetClickable(true)

    self.anim_task = self.inst:DoPeriodicTask(FRAME_TIME, function()
        self:ShowNextFrame()
    end)

    self._move_handler = TheInput:AddMoveHandler(function(x, y)
        self:HandleMouseMove(x, y)
    end)

    self._mouse_button_handler = TheInput:AddMouseButtonHandler(function(button, down, x, y)
        if self.dragging or self:IsScreenPointInside(x, y) then
            self.hovered = true
            self:HandleMouseButton(button, down, x, y)
        elseif self.hovered then
            self.hovered = false
        end
    end)

    self:LoadState()
    self._config_load_listener = self.config:AddLoadListener(function()
        self:LoadState()
    end)
end)

function LibKxyyIntro:GetActualScale()
    return BASE_SCALE * self.scale_ratio
end

function LibKxyyIntro:GetScaledDimensions(scale_ratio)
    local actual_scale = BASE_SCALE * (scale_ratio or self.scale_ratio)
    return FRAME_WIDTH * actual_scale, FRAME_HEIGHT * actual_scale
end

function LibKxyyIntro:GetScreenBounds(scale_ratio)
    local screen_width, screen_height = TheSim:GetScreenSize()
    local widget_width, widget_height = self:GetScaledDimensions(scale_ratio)
    local half_width = widget_width * 0.5
    local half_height = widget_height * 0.5

    local min_x = half_width + SCREEN_MARGIN
    local min_y = half_height + SCREEN_MARGIN
    local max_x = math.max(min_x, screen_width - half_width - SCREEN_MARGIN)
    local max_y = math.max(min_y, screen_height - half_height - SCREEN_MARGIN)

    return min_x, max_x, min_y, max_y
end

function LibKxyyIntro:ClampPosition(x, y, scale_ratio)
    local min_x, max_x, min_y, max_y = self:GetScreenBounds(scale_ratio)
    return Clamp(min_x, max_x, x), Clamp(min_y, max_y, y)
end

function LibKxyyIntro:GetDefaultPosition(scale_ratio)
    local min_x, _, min_y = self:GetScreenBounds(scale_ratio)
    return min_x, min_y
end

function LibKxyyIntro:IsScreenPointInside(screen_x, screen_y)
    local local_x, local_y = GetTopRootMousePosition(screen_x, screen_y)
    local pos_x, pos_y = self:GetPositionXYZ()
    local half_width, half_height = self:GetScaledDimensions()
    half_width = half_width * 0.5
    half_height = half_height * 0.5

    return local_x >= pos_x - half_width
        and local_x <= pos_x + half_width
        and local_y >= pos_y - half_height
        and local_y <= pos_y + half_height
end

function LibKxyyIntro:ApplyScale(scale_ratio, skip_save)
    self.scale_ratio = Clamp(MIN_SCALE_RATIO, MAX_SCALE_RATIO, scale_ratio)

    local actual_scale = self:GetActualScale()
    self.image:SetScale(actual_scale, actual_scale, 1)

    local x, y = self:GetPositionXYZ()
    if x == nil or y == nil then
        x, y = self:GetDefaultPosition(self.scale_ratio)
    else
        x, y = self:ClampPosition(x, y, self.scale_ratio)
    end
    self:SetPosition(x, y, 0)

    if not skip_save then
        self:SaveState()
    end
end

function LibKxyyIntro:AdjustScale(delta_ratio)
    if self.config ~= nil and self.config:Get("lock_ui", false) then
        return false
    end

    local next_ratio = Clamp(MIN_SCALE_RATIO, MAX_SCALE_RATIO, self.scale_ratio + delta_ratio)
    if next_ratio == self.scale_ratio then
        return false
    end

    self:ApplyScale(next_ratio)
    return true
end

function LibKxyyIntro:LoadState()
    local default_x, default_y = self:GetDefaultPosition(1)
    self:ApplyScale(1, true)
    self:SetPosition(default_x, default_y, 0)

    if self.inst == nil or not self.inst:IsValid() or self.config == nil then
        return
    end

    local data = self.config:GetUIState(UI_STATE_NAME)
    if type(data) ~= "table" then
        return
    end

    local scale_ratio = type(data.scale_ratio) == "number" and data.scale_ratio or 1
    self:ApplyScale(scale_ratio, true)

    local saved_x = type(data.x) == "number" and data.x or nil
    local saved_y = type(data.y) == "number" and data.y or nil

    if saved_x == nil or saved_y == nil then
        saved_x, saved_y = self:GetDefaultPosition(self.scale_ratio)
    else
        saved_x, saved_y = self:ClampPosition(saved_x, saved_y, self.scale_ratio)
    end

    self:SetPosition(saved_x, saved_y, 0)
end

function LibKxyyIntro:SaveState()
    if self.config == nil then
        return
    end

    local x, y = self:GetPositionXYZ()
    self.config:SaveUIState(UI_STATE_NAME, {
        version = 1,
        x = x,
        y = y,
        scale_ratio = self.scale_ratio,
    })
end

function LibKxyyIntro:BeginDrag(mouse_x, mouse_y)
    if self.config ~= nil and self.config:Get("lock_ui", false) then
        return
    end

    local current_x, current_y = self:GetPositionXYZ()
    local local_mouse_x, local_mouse_y = GetTopRootMousePosition(mouse_x, mouse_y)

    self.dragging = true
    self.drag_offset_x = current_x - local_mouse_x
    self.drag_offset_y = current_y - local_mouse_y

    self:MoveToFront()
end

function LibKxyyIntro:EndDrag(should_save)
    if not self.dragging then
        return
    end

    self.dragging = false

    if should_save then
        local x, y = self:GetPositionXYZ()
        x, y = self:ClampPosition(x, y, self.scale_ratio)
        self:SetPosition(x, y, 0)
        self:SaveState()
    end
end

function LibKxyyIntro:HandleMouseMove(x, y)
    if self.dragging then
        local mouse_x, mouse_y = GetTopRootMousePosition(x, y)
        local next_x = mouse_x + self.drag_offset_x
        local next_y = mouse_y + self.drag_offset_y

        next_x, next_y = self:ClampPosition(next_x, next_y, self.scale_ratio)
        self:SetPosition(next_x, next_y, 0)
        self.hovered = true
        return
    end

    self.hovered = self:IsScreenPointInside(x, y)
end

function LibKxyyIntro:HandleMouseButton(button, down, x, y)
    if button == MOUSEBUTTON_RIGHT then
        if down then
            self:BeginDrag(x, y)
        else
            self:EndDrag(true)
        end
        return true
    end

    if button == MOUSEBUTTON_LEFT and not down and self.hovered then
        if self.on_activate ~= nil then
            self.on_activate(self)
            return true
        end
    end

    if down and self.hovered then
        if button == MOUSEBUTTON_SCROLLUP then
            return self:AdjustScale(SCALE_STEP)
        elseif button == MOUSEBUTTON_SCROLLDOWN then
            return self:AdjustScale(-SCALE_STEP)
        end
    end

    return false
end

function LibKxyyIntro:SetOnActivate(fn)
    self.on_activate = fn
end

function LibKxyyIntro:ShowNextFrame()
    self.current_frame = self.current_frame + 1
    if self.current_frame > #self.frames then
        self.current_frame = 1
    end

    local frame = self.frames[self.current_frame]
    self.image:SetTexture(frame.atlas, frame.tex)
    self.image:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
end

function LibKxyyIntro:OnRemoveEntity()
    self:EndDrag(false)

    if self.config ~= nil and self._config_load_listener ~= nil then
        self.config:RemoveLoadListener(self._config_load_listener)
        self._config_load_listener = nil
    end

    if self.anim_task ~= nil then
        self.anim_task:Cancel()
        self.anim_task = nil
    end

    if self._move_handler ~= nil then
        self._move_handler:Remove()
        self._move_handler = nil
    end

    if self._mouse_button_handler ~= nil then
        self._mouse_button_handler:Remove()
        self._mouse_button_handler = nil
    end
end

return LibKxyyIntro
