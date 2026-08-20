-- you can do things like:
-- vlua 2+2
-- vlua

local f,e = loadstring("return "..matches[2])
if not f then
	f,e = assert(loadstring(matches[2]))
end

local r = {f()}

if r then
  if type(r[1]) == 'nil' then svo.echof("Code ran OK, there were no results.") svo.showprompt()
  elseif #r == 1 then if type(r) == 'string' or type(r) == 'number' then svo.echof("Code ran OK, results are:\n  "..r[1]) else display(r[1]) end
  else display(r) end
end