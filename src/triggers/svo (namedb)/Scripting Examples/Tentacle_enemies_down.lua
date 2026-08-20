-- if you'd like to use this trigger, enable it and move it out of the NameDB folder - so your changes to it will stay

if ndb.isenemy(matches[2]) then
  if svo.defc.dragonform then
    svo.doadd("becalm")
  else
    svo.doadd("touch tentacle " .. matches[2])
  end
end