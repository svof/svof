if svo.gag_list then deleteLine() end

local vialid = tonumber(matches[2])
local potion = matches[3]
local sips = tonumber(matches[4])
local months = tonumber(matches[5]) or "arty"
local category = svo.es_categories[potion] or "unknown"

svo.es_vials = svo.es_vials or {}
svo.es_vials[vialid] = {months = months, potion = potion, sips = sips}
svo.es_potions[category] = svo.es_potions[category] or {}
svo.es_potions[category][potion] = svo.es_potions[category][potion] or {sips = 0, vials = 0, decays = 0}
svo.es_potions[category][potion].sips = svo.es_potions[category][potion].sips + sips
svo.es_potions[category][potion].vials = svo.es_potions[category][potion].vials + 1

svo.es_vialids = svo.es_vialids or {}
if svo.es_shortnamesr[potion] then
  svo.es_vialids[svo.es_shortnamesr[potion]] = svo.es_vialids[svo.es_shortnamesr[potion]] or {}
  svo.es_vialids[svo.es_shortnamesr[potion]][#svo.es_vialids[svo.es_shortnamesr[potion]]+1] = vialid
end

if type(months) == "number" and months <= svo.conf.decaytime then
  svo.es_potions[category][potion].decays = svo.es_potions[category][potion].decays + 1
end

svo.es_knownstuff[potion] = svo.es_knownstuff[potion] or 2

-- deal with obfuscated vials now
if not line:find("Obfuscated") then return end

if sips <= svo.conf.obfsips then
  svo.doaddfree(string.format("put %s in %s", vialid, svo.conf.obfcontainer))
  svo.storedvials = svo.storedvials or {}
  svo.storedvials[vialid] = true
end