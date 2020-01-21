Svof Refiller
======================
Refilling with this is extremely easy - the script automatically takes care of managing vials and your refilling skill for you, it also does both brewing and compounding so you can use either of these at your liking, as well as refilling **all** of the order in one go.

The script automatically detects the number of fills to use (depending if you're transcendent or not - please check AB for it to know!), won't brew or compound if you're missing ingredients, properly works where it is required more than 50 batches and in case of brewing restoration vials, it will also automatically take the required amount of gold from your pack.

Use of the refiller would be: do **putvials** to put all of your vials away, and have the customer hand you the vials. Do **brew|compound <whole order, each potion separated with a comma>** to have it do all the heavy work for you. Then **givevials <customer>** to hand the vials back to them, and **getvials** to retrieve your own vials. Same thing if you're refilling for yourself - put the vials away.

Aliases
^^^^^^^^
.. glossary
::

  brew|compound <what>
    Does your **entire** order - separate different potions with a comma! For example: ::

    	-- this will refill vials of health
    	brew|compound 5 health

    	-- this will brew 5 health and 2 mana vials.
    	brew 5 health, 2 mana

    	-- this will compound 5 health vials and 2 vials of caloric.
    	compound 5 health, 2 caloric

    	-- some other mixed order that just requires one command to do!
    	brew|compound 1 caloric, 1 mass, 1 health, 3 mana, 1 speed

  brew|compound cancel
    Stops refilling right away.

  vconfig potid <pot/alembic ID>
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
.. glossary
::

	svo done refilling (event)
	  Raised when a successful refill is done. You can use this event, for example, to perform order cost calculations.

	svo.rf_previousorder (table)
	  Contains the details of the previous order that was completed - key names are the potions, and values are amounts, ie: ::

	  	svo.rf_previousorder = {
 		 health = 5,
 		 mana = 2
		}
