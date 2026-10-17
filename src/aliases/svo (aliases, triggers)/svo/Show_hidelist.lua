-- vshow hidelist [all], and vshow hide|unhide <skillset or defence>
if matches[2] == 'hide' or matches[2] == 'unhide' then
  svo.defences.hide_command(matches[2], matches[3])
else
  svo.showhidelist(matches[3] == 'all')
end
svo.showprompt()