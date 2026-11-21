--[[ Iocuns prompt aff thingy from http://forums.achaea.com/index.php?showtopic=39543&view=findpost&p=1283964, taken with permission ]]
--[[ to use in a custom prompt, use the @paracelsus_affs_customtag tag ]]
--[[ this is now used by default in Svo ]]
-- an affliction's tag is its dictionary entry's prompttag, or its name when
-- the entry has none
local function aff_tag(name)
  local entry = svo.dict[name]
  return entry and entry.prompttag or name
end

-- recoded, it's quicker by a third
function paracelsus_affs_customtag2()
  if next(svo.affl) then
    local s, type = {}, type
    for k,v in pairs(svo.affl) do
        if (k == "unknownany" or k == "unknownmental") and (type(v) == 'table') then
          s[#s+1] = ("?"):rep(v.count)
        elseif k == "bleeding" and type(v) == 'table' then
          if v.count >= svo.conf.bleedamount then
            s[#s+1] = string.format("bld(%d)", v.count)
          end
       elseif k == "lovers" and type(v) == 'table' then
          s[#s+1] = string.format("lust(%s)", svo.oneconcat(svo.affl.lovers.names))
        elseif type(v) == 'table' and v.count then
          s[#s+1] = aff_tag(k)..'('..v.count..')'
        else
          s[#s+1] = aff_tag(k)
        end
    end
    return #s > 0 and ("<IndianRed>["..table.concat(s, " ").."]") or "" -- don't display just [] b/c of bleeding
  else
    return ""
  end
end

registerAnonymousEventHandler("svo system loaded", function()
  svo.adddefinition("@paracelsus_affs_customtag", "paracelsus_affs_customtag2()")
  svo.adddefinition("@affs", "paracelsus_affs_customtag2()")
  
  svo.adddefinition("@target", "target")
end)