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
    MagicOption("YYXK_OPALPRECIOUSGEM", "魔力引导"),
    MagicOption("YYXK_COOKBOOK", "批量烹饪"),
    MagicOption("YYXK_FISHINGROD", "捕鱼魔法"),
    MagicOption("YYXK_PITCHFORK", "填海造陆"),
    MagicOption("YYXK_ORANGEGEM", "坐标之力"),
    MagicOption("YYXK_BLUEGEM", "返鲜魔法"),
    MagicOption("YYXK_GREENGEM", "腐败之云"),
    MagicOption("YYXK_NILXIN_CYANGEM", "启迪牢笼"),
    MagicOption("YYXK_NILXIN_GREYGEM", "时间变异"),
    MagicOption("NILXIN_FOXBALL_BLUE", "物品重组"),
    MagicOption("NILXIN_FOXBALL_RED", "物品分解"),
}

return MAGIC_OPTIONS
