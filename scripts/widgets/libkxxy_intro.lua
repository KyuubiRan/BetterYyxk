local Widget = require("widgets/widget")
local Image = require("widgets/image")
local json = require("json")

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
local CONFIG_NAME = "better_yyxk_libkxxy_intro"
local LEGACY_CONFIG_NAME = "better_yyxk_kongxinyeyu_intro"

local PROFILE_KEY_POS_X = "libkxxy_intro_pos_x"
local PROFILE_KEY_POS_Y = "libkxxy_intro_pos_y"
local PROFILE_KEY_SCALE_RATIO = "libkxxy_intro_scale_ratio"
local LEGACY_PROFILE_KEY_POS_X = "kongxinyeyu_intro_pos_x"
local LEGACY_PROFILE_KEY_POS_Y = "kongxinyeyu_intro_pos_y"
local LEGACY_PROFILE_KEY_SCALE_RATIO = "kongxinyeyu_intro_scale_ratio"

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

local LibKxxyIntro = Class(Widget, function(self, owner)
    Widget._ctor(self, "LibKxxyIntro")

    self.owner = owner
    self.config = require("libkxxy_config")
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
end)

function LibKxxyIntro:GetActualScale()
    return BASE_SCALE * self.scale_ratio
end

function LibKxxyIntro:GetScaledDimensions(scale_ratio)
    local actual_scale = BASE_SCALE * (scale_ratio or self.scale_ratio)
    return FRAME_WIDTH * actual_scale, FRAME_HEIGHT * actual_scale
end

function LibKxxyIntro:GetScreenBounds(scale_ratio)
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

function LibKxxyIntro:ClampPosition(x, y, scale_ratio)
    local min_x, max_x, min_y, max_y = self:GetScreenBounds(scale_ratio)
    return Clamp(min_x, max_x, x), Clamp(min_y, max_y, y)
end

function LibKxxyIntro:GetDefaultPosition(scale_ratio)
    local min_x, _, min_y = self:GetScreenBounds(scale_ratio)
    return min_x, min_y
end

function LibKxxyIntro:IsScreenPointInside(screen_x, screen_y)
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

function LibKxxyIntro:ApplyScale(scale_ratio, skip_save)
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

function LibKxxyIntro:AdjustScale(delta_ratio)
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

function LibKxxyIntro:LoadState()
    local default_x, default_y = self:GetDefaultPosition(1)
    self:ApplyScale(1, true)
    self:SetPosition(default_x, default_y, 0)

    local function ApplyConfigData(data, should_migrate)
        if self.inst == nil or not self.inst:IsValid() then
            return
        end

        local scale_ratio = type(data.scale_ratio) == "number" and data.scale_ratio or 1
        self:ApplyScale(scale_ratio, true)

        local saved_x = type(data.x) == "number" and data.x or nil
        local saved_y = type(data.y) == "number" and data.y or nil

        if saved_x ~= nil and saved_y ~= nil and (saved_x < 0 or saved_y < 0) then
            local screen_width, screen_height = TheSim:GetScreenSize()
            saved_x = saved_x + screen_width
            saved_y = saved_y + screen_height
            should_migrate = true
        end

        if saved_x == nil or saved_y == nil then
            saved_x, saved_y = self:GetDefaultPosition(self.scale_ratio)
        else
            saved_x, saved_y = self:ClampPosition(saved_x, saved_y, self.scale_ratio)
        end

        self:SetPosition(saved_x, saved_y, 0)

        if should_migrate then
            self:SaveState()
        end
    end

    local function DecodeConfigData(str)
        local ok, data = pcall(function()
            return json.decode(str)
        end)

        if ok and type(data) == "table" then
            return data
        end
    end

    local function LoadLegacyProfileData()
        local function GetProfileValue(primary_key, legacy_key)
            if Profile == nil then
                return nil
            end

            local value = Profile:GetValue(primary_key)
            if value == nil and legacy_key ~= nil then
                value = Profile:GetValue(legacy_key)
            end

            return value
        end

        return {
            x = GetProfileValue(PROFILE_KEY_POS_X, LEGACY_PROFILE_KEY_POS_X),
            y = GetProfileValue(PROFILE_KEY_POS_Y, LEGACY_PROFILE_KEY_POS_Y),
            scale_ratio = GetProfileValue(PROFILE_KEY_SCALE_RATIO, LEGACY_PROFILE_KEY_SCALE_RATIO),
        }
    end

    local function LoadLegacyState()
        TheSim:GetPersistentString(LEGACY_CONFIG_NAME, function(legacy_load_success, legacy_str)
            if legacy_load_success and legacy_str ~= nil and legacy_str ~= "" then
                local data = DecodeConfigData(legacy_str)
                if data ~= nil then
                    ApplyConfigData(data, true)
                    return
                end
            end

            ApplyConfigData(LoadLegacyProfileData(), true)
        end)
    end

    TheSim:GetPersistentString(CONFIG_NAME, function(load_success, str)
        if load_success and str ~= nil and str ~= "" then
            local data = DecodeConfigData(str)
            if data ~= nil then
                ApplyConfigData(data, false)
                return
            end
        end

        LoadLegacyState()
    end)
end

function LibKxxyIntro:SaveState()
    if TheSim == nil then
        return
    end

    local x, y = self:GetPositionXYZ()
    local payload = {
        version = 1,
        x = x,
        y = y,
        scale_ratio = self.scale_ratio,
    }
    local encoded = json.encode(payload)

    if SavePersistentString ~= nil then
        SavePersistentString(CONFIG_NAME, encoded, false)
    else
        TheSim:SetPersistentString(CONFIG_NAME, encoded, false, nil)
    end
end

function LibKxxyIntro:BeginDrag(mouse_x, mouse_y)
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

function LibKxxyIntro:EndDrag(should_save)
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

function LibKxxyIntro:HandleMouseMove(x, y)
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

function LibKxxyIntro:HandleMouseButton(button, down, x, y)
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

function LibKxxyIntro:SetOnActivate(fn)
    self.on_activate = fn
end

function LibKxxyIntro:ShowNextFrame()
    self.current_frame = self.current_frame + 1
    if self.current_frame > #self.frames then
        self.current_frame = 1
    end

    local frame = self.frames[self.current_frame]
    self.image:SetTexture(frame.atlas, frame.tex)
    self.image:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
end

function LibKxxyIntro:OnRemoveEntity()
    self:EndDrag(false)

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

return LibKxxyIntro
