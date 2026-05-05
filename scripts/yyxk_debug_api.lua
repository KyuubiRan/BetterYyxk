local DBGAPI = {
    status = {
        inf_mana = false,
        yeyunilxin = false,
        xin = 100,
        love = 0,
        gem = {},
        yeyuup = {},
        nilxinup = {},
    },
    listeners = {},
}

local DEBUG_STATUS_CLIENT_FN = "__LibKxyyDebugStatus"
local DEBUG_STATUS_VERSION = "__v2"
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
        "yyxk.yeyunilxin == true",
        "tonumber(yyxk.xin) or 0",
        "tonumber(yyxk.love) or 0",
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
        old_DoMP = yyxk.DoMP,
    }
end
if yyxk.__DebugApi.old_DoMP == nil then
    yyxk.__DebugApi.old_DoMP = yyxk.DoMP
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
        replica[DEBUG_STATUS_CLIENT_FN] = function(_, version, inf_mana, ...)
            if version == DEBUG_STATUS_VERSION then
                local values = { ... }
                local status = {
                    inf_mana = inf_mana == true,
                    yeyunilxin = values[1] == true,
                    xin = tonumber(values[2]) or 0,
                    love = tonumber(values[3]) or 0,
                    yeyuup = {},
                    nilxinup = {},
                    gem = {},
                }
                local index = 4
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

    if status.yeyunilxin ~= nil then
        self.status.yeyunilxin = status.yeyunilxin == true
    end
    if status.xin ~= nil then
        self.status.xin = tonumber(status.xin) or 0
    end
    if status.love ~= nil then
        self.status.love = tonumber(status.love) or 0
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
    ThePlayer.replica.yyxk.skillspoint = amount

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
    local updater = ThePlayer.components.skilltreeupdater

    for i = 1, 9 do
        for skill in pairs(ThePlayer.replica.yyxk.skills) do
            if updater:IsValidSkill(skill) then
                updater:ActivateSkill(skill, ThePlayer.prefab)
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
