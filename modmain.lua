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

local LibKxyyConfig = require("libkxyy_config")
local LibKxyyKeyListener = require("libkxyy_key_listener")
local LibKxyyMagicData = require("libkxyy_magic_data")
local LibKxyyConfigPanel = require("widgets/libkxyy_config_panel")
local LibKxyyDebugPanel = require("widgets/libkxyy_debug_panel")
local LibKxyyIntro = require("widgets/libkxyy_intro")
local LibKxyyMagicWheel = require("widgets/libkxyy_magic_wheel")
local YyxkApi = require("yyxk_api")
local DBGAPI = require("yyxk_debug_api")

local MAGIC_WHEEL_SHORT_PRESS_TIME = 0.2
local DEFAULT_WEAPON_MAGIC_KEY = "YYXK_GATHER"
local HONGYE_TRUE_DAMAGE_EQUIP_DELAY = 0.1
local HONGYE_TRUE_DAMAGE_PENDING_TIMEOUT = 1

local active_magic_wheel = nil
local active_controls = nil
local magic_wheel_open = false
local magic_wheel_down_time = nil
local hongye_true_damage_pending = false
local hongye_true_damage_clear_task = nil
local current_weapon_magic_option = nil
local previous_weapon_magic_option = nil
local initialized = false
local player_active = false
local actions_registered = false
local config_listener_registered = false
local config_load_listener_registered = false

local function IsLocalYyxkPlayer(inst)
    return inst ~= nil and ThePlayer ~= nil and inst == ThePlayer and inst.prefab == "yyxk"
end

local function GetYyxkApi()
    return YyxkApi:GetCurrent()
end

