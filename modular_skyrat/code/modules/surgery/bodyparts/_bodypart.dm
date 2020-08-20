//yes i modularized bodyparts entirely
/obj/item/bodypart
	name = "limb"
	desc = "Why is it detached..."
	force = 3
	throwforce = 3
	icon = 'modular_skyrat/icons/mob/human_parts.dmi'
	w_class = WEIGHT_CLASS_SMALL
	icon_state = ""
	layer = BELOW_MOB_LAYER //so it isn't hidden behind objects when on the floor
	var/mob/living/carbon/owner = null
	var/mob/living/carbon/original_owner = null
	var/needs_processing = FALSE

	var/body_zone //BODY_ZONE_CHEST, BODY_ZONE_L_ARM, etc , used for def_zone
	var/list/aux_icons // associative list, currently used on hands
	var/body_part = null //bitflag used to check which clothes cover this bodypart
	var/use_digitigrade = NOT_DIGITIGRADE //Used for alternate legs, useless elsewhere
	var/list/embedded_objects = list()
	var/held_index = 0 //are we a hand? if so, which one!
	var/is_pseudopart = FALSE //For limbs that don't really exist, eg chainsaws

	var/disabled = BODYPART_NOT_DISABLED //If disabled, limb is as good as missing
	var/body_damage_coeff = 1 //Multiplier of the limb's damage that gets applied to the mob
	var/stam_damage_coeff = 0.75
	var/brutestate = 0
	var/burnstate = 0
	var/brute_dam = 0
	var/burn_dam = 0
	var/stamina_dam = 0
	var/max_stamina_damage = 0
	var/incoming_stam_mult = 1 //Multiplier for incoming staminaloss, decreases when taking staminaloss when the limb is disabled, resets back to 1 when limb is no longer disabled.
	var/max_damage = 0
	var/stam_heal_tick = 0		//per Life(). Defaults to 0 due to citadel changes

	var/brute_reduction = 0 //Subtracted to brute damage taken
	var/burn_reduction = 0	//Subtracted to burn damage taken

	//Coloring and proper item icon update
	var/skin_tone = ""
	var/body_gender = ""
	var/species_id = ""
	var/color_src
	var/base_bp_icon //Overrides the icon being used for this limb. This is mainly for downstreams, implemented and maintained as a favor in return for implementing synths. And also because should_draw_* for icon overrides was pretty messy. You're welcome.
	var/should_draw_gender = FALSE
	var/species_color = ""
	var/mutation_color = ""
	var/no_update = 0
	var/body_markings = ""	//for bodypart markings
	var/body_markings_icon = 'modular_citadel/icons/mob/mam_markings.dmi'
	var/list/markings_color = list()
	var/aux_marking
	var/digitigrade_type

	var/animal_origin = null //for nonhuman bodypart (e.g. monkey)
	var/dismemberable = 1 //whether it can be dismembered with a weapon.

	var/px_x = 0
	var/px_y = 0

	var/species_flags_list = list()
	var/dmg_overlay_type //the type of damage overlay (if any) to use when this bodypart is bruised/burned.

	//Damage messages used by help_shake_act()
	var/no_brute_msg = "not bruised"
	var/light_brute_msg = "bruised"
	var/medium_brute_msg = "battered"
	var/heavy_brute_msg = "mangled"

	var/no_burn_msg = "not burnt"
	var/light_burn_msg = "numb"
	var/medium_burn_msg = "blistered"
	var/heavy_burn_msg = "peeling away"

	/// Bobmed variables
	var/parent_bodyzone //body zone that is considered a "parent" of this bodypart's zone
	var/dismember_bodyzone //body zone that receives wound when this limb is dismembered
	var/list/starting_children = list() //children that are already "inside" this limb on spawn. could be organs or limbs.
	var/list/children_zones = list() //body zones that are considered "children" of this bodypart's zone
	var/list/heal_zones = list() //body zones that are healed in "multiple" mode on medical items
	var/amputation_point //descriptive string used in amputation.
	var/obj/item/cavity_item
	var/cremation_progress = 0 //Gradually increases while burning when at full damage, destroys the limb when at 100
	/// The wounds currently afflicting this body part
	var/list/wounds = list()
	/// The scars currently afflicting this body part
	var/list/scars = list()
	/// Our current stored wound damage multiplier
	var/wound_damage_multiplier = 1
	/// This number is subtracted from all wound rolls on this bodypart, higher numbers mean more defense, negative means easier to wound
	var/wound_resistance = 0
	/// When this bodypart hits max damage, this number is added to all wound rolls. Obviously only relevant for bodyparts that have damage caps.
	var/disabled_wound_penalty = 15
	/// How much we multiply the dismemberment roll chance by, when rolling for dismemberment
	var/dismember_mod = 1
	/// How much we multiply the disembowelment roll chance by, when rolling for disembowelment
	var/disembowel_mod = 1

	/// A hat won't cover your face, but a shirt covering your chest will cover your... you know, chest
	var/scars_covered_by_clothes = TRUE
	/// Descriptions for the locations on the limb for scars to be assigned, just cosmetic
	var/list/specific_locations = list("general area")
	/// So we know if we need to scream if this limb hits max damage
	var/last_maxed
	/// How much generic bleedstacks we have on this bodypart
	var/generic_bleedstacks = 0
	/// If we have a gauze wrapping currently applied (not including splints)
	var/obj/item/stack/current_gauze
	/// If someone has written something on us
	var/etching = ""
	/// Used for bodypart flags, currently used just to identify whether it is organic or not and to give bleed suppression
	var/status = BODYPART_ORGANIC
	/// Self explanatory
	var/disembowable = TRUE
	/// Maximum weight for a cavity item
	var/max_cavity_size = WEIGHT_CLASS_TINY
	/// Synthetic bodyparts can have patches applied but are harder to repair by conventional means
	var/synthetic = FALSE
	/// For robotic limbs that pretend to be organic, for the sake of features, icon paths etc. etc.
	var/render_like_organic = FALSE
	/// This is used for pseudolimbs. Basically replaces the mob overlay icon with this.
	var/mutable_appearance/custom_overlay = null
	/// These were head vars before, but i had to generify behavior for edge cases
	/// (IPCs have their brain in da chest)
	var/mob/living/brain/brainmob = null
	var/obj/item/organ/brain/brain = null
	/// If something is currently grasping this bodypart and trying to staunch bleeding (see [/obj/item/grasp_self])
	var/obj/item/self_grasp/grasped_by

/obj/item/bodypart/Initialize()
	. = ..()
	if(starting_children.len)
		for(var/I in starting_children)
			new I(src)

/obj/item/bodypart/Topic(href, href_list)
	. = ..()
	if(href_list["gauze"])
		var/mob/living/carbon/C = usr
		if(!istype(C) || !C.canUseTopic(owner, TRUE, FALSE, FALSE) || !current_gauze)
			return
		if(C == owner)
			owner.visible_message("<span class='warning'>[owner] starts ripping off \the [current_gauze] from [owner.p_their()] [src.name]!</span>",
								"<span class='warning'>You start ripping off \the [current_gauze] from your name [src.name]!</span>")
			if(do_mob(owner, owner, 5 SECONDS))
				owner.visible_message("<span class='warning'>[owner] rips \the [current_gauze] from [owner.p_their()] [src.name], destroying it in the process!</span>",
									"<span class='warning'>You rip \the [current_gauze] from your [src.name], destroying it in the process!</span>")
				playsound(owner, 'modular_skyrat/sound/effects/clothripping.ogg', 40, 0, -4)
				remove_gauze(FALSE)
			else
				to_chat(owner, "<span class='warning'>You fail to rip \the [current_gauze] on your [src.name] off.</span>")
		else
			if(do_mob(usr, owner, 3 SECONDS))
				usr.visible_message("<span class='warning'>[usr] rips \the [current_gauze] from [owner]'s [src.name], destroying it in the process!</span>",
								"<span class='warning'>You rip \the [current_gauze] from [owner]'s [src.name], destroying it in the process!</span>")
				playsound(owner, 'modular_skyrat/sound/effects/clothripping.ogg', 40, 0, -4)
				remove_gauze(FALSE)
			else
				to_chat(usr, "<span class='warning'>You fail to rip \the [current_gauze] from [owner]'s [src.name].</span>")

