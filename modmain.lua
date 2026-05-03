GLOBAL.setmetatable(env, {
    __index = function(_, key)
        return GLOBAL.rawget(GLOBAL, key)
    end,
})

PrefabFiles = {
}

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

LibKxyyConfig:Load()
LibKxyyKeyListener:Init()

local active_magic_wheel = nil

local function ShowMagicWheel()
    if active_magic_wheel == nil then
        return
    end

    active_magic_wheel:ShowWheel()
end

local function HideMagicWheel()
    if active_magic_wheel == nil then
        return
    end

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
end)

AddClassPostConstruct("widgets/controls", function(self)
    if self.libkxyy_intro ~= nil then
        return
    end

    self.libkxyy_config_panel = self.top_root:AddChild(LibKxyyConfigPanel(self.owner))
    self.libkxyy_intro = self.top_root:AddChild(LibKxyyIntro(self.owner))
    self.libkxyy_magic_wheel = self:AddChild(LibKxyyMagicWheel(LibKxyyMagicData))
    active_magic_wheel = self.libkxyy_magic_wheel

    self.libkxyy_magic_wheel:SetOnSelect(function(option)
        print(string.format("[better_yyxk] selected magic: %s (%s)", tostring(option.key), tostring(option.label)))
    end)

    self.libkxyy_intro:SetOnActivate(function()
        if self.libkxyy_config_panel ~= nil then
            self.libkxyy_config_panel:Toggle()
        end
    end)
end)

-- 客户端功能入口从这里继续扩展。
