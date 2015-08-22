Svof Elist Sorter
================
This script helps you keep your vials in good order - it tells you what you're running low on (with configurable amounts for each elixir/salve/venom), what is about to decay (with configurable time), and has a button for inserting text of which refills would you like (venoms work as well). For vials that are about to decay, it has a feature to pour contents into other vials and then dispose of them via a custom command.

To use it, check *elist* or *vlist* and it'll display a nicely organized menu of it's own after the output. If you're running low on any vials, it'll tell you how many of each, and allow you to click on a button at the end of the menu that'll insert into the command line what stuff do you need.

If you have any vials that are going to decay soon, it'll tell you how many as well, and provide a button that'll dispose of vials that are near decaying. You can give it a custom command to use to dispose of vials - for example, *dispose of decays by: drop vial* or *dispose of decays by: put vial in pack*. Before disposing, the script will intelligently empty out the vial by pouring it into other vials or other empties that aren't going to decay, so you don't lose out.

You can adjust the amount of months below which sorter will consider a vial about to decay, and the amount of vials for each potion/elixir/venom that you'd like to have from the *vconfig2* menu.

Aliases
^^^^^^^^
.. glossary::

  elist
    Shows you the elist summary - how many vials of a certain thing have you got, and how many vials of a potion are you missing (according to your desired stocking preferences).

    It also shows you links to change the desired amounts of vials, refill all vials from tuns, or append the refill request to the command/input line - so you can tell a refiller what you'd like.

  dispose of decays by: <command>
    Uses the custom command to dispose of near-decay vials. Make sure to include the word *vial* in it, it will be substituted with the vial ID. This function *will* save your sips by transferring them to non-decay vials.

    This will check elist first before doing its job, just in case you've bought new vials inbetween the last time you checked elist - and you'd like the new vials to be used for pouring into instead of wasting many old vials away with content still in them.

  vconfig setpotion <potion> <amount>
    Adjusts desired potion amounts. You can also do it via elist > (change desired amounts) > clicking on a number.

  vconfig decaytime <months>
    Sets the amount of months a vial will have left on it to be considered soon to be decaying. If a vial is below this many months, the ``dispose of decays by:`` command will take it into account.

API
^^^^
.. glossary::

  svo.es_potions (table)
    Stores potions in the format of: ::

    	type = {
    		potion = {
    			vials = #,
    			decays = #,
    			sips = #
    		}
    	}

  svo.es_vials (table)
    Stores each vial in the format of: ::

    	vial id = {
    		months = #,
    		potion = contents,
    		sips = #
    	}