/obj/item/bodypart/examine(mob/user)
	. = ..()
	for(var/woundie in wounds)
		var/datum/wound/W = woundie
		if(istype(W))
			. += "[W.get_examine_description(user, FALSE)]"
	for(var/scarrie in scars)
		var/datum/scar/S = scarrie
		if(istype(S))
			. += "[S.get_examine_description(user, FALSE)]"
	if(brute_dam > DAMAGE_PRECISION)
		. += "<span class='warning'>This limb has [brute_dam > 30 ? "severe" : "minor"] bruising.</span>"
	if(burn_dam > DAMAGE_PRECISION)
		. += "<span class='warning'>This limb has [burn_dam > 30 ? "severe" : "minor"] burns.</span>"
	if(etching)
		. += "<span class='notice'>[src] has <b>\"[etching]\"</b> inscribed on it.</span>"
	if((status & BODYPART_ROBOTIC) && (status & BODYPART_ORGANIC))
		. += "<span class='notice'>[src] is seemingly of both inorganic and organic nature.</span>"
	else if(status & BODYPART_ROBOTIC)
		. += "<span class='notice'>[src] is seemingly of inorganic nature.</span>"
	else if(status & BODYPART_ORGANIC)
		. += "<span class='notice'>[src] is seemingly of organic nature.</span>"
	if(status & BODYPART_NOBLEED)
		. += "<span class='notice'>[src] is impervious to [status & BODYPART_ORGANIC ? "bleeding" : "leakage"].</span>"
	for(var/obj/item/bodypart/BP in src)
		if(BP.body_zone in children_zones)
			. += "<span class='notice'>[src] has \a [lowertext(BP.name)] attached. Use a sharp item to cut it off!</span>"

/obj/item/bodypart/blob_act()
	take_damage(max_damage)

/obj/item/bodypart/Destroy()
	if(owner)
		owner.bodyparts -= src
		owner = null
	if(cavity_item)
		QDEL_NULL(cavity_item)
	return ..()

/obj/item/bodypart/attack(mob/living/carbon/C, mob/user)
	if(ishuman(C))
		var/mob/living/carbon/human/H = C
		if(HAS_TRAIT(C, TRAIT_LIMBATTACHMENT))
			if(!H.get_bodypart(body_zone) && !animal_origin)
				if(H == user)
					H.visible_message("<span class='warning'>[H] jams [src] into [H.p_their()] empty socket!</span>",\
					"<span class='notice'>You force [src] into your empty socket, and it locks into place!</span>")
				else
					H.visible_message("<span class='warning'>[user] jams [src] into [H]'s empty socket!</span>",\
					"<span class='notice'>[user] forces [src] into your empty socket, and it locks into place!</span>")
				user.temporarilyRemoveItemFromInventory(src, TRUE)
				attach_limb(C)
				return
	..()

/obj/item/bodypart/attackby(obj/item/W, mob/user, params)
	if(W.sharpness)
		add_fingerprint(user)
		if(!contents.len)
			to_chat(user, "<span class='warning'>There is nothing left inside [src]!</span>")
			return
		playsound(loc, 'sound/weapons/slice.ogg', 50, 1, -1)
		user.visible_message("<span class='warning'>[user] begins to cut open [src].</span>",\
			"<span class='notice'>You begin to cut open [src]...</span>")
		if(do_after(user, 54, target = src))
			drop_organs(user)
	else if(istype(W, /obj/item/cautery) && user.a_intent == INTENT_HELP)
		var/badboy = input(user, "What do you want to inscribe on [src]?", "Malpractice", "") as text
		if(badboy)
			badboy = strip_html_simple(badboy)
			etching = "<b>[badboy]</b>"
			user.visible_message("<span class='notice'>[user] etches something on \the [src] with \the [W].</span>", " <span class='notice'>You etch \"[badboy]\" on [src] with \the [W]. Hehe.</span>")
		else
			return ..()
	else
		return ..()

/obj/item/bodypart/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	..()
	if(!(status & BODYPART_ROBOTIC))
		playsound(get_turf(src), 'sound/misc/splort.ogg', 50, 1, -1)
	pixel_x = rand(-3, 3)
	pixel_y = rand(-3, 3)

//empties the bodypart from its organs and other things inside it
/obj/item/bodypart/proc/drop_organs(mob/user, violent_removal)
	var/turf/T = get_turf(src)
	if(!(status & BODYPART_ROBOTIC))
		playsound(T, 'sound/misc/splort.ogg', 50, 1, -1)
	if(current_gauze)
		remove_gauze(drop_gauze = FALSE)
	for(var/X in get_organs())
		var/obj/item/organ/O = X
		O.transfer_to_limb(src, owner)
	for(var/obj/item/I in src)
		if(I == brain)
			if(user)
				user.visible_message("<span class='warning'>[user] saws [src] open and pulls out a brain!</span>", "<span class='notice'>You saw [src] open and pull out a brain.</span>")
			if(brainmob)
				brainmob.container = null
				brainmob.forceMove(brain)
				brain.brainmob = brainmob
				brainmob = null
			brain.forceMove(T)
			brain = null
			update_icon_dropped()
		else
			if(istype(I, /obj/item/reagent_containers/pill))
				for(var/datum/action/item_action/hands_free/activate_pill/AP in I.actions)
					qdel(AP)
			I.forceMove(T)
	if(cavity_item)
		cavity_item = null

/obj/item/bodypart/proc/get_organs()
	if(!owner)
		return FALSE

	var/list/our_organs
	for(var/X in owner.internal_organs) //internal organs inside the dismembered limb are dropped.
		var/obj/item/organ/O = X
		var/org_zone = check_zone(O.zone)
		if(org_zone == body_zone)
			LAZYADD(our_organs, O)

	return our_organs

/obj/item/bodypart/proc/consider_processing()
	if(stamina_dam > DAMAGE_PRECISION)
		. = TRUE
	//else if.. else if.. so on.
	else
		. = FALSE
	needs_processing = .

//Return TRUE to get whatever mob this is in to update health.
/obj/item/bodypart/proc/on_life()
	if(stam_heal_tick && stamina_dam > DAMAGE_PRECISION)					//DO NOT update health here, it'll be done in the carbon's life.
		if(heal_damage(brute = 0, burn = 0, stamina = (stam_heal_tick * (disabled ? 2 : 1)), only_robotic = FALSE, only_organic = FALSE, updating_health = FALSE))
			. |= BODYPART_LIFE_UPDATE_HEALTH

