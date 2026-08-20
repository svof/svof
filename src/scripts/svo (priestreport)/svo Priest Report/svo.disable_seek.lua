-- disable seek alias in dragonform, because it's for priest only
function svo.disable_seek()
  if not svo.loader.priestreporter then return end
  if svo and svo.defc.dragonform then disableAlias"(seek person) Manually seek & report a person"
  else enableAlias"(seek person) Manually seek & report a person" end
end