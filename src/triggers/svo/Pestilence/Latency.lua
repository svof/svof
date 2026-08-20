local count = 0
for k, v in pairs(svo.affl) do
  if k == "sandfever" or k == "mycalium" or k == "pyramides" or
  k == "flushings" or k == "rebbies" then
    count = count + 1
  end
end
if count >= 3 then
  svo.valid.simplelatency()
  svo.givewarning({
  	initialmsg = "Afflicted with Latency, cannot sip immunity for 13 seconds.",
  	prefixwarning = "Can't sip immunity",
  	duration = 3
  })
end