local API = {
}

function API:GetYyxkReplica()
    if API._yyxk_replica ~= nil then
        return API._yyxk_replica
    end

    if ThePlayer == nil or ThePlayer.prefab ~= "yyxk" then
        return nil
    end

    API._yyxk_replica = ThePlayer.replica.yyxk

    return API._yyxk_replica
end

function API:Say(text)
    ThePlayer.components.talker:Say(text)
end

function API:GetEquippedWeapon()
    if ThePlayer == nil then return nil end

    return ThePlayer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
end

function API:IsYeyu()
    return ThePlayer:HasTag("yeyu")
end

function API:IsNilxin()
    return ThePlayer:HasTag("nilxin")
end

function API:IsSisterSummoned()
    return ThePlayer.yyxk_isjiemei == true
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

function API:SetWeaponMagic(magicKey, magicName)
    local replica = self:GetYyxkReplica()
    if replica == nil then return end

    replica:ToServer("magicWandSpelltype", magicKey)
    self:Say("切换: " .. magicName)
end

function API:SetSkill(skillKey, skillName)
    local replica = self:GetYyxkReplica()
    if replica == nil then return end

    replica:ToServer("setNilSkill", skillKey)
end

return API
