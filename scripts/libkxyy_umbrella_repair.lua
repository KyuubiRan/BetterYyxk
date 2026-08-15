local LibKxyyConfig = require("libkxyy_config")
local RepairData = require("libkxyy_umbrella_repair_data")
local YyxkApi = require("yyxk_api")

local UmbrellaRepair = {
    inst = nil,
    auto_repair_task = nil,
    attacked_listener = nil,
    last_attacked_time = nil,
    pending = nil,
}

local function GetNow()
    return GetTime ~= nil and GetTime() or 0
end

local function GetStackSize(item)
    local stackable = item ~= nil
        and item.replica ~= nil
        and item.replica.stackable
        or nil
    if stackable ~= nil and stackable.StackSize ~= nil then
        return stackable:StackSize() or 1
    end

    stackable = item ~= nil
        and item.components ~= nil
        and item.components.stackable
        or nil
    if stackable ~= nil and stackable.StackSize ~= nil then
        return stackable:StackSize() or 1
    end

    return 1
end

local function CollectGems(holder, counts, first_items)
    if holder == nil
        or holder.GetNumSlots == nil
        or holder.GetItemInSlot == nil then
        return
    end

    local num_slots = holder:GetNumSlots()
    if type(num_slots) ~= "number" then
        return
    end

    for slot = 1, num_slots do
        local item = holder:GetItemInSlot(slot)
        if item ~= nil and item:IsValid() and RepairData.GEM_MAP[item.prefab] ~= nil then
            counts[item.prefab] = (counts[item.prefab] or 0) + GetStackSize(item)
            if first_items[item.prefab] == nil then
                first_items[item.prefab] = item
            end
        end
    end
end

function UmbrellaRepair:GetRepairGem(amulet)
    local inst = self.inst
    local inventory = inst ~= nil
        and inst.replica ~= nil
        and inst.replica.inventory
        or nil
    if inventory == nil then
        return nil
    end

    local counts = {}
    local first_items = {}
    local scope = LibKxyyConfig:Get("umbrella_repair_scope", RepairData.SCOPE_ALL)

    if scope == RepairData.SCOPE_INVENTORY or scope == RepairData.SCOPE_ALL then
        CollectGems(inventory, counts, first_items)
    end

    if scope == RepairData.SCOPE_UMBRELLA or scope == RepairData.SCOPE_ALL then
        local container = amulet ~= nil
            and amulet.replica ~= nil
            and amulet.replica.container
            or nil
        CollectGems(container, counts, first_items)
    end

    local reserve = tonumber(LibKxyyConfig:Get("umbrella_repair_reserve", 0)) or 0
    local selected = nil
    local selected_priority = 0

    for _, gem in ipairs(RepairData.GEMS) do
        local priority = tonumber(LibKxyyConfig:Get(
            RepairData.GetPriorityConfigName(gem.prefab),
            gem.default_priority
        )) or 0

        if priority > selected_priority
            and first_items[gem.prefab] ~= nil
            and (counts[gem.prefab] or 0) > reserve then
            selected = {
                item = first_items[gem.prefab],
                label = gem.label,
            }
            selected_priority = priority
        end
    end

    return selected
end

function UmbrellaRepair:ClearPending()
    local pending = self.pending
    self.pending = nil

    if pending == nil then
        return
    end

    if pending.timeout_task ~= nil then
        pending.timeout_task:Cancel()
    end

    if pending.amulet ~= nil
        and pending.amulet.RemoveEventCallback ~= nil
        and pending.listener ~= nil then
        pending.amulet:RemoveEventCallback("percentusedchange", pending.listener)
    end
end

function UmbrellaRepair:OnRepairConfirmed(percent)
    local pending = self.pending
    if pending == nil or percent == nil or percent < 1 then
        return
    end

    local old_value = math.floor(pending.old_percent * 100 + 0.5)
    local new_value = math.floor(percent * 100 + 0.5)
    local gem_label = pending.gem_label
    self:ClearPending()

    local api = YyxkApi:GetCurrent()
    if api ~= nil then
        api:SayLocal(string.format(
            "已使用 %s 修复伞之护: %d->%d",
            gem_label,
            old_value,
            new_value
        ))
    end
end

