selectString("You glance over ", 1) replace("") deselect()

if
  selectString(" and see that his health", 1) ~= -1
  or selectString(" and see that her health",1 ) ~= -1
  or selectString(" and see that faes health",1 ) ~= -1
then
  replace("") deselect()
end

local percent = math.min(180, math.floor((100/tonumber(multimatches[2][3])) * tonumber(multimatches[2][2])))

echo(string.rep(" ", 36 - #getCurrentLine()))

local width = math.floor((percent * 30) / 100)
fg("a_green") echo(string.rep([[|]], width))
fg("a_darkgreen") echo(string.rep("-", 30 - width))

fg("a_darkgrey") echo(" " .. percent .. "% hp")
deselect() resetFormat()