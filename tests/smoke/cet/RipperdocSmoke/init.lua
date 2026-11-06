-- CET smoke test. Pass: this mod's log (red4ext/plugins/cyber_engine_tweaks/mods/RipperdocSmoke/RipperdocSmoke.log)
-- has "init ok", then, after a save is loaded, "player level N". Remove the folder after testing.
local reported = false

registerForEvent("onInit", function()
    print("[RipperdocSmoke] init ok (CET " .. GetVersion() .. ")")
end)

registerForEvent("onUpdate", function()
    if reported then
        return
    end
    local player = Game.GetPlayer()
    if player == nil then
        return
    end
    local stats = Game.GetStatsSystem()
    local level = stats:GetStatValue(player:GetEntityID(), gamedataStatType.Level)
    print("[RipperdocSmoke] player level " .. tostring(level))
    reported = true
end)
