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

function API:IsSwordEquipped()
    local weapon = self:GetEquippedWeapon()
    if weapon == nil then return false end

    return weapon.prefab == "yeyu_sword"
end

function API:SetWeaponMagic(magicKey, magicName)
    local replica = self:GetYyxkReplica()
    if replica == nil then return end
    if not self:IsNilxin() then
        self:Say("需要切换到空心")
    end

    if self:IsStaffEquipped() then
        replica:ToServer("magicWandSpelltype", magicKey)
        self:Say("切换: " .. magicName)
    else
        self:Say("需要装备魔杖")
    end
end

function API:SetSkill(skillKey, skillName)
    local replica = self:GetYyxkReplica()
    if replica == nil then return end
    if not self:IsNilxin() then
        self:Say("需要切换到空心")
    end

    if self:IsStaffEquipped() then
        replica:ToServer("setNilSkill", skillKey)
        -- self:Say("切换: " .. skillName)
    else
        self:Say("需要装备魔杖")
    end
end

return API