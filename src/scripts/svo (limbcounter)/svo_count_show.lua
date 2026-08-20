svo.lc_counttable = svo.lc_counttable or {
	Runewarden = {
		["Two Handed"] = {
			[1] = {0, 1200},
			[2] = {1201, 1800},
			[3] = {1900, 2400},
			[4] = {2400, 3093},
			[5] = {3888, 4900},
			[6] = {4906, 6246},
			[7] = {6325, 7775},
			[8] = {8030, 9000},
			[9] = {9001, 10000},
			[10] = {10001, 11001}
		},
		["Dual Cutting"] = {
			[1] = {0, 1200},
			[2] = {1201, 1800},
			[3] = {1900, 2400},
			[4] = {2400, 3093},
			[5] = {3888, 4900},
			[6] = {4906, 6246},
			[7] = {6325, 7775},
			[8] = {8030, 9000},
			[9] = {9001, 10000},
			[10] = {10001, 11001}
		},
		["Dual Blunt"] = {
			[1] = {0, 1200},
			[2] = {1201, 1800},
			[3] = {1900, 2400},
			[4] = {2400, 3093},
			[5] = {3888, 4900},
			[6] = {4906, 6246},
			[7] = {6325, 7775},
			[8] = {8030, 9000},
			[9] = {9001, 10000},
			[10] = {10001, 11001}
		}
	}
}



svo.lc_changetable = svo.lc_changetable or {}
svo.lc_changeold = svo.lc_changeold or 0
svo.lc_changenew = svo.lc_changenew or 0
svo.lc_changing = svo.lc_changing or ""

function svo.lc_countshow()
  local classcounter = {}
  if svo.defc.dragonform then
    return
  end
  for _, v in pairs(svo.lc_classlist) do
    if svo.me.class ~= v then
      table.insert(classcounter, v)
    end
  end
	setFgColor(unpack(svo.getDefaultColorNums))
	echo("\n")
	svo.echof("Limbcounter Count")
	echo("\n")
	if table.contains({"Runewarden", "Infernal", "Paladin"}, svo.lc_myclass) then
		svo.lc_countshowknight()
	else
	end
	echo("\n")
end

function svo.lc_countshowknight()
	local spec = string.match(gmcp.Char.Vitals.charstats[3], "Spec: (.*)")
	local counts = svo.lc_counttable[svo.me.class][spec]
	setFgColor(unpack(svo.getDefaultColorNums))
	echo("---- ")
	cecho("<goldenrod>"..svo.me.class..": "..spec)
	setFgColor(unpack(svo.getDefaultColorNums))
	echo(" "..string.rep("-", 53))
	echo("\n|"..string.format("%79s", " ").."|\n|")
	for k, v in ipairs(svo.lc_counttable[svo.me.class][spec]) do
		local last = table.size(svo.lc_counttable[svo.me.class][spec])
		local position = k
		if k ~= last and (k == 3 or k == 6 or k == 9 or k == 12 or k == 15 or k == 18 or k == 21) then
  		echo(""..string.format("%3s", " ")..""..string.format("%1s", "["..string.format("%2s", k).."] - ["))
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][1]).."", [[svo.lc_changestart(]]..position..[[, "first")]], "Change beginning value", true)
    	echo(" - ")
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][2]).."", [[svo.lc_changestart(]]..position..[[, "second")]], "Change end value", true)
    	echo("] "..string.format("%3s", " ").."|\n|")
		elseif k == last and (k == 3 or k == 6 or k == 9 or k == 12 or k == 15 or k == 18 or k == 21) then
  		echo(""..string.format("%3s", " ")..""..string.format("%1s", "["..string.format("%2s", k).."] - ["))
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][1]).."", [[svo.lc_changestart(]]..position..[[, "first")]], "Change beginning value", true)
    	echo(" - ")
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][2]).."", [[svo.lc_changestart(]]..position..[[, "second")]], "Change end value", true)
    	echo("] "..string.format("%3s", " ").."|")
		elseif k == last and (k == 2 or k == 5 or k == 8 or k == 11 or k == 14 or k == 17 or k == 20) then
			echo(""..string.format("%3s", " ")..""..string.format("%1s", "["..string.format("%2s", k).."] - ["))
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][1]).."", [[svo.lc_changestart(]]..position..[[, "first")]], "Change beginning value", true)
    	echo(" - ")
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][2]).."", [[svo.lc_changestart(]]..position..[[, "second")]], "Change end value", true)
    	echo("] "..string.format("%28s", " ").."|")
		elseif k == last and (k == 1 or k == 4 or k == 7 or k == 10 or k == 13 or k == 16 or k == 19) then
			echo(""..string.format("%3s", " ")..""..string.format("%1s", "["..string.format("%2s", k).."] - ["))
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][1]).."", [[svo.lc_changestart(]]..position..[[, "first")]], "Change beginning value", true)
    	echo(" - ")
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][2]).."", [[svo.lc_changestart(]]..position..[[, "second")]], "Change end value", true)
    	echo("] "..string.format("%53s", " ").."|")
		else
			echo(""..string.format("%3s", " ")..""..string.format("%1s", "["..string.format("%2s", k).."] - ["))
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][1]).."", [[svo.lc_changestart(]]..position..[[, "first")]], "Change beginning value", true)
    	echo(" - ")
    	echoLink(""..string.format("%5s", svo.lc_counttable[svo.me.class][spec][k][2]).."", [[svo.lc_changestart(]]..position..[[, "second")]], "Change end value", true)
    	echo("]")
		end
	end
	echo("\n|"..string.format("%79s", " ").."|")
	echo("\n|"..string.format("%5s", " "))
	cechoLink("<green>+", [[svo.lc_addcount()]], "Add Count", true)
	setFgColor(unpack(svo.getDefaultColorNums))
	echo(" Add a count, ")
	cechoLink("<red>-", [[svo.lc_deletecount()]], "Delete Count", true)
	setFgColor(unpack(svo.getDefaultColorNums))
	echo(" Delete a count")
	echo(""..string.format("%43s", " ").."|")
	echo("\n"..string.rep("-", 81))
