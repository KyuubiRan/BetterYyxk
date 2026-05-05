local DBGAPI = {
    status = {
        inf_mana = false,
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

local function BuildStatusSyncBody()
    local args = {
        string.format("%q", DEBUG_STATUS_CLIENT_FN),
        string.format("%q", DEBUG_STATUS_VERSION),
        "status_debug_api.inf_mana == true",
    }

    for _, key in ipairs(YEYU_SKILL_KEYS) do
        args[#args + 1] = "(yyxk.yeyuup ~= nil and yyxk.yeyuup." .. key .. " == true)"
    end

    for _, key in ipairs(NILXIN_SKILL_KEYS) do
        args[#args + 1] = "(yyxk.nilxinup ~= nil and yyxk.nilxinup." .. key .. " == true)"
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
if player ~= nil and player.components ~= nil and player.components.yyxk ~= nil then
    local yyxk = player.components.yyxk
    ]] .. body .. [[
end
]]
end

local function BuildLocalYyxkCommand(body)
    return BuildYyxkCommand(GetPlayerCommandString(), body)
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
                    yeyuup = {},
                    nilxinup = {},
                }
                local index = 1
                for _, key in ipairs(YEYU_SKILL_KEYS) do
                    status.yeyuup[key] = values[index] == true
                    index = index + 1
                end
                for _, key in ipairs(NILXIN_SKILL_KEYS) do
                    status.nilxinup[key] = values[index] == true
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

    ApplySkillStatus(self.status.yeyuup, status.yeyuup)
    ApplySkillStatus(self.status.nilxinup, status.nilxinup)

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

    local command = BuildLocalYyxkCommand([[
            yyxk:DoMP(]] .. tostring(delta) .. [[, false)
    ]])

    return self:RemoteCall(command)
end

-- 设置技能点
function DBGAPI:SetSkillPoints(amount)
    amount = math.floor(tonumber(amount) or 0)
    ThePlayer.replica.yyxk.skillspoint = amount

    amount = tostring(amount)

    local command = BuildLocalYyxkCommand(
        "local amount = " .. amount .. [[

if player.replica ~= nil and player.replica.yyxk ~= nil then
    player.replica.yyxk.skillspoint = amount
end
    ]])

    return self:RemoteCall(command)
end

-- 设置狐心等级
function DBGAPI:SetHuxinLevel(level)
    level = tostring(math.clamp(math.floor(tonumber(level) or 0), 0, 100))

    local command = BuildLocalYyxkCommand(
        "local level = " .. level .. [[

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
    local command = BuildLocalYyxkCommand([[
local group = ]] .. string.format("%q", group) .. [[
local key = ]] .. string.format("%q", key) .. [[
local skills = yyxk[group]
if type(skills) == "table" and skills[key] ~= nil then
    skills[key] = ]] .. (target_enabled and "true" or "false") .. [[
end
    ]] .. STATUS_SYNC_BODY)

    return self:RemoteCall(command)
end

return DBGAPI
