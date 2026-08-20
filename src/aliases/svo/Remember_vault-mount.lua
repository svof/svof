if matches[3] == "ship" then
  send(command, false)
  return
end

if string.starts(matches[3]:lower(), "figurehead") then
  send(command, false)
  return
end

if svo.conf.ridingskill ~= matches[2] then
  svo.echof("Remembered your riding skill at '%s'", matches[2])
end

if svo.conf.ridingsteed ~= matches[3] then
  svo.echof("Remembered your steed at '%s'", matches[3])
end


svo.conf.ridingskill = matches[2]
svo.conf.ridingsteed = matches[3]

send(command, false)