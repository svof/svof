lastCommands = lastCommands or {}

function commandTracker(_,what)
   local howMany = 5
   what = what:lower():gsub("^%s+","")
   table.insert(lastCommands, 1, what)
   table.remove(lastCommands, howMany+1)
end

function commandCheck(what)
   local found = false
   for k,v in ipairs(lastCommands) do
      if rex.match(v, stupidityCheckTable[what]) then
         found = true
      end
   end
   return found
end

stupidityCheckTable = {
	["You waggle your eyebrows comically."]                                                                             = "^waggle",
	["You blink."]                                                                                                      = "^blink",
	["You twitch spasmodically."]                                                                                       = "^twitch",
	["As horrible thoughts fill your mind, you begin to sob uncontrollably."]                                           = "^sob",
	["You hug yourself compassionately."]                                                                               = "^hug",
	["My friend, clearly you know little of the sultry tango, if you think that you can perform it without a partner."] = "^tango",
	["Your mind is whirling with thoughts - you cannot settle down to sleep."]                                          = "^sleep",
	["You get down on one knee and serenade the world."]                                                                = "^serenade",
	["You make a strangled meowing noise and quickly shut up in embarrassment."]                                        = "^meow",
	["You burp obscenely."]                                                                                             = "^(?:burp|belch)",
	["You flap your arms madly."]                                                                                       = "^flap",
	["You wouldn't want to drink a salve. It would not be tasty at all."]                                               = "^(?:sip|drink|sup|quaff) ",
	["Tears fill your eyes and begin to slowly run down your face."]                                                    = "^cry",
	["You drop to one knee, demonstrating your humility and respect."]                                                  = "^humblekneel",
	["You pick your nose absently."]                                                                                    = "^picknose",
	["You wail like an old woman."]                                                                                     = "^wail",
	[ [[You grunt a bit and then let out a loud "OINK!"]] ]                                                             = "^oink",
	[ [[You let out a loud, long "MOOOOOOOOOOO!"]] ]                                                                    = "^moo",
	[ [["The voices! The voices! Get them out of my head!!" you moan, holding your head in pain.]] ]                    = "^voices",
	["You stumble and poke yourself in the eye."]                                                                       = "^poke",
	["Your mind is whirling with thoughts - you cannot settle down to sleep."]                                          = "^sleep",
}