end

function svo.lc_changestart(position, from)
	echo("\n")
	svo.echof("Change Value to What?")
	printCmdLine("vconfig changelimbcount ")
	svo.lc_changing = from
	if table.contains({"Runewarden", "Infernal", "Paladin"}, svo.lc_myclass) then
  	local spec = string.match(gmcp.Char.Vitals.charstats[3], "Spec: (.*)")
		if from == "first" then
			svo.lc_changeold = svo.lc_counttable[svo.me.class][spec][position][1]
		elseif from == "second" then
			svo.lc_changeold = svo.lc_counttable[svo.me.class][spec][position][2]
		end
	end
	svo.lc_changeposition = position
	svo.lc_changenew = to
end

function svo.lc_changeend(new)
	if table.contains({"Runewarden", "Infernal", "Paladin"}, svo.lc_myclass) then
  	local spec = string.match(gmcp.Char.Vitals.charstats[3], "Spec: (.*)")
		if svo.lc_changing == "first" then
  		svo.lc_counttable[svo.me.class][spec][svo.lc_changeposition][1] = new
		elseif svo.lc_changing == "second" then
			svo.lc_counttable[svo.me.class][spec][svo.lc_changeposition][2] = new
		end
	end
	svo.lc_countshow()
end

function svo.lc_addcount()
	local spec = string.match(gmcp.Char.Vitals.charstats[3], "Spec: (.*)")
	local counts = svo.lc_counttable[svo.me.class][spec]
	local last = table.size(svo.lc_counttable[svo.me.class][spec])
	local new = last + 1
	svo.lc_counttable[svo.me.class][spec][new] = {0, 0}
	svo.lc_countshow()
end

function svo.lc_deletecount()
	local spec = string.match(gmcp.Char.Vitals.charstats[3], "Spec: (.*)")
	local counts = svo.lc_counttable[svo.me.class][spec]
	local remove = table.size(svo.lc_counttable[svo.me.class][spec])
	svo.lc_counttable[svo.me.class][spec][remove] = nil
	svo.lc_countshow()
end

svo.config.setoption(
  "changelimbcount",
  {
    type = "number",
    onset =
      function()
        svo.echof(
          "Setting the old value %s to the new value %s",
          svo.lc_changeold, svo.conf.changelimbcount
        )
				svo.lc_changeend(svo.conf.changelimbcount)
      end,
  }
)