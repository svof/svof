svo.boxDisplay("TUMBLING "..matches[2], "sea_green:yellow")

local time = 4.5

if (svo.affl.mangledrightleg or svo.affl.mutilatedrightleg) and (svo.affl.mangledleftleg or svo.affl.mutilatedleftleg) then
  time = 6.5
end

if svo.affl.timeflux then
  local brokenlimbs = svo.countbrokenlimbs()

  if brokenlimbs == 4 then time = time + 2
  elseif brokenlimbs > 0 then time = time + 1 end
end

svo.tumbleTimer = tempTimer(time, [[
if svo.tumbleTimer then
  svo.boxDisplay("TUMBLE FAILED", "dark_slate_gray:red")
  svo.tumbleTimer = nil
end
]])