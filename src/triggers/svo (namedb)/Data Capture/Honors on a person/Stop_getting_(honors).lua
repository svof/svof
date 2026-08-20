setTriggerStayOpen("Honors", 0)
disableTrigger("Honors")

if not temp_name_list then return end

if ndb.gaghonours then
  if ndb.honorseqgag then killTrigger(ndb.honorseqgag) end
  ndb.honorseqgag = tempExactMatchTrigger("You have recovered equilibrium.", [[svo.deleteLineP(); killTrigger(ndb.honorseqgag); ndb.honorseqgag = nil]])
  deleteLine()
end

temp_name_list[1].combat_rank = temp_name_list[1].combat_rank or 0
temp_name_list[1].combat_rating = temp_name_list[1].combat_rating or 0
temp_name_list[1].city_soldier = temp_name_list[1].city_soldier or 0
temp_name_list[1].motto = temp_name_list[1].motto or ""
temp_name_list[1].warcry = temp_name_list[1].warcry or ""

db:merge_unique(ndb.db.people, temp_name_list)

local gaghonours = ndb.gaghonours
ndb.honorsid, ndb.gaghonours = nil, nil

raiseEvent("NameDB finished honors", temp_name_list[1].name, (gaghonours and "quiet" or "manual"))

temp_name_list = nil