mmp.pdb, mmp.pdb_lastupdate = {}, {}
enableTrigger("qwho (svo people tracker)")

if not svo.defc.thirdeye then
  if svo.conf.thirdeye then svo.doaction("thirdeye", "misc")
  else svo.doaction("thirdeye", "herb") end
end

sendSocket("who b\n", false)

if svo.qwhoopen then killTimer(svo.qwhoopen) end
svo.qwhoopen = tempTimer(10, [[
  if not svo.qwhoopen then return end

  disableTrigger("qwho (svo people tracker)")
  svo.echof("qwho didn't finish - manually closed it.")
  tempTimer(0, function() svo.buildwhosummary() svo.showprompt() wrapLine(getLineCount()) end)
  raiseEvent("mmapper updated pdb")
  svo.qwhoopen = nil
]])

svo.showqwho = matches[2]
svo.qwhofilter = matches[3]

svo.echof("Checking all of wholist%s%s...", ((svo.showqwho and svo.showqwho ~= "") and (" for "..svo.showqwho) or ''), (svo.qwhofilter and " in "..svo.qwhofilter or ''))