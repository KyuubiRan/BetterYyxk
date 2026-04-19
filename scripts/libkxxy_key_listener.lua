local KeyListener = {
    actions = {},
    down_handlers = {},
    up_handlers = {},
    pressed = {},
    initialized = false,
    settings_open = false,
}

local function RemoveHandler(handler)
    if handler ~= nil then
        handler:Remove()
    end
end

local function NormalizeKey(key)
    if key == nil or key == -1 then
        return nil
    end

    return key
end

function KeyListener:IsHUDActive()
    if TheFrontEnd == nil then
        return false
    end

    local screen = TheFrontEnd:GetActiveScreen()
    return screen ~= nil and screen.name == "HUD"
end

function KeyListener:IsActionBlocked(action)
    if action == nil then
        return true
    end

    if not self:IsHUDActive() then
        return true
    end

    if self.settings_open and not action.allow_when_settings_open then
        return true
    end

    return false
end

function KeyListener:AttachAction(id)
    local action = self.actions[id]
    if action == nil or action.key == nil or TheInput == nil then
        return
    end

    self.down_handlers[id] = TheInput:AddKeyDownHandler(action.key, function()
        self:HandleKeyDown(id)
    end)

    self.up_handlers[id] = TheInput:AddKeyUpHandler(action.key, function()
        self:HandleKeyUp(id)
    end)
end

function KeyListener:DetachAction(id)
    RemoveHandler(self.down_handlers[id])
    RemoveHandler(self.up_handlers[id])
    self.down_handlers[id] = nil
    self.up_handlers[id] = nil
    self.pressed[id] = nil
end

function KeyListener:Init()
    if self.initialized then
        return
    end

    self.initialized = true
end

function KeyListener:RegisterAction(id, data)
    if id == nil or data == nil then
        return
    end

    self:Init()
    self:DetachAction(id)

    self.actions[id] = {
        key = NormalizeKey(data.key),
        on_down = data.on_down,
        on_up = data.on_up,
        allow_when_settings_open = data.allow_when_settings_open == true,
    }

    self:AttachAction(id)
end

function KeyListener:SetActionKey(id, key)
    local action = self.actions[id]
    key = NormalizeKey(key)

    if action == nil or action.key == key then
        return
    end

    self:DetachAction(id)
    action.key = key
    self:AttachAction(id)
end

function KeyListener:SetSettingsOpen(is_open)
    self.settings_open = is_open == true
end

function KeyListener:IsPressed(id)
    return self.pressed[id] == true
end

function KeyListener:HandleKeyDown(id)
    local action = self.actions[id]
    if self:IsActionBlocked(action) or self.pressed[id] then
        return
    end

    self.pressed[id] = true

    if action.on_down ~= nil then
        action.on_down(id, action.key)
    end
end

function KeyListener:HandleKeyUp(id)
    local action = self.actions[id]
    if action == nil then
        return
    end

    local was_pressed = self.pressed[id] == true
    self.pressed[id] = false

    if was_pressed and action.on_up ~= nil then
        action.on_up(id, action.key)
    end
end

return KeyListener
