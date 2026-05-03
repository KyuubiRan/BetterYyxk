local STAFF_MAGIC_ATLAS = "images/staff_magic.xml"

local function MagicOption(key, label)
    return {
        key = key,
        label = label,
        atlas = STAFF_MAGIC_ATLAS,
        tex = string.lower(key) .. ".tex",
    }
end

local MAGIC_OPTIONS = {
    MagicOption("YYXK_GATHER", "快速采集"),
    MagicOption("YYXK_TOOL", "工具魔法"),
    MagicOption("OPALPRECIOUSGEM", "魔力引导"),
    MagicOption("COOKBOOK", "批量烹饪"),
    MagicOption("FISHINGROD", "捕鱼魔法"),
    MagicOption("PITCHFORK", "填海造陆"),
    MagicOption("ORANGEGEM", "坐标之力"),
    MagicOption("BLUEGEM", "返鲜魔法"),
    MagicOption("GREENGEM", "腐败之云"),
    MagicOption("MOONGLASS", "启迪牢笼"),
    MagicOption("NILXIN_GREYGEM", "时间变异"),
    MagicOption("NILXIN_FOXBALL_BLUE", "物品重组"),
    MagicOption("NILXIN_FOXBALL_RED", "物品分解"),
}

return MAGIC_OPTIONS
