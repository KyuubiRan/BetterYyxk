GLOBAL.setmetatable(env, {
    __index = function(_, key)
        return GLOBAL.rawget(GLOBAL, key)
    end,
})

Assets = {
    Asset("ATLAS", "images/uiwidget_anim.xml"),
    Asset("IMAGE", "images/uiwidget_anim.tex"),
    Asset("ATLAS", "images/staff_magic.xml"),
    Asset("IMAGE", "images/staff_magic.tex"),
}

if TheNet:IsDedicated() then
    return
end

modimport("scripts/text_constants")

local LibKxyyConfig = require("libkxyy_config")
local LibKxyyKeyListener = require("libkxyy_key_listener")
local LibKxyyMagicData = require("libkxyy_magic_data")
local LibKxyyConfigPanel = require("widgets/libkxyy_config_panel")
local LibKxyyIntro = require("widgets/libkxyy_intro")
local LibKxyyMagicWheel = require("widgets/libkxyy_magic_wheel")
local YyxkApi = require("yyxk_api")

LibKxyyConfig:Load()
LibKxyyKeyListener:Init()

local active_magic_wheel = nil
local magic_wheel_open = false

local function GetEnabledMagicOptions()
    local options = {}

    for _, option in ipairs(LibKxyyMagicData) do
        if LibKxyyConfig:IsMagicEnabled(option.key) then
            options[#options + 1] = option
        end
    end

    return options
end

local function IsMagicWheelOptionChanged(changed)
    for _, option in ipairs(LibKxyyMagicData) do
        if changed[LibKxyyConfig:GetMagicEnabledName(option.key)] ~= nil then
            return true
        end
    end

    return false
end

local function RefreshMagicWheelOptions()
    if active_magic_wheel ~= nil then
        active_magic_wheel:SetOptions(GetEnabledMagicOptions())
    end
end

local function ShowMagicWheel()
    if active_magic_wheel == nil then
        return
    end

    if not YyxkApi:CanChangeStaffMagic(true) then
        return
    end

    magic_wheel_open = true
    active_magic_wheel:ShowWheel()
end

local function HideMagicWheel()
    if active_magic_wheel == nil then
        return
    end

    if not magic_wheel_open then
        return
    end

    magic_wheel_open = false
    active_magic_wheel:HideWheel(true)
end

LibKxyyKeyListener:RegisterAction("magic_wheel", {
    key = LibKxyyConfig:Get("magic_wheel_hotkey"),
    on_down = ShowMagicWheel,
    on_up = HideMagicWheel,
})

LibKxyyConfig:AddListener(function(changed)
    if changed.magic_wheel_hotkey ~= nil then
        LibKxyyKeyListener:SetActionKey("magic_wheel", changed.magic_wheel_hotkey)
    end

    if IsMagicWheelOptionChanged(changed) then
        RefreshMagicWheelOptions()
    end
end)

AddClassPostConstruct("widgets/controls", function(self)
    if self.libkxyy_intro ~= nil then
        return
    end

    self.libkxyy_config_panel = self.top_root:AddChild(LibKxyyConfigPanel(self.owner))
    self.libkxyy_intro = self.top_root:AddChild(LibKxyyIntro(self.owner))
    self.libkxyy_magic_wheel = self:AddChild(LibKxyyMagicWheel(GetEnabledMagicOptions()))
    active_magic_wheel = self.libkxyy_magic_wheel

    self.libkxyy_magic_wheel:SetOnSelect(function(option)
        YyxkApi:SetWeaponMagic(option.key, option.label)
    end)

    self.libkxyy_intro:SetOnActivate(function()
        if self.libkxyy_config_panel ~= nil then
            self.libkxyy_config_panel:Toggle()
        end
    end)
end)
