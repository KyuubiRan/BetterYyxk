local API = {
}

API.__index = API

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

function API:_OnSetNilSkill()

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

return API
