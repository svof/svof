-- credit to: http://forums.mudlet.org/viewtopic.php?f=6&t=1818#p9641
local prefix = ""
--if http(s), ftp, or telnet is not in the beginning of the string then http:// will be used instead to prefix the string.
if not rex.find(matches[1], "^(https?:\/\/|ftp|telnet)",1,"i") then
  prefix = "http://"
end

for i,v in ipairs(matches) do
  if selectString(matches[i], 1) ~= -1 then
    setLink([[openUrl("]] .. prefix .. matches[i] ..[[")]], prefix.. matches[i])
    setUnderline(true)
  end
end

deselect()
resetFormat()