//Applies brute and burn damage to the organ. Returns 1 if the damage-icon states changed at all.
//Damage will not exceed max_damage using this proc
//Cannot apply negative damage
/obj/item/bodypart/proc/receive_damage(brute = 0, burn = 0, stamina = 0, blocked = 0, updating_health = TRUE, required_status = null, wound_bonus = 0, bare_wound_bonus = 0, sharpness = SHARP_NONE) // maybe separate BRUTE_SHARP and BRUTE_OTHER eventually somehow hmm
	var/hit_percent = (100-blocked)/100
	if((!brute && !burn && !stamina) || hit_percent <= 0)
		return FALSE
	if(owner && (owner.status_flags & GODMODE))
		return FALSE	//godmode

	if(required_status && !(status & required_status))
		return FALSE

	var/dmg_mlt = CONFIG_GET(number/damage_multiplier) * hit_percent
	brute = round(max(brute * dmg_mlt, 0),DAMAGE_PRECISION)
	burn = round(max(burn * dmg_mlt, 0),DAMAGE_PRECISION)
	stamina = round(max(stamina * dmg_mlt, 0),DAMAGE_PRECISION)
	brute = max(0, brute - brute_reduction)
	burn = max(0, burn - burn_reduction)
	//No stamina scaling.. for now..

	if(!brute && !burn && !stamina)
		return FALSE

	brute *= wound_damage_multiplier
	burn *= wound_damage_multiplier

	switch(animal_origin)
		if(ALIEN_BODYPART,LARVA_BODYPART) //aliens take double burn //nothing can burn with so much snowflake code around
			burn *= 2
	/*
	// START WOUND HANDLING
	*/

	// what kind of wounds we're gonna roll for, take the greater between brute and burn, then if it's brute, we subdivide based on sharpness
	var/wounding_type = (brute > burn ? WOUND_BLUNT : WOUND_BURN)
	var/wounding_dmg = max(brute, burn)

	var/mangled_state = get_mangled_state()
	var/bio_state = owner.get_biological_state()

	var/easy_dismember = HAS_TRAIT(owner, TRAIT_EASYDISMEMBER) // if we have easydismember, we don't reduce damage when redirecting damage to different types (slashing weapons on mangled/skinless limbs attack at 100% instead of 50%)

	// first we check the sharpness var to see if we're slashing or piercing rather than plain blunt
	if(wounding_type == WOUND_BLUNT)
		if(sharpness == SHARP_EDGED)
			wounding_type = WOUND_SLASH
		else if(sharpness == SHARP_POINTY)
			wounding_type = WOUND_PIERCE

	// Incised limbs are obviously weaker
	if(locate(/datum/wound/slash/critical/incision) in wounds)
		switch(wounding_type)
			if(WOUND_BLUNT)
				wounding_dmg *= 1.25
			if(WOUND_SLASH)
				wounding_dmg *= 2
			if(WOUND_PIERCE)
				wounding_dmg *= 1.5
			if(WOUND_INTERNALBLEED)
				wounding_dmg *= 2.25 //well you're just fucked
	
	//Handling for bone only/flesh only/skin only/all of them targets
	// if we're bone only, all cutting attacks go straight to the bone
	if((bio_state & BIO_BONE) && !(bio_state & BIO_FLESH))
		if(wounding_type == WOUND_SLASH)
			wounding_type = WOUND_BLUNT
			if(!easy_dismember)
				wounding_dmg *= 0.5
		else if(wounding_type == WOUND_PIERCE)
			wounding_type = WOUND_BLUNT
			if(!easy_dismember)
				wounding_dmg *= 0.75
		else if(wounding_type == WOUND_INTERNALBLEED)
			wounding_type = WOUND_BLUNT
			if(!easy_dismember)
				wounding_dmg *= 0.65
		
		if((mangled_state & BODYPART_MANGLED_BONE) && (try_disembowel(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus || try_dismember(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus))))
			return
	
	// slime people p much they dont have bone
	else if((bio_state & BIO_FLESH) && !(bio_state & BIO_BONE))
		if(wounding_type == WOUND_BLUNT)
			wounding_type = WOUND_SLASH
			if(!easy_dismember)
				wounding_dmg *= 0.5
		else if(wounding_type == WOUND_PIERCE)
			wounding_dmg *= 1.5 // it's easy to puncture into plain flesh
		else if(wounding_type == WOUND_INTERNALBLEED)
			wounding_dmg *= 1.25 // No bones encasing the organs and blood vessels
		if((mangled_state & BODYPART_MANGLED_MUSCLE) && (try_disembowel(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus || try_dismember(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus))))
			return

	// nothing uses only skin just yet
	else if((bio_state & BIO_SKIN) && !(bio_state & BIO_FLESH) && !(bio_state & BIO_BONE))
		return

	// standard humanoids
	else if(bio_state & BIO_FULL)
		// If there is already a moderate or above cut, the target is just a wee bit softened up
		if((mangled_state & BODYPART_MANGLED_SKIN) && sharpness)
			wounding_dmg *= 1.1
		// if we've already mangled the muscle (critical slash or piercing wound), then the bone is exposed, and we can damage it with sharp weapons at a reduced rate
		// So a big sharp weapon is still all you need to destroy a limb
		else if((mangled_state & (BODYPART_MANGLED_SKIN | BODYPART_MANGLED_MUSCLE)) && sharpness)
			playsound(src, "sound/effects/crackandbleed.ogg", 100)
			if(wounding_type == WOUND_INTERNALBLEED && !easy_dismember)
				wounding_dmg *= 0.8
			if(wounding_type == WOUND_SLASH && !easy_dismember)
				wounding_dmg *= 0.5 // edged weapons pass along 50% of their wounding damage to the bone since the power is spread out over a larger area
			if(wounding_type == WOUND_PIERCE && !easy_dismember)
				wounding_dmg *= 0.75 // piercing weapons pass along 75% of their wounding damage to the bone since it's more concentrated
			wounding_type = WOUND_BLUNT
		else if(mangled_state & BODYPART_MANGLED_BOTH && (try_disembowel(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus || try_dismember(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus))))
			return
	/*
	// END WOUND HANDLING
	*/

	// now we have our wounding_type and are ready to carry on with wounds and dealing the actual damage
	if(owner && wounding_dmg >= WOUND_MINIMUM_DAMAGE && wound_bonus != CANT_WOUND)
		check_wounding(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus)

	var/can_inflict = max_damage - get_damage()
	var/total_damage = brute + burn
	if(total_damage > can_inflict && total_damage > 0) // TODO: the second part of this check should be removed once disabling is all done
		brute = round(brute * (can_inflict / total_damage),DAMAGE_PRECISION)
		burn = round(burn * (can_inflict / total_damage),DAMAGE_PRECISION)

	if(can_inflict <= 0)
		return FALSE

	brute_dam += brute
	burn_dam += burn
	if(status == BODYPART_ROBOTIC)
		if(owner)
			if((brute+burn)>3 && prob((20+brute+burn)))
				do_sparks(3,FALSE,src.owner)

	for(var/i in wounds)
		var/datum/wound/W = i
		W.receive_damage(sharpness, wounding_dmg, wound_bonus)

	//We've dealt the physical damages, if there's room lets apply the stamina damage.
	stamina_dam += round(clamp(stamina, 0, max_stamina_damage - stamina_dam), DAMAGE_PRECISION)

	if(owner && updating_health)
		owner.updatehealth()
		if(stamina > DAMAGE_PRECISION)
			owner.update_stamina()
			. = TRUE
	consider_processing()
	update_disabled()
	return update_bodypart_damage_state() || .