function UmbrellaRepair:BeginPending(amulet, gem, old_percent)
    self:ClearPending()

    local pending = {
        amulet = amulet,
        gem_label = gem.label,
        old_percent = old_percent,
    }
    self.pending = pending

    pending.listener = function(_, data)
        self:OnRepairConfirmed(data ~= nil and tonumber(data.percent) or nil)
    end
    amulet:ListenForEvent("percentusedchange", pending.listener)

    pending.timeout_task = self.inst:DoTaskInTime(RepairData.REPAIR_CONFIRM_TIMEOUT, function()
        if self.pending == pending then
            self:ClearPending()
        end
    end)
end

function UmbrellaRepair:IsAutoRepairBlockedByCombat(api)
    if not LibKxyyConfig:Get("umbrella_auto_repair_combat_check", true) then
        return false
    end

    if api:IsPlayerInCombat() then
        return true
    end

    return self.last_attacked_time ~= nil
        and GetNow() - self.last_attacked_time < RepairData.COMBAT_GRACE_PERIOD
end

function UmbrellaRepair:SayManualFailure(is_auto, text)
    if is_auto then
        return
    end

    local api = YyxkApi:GetCurrent()
    if api ~= nil then
        api:SayLocal(text)
    end
end

function UmbrellaRepair:RepairOnce(is_auto)
    local inst = self.inst
    local api = YyxkApi:GetCurrent()
    if inst == nil
        or inst ~= ThePlayer
        or not inst:IsValid()
        or inst.prefab ~= "yyxk"
        or api == nil
        or self.pending ~= nil then
        return false
    end

    local amulet = api:GetEquippedUmbrella()
    if amulet == nil then
        self:SayManualFailure(is_auto, "需要装备伞之护")
        return false
    end

    local old_percent = api:GetUmbrellaDurabilityPercent(amulet)
    if old_percent == nil then
        self:SayManualFailure(is_auto, "无法读取伞之护耐久")
        return false
    end

    if old_percent >= 1 then
        self:SayManualFailure(is_auto, "伞之护无需修复")
        return false
    end

    if is_auto then
        local threshold = tonumber(LibKxyyConfig:Get("umbrella_auto_repair_threshold", 0)) or 0
        if threshold <= 0 or old_percent * 100 >= threshold then
            return false
        end

        if self:IsAutoRepairBlockedByCombat(api) then
            return false
        end
    end

    local gem = self:GetRepairGem(amulet)
    if gem == nil then
        self:SayManualFailure(is_auto, "没有符合配置的宝石")
        return false
    end

    self:BeginPending(amulet, gem, old_percent)
    if not api:GiveItemToUmbrella(amulet, gem.item) then
        self:ClearPending()
        self:SayManualFailure(is_auto, "当前无法修复伞之护")
        return false
    end

    return true
end

function UmbrellaRepair:RefreshAutoRepairTask()
    if self.auto_repair_task ~= nil then
        self.auto_repair_task:Cancel()
        self.auto_repair_task = nil
    end

    local inst = self.inst
    local threshold = tonumber(LibKxyyConfig:Get("umbrella_auto_repair_threshold", 0)) or 0
    if inst == nil or not inst:IsValid() or threshold <= 0 then
        return
    end

    self.auto_repair_task = inst:DoPeriodicTask(RepairData.AUTO_REPAIR_INTERVAL, function()
        if self.inst == inst and inst:IsValid() and inst == ThePlayer then
            self:RepairOnce(true)
        end
    end, RepairData.AUTO_REPAIR_INTERVAL)
end

function UmbrellaRepair:Attach(inst)
    if inst == nil or not inst:IsValid() or inst ~= ThePlayer or inst.prefab ~= "yyxk" then
        self:Detach()
        return false
    end

    if self.inst ~= inst then
        self:Detach()
        self.inst = inst
        self.attacked_listener = function()
            self.last_attacked_time = GetNow()
        end
        inst:ListenForEvent("attacked", self.attacked_listener)
    end

    self:RefreshAutoRepairTask()
    return true
end

function UmbrellaRepair:Detach()
    self:ClearPending()

    if self.auto_repair_task ~= nil then
        self.auto_repair_task:Cancel()
        self.auto_repair_task = nil
    end

    if self.inst ~= nil and self.attacked_listener ~= nil then
        self.inst:RemoveEventCallback("attacked", self.attacked_listener)
    end

    self.inst = nil
    self.attacked_listener = nil
    self.last_attacked_time = nil
end

return UmbrellaRepair
