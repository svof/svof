Svof Priest Report
======================
This script helps you deal with seek and trace reporting as a Priest. It has two parts: tracing and reporting a persons movements on a channel, and responding to a seek request with information about the person and their companions.

Seek reporting works automatically - whenever someone asks **Locate person** on party or a clan, the system will angel seek the person, and report back on the channel it was asked on - party or a specific clan - information about the person. You will need to add the short alias clan name to the "Seek request" trigger if it's not there, though - because you can't do clan <long clan name> tell in the game.

Aliases
^^^^^^^^
.. glossary::

  tr <person>
    Starts tracing a person. By default, it'll report their movements to party - and you can change it to report to a clan instead with vconfig ccto <short clan name>. You can find the short name of a clan by typing 'clans', the orange brackets denote it.

  tr off
  	Stops tracing and reporting a persons movements.

  vconfig autoseek
    Toggles whenever you respond to 'locate' requests. It might be wise to turn it off when there's someone with consistently quicker responses (ping) around.

  vconfig bettertrace
  	Enables better trace reports that aim to spam you less and be more informative. If someone is speedwalking, the reports will happen for a bunch of rooms at once - so instead of getting 5 chats to pt that someone moved, it'll instead be one, saying they moved five rooms. Where the person just moved one room and it is possible to determine the direction they have, the direction will be mentioned as well. Enabled by default.

  vconfig reportdelay #
  	Adjusts the delay, in seconds, that bettertrace waits before mentioning how many rooms a person has moved. Set to 2 by default.

  seek <person>
  	Manually locates a person and reports to wheever ccto is set to.
