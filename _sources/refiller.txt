Svof Refiller
======================
Refilling with this is extremely easy - the script automatically takes care of managing artefact vials and your refilling skill for you, as well as refilling **all** of the order in one go.

The script automatically detects the number of fills to use (depending if you're transcendent or not - please check AB for it to know!), doesn't boil the pot if you're missing an ingredient (but instead takes them out, and gets the pot and goes on to do the next potion), properly works where inpot requires doing more than 50 ingredients.

Use of the refiller would be: do **putvials** to put all of your vials away, and have the customer hand you the vials. Do **refill <whole order, each potion separated with a comma>** to have it do all the heavy work for you. Then **givevials <customer>** to hand the vials back to them, and **getvials** to retrieve your own vials. Same thing if you're refilling for yourself - put the vials away.

Aliases
^^^^^^^^
.. glossary::

  refill <what>
    Does your **entire** order - separate different potions with a comma, and if you'd like a certain amount of a potion to go into artefact vials, add "# arty" at the end. For example: ::

    	-- this will refill vials of health
    	refill 5 health

    	-- this will refill 3 normal vials and 2 artefact vials of health
    	refill 5 health 2 arty

    	-- this will refill 5 health vials and 2 vials of caloric
    	refill 5 health, 2 caloric

    	-- some other mixed order that just requires one command to do!
    	refill 1 caloric, 1 mass, 1 health, 3 mana, 1 speed

    Take note that when doing artefact refills, you specify them as a portion of the potion - if you want 4 refills of health and 2 of them in artefact vials, you'd do *refill 4 health 2 arty*.

  refill cancel
    Stops refilling right away.

  vconfig potid <pot ID>
    Sets the pot ID to brew things in. Set this to your own, in case there is someone else's pot on the ground.

  vconfig packid <pack ID>
    Sets the back ID to store vials away into when you do 'putvials' before taking on the customers vials. To get them out after, do 'getvials'.

  putvials
  	Stuffs all of your current vials away into a container, so you can take the customers empty and artefact vials without them getting mixed in with yours. You should do this before they give you their vials.

  getvials
  	After you've given vials back with 'givevials', *getvials* will reclaim your vials from the container you hid them in.

  givevials <person>
    Hands over all of your vials to another person.


API
^^^
.. glossary::

	svo done refilling (event)
	  Raised when a successful refill is done. You can use this event, for example, to perform order cost calculations.

	svo.rf_previousorder (table)
	  Contains the details of the previous order that was completed - key names are the potions, and values are tables with 'normal' and 'arty' amounts, ie: ::

	  	svo.rf_previousorder = {
	  	  health = {
	  	    normal = 5,
	  	    arty = 0
	  	  },
	  	  mana = {
	  	    normal = 2,
	  	    arty = 3
	  	  }
	  	}