local function GetEnabledMagicOptions()
    local options = {}

    for _, option in ipairs(LibKxyyMagicData) do
        if LibKxyyConfig:IsMagicEnabled(option.key) then
            options[#options + 1] = option
        end
    end

    return options
end

local function GetMagicOptionByKey(key)
    for _, option in ipairs(LibKxyyMagicData) do
        if option.key == key then
            return option
        end
    end
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

local function EnsureDefaultCurrentWeaponMagic()
    if current_weapon_magic_option == nil then
        current_weapon_magic_option = GetMagicOptionByKey(DEFAULT_WEAPON_MAGIC_KEY)
    end
end

local function GetNow()
    return GetTime ~= nil and GetTime() or 0
end

local function IsSameMagicOption(left, right)
    return left ~= nil and right ~= nil and left.key == right.key
end

local function SetWeaponMagic(option, skip_history)
    if option == nil then
        return false
    end

    local api = GetYyxkApi()
    if api ~= nil and api:SetWeaponMagic(option.key) then
        EnsureDefaultCurrentWeaponMagic()
        if not skip_history and not IsSameMagicOption(option, current_weapon_magic_option) then
            previous_weapon_magic_option = current_weapon_magic_option
            current_weapon_magic_option = option
        end

        api:Say("切换: " .. option.label)
        return true
    end

    return false
end

local function QuickSwitchLastWeaponMagic()
    EnsureDefaultCurrentWeaponMagic()

    local api = GetYyxkApi()
    if previous_weapon_magic_option == nil then
        if api ~= nil then
            api:Say("没有选择任何魔法")
        end
        return false
    end

    local next_option = previous_weapon_magic_option
    if SetWeaponMagic(next_option, true) then
        previous_weapon_magic_option = current_weapon_magic_option
        current_weapon_magic_option = next_option
        return true
    end

    return false
end

local function ShowMagicWheel()
    if not player_active then
        return
    end

    if active_magic_wheel == nil then
        return
    end

    local api = GetYyxkApi()
    if api == nil or not api:CanChangeStaffMagic(true) then
        return
    end

    magic_wheel_down_time = GetNow()
    magic_wheel_open = true
    active_magic_wheel:ShowWheel(LibKxyyConfig:Get("fixed_magic_wheel", true))
end

local function HideMagicWheel()
    if active_magic_wheel == nil then
        return
    end

    if not magic_wheel_open then
        return
    end

    local press_time = magic_wheel_down_time ~= nil and GetNow() - magic_wheel_down_time or nil
    magic_wheel_down_time = nil
    magic_wheel_open = false

    if LibKxyyConfig:Get("quick_switch_previous_magic", true)
        and press_time ~= nil
        and press_time < MAGIC_WHEEL_SHORT_PRESS_TIME then
        active_magic_wheel:HideWheel(false)
        QuickSwitchLastWeaponMagic()
        return
    end

    active_magic_wheel:HideWheel(true)
end

local function ClearHongyeTrueDamagePending()
    hongye_true_damage_pending = false

    if hongye_true_damage_clear_task ~= nil then
        hongye_true_damage_clear_task:Cancel()
        hongye_true_damage_clear_task = nil
    end
end

local function SetHongyeTrueDamagePending(inst)
    ClearHongyeTrueDamagePending()
    hongye_true_damage_pending = true

    if inst ~= nil and inst:IsValid() then
        hongye_true_damage_clear_task = inst:DoTaskInTime(HONGYE_TRUE_DAMAGE_PENDING_TIMEOUT, function()
            hongye_true_damage_clear_task = nil
            hongye_true_damage_pending = false
        end)
    end
end

local function UseHongyeTrueDamage()
    if not player_active then
        return
    end

    local api = GetYyxkApi()
    if api == nil then
        return
    end

    if api:IsSwordEquipped() then
        ClearHongyeTrueDamagePending()
        api:UseItemInHand()
        return
    end

    SetHongyeTrueDamagePending(api.inst)
    if not api:FindAndEquipYeyuSword() then
        ClearHongyeTrueDamagePending()
    end
end

local function RegisterHongyeTrueDamageEquipListener(inst)
    if inst == nil or inst._libkxyy_hongye_true_damage_equip_listener then
        return
    end

    inst._libkxyy_hongye_true_damage_equip_listener = true
    inst:ListenForEvent("equip", function(_, data)
        if not hongye_true_damage_pending then
            return
        end

        if data == nil
            or data.item == nil
            or data.item.prefab ~= "yeyu_sword"
            or data.eslot ~= EQUIPSLOTS.HANDS then
            return
        end

        ClearHongyeTrueDamagePending()
        inst:DoTaskInTime(HONGYE_TRUE_DAMAGE_EQUIP_DELAY, function()
            local api = GetYyxkApi()
            if player_active and api ~= nil and api:IsSwordEquipped() then
                api:UseItemInHand()
            end
        end)
    end)
end

local function ToggleYeyuLungeAttraction()
    if not player_active then
        return
    end

    local api = GetYyxkApi()
    if api ~= nil then
        local enabled = api:ToggleYeyuLungeAttraction()
        api:Say("夜雨突刺吸附: " .. (enabled and "开启" or "关闭"))
    end
end

local function RegisterKeyActions()
    if actions_registered then
        return
    end

    actions_registered = true

    LibKxyyKeyListener:RegisterAction("magic_wheel", {
        key = LibKxyyConfig:Get("magic_wheel_hotkey"),
        on_down = ShowMagicWheel,
        on_up = HideMagicWheel,
    })

    LibKxyyKeyListener:RegisterAction("wanda_teleport_ui", {
        key = LibKxyyConfig:Get("wanda_teleport_ui_hotkey", -1),
        on_down = function()
            local api = GetYyxkApi()
            if player_active and api ~= nil then
                api:ToggleWandaTeleportUi()
            end
        end,
    })

    LibKxyyKeyListener:RegisterAction("debug_panel", {
        key = LibKxyyConfig:Get("debug_panel_hotkey", -1),
        on_down = function()
            if player_active
                and active_controls ~= nil
                and active_controls.libkxyy_debug_panel ~= nil then
                if active_controls.libkxyy_config_panel ~= nil
                    and active_controls.libkxyy_config_panel.shown
                    and not active_controls.libkxyy_debug_panel.shown then
                    active_controls.libkxyy_config_panel:HidePanel()
                end
                active_controls.libkxyy_debug_panel:Toggle()
            end
        end,
        allow_when_settings_open = true,
    })

    LibKxyyKeyListener:RegisterAction("summon_shadow_chest", {
        key = LibKxyyConfig:Get("summon_shadow_chest_hotkey", -1),
        on_down = function()
            local api = GetYyxkApi()
            if player_active and api ~= nil then
                api:SummonShadowChest()
            end
        end,
    })

    LibKxyyKeyListener:RegisterAction("repeat_nilxin_skill", {
        key = LibKxyyConfig:Get("repeat_nilxin_skill_hotkey", -1),
        on_down = function()
            local api = GetYyxkApi()
            if player_active and api ~= nil then
                api:RepeatLastSkill()
            end
        end,
    })

    LibKxyyKeyListener:RegisterAction("locked_repeat_nilxin_skill", {
        key = LibKxyyConfig:Get("locked_repeat_nilxin_skill_hotkey", -1),
        on_down = function()
            local api = GetYyxkApi()
            if player_active and api ~= nil then
                api:ToggleLockedRepeatSkill()
            end
        end,
    })

    LibKxyyKeyListener:RegisterAction("hongye_true_damage", {
        key = LibKxyyConfig:Get("hongye_true_damage_hotkey", -1),
        on_down = UseHongyeTrueDamage,
    })

    LibKxyyKeyListener:RegisterAction("yeyu_lunge_attraction_toggle", {
        key = LibKxyyConfig:Get("yeyu_lunge_attraction_toggle_hotkey", -1),
        on_down = ToggleYeyuLungeAttraction,
    })
end

local function RegisterConfigListener()
    if config_listener_registered then
        return
    end

    config_listener_registered = true

    LibKxyyConfig:AddListener(function(changed)
        if changed.magic_wheel_hotkey ~= nil then
            LibKxyyKeyListener:SetActionKey("magic_wheel", changed.magic_wheel_hotkey)
        end

        if changed.wanda_teleport_ui_hotkey ~= nil then
            LibKxyyKeyListener:SetActionKey("wanda_teleport_ui", changed.wanda_teleport_ui_hotkey)
        end

        if changed.debug_panel_hotkey ~= nil then
            LibKxyyKeyListener:SetActionKey("debug_panel", changed.debug_panel_hotkey)
        end

        if changed.summon_shadow_chest_hotkey ~= nil then
            LibKxyyKeyListener:SetActionKey("summon_shadow_chest", changed.summon_shadow_chest_hotkey)
        end

        if changed.repeat_nilxin_skill_hotkey ~= nil then
            LibKxyyKeyListener:SetActionKey("repeat_nilxin_skill", changed.repeat_nilxin_skill_hotkey)
        end

        if changed.locked_repeat_nilxin_skill_hotkey ~= nil then
            LibKxyyKeyListener:SetActionKey("locked_repeat_nilxin_skill", changed.locked_repeat_nilxin_skill_hotkey)
        end

        if changed.hongye_true_damage_hotkey ~= nil then
            LibKxyyKeyListener:SetActionKey("hongye_true_damage", changed.hongye_true_damage_hotkey)
        end

        if changed.yeyu_lunge_attraction_toggle_hotkey ~= nil then
            LibKxyyKeyListener:SetActionKey("yeyu_lunge_attraction_toggle", changed.yeyu_lunge_attraction_toggle_hotkey)
        end

        if IsMagicWheelOptionChanged(changed) then
            RefreshMagicWheelOptions()
        end
    end)
end

local function ApplyConfigToRuntime()
    LibKxyyKeyListener:SetActionKey("magic_wheel", LibKxyyConfig:Get("magic_wheel_hotkey"))
    LibKxyyKeyListener:SetActionKey("wanda_teleport_ui", LibKxyyConfig:Get("wanda_teleport_ui_hotkey", -1))
    LibKxyyKeyListener:SetActionKey("debug_panel", LibKxyyConfig:Get("debug_panel_hotkey", -1))
    LibKxyyKeyListener:SetActionKey("summon_shadow_chest", LibKxyyConfig:Get("summon_shadow_chest_hotkey", -1))
    LibKxyyKeyListener:SetActionKey("repeat_nilxin_skill", LibKxyyConfig:Get("repeat_nilxin_skill_hotkey", -1))
    LibKxyyKeyListener:SetActionKey("locked_repeat_nilxin_skill", LibKxyyConfig:Get("locked_repeat_nilxin_skill_hotkey", -1))
    LibKxyyKeyListener:SetActionKey("hongye_true_damage", LibKxyyConfig:Get("hongye_true_damage_hotkey", -1))
    LibKxyyKeyListener:SetActionKey("yeyu_lunge_attraction_toggle", LibKxyyConfig:Get("yeyu_lunge_attraction_toggle_hotkey", -1))
    RefreshMagicWheelOptions()
end

local function RegisterConfigLoadListener()
    if config_load_listener_registered then
        return
    end

    config_load_listener_registered = true

    LibKxyyConfig:AddLoadListener(function()
        ApplyConfigToRuntime()
    end)
end

local function SetControlsUIVisible(controls, visible)
    controls = controls or active_controls
    if controls == nil then
        return
    end

    if controls.inst ~= nil and not controls.inst:IsValid() then
        if controls == active_controls then
            active_controls = nil
            active_magic_wheel = nil
        end
        magic_wheel_open = false
        return
    end

    if visible then
        if controls.libkxyy_intro ~= nil then
            controls.libkxyy_intro:Show()
        end
        return
    end

    magic_wheel_open = false

    if controls.libkxyy_intro ~= nil then
        controls.libkxyy_intro:Hide()
    end

    if controls.libkxyy_config_panel ~= nil then
        controls.libkxyy_config_panel:HidePanel()
    end

    if controls.libkxyy_debug_panel ~= nil then
        controls.libkxyy_debug_panel:HidePanel()
    end

    if controls.libkxyy_magic_wheel ~= nil then
        controls.libkxyy_magic_wheel:HideWheel(false)
    end
end

local function AttachControlsUI(self)
    active_controls = self

    if self.libkxyy_intro ~= nil then
        if self.libkxyy_debug_panel == nil then
            self.libkxyy_debug_panel = self.top_root:AddChild(LibKxyyDebugPanel(self.owner))
        end
        SetControlsUIVisible(self, player_active and IsLocalYyxkPlayer(self.owner))
        return
    end

    self.libkxyy_config_panel = self.top_root:AddChild(LibKxyyConfigPanel(self.owner))
    self.libkxyy_debug_panel = self.top_root:AddChild(LibKxyyDebugPanel(self.owner))
    self.libkxyy_intro = self.top_root:AddChild(LibKxyyIntro(self.owner))
    self.libkxyy_magic_wheel = self:AddChild(LibKxyyMagicWheel(GetEnabledMagicOptions()))
    active_magic_wheel = self.libkxyy_magic_wheel

    self.libkxyy_magic_wheel:SetOnSelect(function(option)
        SetWeaponMagic(option)
    end)

    self.libkxyy_intro:SetOnActivate(function()
        if self.libkxyy_config_panel ~= nil then
            self.libkxyy_config_panel:Toggle()
        end
    end)

    SetControlsUIVisible(self, player_active and IsLocalYyxkPlayer(self.owner))
end

local function AttachPlayerControls(inst)
    local hud = inst ~= nil and inst.HUD or nil
    local controls = hud ~= nil and hud.controls or nil
    if controls ~= nil then
        AttachControlsUI(controls)
    end
end

local function HidePlayerControls(inst)
    if ThePlayer ~= nil and inst ~= ThePlayer then
        return
    end

    player_active = false
    SetControlsUIVisible(nil, false)
end

local function TryHidePlayerControls(inst, retries)
    if ThePlayer == nil or inst ~= ThePlayer then
        if retries > 0 and inst ~= nil and inst:IsValid() then
            inst:DoTaskInTime(0.1, function()
                TryHidePlayerControls(inst, retries - 1)
            end)
        end
        return
    end

    HidePlayerControls(inst)
end

local function InitializeForPlayer(inst)
    if not IsLocalYyxkPlayer(inst) then
        return false
    end

    local api = YyxkApi:AttachToPlayer(inst)
    if api == nil then
        return false
    end
    DBGAPI:Init(inst)
    RegisterHongyeTrueDamageEquipListener(inst)

    if not initialized then
        initialized = true
        LibKxyyKeyListener:Init()
        RegisterKeyActions()
        RegisterConfigListener()
        RegisterConfigLoadListener()
        LibKxyyConfig:Load()
    end

    player_active = true

    if not inst._libkxyy_load_success_announced then
        inst._libkxyy_load_success_announced = true
        inst:DoTaskInTime(3, function()
            if inst:IsValid() and ThePlayer == inst and inst._YyxkApi == api then
                api:Say("「空心夜雨」加载成功")
            end
        end)
    end

    return true
end

local function TryInitializePlayer(inst, retries)
    if ThePlayer == nil or inst ~= ThePlayer then
        if retries > 0 and inst ~= nil and inst:IsValid() then
            inst:DoTaskInTime(0.1, function()
                TryInitializePlayer(inst, retries - 1)
            end)
        end
        return
    end

    if InitializeForPlayer(inst) then
        AttachPlayerControls(inst)
        SetControlsUIVisible(nil, true)
        return
    end

    if retries > 0 and inst ~= nil and inst:IsValid() then
        inst:DoTaskInTime(0.1, function()
            TryInitializePlayer(inst, retries - 1)
        end)
    end
end

AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(0, function()
        if inst.prefab == "yyxk" then
            TryInitializePlayer(inst, 20)
        else
            TryHidePlayerControls(inst, 20)
        end
    end)
end)

AddClassPostConstruct("widgets/controls", function(self)
    AttachControlsUI(self)
end)
