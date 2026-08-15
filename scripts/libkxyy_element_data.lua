local ELEMENTS = {
    { key = "water", label = "水" },
    { key = "ice", label = "冰" },
    { key = "fire", label = "火" },
    { key = "lightning", label = "电" },
    { key = "wind", label = "风" },
    { key = "space", label = "空" },
    { key = "moon", label = "月" },
    { key = "shadow", label = "暗" },
}

local ElementData = {
    ELEMENTS = ELEMENTS,
    BY_KEY = {},
    LABELS = {},
    INDEX_BY_KEY = {},
}

for index, element in ipairs(ELEMENTS) do
    ElementData.BY_KEY[element.key] = element
    ElementData.LABELS[element.key] = element.label
    ElementData.INDEX_BY_KEY[element.key] = index
end

function ElementData:IsValid(key)
    return self.BY_KEY[key] ~= nil
end

function ElementData:GetLabel(key)
    local element = self.BY_KEY[key]
    return element ~= nil and element.label or tostring(key or "")
end

function ElementData:Step(key, direction)
    local count = #self.ELEMENTS
    if count == 0 then
        return nil
    end

    local index = self.INDEX_BY_KEY[key] or 1
    index = ((index - 1 + (direction or 0)) % count) + 1
    return self.ELEMENTS[index].key
end

return ElementData
