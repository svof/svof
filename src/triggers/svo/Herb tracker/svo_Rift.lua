if not svo.me.parsingrift then return end -- don't know what we're parsing? we don't know what to reset then, so let's not

if svo.me.parsingrift == 'all' then
  for herb in pairs(svo.me.riftcontents) do
    svo.me.riftcontents[herb] = 0
  end
elseif svo.me.parsingrift == 'herb' then
  for _, herb in pairs(svo.me.herblist) do
   svo.me.riftcontents[herb] = 0
  end
elseif svo.me.parsingrift == 'mineral' then
  for _, mineral in pairs(svo.me.minerallist ) do
   svo.me.riftcontents[mineral] = 0
  end
end