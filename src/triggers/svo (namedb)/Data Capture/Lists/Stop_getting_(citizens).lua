setTriggerStayOpen("Citizens", 0)
stop_capturing = true


ndb.templist = {}
ndb.templist = string.split(ndb.tempnames, ",")

for i,k in pairs(ndb.templist) do
	ndb.templist[i] = k:trim()
end

-- last on name on list might have a dot
if string.sub(ndb.templist[#ndb.templist], -1, -1) == "." then
	ndb.templist[#ndb.templist] = string.sub(ndb.templist[#ndb.templist], 1, -2)
end

ndb.tempnames = nil

temp_name_list = {}

for i,j in ipairs(ndb.templist) do
	temp_name_list[#temp_name_list + 1] = {
		name = j,
		city = gmcp.Char.Status.city:match("^(%w+)")
	}
end

db:merge_unique(ndb.db.people, temp_name_list)

raiseEvent("NameDB got new data")

-- reload all highlights, as citizens list is big anyhow
ndb.loadhighlights()