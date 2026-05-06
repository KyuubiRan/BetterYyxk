local DBGAPI = {
    status = {
        inf_mana = false,
        no_cd = false,
        yeyunilxin = false,
        yyxk_amulet = false,
        xin = 100,
        love = 0,
        wand_decompose = 0,
        yeyu_foxfire = 0,
        gem = {},
        yeyuup = {},
        nilxinup = {},
    },
    listeners = {},
}

local DEBUG_STATUS_CLIENT_FN = "__LibKxyyDebugStatus"
local DEBUG_STATUS_VERSION = "__v4"
local YEYU_SKILL_KEYS = {
    "multithrust",
    "crazy",
    "swordqi",
    "sharpblade",
    "aoe",
    "draw",
    "kill",
    "agile",
    "yeyu",
}
local NILXIN_SKILL_KEYS = {
    "fire",
    "water",
    "ice",
    "lightning",
    "wind",
    "space",
    "moon",
    "shadow",
    "nilxin",
}
local GEM_KEYS = {
    "nilxin_greygem",
    "nilxin_cyangem",
    "purplegem",
    "bluegem",
    "redgem",
    "orangegem",
    "yellowgem",
    "greengem",
    "opalpreciousgem",
}
local POTION_BUFF_KEYS = {
    "scale",
    "qbwh",
    "stian",
    "shenshu",
    "NILXIN_FOXBALL_REDOPALPRECIOUSGEM",
    "NILXIN_FOXBALL_REDORANGEGEM",
    "yyxkmp",
    "mybd",
    "mysm",
    "smhf",
    "whbe",
    "cydjs",
    "cantxinao",
    "picksomething2",
    "NILXIN_FOXBALL_REDBLUEGEM",
    "NILXIN_FOXBALL_REDREDGEM",
}

local function GetPlayerCommandString()
    local userid = ThePlayer ~= nil and ThePlayer.userid or nil
    if userid == nil then
        userid = ""
    end

    return "UserToPlayer(" .. string.format("%q", userid) .. ")"
end

local function HasArgs(...)
    return select("#", ...) > 0
end

local function PackCommand(command)
    command = tostring(command or "")
    command = command:gsub("%-%-%[%[.-%]%]", " ")
    command = command:gsub("%-%-[^\n]*", "")
    command = command:gsub("%s+", " ")
    command = command:gsub("^%s+", "")
    command = command:gsub("%s+$", "")
    return command
end

local function GetRemotePosition()
    if TheSim ~= nil and TheSim.ProjectScreenPos ~= nil and TheSim.GetPosition ~= nil then
        local x, y, z = TheSim:ProjectScreenPos(TheSim:GetPosition())
        if x ~= nil and z ~= nil then
            return x, z
        end
    end

    if ThePlayer ~= nil and ThePlayer.Transform ~= nil then
        local x, _, z = ThePlayer.Transform:GetWorldPosition()
        return x, z
    end

    return 0, 0
end

local function GetExecuteMode()
    if TheNet == nil then
        return nil
    end

    if TheNet:GetIsClient() and (TheNet:GetIsServerAdmin() or (IsConsole ~= nil and IsConsole())) then
        return "remote"
    end

    if TheNet:GetIsServer() and not TheNet:GetServerIsDedicated() and ExecuteConsoleCommand ~= nil then
        return "local"
    end

    return nil
end

local function BuildCommand(command, ...)
    if type(command) ~= "string" or HasArgs(...) then
        return nil
    end

    return PackCommand(command)
end

local function NotifyListeners(status)
    for listener in pairs(DBGAPI.listeners) do
        listener(status)
    end
end

local function ApplySkillStatus(target, source)
    if type(source) ~= "table" then
        return
    end

    for k in pairs(target) do
        target[k] = nil
    end

    for k, v in pairs(source) do
        target[k] = v == true
    end
end

local function ApplyNumberStatus(target, source)
    if type(source) ~= "table" then
        return
    end

    for k in pairs(target) do
        target[k] = nil
    end

    for k, v in pairs(source) do
        target[k] = tonumber(v) or 0
    end
end

