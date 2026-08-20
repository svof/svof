--Disabled on purpose
--This currently does not have a formula to determine break counts. 
--You will need to test and add in your own counts based upon the weapon you have.
--Once you have tested you can enable this to get a rough estimate on your break count.
--Shikudo hits are broken up into 3 groups. The groups are as follow:
--Group 1 (lowest limb damage, highest count) - Dart
--Group 2 (middle limb damage, middle count) - Spinkick, Nervestrike, Needle, Livestrike, Thrust
--Group 3 (highest limb damage, lowest count) - Risingkick, Frontkick, Flashheel, Hiraku, Hiru, Ruku, Kuro

--The below function will place the hits in an appropriate form so the limb counter can track all of the seperate hits
--svo.lc_shikudocount(lowest, middle, highest)

--You will need to go through each attack group and find what the limb counts are to set them accordingly

local maxhp = tonumber(multimatches[2][3])
local person = multimatches[2][2]

local hits

--Modify your counts here
if maxhp > 9000 then svo.lc_shikudocount(person, 5, 6, 7)
elseif maxhp > 5000 then svo.lc_shikudocount(person, 4, 5, 6)
elseif maxhp > 4000 then svo.lc_shikudocount(person, 3, 4, 5)
elseif maxhp > 2000 then svo.lc_shikudocount(person, 2, 3, 4)
else svo.lc_shikudocount(person, 1, 2, 3)
end

echo("\n")
svo.echof("My guess would be Group 1: %s, Group 2: %s, Group 3: %s.", svo.lc_shikudoskill.lowest, svo.lc_shikudoskill.middle, svo.lc_shikudoskill.highest)