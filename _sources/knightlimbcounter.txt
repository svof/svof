Svof Multi-Person Knight Limbcounter
======================================
The knight limbcounter automatically tracks whomever you are hitting, and tells you their limb status after each hit - along with any limbs that are prepped, if any.

It also has a feature of showing the last hit opponents limb status on the prompt - to use this, add the *@kl_prompttag*, *@kl_prompttag2* or *@kl_prompttag3* tag to your :ref:`custom prompt<customprompt>`. The tags display the same information in different ways, so choose whichever one you'd like. If you'd like to modify a tag, the source code for them is available in the script for the addon - copy it into a new script (so it doesn't get overwritten on an update) and feel free to tinker.

If you just want to keep your prompt as-is, then you can use this: ::

	vconfig customprompt ^1@healthh, ^2@manam, ^5@endurancee, ^4@willpowerw ^W@eqbal@defs^b|@kl_prompttag^W- @affs

You might also find this `example targetting alias <http://www.ironrealms.com/mud-scripts/example-hit-a-targetted-limb-alias>`_ useful for attacking with.

vconfig options
^^^^^^^^^^^^^^^^
.. glossary::

  limbprep
  	Sets the amount of which after which a limb will break - this is essentially *hitsneeded - amount of points one hit does*. For knights, this should be at 2 (because of dsl), and for single-hit weapon users, 1.

  weaponone
  	Sets the damage on the first weapon (as reported by weaponprobe), used in guesstimating the amount of hits. To adjust this via script, do *svo.config.set("weaponone", #)*.

  weapontwo
  	Sets the damage on the second weapon, used in guesstimating the amount of hits.

Aliases
^^^^^^^^^^
.. glossary::

  vsl
  	Shows limb data of everything that the counter is keeping track of.

  assess <person>
    Shows the limbcounters guesstimate on how many hits are needed to break a limb. Given how this is an estimate and is not completely accurate all of the time, the estimate does not set the persons hits needed - use the ``shn`` alias for that.

    This is an estimate to aid you only.

  nn
  	Resets the limb data of the last hit person.

  nn *person*
  	Resets the limb data of a given *person*.

  nn *t/h/rl/ll/ra/la*
  	Resets a specific limb of the last hit person.

  shn *amount*
  	Sets the hits needed to break the last person you hit limbs.

  shn *person* *amount*
  	Sets the hits needed to break of a specific person.

  kk
  	Sets the hits needed to break the last hit persons limb to their currently most damaged limb.

API
^^^^^^^^^^
.. glossary::

  svo limbcounter hit (who, where) (event)
    This `Mudlet event <http://doc.svo.vadisystems.com/#event-use-examples>`_ goes off when you've hit someone's limb. The event arguments include whom and where did you hit them.

  svo limbcounter reset (event)
    This event is raised when the limbcounter is reset (either fully, or only an a person, or a specific persons limb). You can then re-read the current *svo.kl_list* table to get the current values.

  svo limb reset (who, where) (event)
    This event is raised when a particular limb is reset - either due to being over hits needed when the limbcounter is syncronized (with kk), or when setting the hits needed (with shn).

  svo limb broke (who, here) (event)
    This event is raised when a limb is broken, according to the limbcounter.

  svo.kl_list (table)
  	A table containing all of the limbcounters tracking data - organized by named tables of people and their limb status, along with their breaking points. ::

	  	display(svo.kl_list)

	  	--[[yields, for example:
		table {
		  'Person2': table {
		    'kl_break_at': 10
		    'rightleg': 0
		    'leftleg': 4
		    'torso': 0
		    'leftarm': 0
		    'rightarm': 0
		    'head': 0
		  }
		  'Person1': table {
		    'kl_break_at': 10
		    'rightleg': 0
		    'leftleg': 0
		    'torso': 4
		    'leftarm': 0
		    'rightarm': 0
		    'head': 9
		  }
		}
	  	]]

  svo.lasthit (string)
  	Stores the last hit persons name. You can use it to check a specific limb status in an alias, for example: ::

  		echo(string.format("%s's head is at %s.\n", svo.lasthit, svo.kl_list[svo.lasthit].head))


API examples
~~~~~~~~~~~~
Adding a few hits to a person you're targetting manually via scripting: ::

  if not svo.kl_list[target] then svo.echof("Haven't got any limb data on %s yet!", target) return end

  -- add 2 points of damage to their head
  svo.kl_list[target].head = svo.kl_list[target].head + 2

