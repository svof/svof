svo.rmaff('calcifiedskull')
-- the calcification is done, and takes the head's damage up a level
-- (AFFLICTION SHOW, captured 2026-10-20): none to damagedhead, damagedhead
-- to mangledhead, and from mangledhead it kills
if svo.affs.damagedhead then
  svo.valid.simplemangledhead()
elseif not svo.affs.mangledhead then
  svo.valid.simpledamagedhead()
end