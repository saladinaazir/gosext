THIS STUFF IS OUTDATED, ASK FOR NEW STUFF ON DISCORD


edit.rar version 1.21, last updated 12/12/2022
1.21 changes so far:
--improved irelia fps, fixed couple of issues
--added seriesv2 (tryn, jax) tryn has pog ultcalcs logic, and improved manual e cast (double press when E is on cd and you'll galeforce instead)
--added "targeted" option to test.lua (example settings for zed r here https://i.imgur.com/QPjuK13.png, this just means script will cast R on target if press R, may add better logic to only cast if you aren't moused over a valid target, rn sometimes will ult target even if you are moused on a diff character)
--improved impulsevlad r calcs (with same aoe out of range logic as killerannie)
--improved/released ctrlzed
--new 14yas, lots of good stuff
-moved to github
1.2 changes:
	-improved 14ryze,14zilean,pussyvelkoz, impulsevlad sussy mundo, simpleaio ksante, devx zeri,pussy ahri, and no doubt others i just dont remember
	-added sussy tk, ctrlzed,14kennen,clover vex, killerannie+karthus
	

DISCLAIMER: these are scripts originally made by other people that I edited to make them better for me. I never intended to release these to anyone else, so they are just in the state that I use them in. there are no doubt features that you might want but i have no use for,
and still bugs here that I haven't discovered, or know but haven't bothered to fix (like ryze lvl 1 when you take w only uses w in "w prio off" bc i never bothered to make an exception in the logic for when haven't lvled Q or E)
-listed changes are only some of what i did, i can't remember everything, i just tweak shit in practice tool and games until it works for me. 


TRY EVERYTHING LISTED ON TARGET DUMMIES IN PRACTICE TOOL. IF THE DUMMY IS LOADED IN GOS, BUT SCRIPT STILL WON'T USE SPELL, TRY RELOADING 2XF6 AS SCRIPT MIGHT ONLY LOAD ENEMIES AT THE START OF GAME

FOR PUSSYAIO CHAMPS, PASTE INTO COMMON>PUSSYAIO>CHAMPS FOLDER

JUST READ THE SCRIPT LOGIC IN NOTEPAD IF YOU WANT TO SEE HOW IT WORKS, THEN CHANGE IT HOW YOU WANT. THIS SHIT IS EASY.


IF THE ORIGINAL SCRIPT CREATOR UPDATES THEIR SCRIPT, USE WINMERGE OR SOMETHING TO UPDATE WHAT YOU WANT, AND KEEP WHAT YOU WANT.

IF SOMETHING HERE IS BROKEN, MESSAGE ME AND I'LL FIX IT 



-autolvl.lua (dnsactivator lite)
	-dnsactivator with only the most useful item options left to improve fps and stop random crashes
	-improved autolvl ability sequencing logic
	-everfrost only used on stun by default, option for using on slow as well, as well as a semimanual everfrost key
	-fixed data and prediction for ironspike whip items
	-Semimanual SS keys for exhaust and ignite. Go into LoL settings, and set the key to G, then set your key in script to your normal key ("F"). when you press f, script will press G on your target.
	uhh im not sure if the useon enemy window works anymore, but will only use on your current target so dont need menu

-test.lua
	-this tool lets you rebind an ability key so when you press your ability key, GG Orbwalker uses that ability where your cursor is.
	-this avoids issues with the orbwalker clicking at the same time and sending you tristana jumping onto your aa target rather than where your cursor was
	-bind LoL key for that ability to another key, I use "L" (bind w in lol settings for tristana to "L")
	-a couple of edits for champ scripts that I want to also be able to cast the ability automatically will be set to use "L" such as Kassadin, so you will need to use L or fix the code (it's easy to fix shit, just use notepad++ and Ctrl-F)
	

14Ryze: 
			--completely reworked logic, only use "w prio on" when rooting is a priority
			-would recc using disable AA options only after laning phase
			-meta note: this shit is not the brain off 1v9 ryze of season 5, this shit will give you faker mechanics, but this character's strength is in getting prio then roaming to snowball, if you brain off fight you will lose like everyone else who plays ryze.
			-1.2 update: refined the qeqwq logic to help ensure that you can get the combo where you press w on e marked target near max range while Q is in midair, and proc the mark for the root before q hits, giving you a root without losing DPS.
14tristana:
			-added accurate dmg logic slider to E and R, so won't waste abilities on target that takes 1 aa to kill.
			-would reccomend r aa slider at 1.5 so you only R when the target couldn't be killed by a single AA
			-fixed aa targeting logic to smoothly transition between focusing the target with a bomb on them but autoattacking other targets like normal if bomb target is out of range.
			
14zilean: 
			-lots of conditional logic statements changed, multiple E setting keys
			-improved R logic (adapted from seriesv2 tryndamere, will either ult if hp% goes below slider threshold, or if the AA/spells nearby enemy is using will kill target.)
			-R logic knows which target is being AA, but doesn't know if spell will hit or not, if anyone wants to write that logic or port what's been written for pussyaio's fioraW logic, go for it.
			-flee key uses selfcast E, and W if not sped up and e cd>3 seconds.
			-e slow manual key
			-
			-"use e before W" option should generally be enabled out of lane when you have no mana issues, will use E if it's up (prioritizing enemies) just so you get more value out of W's cooldown reduction.
			-"use e on self if no one in range" option means that when the above option is used, will speed you up in target not in range.
			1.2 update: r dmglogic now knows if an enemy skillshot will hit or not when calculating incoming dmg.
14garen: 
			-r logic now has checks in place to not ult stuff like spellshield, kindredR, trynr, fioraw, etc
			-r toggle key(so you dont waste r on yuumi after fight or some shit)


WR Darius:
			-similar R logic to tryndamere
			-e semimanual cast key (i have it set to my flee key so it will use orb to move)
			-tweaked Q range helper logic, now allows you to walk more freely
			
WR Twisted Fate: -added red card aoe on minions when out of aa range to the harass.

Sussy:
	Mundo:
			-added ranged E harass usage on killable minions	
	1.2 update: Added tahm kench, added Q lasthits to mundo
	-note for tahm kench: GoS doesn't track number of passive stacks, so I couldn't simply code casting Q or R on target with 3 stacks, so script is more janky then i'd like.
yoneMomz: 
	-skillshot data changed, switched to ggprediction
	-added semi R key
	-w will only be used if q isn't ready
	-w in teamfight only when can hit multiple people
	-q checks won't q on aa blockers like shen w, fiora w, jax, kayle ready
	-q3 checks for spellshield, kindred R, if fighting fiora, won't use when she has w ready  etc
	-lasthit logic will only q when minion isn't in melee range

Simpleaio Lissandra:
	-improved extended q logic
	-r enemy key, r ally key
	-r enemy won't waste r on bad target

Simpleaio KSante
	-DONT USE UNLESS YOU UNDERSTAND WELL HOW KSANTE WORKS, AND WILL TRY IN PRACTICE TOOL, AND EVEN IF YOU DO, CHAMP IS A BIT OF AN INT UNLESS YOU'RE SKILLED
	-set w key in LoL to "L" , release w key while holding space for script to aim (I spent a bunch of time on this so i feel attached to the idea, but it might be better to just not use this feature and use w manually)
	-added auto w for morde ult (cancel his ult every time lmao)
	-i'd reccomend setting W aim to off, but if set to on, will cast at target if your mouse isn't pointed towards him
	-i'd also recc turning the auto E off, but if set to on, if you're out of q range of a target, it will E to jump to an allied champ/minion that's in range of your target
	-1.2 update: added Q lasthit+ smart Q waveclear logic, 2 R keys, one of which will only R target into Wall, (also added was W integration with a spelldodge script that's not included here, idk if this broke any previous functionality)
DevxGnar: 
		- changed q/w prediction
		- will cast boulder no matter if collision if you're near target as q aoe will hit even if minions in the way
		-q toggle key 
		-dont use e or r logic, bro do that shit manually
		
DevXMorde:	
			-semimanual e key
			-range sliders
			-added GGprediction 
			-casts e a (variable, use slider, recommend around 100) behind them (for more accurate hitting)
			
i might have messed with other devx stuff, i was trying to make a good syndra before I just gave up.

drawcircle: it draws a circle, i paid $3 a few months ago to impuls to write me this bc i had no idea how to code lmao. (check commented code in drawcircle for a couple things to uncomment for testing stuff, using hasbuff on myself or target dummy i'm shooting spell at to find buff titles is convenient)

GGAIO Twitch: -improved twitch damage calcs, adding drawing on target when passive or passive+E if up will kill through their hp/second regen
			-i'd still recc using E manually, but this makes understanding AP twitch damage thresholds MUCH easier.

PussyKassadin
	-fixed bugs that caused crashes and bad coding causing kass to stand still after w autoattacking
	-tweaked R range logic a bit
	-won't use R randomly to stack up (you can do that bro, script will just grief you)
	-intended for use with test.lua and r key bound to "L"

PussyVelkoz
	-fixed r semimanual key
	-tweaked logic a bit
	-"Q Harass" option also toggles whether the script will try to Q1 diagonally to hit (reccomended off, do this yourself)
	-Q2 will use even if combo button not held down
	-1.2 update: added slider to activate Q a set distance early to account for ping (or if enemies keep walking towards you) i'd set this number to a little over your ping, i have 60 ping, i use like 70.
PussyAnivia
	-improved q2 detection and logic (anivia will double proc q (both flyover dmg and recast dmg hitting) consistently now)
	-option to q2 on only target or any champ
	-q on/off toggle and press keys (toggle will cast with high hitchance, press with normal)
	-harass key now just casts r (uncomment code for chasing w usage)
	-flee w
	-NO AUTO R LOGIC IN SCRIPT

PussyAhri
	-idk it's prob pretty similar but ik i changed some values
	-key to cast e, if flash is up, will cast e at target up to 1300 or so units away ignoring collision (casts e normally if flash not up)
	-press key then flash to different angle for flash charm (once a-fucking-gain, practice tool this)
	-use r manually, duh
	-1.2 update:added e flash key (test this out in practice tool, it only casts E if there are no collisions b/t your flash position and the target)

SchulepinLucian:
		-don't use script E, just use test.lua and manual E, trust me
		-reworked  logic a bit, would recc using the "E priority" option
		-if someone looks at the code, they'll see I put in E logic that would shortcast E if mouse was close to lucian for max dps, would longdash if mouse was far away.
		-might still be bugs if you turned e usage on, not sure


ImpulsVlad
	- tons of shit
	-improved logic
	- press key2 to start channeling e, will auto e2 if charged and will hit
	- press key3 to channel e, will auto e2 as soon as charged (so you dont get slowed)
	-use those keys instead of burst key

MomzIrelia
	-best irelia script on the platform no contest, i put wayyy too much work into this, tho credit to Momz for updating pussyaio irelia
	-redone e logic, will hit multiple targets
	-draws q killable minions/monsters 
	-tons more logic
	-dont use gapcloser q or laneclear q, just use "A" aka flee to dash to minions near your cursor while fighting or clearing etc
	-script will auto reactivate w, but cast w1 yourself

ctrlzed
	-a reworked version of pussyzed with better rdmgcalcs, draws for calcs and clones that you can TP back to, better shadow tracking for Q logic,massively changed Q logic, manual W/Q keys, Q lasthitting, etc
	-there are better ways to track w/r shadows, i'll redo that at some point to have better fps
	-i don't think i made it a menu option, but pressing A makes you cast shadow towards enemy
	-Use harass for automatic q/w/e combo, for combo I'd recc using W and R yourself (I didn't edit w combo logic at all, i didn't make many changes to r logic as I use manually)
	-IMPORTANT: THIS SHIT IS NOT POLISHED, I'M ONLY INCLUDING IT HERE BECAUSE THERE ARE NO OTHER FUNCTIONING ZED SCRIPTS. ZED IS HARD TO PLAY MANUALLY, AND YOU SHOULD ONLY CONSIDER USING THIS IF YOU CAN PLAY ZED AT LEAST PARTIALLY
	MANUALLY, WHICH REQUIRES PATIENCE FOR HIS TERRIBLE EARLYGAME, AND BRAINPOWER FOR USING W AND R. GO TRY THIS SHIT IN PRACTICETOOL FOR A LONG TIME.
14kennen
	-added much smarter w logic (seriously, kennen needed it),Q lasthit, dmgcalcs
clovervex:
	-made vex a little more intelligent when it comes to using E then Q1
	-fixed Qprediction logic to understand how vex Q changes missile speeds past 500 range (wtf why wasn't this done in orignal script)
	-added extended E casting logic (this logic takes 2 mins to copy over to any script like this that you want, someone asked me to do it to pussysoraka so i did, it's super ez to do and makes a huge difference)
Killerannie
	-since I was working with hens, what he hasn't implemented are very minor things
	-this doesn't include the autoupdate function, and GoS will recognize it as a separate script
	-2 r keys (one to consider flash, the other won't)
	-r keys will work even if you're also simultaneously using combo
	-controllable R buffers for both combo modes
	-combo damage%ages are drawn when not killable
KillerKarthus
	-Q extended+Q snap to max range logic (again, extended cast logic is almost a requirement to have with champs with circlular skillshots, it's the major shortcoming of all current preds)
	-R damage calcs consider precision runes, liandries, shadowflame
	-lvl slider for Q while in AA range lasthitting 
	-toggle+lvl slider for weaving in Q and aas without canceling the aas(extremely important early for lane karthus)
	-experimental E lasthit
	-option to only R in zombie mode at the last second
  14Yasuo
	- beyblade logic needs a menu setting to enable/disable R,
	-yasuo's animation speed changes fluidly with attackspeed, so that as well as ping means that values that worked for me might not work in all situations, i tried to adjust for EQ animation speed, but it could use work
	-iirc the beyblade key will always try to keyblade as well, but you can't keyblade if you have low attack speed, so just R manually
	-I think people should always disable using E in combo, and use the "flee" key to dash towards cursor, I modified the original function so it won't dash perpendicularly to your cursor, made the flee key work during combo, and added an option to Q while Eing if circular Q will hit
	-Lasthit out of aa range minions 
	-some other random bugfixes/improvements
	if you know how to code and enjoy using this, try practice tooling and giving me feedback about what to change with the combo airblade and separate beyblade/keyblade key to make it as consistent as possible.