/// Allows us to roll for and apply a wound without actually dealing damage. Used for aggregate wounding power with pellet clouds (note this doesn't let sharp go to bone)
/obj/item/bodypart/proc/painless_wound_roll(wounding_type, phantom_wounding_dmg, wound_bonus, bare_wound_bonus)
	if(!owner || phantom_wounding_dmg <= WOUND_MINIMUM_DAMAGE || wound_bonus == CANT_WOUND)
		return

	var/mangled_state = get_mangled_state()
	var/bio_state = owner.get_biological_state()

	var/easy_dismember = HAS_TRAIT(owner, TRAIT_EASYDISMEMBER) // if we have easydismember, we don't reduce damage when redirecting damage to different types (slashing weapons on mangled/skinless limbs attack at 100% instead of 50%)

	// Incised limbs are obviously weaker
	if(locate(/datum/wound/slash/critical/incision) in wounds)
		switch(wounding_type)
			if(WOUND_BLUNT)
				phantom_wounding_dmg *= 1.25
			if(WOUND_SLASH)
				phantom_wounding_dmg *= 2
			if(WOUND_PIERCE)
				phantom_wounding_dmg *= 1.5
			if(WOUND_INTERNALBLEED)
				phantom_wounding_dmg *= 2.25 //well you're just fucked
	
	//Handling for bone only/flesh only/skin only/all of them targets
	if((bio_state & BIO_BONE) && !(bio_state & BIO_FLESH)) // if we're bone only, all cutting attacks go straight to the bone
		if(wounding_type == WOUND_SLASH)
			wounding_type = WOUND_BLUNT
			if(!easy_dismember)
				phantom_wounding_dmg *= 0.5
		else if(wounding_type == WOUND_PIERCE)
			wounding_type = WOUND_BLUNT
			if(!easy_dismember)
				phantom_wounding_dmg *= 0.75
		else if(wounding_type == WOUND_INTERNALBLEED)
			wounding_type = WOUND_BLUNT
			if(!easy_dismember)
				phantom_wounding_dmg *= 0.65
		
		if((mangled_state & BODYPART_MANGLED_BONE) && (try_disembowel(wounding_type, phantom_wounding_dmg, wound_bonus, bare_wound_bonus || try_dismember(wounding_type, phantom_wounding_dmg, wound_bonus, bare_wound_bonus))))
			return
	
	// slime people p much, they dont have bone
	else if((bio_state & BIO_FLESH) && !(bio_state & BIO_BONE))
		if(wounding_type == WOUND_BLUNT)
			wounding_type = WOUND_SLASH
			if(!easy_dismember)
				phantom_wounding_dmg *= 0.5
		else if(wounding_type == WOUND_PIERCE)
			phantom_wounding_dmg *= 1.5 // it's easy to puncture into plain flesh
		else if(wounding_type == WOUND_INTERNALBLEED)
			phantom_wounding_dmg *= 1.25 // No bones encasing the organs and blood vessels
		if((mangled_state & BODYPART_MANGLED_MUSCLE) && (try_disembowel(wounding_type, phantom_wounding_dmg, wound_bonus, bare_wound_bonus || try_dismember(wounding_type, phantom_wounding_dmg, wound_bonus, bare_wound_bonus))))
			return

	// nothing uses only skin just yet
	else if((bio_state & BIO_SKIN) && !(bio_state & BIO_FLESH) && !(bio_state & BIO_BONE))
		return

	// standard humanoids
	else if(bio_state & BIO_FULL)
		// If there is already a moderate or above cut, the target is just a wee bit softened up
		if((mangled_state & BODYPART_MANGLED_SKIN) && sharpness)
			phantom_wounding_dmg *= 1.1
		// if we've already mangled the muscle (critical slash or piercing wound), then the bone is exposed, and we can damage it with sharp weapons at a reduced rate
		// So a big sharp weapon is still all you need to destroy a limb
		else if((mangled_state & (BODYPART_MANGLED_SKIN | BODYPART_MANGLED_MUSCLE)) && sharpness)
			playsound(src, "sound/effects/crackandbleed.ogg", 100)
			if(wounding_type == WOUND_INTERNALBLEED && !easy_dismember)
				phantom_wounding_dmg *= 0.8
			if(wounding_type == WOUND_SLASH && !easy_dismember)
				phantom_wounding_dmg *= 0.5 // edged weapons pass along 50% of their wounding damage to the bone since the power is spread out over a larger area
			if(wounding_type == WOUND_PIERCE && !easy_dismember)
				phantom_wounding_dmg *= 0.75 // piercing weapons pass along 75% of their wounding damage to the bone since it's more concentrated
			wounding_type = WOUND_BLUNT
		else if((mangled_state & BODYPART_MANGLED_BOTH) && (try_disembowel(wounding_type, phantom_wounding_dmg, wound_bonus, bare_wound_bonus || try_dismember(wounding_type, phantom_wounding_dmg, wound_bonus, bare_wound_bonus))))
			return

	check_wounding(wounding_type, phantom_wounding_dmg, wound_bonus, bare_wound_bonus)

//Heals brute and burn damage for the organ. Returns 1 if the damage-icon states changed at all.
//Damage cannot go below zero.
//Cannot remove negative damage (i.e. apply damage)
/obj/item/bodypart/proc/heal_damage(brute, burn, stamina, only_robotic = FALSE, only_organic = TRUE, updating_health = TRUE)
	if(only_robotic && !(status & BODYPART_ROBOTIC)) //This makes organic limbs not heal when the proc is in Robotic mode.
		return

	if(only_organic && !(status & BODYPART_ORGANIC)) //This makes robolimbs not healable by chems.
		return

	brute_dam	= round(max(brute_dam - brute, 0), DAMAGE_PRECISION)
	burn_dam	= round(max(burn_dam - burn, 0), DAMAGE_PRECISION)
	stamina_dam = round(max(stamina_dam - stamina, 0), DAMAGE_PRECISION)
	if(owner && updating_health)
		owner.updatehealth()
	if(owner.dna && owner.dna.species && (REVIVESBYHEALING in owner.dna.species.species_traits))
		if((owner.health > owner.dna.species.revivesbyhealreq) && !owner.hellbound)
			if((NOBLOOD in owner.dna.species.species_traits) || (owner.blood_volume >= BLOOD_VOLUME_OKAY))
				owner.revive(0)
				owner.cure_husk(0) // If it has REVIVESBYHEALING, it probably can't be cloned. No husk cure.
	consider_processing()
	update_disabled()
	return update_bodypart_damage_state() 

//Returns total damage.
/obj/item/bodypart/proc/get_damage(include_stamina = FALSE)
	var/total = brute_dam + burn_dam
	if(include_stamina)
		total = max(total, stamina_dam)
	return total

//Checks disabled status thresholds
/obj/item/bodypart/proc/update_disabled(var/upparent = TRUE, var/upchildren = TRUE)
	if(!owner)
		return
	set_disabled(is_disabled())
	if(upparent)
		if(parent_bodyzone)
			var/obj/item/bodypart/BP = owner.get_bodypart(parent_bodyzone)
			if(BP)
				BP.update_disabled(TRUE, FALSE)
	if(children_zones)
		for(var/zoner in children_zones)
			var/obj/item/bodypart/CBP = owner.get_bodypart(zoner)
			if(CBP)
				CBP.update_disabled(FALSE, TRUE)

/obj/item/bodypart/proc/is_disabled()
	if(!owner)
		return
	if(HAS_TRAIT(owner, TRAIT_PARALYSIS))
		return BODYPART_DISABLED_PARALYSIS
	for(var/i in wounds)
		var/datum/wound/W = i
		if(W.disabling)
			return BODYPART_DISABLED_WOUND
	if(can_dismember() && !HAS_TRAIT(owner, TRAIT_NODISMEMBER))
		. = disabled //inertia, to avoid limbs healing 0.1 damage and being re-enabled
		if((parent_bodyzone != null) && !istype(src, /obj/item/bodypart/groin))
			if(!(owner.get_bodypart(parent_bodyzone)))
				return BODYPART_DISABLED_DAMAGE
			else
				var/obj/item/bodypart/parent = owner.get_bodypart(parent_bodyzone)
				if(parent.is_disabled())
					return parent.is_disabled()
		if(get_damage(TRUE) >= ((max_damage - min(5, max_damage * 0.1)) * (HAS_TRAIT(owner, TRAIT_EASYLIMBDISABLE) ? 0.6 : 1))) //Easy limb disable disables the limb at 40% health instead of 0%
			if(!last_maxed)
				owner.emote("scream")
				last_maxed = TRUE
			if(stamina_dam >= max_damage)
				return BODYPART_DISABLED_DAMAGE
		else if(disabled && (get_damage(TRUE) <= (max_damage * 0.8))) // reenabled at 80% now instead of 50% as of wounds update
			last_maxed = FALSE
		if(stamina_dam >= max_stamina_damage)
			return BODYPART_DISABLED_DAMAGE
		if(disabled && (get_damage(TRUE) <= (max_damage * 0.5)))
			return BODYPART_NOT_DISABLED
	else
		return BODYPART_NOT_DISABLED

/obj/item/bodypart/proc/check_disabled() //This might be depreciated and should be safe to remove.
	if(!can_dismember() || HAS_TRAIT(owner, TRAIT_NODISMEMBER))
		return
	if(!disabled && (get_damage(TRUE) >= max_damage))
		set_disabled(TRUE)
	else if(disabled && (get_damage(TRUE) <= (max_damage * 0.5)))
		set_disabled(FALSE)


/obj/item/bodypart/proc/set_disabled(new_disabled)
	if(disabled == new_disabled || !owner)
		return FALSE
	disabled = new_disabled
	if(disabled && owner.get_item_for_held_index(held_index))
		owner.dropItemToGround(owner.get_item_for_held_index(held_index))
	owner.update_health_hud() //update the healthdoll
	owner.update_body()
	owner.update_mobility()
	if(!disabled)
		incoming_stam_mult = 1
	return TRUE

