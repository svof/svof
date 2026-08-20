send("ir "..(matches[2] or ''), false)

if matches[2] == "herb" or matches[2] == "mineral" then
  svo.me.parsingrift = matches[2]
elseif not matches[2] then
  svo.me.parsingrift = "all"
end