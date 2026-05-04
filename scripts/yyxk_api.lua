local LibKxyyConfig = require("libkxyy_config")

local API = {
}

local NILXIN_SKILL_LIST = {
    water = "水",
    fire = "火",
    ice = "冰",
    lightning = "电",
    wind = "风",
    space = "空",
    moon = "月",
    shadow = "暗",
}
local LOCKED_REPEAT_INTERVAL = 0.1
local LUNGE_ATTRACTION_CANT_TAGS = { "player", "playerghost", "FX", "NOCLICK", "noattack", "notarget", "companion" }
local LUNGE_ATTRACTION_ONEOF_TAGS = { "_combat", "_health" }
local lunge_attraction_active = false

API.__index = API

local function PackArgs(...)
    return {
        n = select("#", ...),
        ...
    }
end

function API:IsYyxkPlayer(inst)
    return inst ~= nil and inst.prefab == "yyxk"
end

function API:IsLocalYyxkPlayer(inst)
    return self:IsYyxkPlayer(inst) and ThePlayer ~= nil and inst == ThePlayer
end

function API:GetCurrent()
    return ThePlayer ~= nil and ThePlayer._YyxkApi or nil
end

function API:AttachToPlayer(inst)
    if not self:IsLocalYyxkPlayer(inst) then
        return nil
    end

    if inst._YyxkApi ~= nil then
        inst._YyxkApi.inst = inst
        setmetatable(inst._YyxkApi, self)

        if inst._YyxkApi:InitHooks() then
            return inst._YyxkApi
        end

        return nil
    end

    local player_api = setmetatable({
        inst = inst,
    }, self)

    inst._YyxkApi = player_api

    if not player_api:InitHooks() then
        inst._YyxkApi = nil
        return nil
    end

    return player_api
end

function API:_OnSetNilSkill(skillKey)
    if NILXIN_SKILL_LIST[skillKey] == nil then
        return
    end

    if self._locked_repeat_task ~= nil
        and not self._locked_repeat_casting
        and self._locked_repeat_skill_key ~= skillKey then
        self._locked_repeat_skill_key = skillKey
        self:Say("切换锁定施法: " .. NILXIN_SKILL_LIST[skillKey])
    end

    self._last_nilxin_skill_key = skillKey
end

function API:IsValidLungeAttractionTarget(target)
    if target == nil
        or target == self.inst
        or not target:IsValid()
        or target.Transform == nil then
        return false
    end

    local health = target.replica ~= nil and target.replica.health or nil
    if health == nil and target.components ~= nil then
        health = target.components.health
    end

    return health ~= nil and not health:IsDead()
end

function API:GetYeyuLungeAttractionRange()
    return LibKxyyConfig:Get("yeyu_lunge_attraction_range", 2)
end

function API:SetYeyuLungeAttractionEnabled(enabled)
    lunge_attraction_active = enabled == true
end

function API:ToggleYeyuLungeAttraction()
    self:SetYeyuLungeAttractionEnabled(not lunge_attraction_active)
    return lunge_attraction_active
end

function API:IsYeyuLungeAttractionEnabled()
    return self:IsYeyu()
        and lunge_attraction_active == true
end

function API:FindLungeAttractionTarget(x, y, z)
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if x == nil or y == nil or z == nil or TheSim == nil then
        return nil
    end

    local closest = nil
    local closest_distance_sq = nil
    local ents = TheSim:FindEntities(
        x,
        y,
        z,
        self:GetYeyuLungeAttractionRange(),
        nil,
        LUNGE_ATTRACTION_CANT_TAGS,
        LUNGE_ATTRACTION_ONEOF_TAGS
    )

    for _, target in ipairs(ents) do
        if self:IsValidLungeAttractionTarget(target) then
            local target_x, _, target_z = target.Transform:GetWorldPosition()
            local distance_sq = (target_x - x) * (target_x - x) + (target_z - z) * (target_z - z)
            if closest == nil or distance_sq < closest_distance_sq then
                closest = target
                closest_distance_sq = distance_sq
            end
        end
    end

    return closest
end

function API:GetLungeAttractedArgs(...)
    local args = PackArgs(...)
    local target = self:FindLungeAttractionTarget(args[1], args[2], args[3])
    if target == nil then
        return nil
    end

    args[1], args[2], args[3] = target.Transform:GetWorldPosition()
    return args
end

function API:InitHooks()
    if not self:IsLocalYyxkPlayer(self.inst) then
        return false
    end

    self._yyxk_replica = nil

    local replica = self:GetYyxkReplica()
    if replica == nil then return false end

    if self._hooked_replica == replica then
        return true
    end

    local original_to_server = replica._libkxyy_original_to_server or replica.ToServer
    replica._libkxyy_original_to_server = original_to_server
    self._ToServerFn = original_to_server
    self._hooked_replica = replica

    local player_api = self
    replica.ToServer = function(self, fnName, ...)
        if fnName == "setNilSkill" then
            player_api:_OnSetNilSkill(...)
        end

        if fnName == "LUNGE" then
            if player_api:IsYeyuLungeAttractionEnabled() then
                local attracted_args = player_api:GetLungeAttractedArgs(...)
                if attracted_args ~= nil then
                    return original_to_server(self, fnName, unpack(attracted_args, 1, attracted_args.n))
                end
            end

            return original_to_server(self, fnName, ...)
        end

        return original_to_server(self, fnName, ...)
    end

    return true
end

function API:GetYyxkReplica()
    local inst = self.inst
    if not self:IsLocalYyxkPlayer(inst) then
        return nil
    end

    if self._yyxk_replica ~= nil then
        return self._yyxk_replica
    end

    self._yyxk_replica = inst.replica ~= nil and inst.replica.yyxk or nil

    return self._yyxk_replica