//Updates an organ's brute/burn states for use by update_damage_overlays()
//Returns 1 if we need to update overlays. 0 otherwise.
/obj/item/bodypart/proc/update_bodypart_damage_state()
	var/tbrute	= round( (brute_dam/max_damage)*3, 1 )
	var/tburn	= round( (burn_dam/max_damage)*3, 1 )
	if((tbrute != brutestate) || (tburn != burnstate))
		brutestate = tbrute
		burnstate = tburn
		return TRUE
	return FALSE

//Change bodypart status
/obj/item/bodypart/proc/change_bodypart_status(new_limb_status, heal_limb, change_icon_to_default, override = TRUE)
	if(override)
		status = new_limb_status
	else
		status |= new_limb_status
	if(heal_limb)
		burn_dam = 0
		brute_dam = 0
		brutestate = 0
		burnstate = 0

	if(change_icon_to_default)
		if(status & BODYPART_ORGANIC)
			icon = base_bp_icon || DEFAULT_BODYPART_ICON_ORGANIC
		else if(status & BODYPART_ROBOTIC)
			icon = DEFAULT_BODYPART_ICON_ROBOTIC

	if(owner)
		owner.updatehealth()
		owner.update_body() //if our head becomes robotic, we remove the lizard horns and human hair.
		owner.update_hair()
		owner.update_damage_overlays()
		owner.update_medicine_overlays()

//Status related procs
/obj/item/bodypart/proc/is_organic_limb()
	return (status & BODYPART_ORGANIC)

/obj/item/bodypart/proc/is_robotic_limb()
	return (status & BODYPART_ROBOTIC)

/obj/item/bodypart/proc/is_mixed_limb()
	return (is_organic_limb() && is_robotic_limb())

/obj/item/bodypart/proc/can_bleed()
	return (status & BODYPART_NOBLEED)

//to update the bodypart's icon when not attached to a mob
/obj/item/bodypart/proc/update_icon_dropped()
	cut_overlays()
	var/list/standing = get_limb_icon(1)
	if(!standing.len)
		icon_state = initial(icon_state)//no overlays found, we default back to initial icon.
		return
	for(var/image/I in standing)
		I.pixel_x = px_x
		I.pixel_y = px_y
	for(var/obj/item/bodypart/BP in src)
		var/list/substanding = BP.get_limb_icon(1)
		for(var/image/I in substanding)
			I.pixel_x = px_x
			I.pixel_y = px_y
		standing |= substanding
		for(var/obj/item/bodypart/grandchild in BP)
			var/list/subsubstanding = grandchild.get_limb_icon(1)
			for(var/image/I in subsubstanding)
				I.pixel_x = px_x
				I.pixel_y = px_y
			standing |= subsubstanding
			//the ride never ends
			for(var/obj/item/bodypart/ggrandchild in grandchild)
				var/list/subsubsubstanding = ggrandchild.get_limb_icon(1)
				for(var/image/I in subsubsubstanding)
					I.pixel_x = px_x
					I.pixel_y = px_y
				standing |= subsubsubstanding
	if(!standing.len)
		icon_state = initial(icon_state)//no overlays found, we default back to initial icon.
		return
	add_overlay(standing)

/obj/item/bodypart/deconstruct(disassembled = TRUE)
	drop_organs()
	qdel(src)

/**
  * check_wounding() is where we handle rolling for, selecting, and applying a wound if we meet the criteria
  *
  * We generate a "score" for how woundable the attack was based on the damage and other factors discussed in [check_woundings_mods()], then go down the list from most severe to least severe wounds in that category.
  * We can promote a wound from a lesser to a higher severity this way, but we give up if we have a wound of the given type and fail to roll a higher severity, so no sidegrades/downgrades
  *
  * Arguments:
  * * woundtype- Either WOUND_SLASH, WOUND_PIERCE, WOUND_BLUNT, or WOUND_BURN based on the attack type.
  * * damage- How much damage is tied to this attack, since wounding potential scales with damage in an attack (see: WOUND_DAMAGE_EXPONENT)
  * * wound_bonus- The wound_bonus of an attack
  * * bare_wound_bonus- The bare_wound_bonus of an attack
  */
/obj/item/bodypart/proc/check_wounding(woundtype, damage, wound_bonus, bare_wound_bonus)
	// actually roll wounds if applicable
	var/organic = is_organic_limb()
	if(HAS_TRAIT(owner, TRAIT_EASYLIMBDISABLE))
		damage *= 1.5

	var/base_roll = rand(1, round(damage ** WOUND_DAMAGE_EXPONENT))
	var/injury_roll = base_roll
	var/check_gauze = FALSE
	injury_roll += check_woundings_mods(woundtype, damage, wound_bonus, bare_wound_bonus)
	var/list/wounds_checking

	switch(woundtype)
		if(WOUND_BLUNT)
			wounds_checking = WOUND_LIST_BLUNT
			if(!organic)
				wounds_checking = WOUND_LIST_BLUNT_MECHANICAL
			check_gauze = TRUE
		if(WOUND_SLASH)
			wounds_checking = WOUND_LIST_SLASH
			if(!organic)
				wounds_checking = WOUND_LIST_SLASH_MECHANICAL
			check_gauze = TRUE
		if(WOUND_PIERCE)
			wounds_checking = WOUND_LIST_PIERCE
			if(!organic)
				wounds_checking = WOUND_LIST_PIERCE_MECHANICAL
			check_gauze = TRUE
		if(WOUND_BURN)
			wounds_checking = WOUND_LIST_BURN
			if(!organic)
				wounds_checking = WOUND_LIST_BURN_MECHANICAL
			check_gauze = TRUE
		if(WOUND_INTERNALBLEED)
			wounds_checking = WOUND_LIST_INTERNAL_BLEEDING
	
	if(!length(wounds_checking))
		return
	
	//check if there's gauze, and if we should destroy or damage it, before we apply any wounds
	if(current_gauze && check_gauze)
		if(prob(base_roll/4))
			if(prob(base_roll/2))
				owner.visible_message("<span class='danger'>\The [current_gauze] on [owner]'s [src.name] shreds apart completely!</span>", "<span class='userdanger'>\The [current_gauze] on your [src.name] gets completely shredded!</span>")
				var/obj/item/reagent_containers/rag/R = new /obj/item/reagent_containers/rag()
				R.name = "shredded [current_gauze.name]"
				R.desc = "Pretty worthless for medicine now..."
				R.add_mob_blood(owner)
				remove_gauze(drop_gauze = FALSE)
			else
				owner.visible_message("<span class='danger'>\The [current_gauze] on [owner]'s [src.name] falls off!</span>", "<span class='userdanger'>\The [current_gauze] on your [src.name] falls off!</span>")
				current_gauze.add_mob_blood(owner)
				remove_gauze(drop_gauze = TRUE)
		
		else if(prob(base_roll))
			owner.visible_message("<span class='boldwarning'>\The [current_gauze] on [owner]'s [src.name] tears up a bit!</span>", "<span class='danger'>\The [current_gauze] on your [src.name] tears up a bit!</span>")
			for(var/i in wounds)
				var/datum/wound/woundie = i
				if(istype(woundie))
					seep_gauze(current_gauze.absorption_rate * (0.25 * woundie.severity))
			seep_gauze(current_gauze.absorption_rate * round(damage/25, 1))

	// quick re-check to see if bare_wound_bonus applies, for the benefit of log_wound(), see about getting the check from check_woundings_mods() somehow
	if(ishuman(owner))
		var/mob/living/carbon/human/H = owner
		var/list/clothing = H.clothingonpart(src)
		for(var/c in clothing)
			var/obj/item/clothing/clothes_check = c
			// unlike normal armor checks, we tabluate these piece-by-piece manually so we can also pass on appropriate damage the clothing's limbs if necessary
			if(clothes_check.armor.getRating("wound"))
				bare_wound_bonus = 0
				break

	//cycle through the wounds of the relevant category from the most severe down
	for(var/PW in wounds_checking)
		//I fucking hate byond, i cannot see the possible zones without creating a fucking new wound datum
		var/datum/wound/possible_wound = new PW()
		if(!(body_zone in possible_wound.viable_zones)) //Applying this wound won't even work, let's try the next one
			qdel(possible_wound)
			continue
		var/datum/wound/replaced_wound
		for(var/i in wounds)
			var/datum/wound/existing_wound = i
			if(existing_wound.type in wounds_checking)
				if(existing_wound.severity >= initial(possible_wound.severity))
					return
				else
					replaced_wound = existing_wound

		if(possible_wound.threshold_minimum * CONFIG_GET(number/wound_threshold_multiplier) < injury_roll)
			var/datum/wound/new_wound
			if(replaced_wound)
				new_wound = replaced_wound.replace_wound(possible_wound.type)
				log_wound(owner, new_wound, damage, wound_bonus, bare_wound_bonus, base_roll)
				qdel(possible_wound)
			else
				new_wound = new possible_wound.type
				new_wound.apply_wound(src)
				if(new_wound.wound_type == (WOUND_LIST_BURN || WOUND_LIST_BURN_MECHANICAL))
					for(var/datum/wound/slash/critical/incision/inch in wounds) //yes, getting a burn wound cauterizes open incisions
						inch.remove_wound()
				log_wound(owner, new_wound, damage, wound_bonus, bare_wound_bonus, base_roll)
				qdel(possible_wound)
			return new_wound

