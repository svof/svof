local name = multimatches[2][2]

if not svo.isenemy(name) then return end

svo.givewarning({
	initialmsg = string.format("%s started Eliminate on someone!", name),
	prefixwarning = name.." eliminating someone",
	startin = 1,
	duration = 2
})