svo.valid.got_rebounding()

if svo.enabledskills.discipline or svo.enabledskills.malignity or svo.enabledskills.valour or svo.enabledskills.dominion or svo.enabledskills.swashbuckling or svo.enabledskills.striking or svo.enabledskills.spirituality then
  selectCurrentLine()
  setBold(true)
  setUnderline(true)
  fg("royal_blue")
  deselect()
  resetFormat()
end