// try forcing a specific wound, but only if there isn't already a wound of that severity or greater for that type on this bodypart
/obj/item/bodypart/proc/force_wound_upwards(specific_woundtype, smited = FALSE)
	var/datum/wound/new_wound = new specific_woundtype
	for(var/datum/wound/existing_wound in wounds)
		if(existing_wound.wound_type == new_wound.wound_type)
			if(existing_wound.severity < initial(new_wound.severity)) // we only try if the existing one is inferior to the one we're trying to force
				existing_wound.replace_wound(new_wound, smited)
			return

	var/severity = new_wound.severity
	if(!(body_zone in new_wound.viable_zones))
		var/list/fuck = (new_wound.wound_type - new_wound.type)
		for(var/i in fuck)
			new_wound = new i()
			if(!(body_zone in new_wound.viable_zones) || (severity != new_wound.severity))
				qdel(new_wound)
				continue
			else
				break
	if(new_wound)
		new_wound.apply_wound(src, smited = smited)

/**
  * check_wounding_mods() is where we handle the various modifiers of a wound roll
  *
  * A short list of things we consider: any armor a human target may be wearing, and if they have no wound armor on the limb, if we have a bare_wound_bonus to apply, plus the plain wound_bonus
  * We also flick through all of the wounds we currently have on this limb and add their threshold penalties, so that having lots of bad wounds makes you more liable to get hurt worse
  * Lastly, we add the inherent wound_resistance variable the bodypart has (heads and chests are slightly harder to wound), and a small bonus if the limb is already disabled
  *
  * Arguments:
  * * It's the same ones on [receive_damage()]
  */
/obj/item/bodypart/proc/check_woundings_mods(wounding_type, damage, wound_bonus, bare_wound_bonus)
	var/armor_ablation = 0
	var/injury_mod = 0
	
	if(owner && ishuman(owner))
		var/mob/living/carbon/human/H = owner
		var/list/clothing = H.clothingonpart(src)
		for(var/c in clothing)
			var/obj/item/clothing/C = c
			// unlike normal armor checks, we tabluate these piece-by-piece manually so we can also pass on appropriate damage the clothing's limbs if necessary
			armor_ablation += C.armor.getRating("wound")
			if(wounding_type == WOUND_SLASH)
				C.take_damage_zone(body_zone, damage, BRUTE, armour_penetration)
			else if(wounding_type == WOUND_BURN && damage >= 10) // lazy way to block freezing from shredding clothes without adding another var onto apply_damage()
				C.take_damage_zone(body_zone, damage, BURN, armour_penetration)

		if(!armor_ablation)
			injury_mod += bare_wound_bonus

	injury_mod -= armor_ablation
	injury_mod += wound_bonus

	for(var/thing in wounds)
		var/datum/wound/W = thing
		injury_mod += W.threshold_penalty

	var/part_mod = -wound_resistance
	if(is_disabled())
		part_mod += disabled_wound_penalty

	injury_mod += part_mod

	return injury_mod

/// Get whatever wound of the given type is currently attached to this limb, if any
/obj/item/bodypart/proc/get_wound_type(checking_type)
	if(isnull(wounds))
		return

	for(var/datum/wound/W in wounds)
		if(istype(W, checking_type))
			return W

/**
  * update_wounds() is called whenever a wound is gained or lost on this bodypart, as well as if there's a change of some kind on a bone wound possibly changing disabled status
  *
  * Covers tabulating the damage multipliers we have from wounds (burn specifically), as well as deleting our gauze wrapping if we don't have any wounds that can use bandaging
  *
  * Arguments:
  * * replaced- If true, this is being called from the remove_wound() of a wound that's being replaced, so the bandage that already existed is still relevant, but the new wound hasn't been added yet
  */
/obj/item/bodypart/proc/update_wounds(replaced = FALSE)
	var/dam_mul = 1 //initial(wound_damage_multiplier)

	// we can (normally) only have one wound per type, but remember there's multiple types (smites like :B:loodless can generate multiple cuts on a limb)
	for(var/datum/wound/W in wounds)
		dam_mul *= W.damage_multiplier_penalty
	
	if(!LAZYLEN(wounds) && current_gauze && !replaced && (current_gauze.absorption_capacity <= 0))
		owner.visible_message("<span class='notice'>\The [current_gauze] on [owner]'s [name] fall away.</span>", "<span class='notice'>The [current_gauze] on your [name] fall away.</span>")
		remove_gauze(drop_gauze = FALSE)

	wound_damage_multiplier = dam_mul
	update_disabled()

/obj/item/bodypart/proc/get_bleed_rate()
	if(status & BODYPART_NOBLEED)
		return 0

	var/bleed_rate = 0
	if(generic_bleedstacks > 0)
		bleed_rate++
	
	//We want an accurate reading of .len
	listclearnulls(embedded_objects)
	for(var/obj/item/embeddies in embedded_objects)
		if(!embeddies.isEmbedHarmless())
			bleed_rate += 0.5

	for(var/thing in wounds)
		var/datum/wound/W = thing
		if(istype(W))
			bleed_rate += W.blood_flow
	
	if(current_gauze)
		bleed_rate = max(0, bleed_rate - current_gauze.absorption_rate)
	
	if(owner.mobility_flags & ~MOBILITY_STAND)
		bleed_rate *= 0.75

	if(grasped_by)
		bleed_rate *= 0.7
	
	if(!bleed_rate)
		QDEL_NULL(grasped_by)

	return bleed_rate

/obj/item/bodypart/proc/apply_gauze(obj/item/stack/I)
	if(!istype(I) || !I.absorption_capacity)
		return
	QDEL_NULL(current_gauze)
	current_gauze = new I.type(src)
	current_gauze.amount = 1
	I.use(1)
	if(!owner)
		update_icon_dropped()
	else
		owner.update_medicine_overlays()

/obj/item/bodypart/proc/remove_gauze(drop_gauze = FALSE)
	if(!current_gauze)
		return
	
	if(!drop_gauze)
		QDEL_NULL(current_gauze)
	else
		var/turf/drop = get_turf(src)
		current_gauze.forceMove(drop)
		current_gauze = null
	
	if(!owner)
		update_icon_dropped()
	else
		owner.update_medicine_overlays()

/**
  * seep_gauze() is for when a gauze wrapping absorbs blood or pus from wounds, lowering its absorption capacity.
  *
  * The passed amount of seepage is deducted from the bandage's absorption capacity, and if we reach a negative absorption capacity, the bandages fall off and we're left with nothing.
  *
  * Arguments:
  * * seep_amt - How much absorption capacity we're removing from our current bandages (think, how much blood or pus are we soaking up this tick?)
  */
