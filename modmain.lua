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
}

if TheNet:IsDedicated() then
    return
end

modimport("scripts/text_constants")

local LibKxxyConfig = require("libkxxy_config")
local LibKxxyKeyListener = require("libkxxy_key_listener")
local LibKxxyConfigPanel = require("widgets/libkxxy_config_panel")
local LibKxxyIntro = require("widgets/libkxxy_intro")

LibKxxyConfig:Load()
LibKxxyKeyListener:Init()

LibKxxyKeyListener:RegisterAction("test_hotkey", {
    key = LibKxxyConfig:Get("test_hotkey", -1),
    on_down = function()
        if ThePlayer ~= nil and ThePlayer.components ~= nil and ThePlayer.components.talker ~= nil then
            ThePlayer.components.talker:Say("Hello")
        end
    end,
})

LibKxxyConfig:AddListener(function(changed)
    if changed.test_hotkey ~= nil then
        LibKxxyKeyListener:SetActionKey("test_hotkey", changed.test_hotkey)
    end
end)

AddClassPostConstruct("widgets/controls", function(self)
    if self.libkxxy_intro ~= nil then
        return
    end

    self.libkxxy_config_panel = self.top_root:AddChild(LibKxxyConfigPanel(self.owner))
    self.libkxxy_intro = self.top_root:AddChild(LibKxxyIntro(self.owner))
    self.libkxxy_intro:SetOnActivate(function()
        if self.libkxxy_config_panel ~= nil then
            self.libkxxy_config_panel:Toggle()
        end
    end)
end)

-- 客户端功能入口从这里继续扩展。
