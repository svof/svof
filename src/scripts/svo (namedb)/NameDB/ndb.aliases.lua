function ndb.showwhois(whom)
  whom = whom:lower():title()
  local data = ndb.getname(whom)

  if not data then svo.echof("I'm afraid we don't know person named %s.", matches[2]:title()) svo.showprompt() return end

  cecho("\n<a_darkblue>--<purple>(svo) <a_grey>"..data.name.."'s ("..data.gender:sub(1,1)..") NameDB profile<a_darkblue>" .. ("-"):rep(55-#data.name) .. "\n")

  local function getclass()
    return (data.class == '' and 'unknown' or data.class)
  end

  local function getxprank()
    return (data.xp_rank == -2 and 'unranked' or (data.xp_rank == -1 and 'unknown' or data.xp_rank))
  end

  local function getmight()
    return (data.might == -1 and 'unranked' or data.might)
  end

  local function getlevel()
    return ((data.level == -1 or data.level == 0 or data.level == nil) and 'unknown' or data.level)
  end

  local function getcombatrank()
    return (data.combat_rank > 0
       and ("%d (rank) %d (score)"):format(data.combat_rank, data.combat_rating)
       or (data.combat_rank == 0 and 'unranked' or 'unknown'))
  end

  local function getdragon()
    return (data.dragon == 1 and 'yep' or 'nope')
  end

  local function getrace()
    return (data.race == '' and 'unknown' or data.race)
  end

  local function getbirthday()
    return ((data.birth_day ~= 0
       and ("%d %s(%d) %d"):format(data.birth_day, ndb.valid.months[data.birth_month], data.birth_month, data.birth_year)
       or '') .. (data.birth_hidden == 1 and ' (h)' or ''))

  end

  local function getimportance()
    return (data.importance == 0 and 'unset' or data.importance)
  end

  local function getinfamous()
    return (data.infamous == -1 and 'unknown' or (data.infamous == 0 and 'none' or ndb.valid.shortinfamous[data.infamous]))
  end

  if data.immortal == 0 then
    cecho("<a_darkcyan>  Orgs:\n")
    cecho(string.format("<a_darkgrey>    House:  %-24s City:        %s (cr%s)%s\n",
      (data.guild == '' and 'unknown' or data.guild),
      (data.city == '' and 'unknown' or data.city),
      (data.city_rank == 0 and '?' or data.city_rank),
      (data.city_soldier == 0 and '' or ' (S)')
    ))

    cecho(string.format("<a_darkgrey>    Order:  %-24s Mark:        %s\n",
      (data.order == '' and 'unknown' or data.order),
      (data.mark == '' and 'no' or data.mark)
    ))

    cecho("\n<a_darkcyan>  Personal:\n")
    cecho(string.format("<a_darkgrey>    Class:  %-24s Infamy:      %s\n",
      getclass(),
      getinfamous()
    ))
    cecho(string.format("<a_darkgrey>    Level:  %-24s XP rank:     %s\n",
      getlevel(),
      getxprank()
    ))
    cecho(string.format("<a_darkgrey>    Might:  %-24s Combat:      %s\n",
      getmight(),
      getcombatrank()
    ))
    cecho(string.format("<a_darkgrey>    Dragon: %-24s Race:        %s\n",
      getdragon(),
      getrace()
    ))
    cecho(string.format("<a_darkgrey>    Birth:  %-24s Importance:  %s\n",
      getbirthday(),
      getimportance()
    ))
    
    cecho("\n<a_darkcyan>  Status to you:\n")
    cecho(string.format("<a_darkgrey>    City enemy:  %-19s House enemy: %s\n",
      (data.cityenemy == 0 and 'nope' or 'yep'),
      (data.houseenemy == 0 and 'nope' or 'yep')
    ))

    cecho(string.format("<a_darkgrey>    Order enemy: %-19s \n",
      data.orderenemy == 0 and 'nope' or 'yep'
    ))

    local currenstatus
    if data.iff == -1 then
      if ndb.isenemy(data.name) then currenstatus = "enemy (auto)"
      else currenstatus = "ally (auto)" end
    end

    cecho(string.format("<a_darkgrey>    Actual status to you: %s\n", 
      (data.iff == -1 and currenstatus or (data.iff == 1 and "enemy (manual)" or "ally (manual)"))
    ))
  else
    cecho("\n<a_darkcyan>    They are an Immortal.\n")
  end

  cecho("\n<a_darkcyan>  Notes (")
  setUnderline(true)
  fg("a_darkcyan")
  echoLink("edit", 'printCmdLine"ndb set '..whom:title()..' notes '..data.notes:gsub("\n", [[\\n]])..'"', 'Click to edit the notes you have on '..whom:title()..' - you can use \\n for a linebreak, and <color> to color text', true)
  resetFormat()
  cecho("<a_darkcyan>):\n")
  cecho(string.format("    <a_blue>- <a_grey>"..((data.notes and data.notes ~= "") and data.notes:gsub("\n", "\n    <a_blue>-<reset> ") or "none yet").."\n"))
  deselect() fg("a_darkblue") echo(string.rep("-", 80)) resetFormat() echo'\n'
  svo.showprompt()
end

function ndb.exportmenu()
  svo.echof("Exporting works in 3 steps:\n")

  setFgColor(unpack(svo.getDefaultColorNums))
  echo("a) select what data about people you'd like to export:\n")
  for key, _ in pairs(ndb.schema.people) do
    echo("  ")

    if key == "name" then
      echoLink("[X] name", [[svo.echof("The name has to stay, otherwise what'll be there to import?")]], "If you'd just like to share the list of names known, you can tick everything else off and leave this on", true)
    else
      echoLink("["..(ndb.exportdata.fields[key] and 'X' or ' ')..'] '..key, 
        [[ndb.exportdata.fields.]]..key..[[ = ]]..tostring(not ndb.exportdata.fields[key])..[[;ndb.exportmenu()]],
        'Click to '..(not ndb.exportdata.fields[key] and 'add' or 'remove') .. ' '..key .. ' for export', true)
    end
    echo("\n")
  end

  echo("\n")
  echo("b) select which people you'd like to export:\n")
  for key, _ in pairs(ndb.exportdata.people) do
    setFgColor(unpack(svo.getDefaultColorNums))
    echo("  ")

    echoLink("["..(ndb.exportdata.people[key] and 'X' or ' ')..'] '..key, 
      [[ndb.exportdata.people.]]..key..[[ = ]]..tostring(not ndb.exportdata.people[key])..[[;ndb.exportmenu()]],
      (ndb.exportdata.people[key] and 'Click to export '..key or 'Click not to export '..key), true)

    echo("\n")
  end

  echo("\n")
  echo("d) select a folder to export to: ")
  setUnderline(true)
  echoLink((not ndb.exportdata.location and "<folder>" or ndb.exportdata.location), [[
    ndb.exportdata.location = invokeFileDialog(false, "Where do you want to save the file? Select it and click Open")
    if ndb.exportdata.location == "" then ndb.exportdata.location = false end
    ndb.exportmenu()]],
    '', true)
  setUnderline(false)
  echo("\n")

  echo("\n")
  svo.echofn("All set? ")

  setUnderline(true)
  setFgColor(unpack(svo.getDefaultColorNums))
  echoLink("Export!", (not ndb.exportdata.location and 'svo.echof("Pick a folder to export to, silly.")' or 'ndb.doexport()'), 'Click to export', true)
  setUnderline(false)
end

function ndb.importmenu()
  svo.echof("Import NameDB data:")

  setFgColor(unpack(svo.getDefaultColorNums))
  echo("\n")
  if not ndb.importdata.location then echo("a) select a file to import: ") else echo("a) file to import: ") end
  setUnderline(true)
  echoLink((not ndb.importdata.location and "<file>" or ndb.importdata.location), [[
    ndb.importdata.location = invokeFileDialog(true, "Pick the file you'd like to import and select Open")
    if ndb.importdata.location == "" then ndb.importdata.location = false end
    if ndb.importdata.location then ndb.getimportfields() end
    ndb.importmenu()]],
    '', true)
  setUnderline(false)
  echo("\n")

  echo("\n")
  if not ndb.importdata.data then
    echo("b) select which fields to import once you've picked a file")
  else
    echo("b) select which fields to import:\n")
    for key, _ in pairs(ndb.importdata.fields) do
      echo("  ")

      if key == "name" then
        echoLink("[X] name", [[svo.echof("The name has to stay, otherwise how will the import data make sense?")]], "The persons name - this has to stay", true)
      else
        echoLink("["..(ndb.importdata.fields[key] and 'X' or ' ')..'] '..key, 
          [[ndb.importdata.fields.]]..key..[[ = ]]..tostring(not ndb.importdata.fields[key])..[[;ndb.importmenu()]],
          'Click to '..(not ndb.importdata.fields[key] and 'add' or 'remove') .. ' '..key .. ' for import', true)
      end
      echo("\n")
    end
  end
  echo("\n")

  echo("\n")
  svo.echofn("All set? ")

  setUnderline(true)
  setFgColor(unpack(svo.getDefaultColorNums))
  echoLink("Import!", (not ndb.importdata.data and 'svo.echof("Pick a file to import first!")' or 'ndb.doimport()'), 'Click to import', true)
  setUnderline(false)
  echo("\n")
end

function ndb.checkqw(suffix, how)
  if ndb.qwtimer then killTimer(ndb.qwtimer) end

  enableTrigger("NameDB qw")
  enableTrigger("NameDB qw 2")
  ndb.qwtimer = tempTimer(3, function() disableTrigger("NameDB qw"); disableTrigger("NameDB qw 2"); ndb.qwtimer = nil end)
  ndb.qwtype = how

  send("qwc", false)
end