/obj/item/bodypart/proc/seep_gauze(seep_amt = 0)
	if(!current_gauze)
		return
	current_gauze.absorption_capacity -= seep_amt
	if(current_gauze.absorption_capacity <= 0)
		owner.visible_message("<span class='danger'>\The [current_gauze] on [owner]'s [name] fall away in rags.</span>", "<span class='warning'>\The [current_gauze] on your [name] fall away in rags.</span>", vision_distance=COMBAT_MESSAGE_RANGE)
		remove_gauze()

//Update_limb() changes because synths
/obj/item/bodypart/proc/update_limb(dropping_limb, mob/living/carbon/source)
	var/mob/living/carbon/C
	if(source)
		C = source
		if(!original_owner)
			original_owner = source
	else if(original_owner && owner != original_owner) //Foreign limb
		no_update = TRUE
	else
		C = owner
		no_update = FALSE

	if(HAS_TRAIT(C, TRAIT_HUSK) && is_organic_limb())
		species_id = "husk" //overrides species_id
		dmg_overlay_type = "" //no damage overlay shown when husked
		should_draw_gender = FALSE
		color_src = FALSE
		base_bp_icon = DEFAULT_BODYPART_ICON
		no_update = TRUE
		body_markings = "husk" // reeee
		aux_marking = "husk"

	if(no_update)
		return

	if(!animal_origin)
		var/mob/living/carbon/human/H = C
		color_src = FALSE

		var/datum/species/S = H.dna.species
		base_bp_icon = S?.icon_limbs || DEFAULT_BODYPART_ICON
		species_id = S.limbs_id
		species_flags_list = H.dna.species.species_traits

		//body marking memes
		var/list/colorlist = list()
		colorlist.Cut()
		colorlist += ReadRGB("[H.dna.features["mcolor"]]0")
		colorlist += ReadRGB("[H.dna.features["mcolor2"]]0")
		colorlist += ReadRGB("[H.dna.features["mcolor3"]]0")
		colorlist += list(0,0,0, S.hair_alpha)
		for(var/index=1, index<=colorlist.len, index++)
			colorlist[index] = colorlist[index]/255

		if(S.use_skintones)
			skin_tone = H.skin_tone
			base_bp_icon = (base_bp_icon == DEFAULT_BODYPART_ICON) ? DEFAULT_BODYPART_ICON_ORGANIC : base_bp_icon
		else
			skin_tone = ""

		body_gender = H.dna.features["body_model"]
		should_draw_gender = S.sexes

		var/mut_colors = (MUTCOLORS in S.species_traits)
		if(mut_colors)
			if(S.fixed_mut_color)
				species_color = S.fixed_mut_color
			else
				species_color = H.dna.features["mcolor"]
			base_bp_icon = (base_bp_icon == DEFAULT_BODYPART_ICON) ? DEFAULT_BODYPART_ICON_ORGANIC : base_bp_icon
		else
			species_color = ""

		if(base_bp_icon != DEFAULT_BODYPART_ICON)
			color_src = mut_colors ? MUTCOLORS : ((H.dna.skin_tone_override && S.use_skintones == USE_SKINTONES_GRAYSCALE_CUSTOM) ? CUSTOM_SKINTONE : SKINTONE)

		if(S.mutant_bodyparts["legs"])
			if(body_zone == BODY_ZONE_L_LEG || body_zone == BODY_ZONE_R_LEG || body_zone == BODY_ZONE_PRECISE_R_FOOT || body_zone == BODY_ZONE_PRECISE_L_FOOT)
				if(DIGITIGRADE in S.species_traits)
					digitigrade_type = lowertext(H.dna.features["legs"])
			else
				digitigrade_type = null

		if(S.mutant_bodyparts["mam_body_markings"])
			var/datum/sprite_accessory/Smark
			Smark = GLOB.mam_body_markings_list[H.dna.features["mam_body_markings"]]
			if(Smark)
				body_markings_icon = Smark.icon
			if(H.dna.features["mam_body_markings"] != "None")
				body_markings = Smark?.icon_state || lowertext(H.dna.features["mam_body_markings"])
				aux_marking = Smark?.icon_state || lowertext(H.dna.features["mam_body_markings"])
			else
				body_markings = "plain"
				aux_marking = "plain"
			markings_color = list(colorlist)

		else
			body_markings = null
			aux_marking = null

		if(!dropping_limb && H.dna.check_mutation(HULK))
			mutation_color = "00aa00"
		else
			mutation_color = ""

		if(istype(S, /datum/species/synth))
			var/datum/species/synth/synthspecies = S
			var/redundantactualhealth = (100 - (owner.getBruteLoss() + owner.getFireLoss() + owner.getOxyLoss() + owner.getToxLoss() + owner.getCloneLoss()))
			if(synthspecies.isdisguised == FALSE || (synthspecies.actualhealth < 45) || (redundantactualhealth < 45))
				base_bp_icon = initial(synthspecies.icon_limbs)

		dmg_overlay_type = S.damage_overlay_type

	else if(animal_origin == MONKEY_BODYPART) //currently monkeys are the only non human mob to have damage overlays.
		dmg_overlay_type = animal_origin

	if(status == BODYPART_ROBOTIC)
		dmg_overlay_type = "robotic"
		if(!render_like_organic)
			body_markings = null
			aux_marking = null

	if(dropping_limb)
		no_update = TRUE //when attached, the limb won't be affected by the appearance changes of its mob owner.

