-- The module priority this group used to set on install has no meaning in a
-- single package: load order comes from where these items sit in the tree.

svo = svo or {}; svo.loader = svo.loader or {}
function svo.buildwhosummary()
  local time = createStopWatch(); startStopWatch(time)
  local areas = {}

  local pdb, getnums, getRoomArea, areatabler = mmp.pdb, mmp.getnums, getRoomArea, mmp.areatabler
  for name in pairs(mmp.pdb_lastupdate) do
    local room = pdb[name]
    local roomids = getnums(room, true)

    if not roomids then
      areas["unknown area"] = areas["unknown area"] or {}
      areas["unknown area"][room] = areas["unknown area"][room] or {}
      areas["unknown area"][room][#areas["unknown area"][room]+1] = name
    elseif #roomids == 1 then
      local area = areatabler[getRoomArea(roomids[1])] or "unknown area"
      areas[area] = areas[area] or {}
      areas[area][room] = areas[area][room] or {}
      areas[area][room][#areas[area][room]+1] = name
    else
      local singlearea = mmp.areatabler[getRoomArea(roomids[1])] or '?'

      local inexact
      for i = 1, #roomids do
        if singlearea ~= mmp.areatabler[getRoomArea(roomids[i])] then
          areas["uncertain area"] = areas["uncertain area"] or {}
          areas["uncertain area"][room] = areas["uncertain area"][room] or {}
          areas["uncertain area"][room][#areas["uncertain area"][room]+1] = name
          inexact = true
          break
        end
      end

      if not inexact then
        areas[singlearea] = areas[singlearea] or {}
        areas[singlearea][room] = areas[singlearea][room] or {}
        areas[singlearea][room][#areas[singlearea][room]+1] = name
      end
    end
  end

  local sortedareas = {}
  for area in pairs(areas) do sortedareas[#sortedareas+1] = area end
  table.sort(sortedareas)

  svo.qwhoareas, svo.qwhosortedareas = areas, sortedareas

  if not svo.showqwho then return end
  if svo.qwhofilter then svo.qwhofilter = svo.qwhofilter:lower() end

  if #sortedareas == 0 then svo.echof("Didn't pick anyone up on the who list - it was empty.") return end

  local cecho, sformat, concatand, concatandf = cecho, string.format, svo.concatand, svo.concatandf

  -- wraps the name so people after a <reset> are still white
  local function wrapname(name)
    return "<white>"..ndb.getcolorn(name).."<reset>"
  end

  local function rendergeneral()
    svo.echof("%s ungemmed people are visible:", table.size(mmp.pdb_lastupdate))
    for i = 1, #sortedareas do
      if not svo.qwhofilter or sortedareas[i]:lower():find(svo.qwhofilter, 1, true) then
        cecho(sformat(" <CadetBlue>in %s:\n", sortedareas[i]))
        for room, people in pairs(areas[sortedareas[i]]) do
          table.sort(people)
          cecho(sformat("   in %s: <white>%s <DarkSlateGray>(%d %s)\n", room, concatandf(people, wrapname), #people, (#people == 1 and "person" or "people")))
        end
      end
    end
  end

  local function rendergroups()
    svo.echof("%s ungemmed people are visible, showing groups only:", table.size(mmp.pdb_lastupdate))
    for i = 1, #sortedareas do
      if not svo.qwhofilter or sortedareas[i]:lower():find(svo.qwhofilter, 1, true) then
        local showedarea
        for room, people in pairs(areas[sortedareas[i]]) do
          if #people > 1 then
            if not showedarea then cecho(sformat(" <CadetBlue>in %s:\n", sortedareas[i])) showedarea = true end
            table.sort(people)
            cecho(sformat("   in %s: <white>%s <DarkSlateGray>(%d %s)\n", room, concatandf(people, wrapname), #people, (#people == 1 and "person" or "people")))
          end
        end
      end
    end
  end

  local function renderwatchfor()
    -- make an indexed list
    local watchfor = {}; for name in pairs(svo.me.watchfor) do watchfor[#watchfor+1] = name end

    svo.echof("%s ungemmed people are visible, showing watchfor names only:", table.size(mmp.pdb_lastupdate))
    for i = 1, #sortedareas do
      if not svo.qwhofilter or sortedareas[i]:lower():find(svo.qwhofilter, 1, true) then
        local showedarea
        for room, people in pairs(areas[sortedareas[i]]) do
          local intersection = table.n_intersection(watchfor, people)
          if #intersection > 0 then
            if not showedarea then cecho(sformat(" <CadetBlue>in %s:\n", sortedareas[i])) showedarea = true end
            table.sort(people)
            cecho(sformat("   in %s: <white>%s <DarkSlateGray>(%d %s)\n", room, concatandf(people, wrapname), #people, (#people == 1 and "person" or "people")))
          end
        end
      end
    end
  end

  if svo.showqwho == 'g' then
    rendergroups()
  elseif svo.showqwho == 'w' then
    if not svo.me.watchfor or not next(svo.me.watchfor) then svo.echof("You don't have anyone on the watchfor list - do vconfig watchfor <person> to add someone first.") return
    else renderwatchfor() end
  else
    rendergeneral()
  end

  svo.showqwho = nil
  if svo.conf.debug and not s then display(m) end
  if svo.conf.perf then svo.echof("qwho rendered in %ss", stopStopWatch(time)) end
end