local function BuildStatusSyncBody()
    local args = {
        string.format("%q", DEBUG_STATUS_CLIENT_FN),
        string.format("%q", DEBUG_STATUS_VERSION),
        "status_debug_api.inf_mana == true",
        "status_debug_api.no_cd == true",
        "yyxk.yeyunilxin == true",
        "tonumber(yyxk.xin) or 0",
        "tonumber(yyxk.love) or 0",
        "yyxk.yyxk_amulet == true",
        [[(function()
            local inv = player.components.inventory
            local weapon = inv ~= nil and inv:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
            return weapon ~= nil and weapon.prefab == "nilxin_scepter" and tonumber(weapon.redSum) or 0
        end)()]],
        [[(function()
            local inv = player.components.inventory
            local weapon = inv ~= nil and inv:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
            if weapon ~= nil and weapon.prefab == "yeyu_sword" then
                return math.max(0, math.floor(((tonumber(yyxk.yeyusworddamage) or 55) - 55) / 3))
            end
            return 0
        end)()]],
    }

    for _, key in ipairs(YEYU_SKILL_KEYS) do
        args[#args + 1] = "(yyxk.yeyuup ~= nil and yyxk.yeyuup." .. key .. " == true)"
    end

    for _, key in ipairs(NILXIN_SKILL_KEYS) do
        args[#args + 1] = "(yyxk.nilxinup ~= nil and yyxk.nilxinup." .. key .. " == true)"
    end

    for _, key in ipairs(GEM_KEYS) do
        args[#args + 1] = "(yyxk.gem ~= nil and tonumber(yyxk.gem." .. key .. ") or 0)"
    end

    return [[
if yyxk.ToClient ~= nil then
    local status_debug_api = yyxk.__DebugApi or {}
    yyxk:ToClient(]] .. table.concat(args, ", ") .. [[)
end
]]
end

local STATUS_SYNC_BODY = BuildStatusSyncBody()

local DEBUG_API_INIT_BODY = [[
if yyxk.__DebugApi == nil then
    yyxk.__DebugApi = {
        inf_mana = false,
        no_cd = false,
        old_DoMP = yyxk.DoMP,
        old_iscdFN = yyxk.iscdFN,
    }
end
if yyxk.__DebugApi.old_DoMP == nil then
    yyxk.__DebugApi.old_DoMP = yyxk.DoMP
end
if yyxk.__DebugApi.old_iscdFN == nil then
    yyxk.__DebugApi.old_iscdFN = yyxk.iscdFN
end
local debug_api = yyxk.__DebugApi
]]

local function BuildYyxkCommand(player_expr, body)
    return [[
        local player = ]] .. player_expr .. [[
        if player ~= nil
            and player.components ~= nil
            and player.components.yyxk ~= nil then
            local yyxk = player.components.yyxk
    ]] .. body .. [[
        end
    ]]
end

local function BuildLocalYyxkCommand(body)
    return BuildYyxkCommand(GetPlayerCommandString(), body)
end

local function BuildLocalYyxkCommandWithValue(name, value, body)
    return BuildLocalYyxkCommand("local " .. name .. " = " .. tostring(value) .. "\n" .. body)
end

local function BuildLocalYyxkCommandWithValues(values, body)
    local lines = {}
    for _, value_def in ipairs(values) do
        lines[#lines + 1] = "local " .. value_def[1] .. " = " .. tostring(value_def[2])
    end

    return BuildLocalYyxkCommand(table.concat(lines, "\n") .. "\n" .. body)
end

local function ContainsValue(values, value)
    for _, item in ipairs(values) do
        if item == value then
            return true
        end
    end

    return false
end

local function BuildLocalDebugApiCommand(body, sync_status)
    return BuildLocalYyxkCommand(DEBUG_API_INIT_BODY .. body .. (sync_status and STATUS_SYNC_BODY or ""))
end

local function BuildLocalStatusCommand()
    return BuildLocalYyxkCommand(STATUS_SYNC_BODY)
end

-- 是否管理员权限（服务器或单人）
function DBGAPI:IsAdmin()
    return GetExecuteMode() ~= nil
end

-- 初始化
function DBGAPI:Init(inst)
    if inst._YyxkApi == nil then
        return false
    end

    self.inst = inst
    local replica = inst.replica ~= nil and inst.replica.yyxk or nil
    if replica ~= nil then
        replica[DEBUG_STATUS_CLIENT_FN] = function(_, version, inf_mana, no_cd, ...)
            if version == DEBUG_STATUS_VERSION then
                local values = { ... }
                local status = {
                    inf_mana = inf_mana == true,
                    no_cd = no_cd == true,
                    yeyunilxin = values[1] == true,
                    xin = tonumber(values[2]) or 0,
                    love = tonumber(values[3]) or 0,
                    yyxk_amulet = values[4] == true,
                    wand_decompose = tonumber(values[5]) or 0,
                    yeyu_foxfire = tonumber(values[6]) or 0,
                    yeyuup = {},
                    nilxinup = {},
                    gem = {},
                }
                local index = 7
                for _, key in ipairs(YEYU_SKILL_KEYS) do
                    status.yeyuup[key] = values[index] == true
                    index = index + 1
                end
                for _, key in ipairs(NILXIN_SKILL_KEYS) do
                    status.nilxinup[key] = values[index] == true
                    index = index + 1
                end
                for _, key in ipairs(GEM_KEYS) do
                    status.gem[key] = tonumber(values[index]) or 0
                    index = index + 1
                end
                self:ApplyStatus(status)
            else
                self:ApplyStatus({
                    inf_mana = version == true,
                })
            end
        end
    end

    return true
end

function DBGAPI:AddListener(listener)
    if listener ~= nil then
        self.listeners[listener] = true
    end

    return listener
end

function DBGAPI:RemoveListener(listener)
    if listener ~= nil then
        self.listeners[listener] = nil
    end
end

function DBGAPI:ApplyStatus(status)
    if type(status) ~= "table" then
        return
    end

    if status.inf_mana ~= nil then
        self.status.inf_mana = status.inf_mana == true
    end

    if status.no_cd ~= nil then
        self.status.no_cd = status.no_cd == true
    end

    if status.yeyunilxin ~= nil then
        self.status.yeyunilxin = status.yeyunilxin == true
    end
    if status.yyxk_amulet ~= nil then
        self.status.yyxk_amulet = status.yyxk_amulet == true
    end
    if status.xin ~= nil then
        self.status.xin = tonumber(status.xin) or 0
    end
    if status.love ~= nil then
        self.status.love = tonumber(status.love) or 0
    end
    if status.wand_decompose ~= nil then
        self.status.wand_decompose = tonumber(status.wand_decompose) or 0
    end
    if status.yeyu_foxfire ~= nil then
        self.status.yeyu_foxfire = tonumber(status.yeyu_foxfire) or 0
    end

    ApplySkillStatus(self.status.yeyuup, status.yeyuup)
    ApplySkillStatus(self.status.nilxinup, status.nilxinup)
    ApplyNumberStatus(self.status.gem, status.gem)

    NotifyListeners(self.status)
end

function DBGAPI:GetStatus()
    return self.status
end

function DBGAPI:SyncStatus()
    return self:RemoteCall(BuildLocalStatusCommand())
end

-- 远程调用
function DBGAPI:RemoteCall(command, ...)
    local mode = GetExecuteMode()
    if mode == nil then
        return false
    end

    command = BuildCommand(command, ...)
    if command == nil or command == "" then
        return false
    end

    if mode == "remote" then
        local x, z = GetRemotePosition()
        TheNet:SendRemoteExecute(command, x, z)
        return true
    end

    if mode == "local" then
        ExecuteConsoleCommand(command)
        return true
    end

    return false
end

-- 恢复魔力
function DBGAPI:DeltaMana(delta)
    delta = tonumber(delta) or 0

    local command = BuildLocalYyxkCommandWithValue("delta", delta, [[
yyxk:DoMP(delta, false)
    ]])

    return self:RemoteCall(command)
end

-- 设置技能点
function DBGAPI:SetSkillPoints(amount)
    amount = math.floor(tonumber(amount) or 0)
    self.inst.replica.yyxk.skillspoint = amount

    local command = BuildLocalYyxkCommandWithValue("amount", amount, [[
if player.replica ~= nil and player.replica.yyxk ~= nil then
    player.replica.yyxk.skillspoint = amount
end
    ]])

    return self:RemoteCall(command)
end

-- 设置狐心等级
function DBGAPI:SetHuxinLevel(level)
    level = math.clamp(math.floor(tonumber(level) or 0), 0, 100)

    local command = BuildLocalYyxkCommandWithValue("level", level, [[
if level == 0 then
    player.components.yyxkf:delBuff("cylv")
else
    player.components.yyxkf:addBuff("cylv", "cylv", nil, 1)
    player.components.yyxkf.buff.cylv.layer = level
    player.components.yyxkf:subBuff("cylv", 0, nil)
end
    ]])

    return self:RemoteCall(command)
end

-- 技能树全开
function DBGAPI:UnlockSkillTree()
    local updater = self.inst.components.skilltreeupdater

    for i = 1, 9 do
        for skill in pairs(self.inst.replica.yyxk.skills) do
            if updater:IsValidSkill(skill) then
                updater:ActivateSkill(skill, self.inst.prefab)
            end
        end
    end

    return true
end

-- 解锁身法和大狐狸
function DBGAPI:UnlockMovementFox()
    local command = BuildLocalYyxkCommand([[
yyxk.magicWandSkill = {}
    ]])

    return self:RemoteCall(command)
end

-- 设置姐妹解锁状态
function DBGAPI:SetJiemeiUnlocked(enabled)
    local command = BuildLocalYyxkCommandWithValue("enabled", enabled == true and "true" or "false", [[
yyxk.yeyunilxin = enabled
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

-- 设置姐妹心情
function DBGAPI:SetJiemeiXin(value)
    value = math.max(-99, math.min(100, math.floor(tonumber(value) or 0)))

    local command = BuildLocalYyxkCommandWithValue("value", value, [[
yyxk.xin = value
if yyxk.setXinFN ~= nil then
    yyxk:setXinFN(0)
end
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

-- 设置姐妹好感
function DBGAPI:SetJiemeiLove(value)
    value = math.floor(tonumber(value) or 0)

    local command = BuildLocalYyxkCommandWithValue("value", value, [[
yyxk.love = value
if yyxk.jiemei ~= nil and yyxk.jiemei.yyxk_bz ~= nil and yyxk.jiemei.yyxk_bz.components ~= nil and yyxk.jiemei.yyxk_bz.components.named ~= nil then
    yyxk.jiemei.yyxk_bz.components.named:SetName("狐狸宝珠(♡" .. yyxk.love .. ")")
end
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

-- 设置满级伞护
function DBGAPI:SetYyxkAmulet(enabled)
    local command = BuildLocalYyxkCommandWithValue("enabled", enabled == true and "true" or "false", [[
yyxk.yyxk_amulet = enabled
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

-- 设置魔杖分解数
function DBGAPI:SetWandDecompose(value)
    value = math.max(0, math.floor(tonumber(value) or 0))

    local command = BuildLocalYyxkCommandWithValue("value", value, [[
local inv = player.components.inventory
if inv ~= nil then
    local weapon = inv:GetEquippedItem(EQUIPSLOTS.HANDS)
    if weapon ~= nil and weapon.prefab == "nilxin_scepter" and weapon.redSum ~= nil then
        weapon.redSum = value
    end
end
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

-- 设置红叶狐火数
function DBGAPI:SetYeyuFoxfire(value)
    value = math.max(0, math.floor(tonumber(value) or 0))

    local command = BuildLocalYyxkCommandWithValue("value", value, [[
local inv = player.components.inventory
if inv ~= nil then
    local weapon = inv:GetEquippedItem(EQUIPSLOTS.HANDS)
    if weapon ~= nil and weapon.prefab == "yeyu_sword" then
        yyxk.yeyusworddamage = 55 + 3 * math.floor(value)
        if weapon.components ~= nil and weapon.components.weapon ~= nil then
            weapon.components.weapon:SetDamage(yyxk.yeyusworddamage)
        end
    end
end
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

-- 设置元素等级
function DBGAPI:SetGemValue(key, value)
    if type(key) ~= "string" or key == "" then
        return false
    end

    local known = false
    for _, gem_key in ipairs(GEM_KEYS) do
        if gem_key == key then
            known = true
            break
        end
    end
    if not known then
        return false
    end

    value = math.floor(tonumber(value) or 0)

    local command = BuildLocalYyxkCommandWithValues({
        { "key", string.format("%q", key) },
        { "value", value },
    }, [[
if yyxk.gem == nil then
    yyxk.gem = {}
end
yyxk.gem[key] = value
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

-- 生成药剂
function DBGAPI:CreatePotion(level, buffs)
    level = math.max(1, math.min(9, math.floor(tonumber(level) or 1)))
    buffs = type(buffs) == "table" and buffs or {}

    local values = {
        { "level", level },
    }
    local lines = {
        "local data = { lv = level }",
    }

    local used = {}
    for _, buff in ipairs(buffs) do
        local key = type(buff) == "table" and buff.key or nil
        if key ~= nil and not used[key] and ContainsValue(POTION_BUFF_KEYS, key) then
            used[key] = true
            local value_name = "buff_value_" .. tostring(#values)
            values[#values + 1] = { value_name, tonumber(buff.value) or 0 }
            lines[#lines + 1] = "data[" .. string.format("%q", key) .. "] = " .. value_name
        end
    end

    local command = BuildLocalYyxkCommandWithValues(values, [[
local item = SpawnPrefab("yyxk_yaoji")
if item ~= nil then
    ]] .. table.concat(lines, "\n    ") .. [[
    if item.a ~= nil then
        item:a(data)
    end
    if item.components ~= nil and item.components.finiteuses ~= nil then
        item.components.finiteuses:SetPercent(1)
    end
    if player.components.inventory ~= nil then
        player.components.inventory:GiveItem(item, nil, player:GetPosition())
    else
        item.Transform:SetPosition(player.Transform:GetWorldPosition())
    end
end
    ]])

    return self:RemoteCall(command)
end

-- 切换无限魔力
function DBGAPI:ToggleInfMana()
    local command = BuildLocalDebugApiCommand([[
debug_api.inf_mana = not debug_api.inf_mana
if debug_api.inf_mana then
    yyxk.DoMP = function(component, mp, b, p)
        if mp ~= nil and mp <= 0 then
            return true
        end
        return debug_api.old_DoMP(component, mp, b, p)
    end
else
    yyxk.DoMP = debug_api.old_DoMP
end
    ]], true)

    return self:RemoteCall(command)
end

-- 切换无冷却
function DBGAPI:ToggleNoCooldown()
    local command = BuildLocalDebugApiCommand([[
debug_api.no_cd = not debug_api.no_cd
if debug_api.no_cd then
    yyxk.iscdFN = function(component, n, t, say)
        return true
    end
else
    yyxk.iscdFN = debug_api.old_iscdFN
end
    ]], true)

    return self:RemoteCall(command)
end

-- 设置技能解锁状态
function DBGAPI:SetSkillUnlocked(group, key, enabled)
    if group ~= "yeyuup" and group ~= "nilxinup" then
        return false
    end

    if type(key) ~= "string" or key == "" then
        return false
    end

    local target_enabled = enabled == true
    local command = BuildLocalYyxkCommandWithValues({
        { "group", string.format("%q", group) },
        { "key", string.format("%q", key) },
        { "target_enabled", target_enabled and "true" or "false" },
    }, [[
local skills = yyxk[group]
if type(skills) == "table" and skills[key] ~= nil then
    skills[key] = target_enabled
    if yyxk.__DebugApi ~= nil and type(yyxk.__DebugApi.status) == "table" then
        if yyxk.__DebugApi.status[group] == nil then
            yyxk.__DebugApi.status[group] = {}
        end
        yyxk.__DebugApi.status[group][key] = skills[key] == true
    end
end
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

return DBGAPI
