svo.echof("You are on the %s release stream!\nYour Svof version is " .. svo.version .. "\n\nYou have the following modules installed:", svo.conf.releasechannel)
for k,v in pairs(svo.modules_version) do
  decho(string.format("%sv%s: %s\n", svo.getDefaultColor(), v, k))
end
svo.showprompt()