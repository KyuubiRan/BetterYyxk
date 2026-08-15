local LibKxyyConfig = require("libkxyy_config")
local ElementData = require("libkxyy_element_data")

local UI_STATE_NAME = "element_queue"
local DEFAULT_NEW_ELEMENT = "wind"
local MODE_TARGET = "target"
local MODE_GLOBAL = "global"

local function MakeTargetCursorMap()
    return setmetatable({}, { __mode = "k" })
end

local ElementQueue = {
    MODE_TARGET = MODE_TARGET,
    MODE_GLOBAL = MODE_GLOBAL,
    MODE_OPTIONS = {
        { text = "目标模式", data = MODE_TARGET },
        { text = "全局模式", data = MODE_GLOBAL },
    },
    state = nil,
    enabled = false,
    cursor = 1,
    target_cursors = MakeTargetCursorMap(),
    listeners = {},
    player = nil,
    api = nil,
}

local function PackArgs(...)
    return {
        n = select("#", ...),
        ...,
    }
end

local function CopyElements(elements)
    local copied = {}
    if type(elements) ~= "table" then
        return copied
    end

    for _, key in ipairs(elements) do
        if ElementData:IsValid(key) then
            copied[#copied + 1] = key
        end
    end

    return copied
end

local function TrimName(name)
    if type(name) ~= "string" then
        return nil
    end

    name = string.match(name, "^%s*(.-)%s*$")
    return name ~= "" and name or nil
end

local function MakeDefaultState()
    return {
        version = 1,
        next_id = 1,
        current_id = nil,
        presets = {},
    }
end

local function NormalizeState(raw)
    if type(raw) ~= "table" or type(raw.presets) ~= "table" then
        return MakeDefaultState()
    end

    local normalized = {
        version = 1,
        next_id = 1,
        current_id = nil,
        presets = {},
    }
    local used_ids = {}
    local highest_id = 0

    for _, raw_preset in ipairs(raw.presets) do
        if type(raw_preset) == "table" then
            local id = math.floor(tonumber(raw_preset.id) or 0)
            if id <= 0 or used_ids[id] then
                id = highest_id + 1
                while used_ids[id] do
                    id = id + 1
                end
            end

            used_ids[id] = true
            highest_id = math.max(highest_id, id)
            normalized.presets[#normalized.presets + 1] = {
                id = id,
                name = TrimName(raw_preset.name) or ("队列" .. tostring(#normalized.presets + 1)),
                elements = CopyElements(raw_preset.elements),
            }
        end
    end

    local requested_current_id = math.floor(tonumber(raw.current_id) or 0)
    for _, preset in ipairs(normalized.presets) do
        if preset.id == requested_current_id then
            normalized.current_id = preset.id
            break
        end
    end

    if normalized.current_id == nil and normalized.presets[1] ~= nil then
        normalized.current_id = normalized.presets[1].id
    end

    normalized.next_id = math.max(math.floor(tonumber(raw.next_id) or 1), highest_id + 1, 1)
    return normalized
end

function ElementQueue:EnsureState()
    if self.state == nil then
        self.state = MakeDefaultState()
    end

    return self.state
end

function ElementQueue:Load()
    self.state = NormalizeState(LibKxyyConfig:GetUIState(UI_STATE_NAME))
    self:ResetCursors()
    self:NotifyListeners()
end

function ElementQueue:Save()
    LibKxyyConfig:SaveUIState(UI_STATE_NAME, self:EnsureState())
end

function ElementQueue:AddListener(listener)
    if listener ~= nil then
        self.listeners[listener] = true
    end

    return listener
end

function ElementQueue:RemoveListener(listener)
    if listener ~= nil then
        self.listeners[listener] = nil
    end
end

function ElementQueue:NotifyListeners()
    for listener in pairs(self.listeners) do
        listener(self)
    end
end

function ElementQueue:GetPresets()
    return self:EnsureState().presets
end

function ElementQueue:GetPresetById(id)
    for index, preset in ipairs(self:GetPresets()) do
        if preset.id == id then
            return preset, index
        end
    end
end

function ElementQueue:GetCurrentPreset()
    return self:GetPresetById(self:EnsureState().current_id)
end

function ElementQueue:SelectPreset(id, save)
    local preset = self:GetPresetById(id)
    if preset == nil then
        return false
    end

    self.state.current_id = preset.id
    self:ResetCursors()
    if save ~= false then
        self:Save()
    end
    self:NotifyListeners()
    return true
end

function ElementQueue:AddPreset()
    local state = self:EnsureState()
    local id = state.next_id
    state.next_id = id + 1

    local preset = {
        id = id,
        name = "队列" .. tostring(#state.presets + 1),
        elements = {},
    }
    state.presets[#state.presets + 1] = preset
    state.current_id = id
    self:ResetCursors()
    self:Save()
    self:NotifyListeners()
    return preset
end

function ElementQueue:RemovePreset(id)
    local state = self:EnsureState()
    local _, index = self:GetPresetById(id)
    if index == nil then
        return false
    end

    local removed_current = state.current_id == id
    table.remove(state.presets, index)
    if removed_current then
        local next_preset = state.presets[index] or state.presets[index - 1]
        state.current_id = next_preset ~= nil and next_preset.id or nil
        self:ResetCursors()
    end

    self:Save()
    self:NotifyListeners()
    return true
end

function ElementQueue:RenamePreset(id, name)
    local preset = self:GetPresetById(id)
    if preset == nil then
        return nil
    end

    local normalized_name = TrimName(name) or preset.name
    if normalized_name ~= preset.name then
        preset.name = normalized_name
        self:Save()
        self:NotifyListeners()
    end

    return preset.name
end

function ElementQueue:SelectRelativePreset(direction, api)
    local presets = self:GetPresets()
    if #presets == 0 then
        if api ~= nil then
            api:Say("没有元素队列")
        end
        return false
    end

    local _, index = self:GetCurrentPreset()
    index = index or 1
    direction = tonumber(direction) or 0
    index = ((index - 1 + direction) % #presets) + 1
    self:SelectPreset(presets[index].id)
    if api ~= nil then
        api:Say("切换元素队列: " .. presets[index].name)
    end
    return true
end

function ElementQueue:AddElement(key)
    local preset = self:GetCurrentPreset()
    key = ElementData:IsValid(key) and key or DEFAULT_NEW_ELEMENT
    if preset == nil then
        return false
    end

    preset.elements[#preset.elements + 1] = key
    self:ResetCursors()
    self:Save()
    self:NotifyListeners()
    return true
end

function ElementQueue:RemoveElement(index)
    local preset = self:GetCurrentPreset()
    if preset == nil or preset.elements[index] == nil then
        return false
    end

    table.remove(preset.elements, index)
    self:ResetCursors()
    self:Save()
    self:NotifyListeners()
    return true
end

function ElementQueue:SetElement(index, key)
    local preset = self:GetCurrentPreset()
    if preset == nil or preset.elements[index] == nil or not ElementData:IsValid(key) then
        return false
    end

    if preset.elements[index] == key then
        return true
    end

    preset.elements[index] = key
    self:ResetCursors()
    self:Save()
    self:NotifyListeners()
    return true
end

function ElementQueue:StepElement(index, direction)
    local preset = self:GetCurrentPreset()
    if preset == nil or preset.elements[index] == nil then
        return false
    end

    return self:SetElement(index, ElementData:Step(preset.elements[index], direction))
end

function ElementQueue:MoveElement(index, direction)
    local preset = self:GetCurrentPreset()
    local destination = index + direction
    if preset == nil
        or preset.elements[index] == nil
        or preset.elements[destination] == nil then
        return false
    end

    preset.elements[index], preset.elements[destination] = preset.elements[destination], preset.elements[index]
    self:ResetCursors()
    self:Save()
    self:NotifyListeners()
    return true
end

function ElementQueue:IsEnabled()
    return self.enabled == true
end

function ElementQueue:ResetCursors()
    self.cursor = 1
    self.target_cursors = MakeTargetCursorMap()
end

function ElementQueue:Toggle(api)
    if self.enabled then
        self.enabled = false
        self:ResetCursors()
        if api ~= nil then
            api:Say("空心元素队列: 关闭")
        end
        self:NotifyListeners()
        return false
    end

    local preset = self:GetCurrentPreset()
    if preset == nil or #preset.elements == 0 then
        if api ~= nil then
            api:Say("当前元素队列为空")
        end
        return false
    end

    self.enabled = true
    self:ResetCursors()
    if api ~= nil then
        api:Say("空心元素队列: 开启")
    end
    self:NotifyListeners()
    return true
end

function ElementQueue:ResetRuntime()
    self.enabled = false
    self:ResetCursors()
    self.player = nil
    self.api = nil
    self:NotifyListeners()
end

function ElementQueue:TryPrepareAttack(buffered_action)
    local inst = self.player
    local api = self.api
    if not self.enabled
        or inst == nil
        or inst ~= ThePlayer
        or api == nil
        or buffered_action == nil
        or buffered_action.doer ~= inst
        or buffered_action.action ~= ACTIONS.ATTACK
        or buffered_action.target == nil
        or buffered_action.target.IsValid == nil
        or not buffered_action.target:IsValid()
        or not api:IsNilxin()
        or not api:IsStaffEquipped() then
        return false
    end

    local preset = self:GetCurrentPreset()
    if preset == nil or #preset.elements == 0 then
        return false
    end

    local target = buffered_action.target
    local mode = LibKxyyConfig:Get("nilxin_element_queue_mode", MODE_TARGET)
    local cursor = mode == MODE_GLOBAL and self.cursor or self.target_cursors[target]
    if cursor == nil or cursor < 1 or cursor > #preset.elements then
        cursor = 1
    end

    local key = preset.elements[cursor]
    if not ElementData:IsValid(key) or not api:SetSkill(key) then
        return false
    end

    local next_cursor = cursor % #preset.elements + 1
    if mode == MODE_GLOBAL then
        self.cursor = next_cursor
    else
        self.target_cursors[target] = next_cursor
    end
    return true
end

-- 主机、预测客户端和无预测客户端的普通攻击入口不同，分别在各自
-- 真正执行或发送攻击请求前设置元素，避免无目标按键推进队列。
function ElementQueue:InstallMasterAttackHook(inst)
    if inst._libkxyy_element_queue_original_perform_buffered_action ~= nil
        or inst.PerformBufferedAction == nil then
        return
    end

    local original = inst.PerformBufferedAction
    inst._libkxyy_element_queue_original_perform_buffered_action = original
    inst.PerformBufferedAction = function(inst_self, ...)
        ElementQueue:TryPrepareAttack(inst_self.bufferedaction)
        return original(inst_self, ...)
    end
end

function ElementQueue:InstallPredictingClientAttackHook(controller)
    if controller._libkxyy_element_queue_original_remote_buffered_action ~= nil
        or controller.RemoteBufferedAction == nil then
        return
    end

    local original = controller.RemoteBufferedAction
    controller._libkxyy_element_queue_original_remote_buffered_action = original
    controller.RemoteBufferedAction = function(controller_self, buffered_action, ...)
        if controller_self.classified ~= nil
            and controller_self.classified.iscontrollerenabled ~= nil
            and controller_self.classified.iscontrollerenabled:value() then
            ElementQueue:TryPrepareAttack(buffered_action)
        end
        return original(controller_self, buffered_action, ...)
    end
end

function ElementQueue:InstallNonPredictingClientAttackHooks(controller)
    if controller._libkxyy_element_queue_original_remote_attack_button == nil
        and controller.RemoteAttackButton ~= nil then
        local original_remote_attack = controller.RemoteAttackButton
        controller._libkxyy_element_queue_original_remote_attack_button = original_remote_attack
        controller.RemoteAttackButton = function(controller_self, target, force_attack, is_left_mouse, is_released, ...)
            if target ~= nil and not is_released then
                ElementQueue:TryPrepareAttack({
                    doer = controller_self.inst,
                    target = target,
                    action = ACTIONS.ATTACK,
                })
            end
            return original_remote_attack(
                controller_self,
                target,
                force_attack,
                is_left_mouse,
                is_released,
                ...
            )
        end
    end

    if controller._libkxyy_element_queue_original_do_action_auto_equip == nil
        and controller.DoActionAutoEquip ~= nil then
        local original_auto_equip = controller.DoActionAutoEquip
        controller._libkxyy_element_queue_original_do_action_auto_equip = original_auto_equip
        controller.DoActionAutoEquip = function(controller_self, buffered_action, ...)
            local results = PackArgs(original_auto_equip(controller_self, buffered_action, ...))
            ElementQueue:TryPrepareAttack(buffered_action)
            return unpack(results, 1, results.n)
        end
    end
end

function ElementQueue:Attach(inst, api)
    if inst == nil or api == nil then
        return false
    end

    local controller = inst.components ~= nil and inst.components.playercontroller or nil
    if controller == nil or controller.DoActionAutoEquip == nil then
        return false
    end

    self.player = inst
    self.api = api

    if controller.ismastersim then
        self:InstallMasterAttackHook(inst)
    elseif controller.locomotor ~= nil then
        self:InstallPredictingClientAttackHook(controller)
    else
        self:InstallNonPredictingClientAttackHooks(controller)
    end

    return true
end

return ElementQueue
