local DBGAPI = {
    status = {
        inf_mana = false,
    },
    listeners = {},
}

local DEBUG_STATUS_CLIENT_FN = "__LibKxyyDebugStatus"

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

local function BuildDebugCommand(player_expr, body)
    return [[
        local player = ]] .. player_expr .. [[
        if player ~= nil
            and player.components ~= nil
            and player.components.yyxk ~= nil then
            local yyxk = player.components.yyxk
            if yyxk.__DebugApi == nil then
                yyxk.__DebugApi = {
                    inf_mana = false,
                    old_DoMP = yyxk.DoMP,
                }
            elseif yyxk.__DebugApi.old_DoMP == nil then
                yyxk.__DebugApi.old_DoMP = yyxk.DoMP
            end
            local debug_api = yyxk.__DebugApi
    ]] .. body .. [[
            if yyxk.ToClient ~= nil then
                yyxk:ToClient("]] .. DEBUG_STATUS_CLIENT_FN .. [[", debug_api.inf_mana == true)
            end
        end
    ]]
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
        replica[DEBUG_STATUS_CLIENT_FN] = function(_, inf_mana)
            self:ApplyStatus({
                inf_mana = inf_mana == true,
            })
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

    NotifyListeners(self.status)
end

function DBGAPI:GetStatus()
    return self.status
end

function DBGAPI:SyncStatus()
    return self:RemoteCall(BuildDebugCommand(GetPlayerCommandString(), ""))
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

    local command = [[
        local player = ]] .. GetPlayerCommandString() .. [[
        if player ~= nil
            and player.components ~= nil
            and player.components.yyxk ~= nil then
            player.components.yyxk:DoMP(]] .. tostring(delta) .. [[, false)
        end
    ]]

    return self:RemoteCall(command)
end

-- 切换无限魔力
function DBGAPI:ToggleInfMana()
    local command = BuildDebugCommand(GetPlayerCommandString(), [[
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
    ]])

    return self:RemoteCall(command)
end

return DBGAPI
