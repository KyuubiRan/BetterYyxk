local Data = {
    AUTO_REPAIR_INTERVAL = 3,
    COMBAT_GRACE_PERIOD = 6,
    REPAIR_CONFIRM_TIMEOUT = 2,

    SCOPE_INVENTORY = "inventory",
    SCOPE_UMBRELLA = "umbrella",
    SCOPE_ALL = "all",
}

Data.SCOPE_OPTIONS = {
    { text = "仅物品栏", data = Data.SCOPE_INVENTORY },
    { text = "仅伞护内", data = Data.SCOPE_UMBRELLA },
    { text = "全部", data = Data.SCOPE_ALL },
}

Data.GEMS = {
    { prefab = "redgem", label = "红宝石", default_priority = 100 },
    { prefab = "bluegem", label = "蓝宝石", default_priority = 100 },
    { prefab = "orangegem", label = "橙宝石", default_priority = 0 },
    { prefab = "yellowgem", label = "黄宝石", default_priority = 0 },
    { prefab = "greengem", label = "绿宝石", default_priority = 0 },
    { prefab = "purplegem", label = "紫宝石", default_priority = 0 },
    { prefab = "opalpreciousgem", label = "彩虹宝石", default_priority = 0 },
    { prefab = "nilxin_cyangem", label = "青宝石", default_priority = 0 },
    { prefab = "nilxin_greygem", label = "灰宝石", default_priority = 0 },
}

Data.GEM_MAP = {}
for _, gem in ipairs(Data.GEMS) do
    Data.GEM_MAP[gem.prefab] = gem
end

function Data.GetPriorityConfigName(prefab)
    return "umbrella_repair_priority_" .. prefab
end

return Data
