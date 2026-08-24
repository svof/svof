--Disabled on purpose
--This currently does not have a formula to determine break counts. 
--You will need to test and add in your own counts based upon the weapon you have.
--Once you have tested you can enable this to get a rough estimate on your break count.

local maxhp = tonumber(multimatches[2][2])

local hits

--Modify your counts here
if maxhp > 9000 then hits = 6
elseif maxhp > 5000 then hits = 5
elseif maxhp > 4000 then hits = 4
elseif maxhp > 2000 then hits = 3
else hits = 2
end

echo("\n")
svo.echof("My guess would be %d hits.", hits)