end

function API:SendToServer(fnName, ...)
    if not self:IsLocalYyxkPlayer(self.inst) then return false end

    local replica = self:GetYyxkReplica()
    if replica == nil then return false end

    if self._ToServerFn == nil then return false end

    self._ToServerFn(replica, fnName, ...)
    return true
end

function API:Say(text)
    local inst = self.inst
    if inst ~= nil and inst.components ~= nil and inst.components.talker ~= nil then
        inst.components.talker:Say(text)
    end
end

function API:GetEquippedWeapon()
    local inst = self.inst
    if not self:IsLocalYyxkPlayer(inst) then return nil end

    return inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
end

function API:IsYeyu()
    return self.inst ~= nil and self.inst:HasTag("yeyu")
end

function API:IsNilxin()
    return self.inst ~= nil and self.inst:HasTag("nilxin")
end

function API:IsSisterSummoned()
    return self.inst ~= nil and self.inst.yyxk_isjiemei == true
end

function API:IsStaffEquipped()
    local weapon = self:GetEquippedWeapon()
    if weapon == nil then return false end

    return weapon.prefab == "nilxin_scepter"
end

function API:CanChangeStaffMagic(showReason)
    if not self:IsNilxin() then
        if showReason then
            self:Say("需要切换到空心")
        end
        return false
    end

    if not self:IsStaffEquipped() then
        if showReason then
            self:Say("需要装备魔杖")
        end
        return false
    end

    return true
end

function API:IsSwordEquipped()
    local weapon = self:GetEquippedWeapon()
    if weapon == nil then return false end

    return weapon.prefab == "yeyu_sword"
end

function API:SetWeaponMagic(magicKey)
    return self:SendToServer("magicWandSpelltype", magicKey)
end

function API:SetSkill(skillKey)
    return self:SendToServer("setNilSkill", skillKey)
end

function API:RepeatLastSkill()
    local skillKey = self._last_nilxin_skill_key
    local skillName = skillKey ~= nil and NILXIN_SKILL_LIST[skillKey] or nil

    if skillName == nil then
        self:Say("没有选择任何魔法")
        return false
    end

    if self:SetSkill(skillKey) then
        self:Say("快捷施法: " .. skillName)
        return true
    end

    return false
end

function API:StartLockedRepeatSkill()
    local skillKey = self._last_nilxin_skill_key
    local skillName = skillKey ~= nil and NILXIN_SKILL_LIST[skillKey] or nil

    if skillName == nil then
        self:Say("没有选择任何魔法")
        return false
    end

    if self._locked_repeat_task ~= nil then
        self:StopLockedRepeatSkill(false)
    end

    self._locked_repeat_skill_key = skillKey
    self:Say("锁定施法: " .. skillName)

    self._locked_repeat_task = self.inst:DoPeriodicTask(LOCKED_REPEAT_INTERVAL, function()
        if not self:IsLocalYyxkPlayer(self.inst) then
            self:StopLockedRepeatSkill(false)
            return
        end

        self._locked_repeat_casting = true
        self:SetSkill(self._locked_repeat_skill_key)
        self._locked_repeat_casting = false
    end)

    return true
end

function API:StopLockedRepeatSkill(showMessage)
    if self._locked_repeat_task ~= nil then
        self._locked_repeat_task:Cancel()
        self._locked_repeat_task = nil
    end

    self._locked_repeat_skill_key = nil
    self._locked_repeat_casting = false
    self:SetSkill(nil)

    if showMessage then
        self:Say("取消锁定施法")
    end
end

function API:ToggleLockedRepeatSkill()
    if self._locked_repeat_task ~= nil then
        self:StopLockedRepeatSkill(true)
        return false
    end

    return self:StartLockedRepeatSkill()
end

function API:ToggleWandaTeleportUi()
    local inst = self.inst
    if not self:IsLocalYyxkPlayer(inst) then return end

    local hud = inst.HUD
    local controls = hud ~= nil and hud.controls or nil
    local yyxkui = controls ~= nil and controls.yyxkui or nil
    local yyxk = yyxkui ~= nil and yyxkui.yyxk or nil
    local yyxk10 = yyxk ~= nil and yyxk.yyxk10 or nil

    if yyxkui == nil or yyxk10 == nil then
        return
    end

    if yyxk10.shown then
        yyxk10:Hide()
        if yyxk.shown then
            yyxk:Hide()
        end
    else
        if not yyxk.shown then
            yyxk:Show()
            yyxk:MoveToFront()
        end
        yyxk10:Show()
        yyxk10:MoveToFront()
    end
end

function API:SummonShadowChest()
    return self:SendToServer("cykjccFN")
end

function API:FindAndEquipInInv(prefab)
    local inst = self.inst
    local inv = inst.replica.inventory

    for i = 1, inv:GetNumSlots() do
        local item = inv:GetItemInSlot(i)
        if item ~= nil and item.prefab == prefab then
            if inst.components ~= nil and inst.components.inventory ~= nil then
                inst.components.inventory:EquipActionItem(item)
            elseif SendRPCToServer ~= nil and RPC ~= nil and RPC.EquipActionItem ~= nil then
                SendRPCToServer(RPC.EquipActionItem, item)
            else
                inv:EquipActionItem(item)
            end
            return true
        end
    end

    return false
end

function API:FindAndEquipYeyuSword()
    return self:FindAndEquipInInv("yeyu_sword")
end

function API:UseItemInHand()
    local inst = self.inst
    local inv = inst.replica.inventory

    inv:UseItemFromInvTile(inv:GetEquippedItem(EQUIPSLOTS.HANDS))
end

return API
