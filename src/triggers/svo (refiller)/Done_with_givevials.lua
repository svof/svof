if not svo.givevials then return end

if svo.givevials.selfish then
  svo.defs.keepup("selfishness", true)
end

svo.givevials = nil
echo'\n' svo.echof("Handed all vials over.")