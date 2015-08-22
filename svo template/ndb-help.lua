{
  {
    term = "vconfig politics",
    definition = {
      "Gives you a menu where you can adjust city relationship stances, and setup highlights."
    }
  },
  {
    term = "ndb",
    definition = {
      "NameDB alias cheetsheet - shows the same information as this aliases list. Hover your mouse or click on an alias to see the description."
    }
  },
  {
    term = "ndb long",
    definition = {
      "NameDB alias cheetsheet, with the descriptions expanded."
    }
  },
  {
    term = "vconfig autocheck yep/nope",
    definition = {
      "Sets whenever NameDB should automatically check new people it comes across to gather information about them or not. Most of the time this does grab their citizenship."
    }
  },
  {
    term = "vconfig usehonors yep/nope",
    definition = {
      "Sets whenever NameDB should use honors for checking names - honors allows qwm, qwi and qwic to work."
    }
  },
  {
    term = "vconfig autoclassset #",
    definition = {
      "Sets the amount of consecutive hits an opponents should do from a class before NameDB remembers them as that specific class. This is to prevent illusions easily messing with their known class."
    }
  },
  {
    term = "qw/qw2",
    definition = {
      "Checks the QW list and records new adventurer names and their city affiliation for use in highlighting. NameDB uses the in-game 'qwc' command for this.",
      "",
      ":note: You need to have CONFIG MXP OFF in-game for the city affiliation capture to work - as the name highlighting done by the game here with MXP is different from elsewhere and isn't supported by Mudlet."
    }
  },
  {
    term = "qw update",
    definition = {
      "Re-checks all names on the QW list, even if they're already and currently known - required ``vconfig usehonors`` to be on."
    }
  },
  {
    term = "qwc",
    definition = {
      "Checks the QW list and display you a menu of players present by their organization affiliation, sorted:"
    }
  },
  {
    term = "qwm",
    definition = {
      "Shows ungemmed Marks on the QW list."
    }
  },
  {
    term = "qwic",
    definition = {
      "Shows ungemmed Infamous on the QW list."
    }
  },
  {
    term = "qwi",
    definition = {
      "Re-checks all people visible on the QW list and then shows the ungemmed Infamous."
    }
  },
  {
    term = "ppof <city>",
    definition = {
      "Checks QW list and citizens of a particular city to cc (so party or a clan, depends what you've set vconfig ccto to)"
    }
  },
  {
    term = "ndb infamous",
    definition = {
      "Shows the list of known Infamous people from the database."
    }
  },
  {
    term = "house/order/city enemies",
    definition = {
      "Sets the enemy status of the people that NameDB knows of from those lists. This won't auto-add names it doesn't know for checking (so your db doesn't get filled up with dormant people and they'll be getting highlighted for no reason)."
    }
  },
  {
    term = "house/order/city enemies add",
    definition = {
      "Sets the enemy status of the people from those lists, and auto-adds names it doesn't know for checking."
    }
  },
  {
    term = "ndb honorsnew",
    definition = {
      "If vconfig autocheck is off, ndb honorsnew will allow NameDB to honors the new people it knows of."
    }
  },
  {
    term = "ndb cancel",
    definition = {
      "Stops honors'ing the list of people that need to be checked."
    }
  },
  {
    term = "npp",
    definition = {
      "Stops/resumes name highlighting. You might want to turn highlighting off for KoTHs, for example, where the game-provided colors are more important."
    }
  },
  {
    term = "npp on/off",
    definition = {
      "Stops/resumes name highlighting explicitly."
    }
  },
  {
    term = "vconfig highlightignore <person>",
    definition = {
      "Adds/removes a name on the list that keeps track of who should not be highlighted."
    }
  },
  {
    term = "vshow highlightignore",
    definition = {
      "Shows the list of persons who shouldn't be highlighted."
    }
  },
  {
    term = "cw",
    definition = {
      "Appends class and Dragon information to each adventurer on the CW list, as well as providing a total summary of classes at the bottom. This looks best when Mudlets screenwidth is set to 100 in Mudlets settings (the games, as set via CONFIG, should be 0)."
    }
  },
  {
    term = "iff <person> ally/enemy/auto",
    definition = {
      "Explicitly sets a persons status to you, overriding the auto-determination of enemy vs non-enemy by NameDB.",
      "",
      "Making them an ally will make NameDB disregard their citizenship and political stances and whenever they're a house/order/city enemy - thus never considering them an enemy.",
      "",
      "Making them an enemy will always consider them an enemy, disregarding anything else.",
      "",
      "Setting it to auto will have NameDB compute their status to you depending on a number of things - if they're in a city that is considered an enemy to you, or if they're a house/city/order enemy, they'll be considered an enemy. Otherwise, they won't be an enemy."
    }
  },
  {
    term = "ndb set <person> notes <notes>",
    definition = {
      "Adjusts the notes you have on the person to the new ones. If you do *whois person* and click on *'edit'*, you an edit current notes you have on them. You can use the same color formatting from a cecho to color your notes (ie *<red> text*), and insert \\n's in the same manner to get a linebreak."
    }
  },
  {
    term = "ndb export",
    definition = {
      "Opens up a menu where you can export your data. It allows you to selectively export fields (so you don't have to share everything, for example, not your notes), and which people to export (atm, it's everybody)."
    }
  },
  {
    term = "ndb import",
    definition = {
      "Opens up a menu where you can import exported NameDB data. You can selectively choose which fields about a person should be imported - they will overwrite what you've had. This will not clear your names in NameDB that you've got already - if you'd like to start clean, use 'ndb delete all'."
    }
  },
  {
    term = "ndb delete <person>",
    definition = {
      "Wipes an individual entry from NameDB."
    }
  },
  {
    term = "ndb delete all",
    definition = {
      "Wipes all data from the database, essentially making you start over clean. You have to use this alias twice for it to go off."
    }
  },
  {
    term = "ndb delete unranked",
    definition = {
      "Wipes all unranked - that is, newbies and older players - from NameDB."
    }
  },
  {
    term = "ndb update all",
    definition = {
      "Re-checks every person in the database. This can't be undone, only paused (with ndb cancel) - NameDB will re-check everybody as you've asked it to, so don't do it on a whim!"
    }
  },
  {
    term = "ndb set <person> class <class>",
    definition = {
      "Manually sets/adjusts the persons class. It's always stored in lowercase by NameDB. NameDB automatically picks up the class from cwho and hwho lists, but this isn't possible for everyone."
    }
  },
  {
    term = "ndb set <person> city <city>",
    definition = {
      "Manually changes the persons city. It's always stored in proper case (first letter capitalized) by NameDB. NameDB automatically picks it up from honors for you already."
    }
  },
  {
    term = "ndb set <person> title <title>",
    definition = {
      "Adjusts the persons title as NameDB knows it. It's not really useful for much, as titles change all the time, but the option to set/retrieve them is there for you."
    }
  },
  {
    term = "ndb set <person> city_rank <rank>",
    definition = {
      "Manually adjusts the persons city rank. 0 is known, 1 is cr1 and 6 is cr6. NameDB automatically picks up the city rank from honors for you already."
    }
  },
  {
    term = "ndb set <person> house <house>",
    definition = {
      "Manually adjusts the persons House affiliation. NameDB can only capture this from hwho or house members, so you'd want to use this for setting others' Houses if that's something you want to track."
    }
  },
  {
    term = "ndb set <person> order <order>",
    definition = {
      "Manually adjusts the persons Order affiliation. NameDB stores it with proper titlecase, and it'll pull information from ORDER MEMBERS for you. You will need to manually input the members of other Orders though."
    }
  },
  {
    term = "ndb set <person> might <might>",
    definition = {
      "Adjusts the persons might (lessons invested vs you) relative to you - 0 is 0% of your might, 100 is equal to you. *-1* is unknown, and will cause NameDB to re-honors the person. NameDB automatically captures this from honors."
    }
  },
  {
    term = "ndb set <person> importance <number>",
    definition = {
      "Manually sets a persons \"importance\". This isn't used by NameDB, but it's a way for you to explicitly prioritize people without relying on heuristics such as city rank and might."
    }
  },
  {
    term = "ndb set <person> xp_rank <number>",
    definition = {
      "Manually sets the persons rank in experience in the game. *-2* is unranked, *-1* is unknown - this'll cause NameDB to auto-honors the person. Any other number is their actual rank. NameDB automatically captures this from honors."
    }
  },
  {
    term = "ndb set <person> immortal <yep/nope>",
    definition = {
      "Manually adjusts whenever somebody is an Immortal or not. NameDB automatically captures this from honors."
    }
  },
  {
    term = "ndb set <person> cityenemy/houseenemy/orderenemy <yep/nope>",
    definition = {
      "Manually sets whenever the person is your citys, houses or orders enemy.  NameDB automatically captures this from the enemy lists, but you can adjust it manually as well."
    }
  },
  {
    term = "ndb stats",
    definition = {
      "A little stats alias showing the number of people known and city populations."
    }
  }
}