/obj/item/bodypart/proc/get_limb_icon(dropped)
	cut_overlays()
	icon_state = "" //to erase the default sprite, we're building the visual aspects of the bodypart through overlays alone.

	. = list()

	if(custom_overlay)
		. += custom_overlay
		return

	var/image_dir = 0
	var/icon_gender = (body_gender == FEMALE) ? "f" : "m" //gender of the icon, if applicable

	if(dropped)
		image_dir = SOUTH
		if(dmg_overlay_type)
			if(brutestate)
				. += image('modular_skyrat/icons/mob/dam_mob.dmi', "[dmg_overlay_type]_[body_zone]_[brutestate]0", -DAMAGE_LAYER, image_dir)
			if(burnstate)
				. += image('modular_skyrat/icons/mob/dam_mob.dmi', "[dmg_overlay_type]_[body_zone]_0[burnstate]", -DAMAGE_LAYER, image_dir)
			to_chat(owner, "[dmg_overlay_type]_[body_zone]_[brutestate]0")
			to_chat(owner, "[dmg_overlay_type]_[body_zone]_0[burnstate]")

		if(!isnull(body_markings) && status == BODYPART_ORGANIC)
			if(!use_digitigrade)
				if((body_zone == BODY_ZONE_CHEST) || (body_zone == BODY_ZONE_PRECISE_GROIN))
					. += image(body_markings_icon, "[body_markings]_[body_zone]_[icon_gender]", -MARKING_LAYER, image_dir)
				else
					. += image(body_markings_icon, "[body_markings]_[body_zone]", -MARKING_LAYER, image_dir)
			else
				. += image(body_markings_icon, "[body_markings]_[digitigrade_type]_[use_digitigrade]_[body_zone]", -MARKING_LAYER, image_dir)

	var/image/limb = image(layer = -BODYPARTS_LAYER, dir = image_dir)
	var/list/aux = list()
	var/image/marking
	var/list/auxmarking = list()

	. += limb

	if(animal_origin)
		if(is_organic_limb())
			limb.icon = 'icons/mob/animal_parts.dmi'
			if(species_id == "husk")
				limb.icon_state = "[animal_origin]_husk_[body_zone]"
			else
				limb.icon_state = "[animal_origin]_[body_zone]"
		else
			limb.icon = 'icons/mob/augmentation/augments.dmi'
			limb.icon_state = "[animal_origin]_[body_zone]"
		return

	if(body_zone != BODY_ZONE_HEAD && body_zone != BODY_ZONE_CHEST && body_zone != BODY_ZONE_PRECISE_GROIN)
		should_draw_gender = FALSE

	if(is_organic_limb() || render_like_organic)
		limb.icon = base_bp_icon || 'icons/mob/human_parts.dmi'
		if(should_draw_gender)
			limb.icon_state = "[species_id]_[body_zone]_[icon_gender]"
		else if (use_digitigrade)
			if(base_bp_icon == DEFAULT_BODYPART_ICON_ORGANIC) //Compatibility hack for the current iconset.
				limb.icon_state = "[digitigrade_type]_[use_digitigrade]_[body_zone]"
			else
				limb.icon_state = "[species_id]_[digitigrade_type]_[use_digitigrade]_[body_zone]"
		else
			limb.icon_state = "[species_id]_[body_zone]"

		// Body markings
		if(!isnull(body_markings))
			if(species_id == "husk")
				marking = image('modular_citadel/icons/mob/markings_notmammals.dmi', "husk_[body_zone]", -MARKING_LAYER, image_dir)
			else if(species_id == "husk" && use_digitigrade)
				marking = image('modular_citadel/icons/mob/markings_notmammals.dmi', "husk_[digitigrade_type]_[use_digitigrade]_[body_zone]", -MARKING_LAYER, image_dir)

			else if(!use_digitigrade)
				if((body_zone == BODY_ZONE_CHEST) || (body_zone == BODY_ZONE_PRECISE_GROIN))
					marking = image(body_markings_icon, "[body_markings]_[body_zone]_[icon_gender]", -MARKING_LAYER, image_dir)
				else
					marking = image(body_markings_icon, "[body_markings]_[body_zone]", -MARKING_LAYER, image_dir)
			else
				marking = image(body_markings_icon, "[body_markings]_[digitigrade_type]_[use_digitigrade]_[body_zone]", -MARKING_LAYER, image_dir)

			. += marking

		// Citadel End

		if(aux_icons)
			for(var/I in aux_icons)
				var/aux_layer = aux_icons[I]
				aux += image(limb.icon, "[species_id]_[I]", -aux_layer, image_dir)
				if(!isnull(aux_marking))
					if(species_id == "husk")
						auxmarking += image('modular_citadel/icons/mob/markings_notmammals.dmi', "husk_[I]", -aux_layer, image_dir)
					else
						auxmarking += image(body_markings_icon, "[body_markings]_[I]", -aux_layer, image_dir)
			. += aux
			. += auxmarking
		/*
		if((body_zone in list(BODY_ZONE_PRECISE_GROIN, BODY_ZONE_CHEST)) && (!owner || dropped))
			for(var/obj/item/organ/genital/G in src)
				var/datum/sprite_accessory/S
				var/size = G.size
				switch(G.type)
					if(/obj/item/organ/genital/penis)
						S = GLOB.cock_shapes_list[G.shape]
					if(/obj/item/organ/genital/testicles)
						S = GLOB.balls_shapes_list[G.shape]
					if(/obj/item/organ/genital/vagina)
						S = GLOB.vagina_shapes_list[G.shape]
					if(/obj/item/organ/genital/breasts)
						S = GLOB.breasts_shapes_list[G.shape]

				if(!S || S.icon_state == "none")
					continue
				var/aroused_state = FALSE
				var/accessory_icon = S.icon
				var/do_center = S.center
				var/dim_x = S.dimension_x
				var/dim_y = S.dimension_y

				var/mutable_appearance/genital_overlay = mutable_appearance(accessory_icon, layer = -GENITALS_EXPOSED_LAYER)
				if(do_center)
					genital_overlay = center_image(genital_overlay, dim_x, dim_y)

				genital_overlay.color = G.color

				genital_overlay.icon_state = "[G.slot]_[S.icon_state]_[size][(original_owner?.dna?.species?.use_skintones && !original_owner?.dna?.skin_tone_override) ? "_s" : ""]_[aroused_state]_FRONT"
				. += genital_overlay
		*/
	else
		limb.icon = icon
		if(should_draw_gender)
			limb.icon_state = "[body_zone]_[icon_gender]"
		else
			limb.icon_state = "[body_zone]"

		if(aux_icons)
			for(var/I in aux_icons)
				var/aux_layer = aux_icons[I]
				aux += image(limb.icon, "[I]", -aux_layer, image_dir)
				if(!isnull(aux_marking))
					if(species_id == "husk")
						auxmarking += image('modular_citadel/icons/mob/markings_notmammals.dmi', "husk_[I]", -aux_layer, image_dir)
					else
						auxmarking += image(body_markings_icon, "[body_markings]_[I]", -aux_layer, image_dir)
			. += auxmarking
			. += aux

		if(!isnull(body_markings))
			if(species_id == "husk")
				marking = image('modular_citadel/icons/mob/markings_notmammals.dmi', "husk_[body_zone]", -MARKING_LAYER, image_dir)
			else if(species_id == "husk" && use_digitigrade)
				marking = image('modular_citadel/icons/mob/markings_notmammals.dmi', "husk_digitigrade_[use_digitigrade]_[body_zone]", -MARKING_LAYER, image_dir)

			else if(!use_digitigrade)
				if((body_zone == BODY_ZONE_CHEST) || (body_zone == BODY_ZONE_PRECISE_GROIN))
					marking = image(body_markings_icon, "[body_markings]_[body_zone]_[icon_gender]", -MARKING_LAYER, image_dir)
				else
					marking = image(body_markings_icon, "[body_markings]_[body_zone]", -MARKING_LAYER, image_dir)
			else
				marking = image(body_markings_icon, "[body_markings]_[digitigrade_type]_[use_digitigrade]_[body_zone]", -MARKING_LAYER, image_dir)
			. += marking
		
		/*
		if((body_zone in list(BODY_ZONE_PRECISE_GROIN, BODY_ZONE_CHEST)) && (!owner || dropped))
			for(var/obj/item/organ/genital/G in src)
				var/datum/sprite_accessory/S
				var/size = G.size
				switch(G.type)
					if(/obj/item/organ/genital/penis)
						S = GLOB.cock_shapes_list[G.shape]
					if(/obj/item/organ/genital/testicles)
						S = GLOB.balls_shapes_list[G.shape]
					if(/obj/item/organ/genital/vagina)
						S = GLOB.vagina_shapes_list[G.shape]
					if(/obj/item/organ/genital/breasts)
						S = GLOB.breasts_shapes_list[G.shape]

				if(!S || S.icon_state == "none")
					continue
				var/aroused_state = FALSE
				var/accessory_icon = S.icon
				var/do_center = S.center
				var/dim_x = S.dimension_x
				var/dim_y = S.dimension_y

				var/mutable_appearance/genital_overlay = mutable_appearance(accessory_icon, layer = -GENITALS_EXPOSED_LAYER)
				if(do_center)
					genital_overlay = center_image(genital_overlay, dim_x, dim_y)

				genital_overlay.color = G.color

				genital_overlay.icon_state = "[G.slot]_[S.icon_state]_[size][(original_owner?.dna?.species?.use_skintones && !original_owner?.dna?.skin_tone_override) ? "_s" : ""]_[aroused_state]_FRONT"
				. += genital_overlay
		*/
	if(color_src) //TODO - add color matrix support for base species limbs
		var/draw_color = mutation_color || species_color
		var/grayscale = FALSE
		if(!draw_color)
			draw_color = SKINTONE2HEX(skin_tone)
			grayscale = color_src == CUSTOM_SKINTONE //Cause human limbs have a very pale pink hue by def.
		else
			draw_color = "#[draw_color]"
		if(draw_color)
			if(grayscale)
				limb.icon_state += "_g"
			limb.color = draw_color
			if(aux_icons)
				for(var/a in aux)
					var/image/I = a
					if(grayscale)
						I.icon_state += "_g"
					I.color = draw_color
				if(!isnull(aux_marking))
					for(var/a in auxmarking)
						var/image/I = a
						if(species_id == "husk")
							I.color = "#141414"
						else
							I.color = list(markings_color)

			if(!isnull(body_markings))
				if(species_id == "husk")
					marking.color = "#141414"
				else
					marking.color = list(markings_color)
	
	return
