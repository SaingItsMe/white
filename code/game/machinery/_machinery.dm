/**
 * Machines in the world, such as computers, pipes, and airlocks.
 *
 *Overview:
 *  Used to create objects that need a per step proc call.  Default definition of 'Initialize()'
 *  stores a reference to src machine in global 'machines list'.  Default definition
 *  of 'Destroy' removes reference to src machine in global 'machines list'.
 *
 *Class Variables:
 *  use_power (num)
 *     current state of auto power use.
 *     Possible Values:
 *        NO_POWER_USE -- no auto power use
 *        IDLE_POWER_USE -- machine is using power at its idle power level
 *        ACTIVE_POWER_USE -- machine is using power at its active power level
 *
 *  active_power_usage (num)
 *     Value for the amount of power to use when in active power mode
 *
 *  idle_power_usage (num)
 *     Value for the amount of power to use when in idle power mode
 *
 *  power_channel (num)
 *     What channel to draw from when drawing power for power mode
 *     Possible Values:
 *        AREA_USAGE_EQUIP:0 -- Equipment Channel
 *        AREA_USAGE_LIGHT:2 -- Lighting Channel
 *        AREA_USAGE_ENVIRON:3 -- Environment Channel
 *
 *  component_parts (list)
 *     A list of component parts of machine used by frame based machines.
 *
 *  stat (bitflag)
 *     Machine status bit flags.
 *     Possible bit flags:
 *        BROKEN -- Machine is broken
 *        NOPOWER -- No power is being supplied to machine.
 *        MAINT -- machine is currently under going maintenance.
 *        EMPED -- temporary broken by EMP pulse
 *
 *Class Procs:
 *  Initialize()
 *
 *  Destroy()
 *
 *	update_mode_power_usage()
 *		updates the static_power_usage var of this machine and makes its static power usage from its area accurate.
 *		called after the idle or active power usage has been changed.
 *
 *	update_power_channel()
 *		updates the static_power_usage var of this machine and makes its static power usage from its area accurate.
 *		called after the power_channel var has been changed or called to change the var itself.
 *
 *	unset_static_power()
 *		completely removes the current static power usage of this machine from its area.
 *		used in the other power updating procs to then readd the correct power usage.
 *
 *
 *     Default definition uses 'use_power', 'power_channel', 'active_power_usage',
 *     'idle_power_usage', 'powered()', and 'use_power()' implement behavior.
 *
 *  powered(chan = -1)         'modules/power/power.dm'
 *     Checks to see if area that contains the object has power available for power
 *     channel given in 'chan'. -1 defaults to power_channel
 *
 *  use_power(amount, chan=-1)   'modules/power/power.dm'
 *     Deducts 'amount' from the power channel 'chan' of the area that contains the object.
 *
 *  power_change()               'modules/power/power.dm'
 *     Called by the area that contains the object when ever that area under goes a
 *     power state change (area runs out of power, or area channel is turned off).
 *
 *  RefreshParts()               'game/machinery/machine.dm'
 *     Called to refresh the variables in the machine that are contributed to by parts
 *     contained in the component_parts list. (example: glass and material amounts for
 *     the autolathe)
 *
 *     Default definition does nothing.
 *
 *  process()                  'game/machinery/machine.dm'
 *     Called by the 'machinery subsystem' once per machinery tick for each machine that is listed in its 'machines' list.
 *
 *  process_atmos()
 *     Called by the 'air subsystem' once per atmos tick for each machine that is listed in its 'atmos_machines' list.
 *	Compiled by Aygar
 */
/obj/machinery
	name = "machinery"
	icon = 'icons/obj/stationobjs.dmi'
	desc = "Some kind of machine."
	verb_say = "бипает"
	verb_yell = "вспыхивает"
	pressure_resistance = 15
	pass_flags_self = PASSMACHINE
	max_integrity = 200
	layer = BELOW_OBJ_LAYER //keeps shit coming out of the machine from ending up underneath it.
	flags_ricochet = RICOCHET_HARD
	receive_ricochet_chance_mod = 0.3

	anchored = TRUE
	interaction_flags_atom = INTERACT_ATOM_ATTACK_HAND | INTERACT_ATOM_UI_INTERACT

	var/machine_stat = NONE
	var/use_power = IDLE_POWER_USE
		//0 = dont use power
		//1 = use idle_power_usage
		//2 = use active_power_usage
	///the amount of static power load this machine adds to its area's power_usage list when use_power = IDLE_POWER_USE
	var/idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION
	///the amount of static power load this machine adds to its area's power_usage list when use_power = ACTIVE_POWER_USE
	var/active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION
	///the current amount of static power usage this machine is taking from its area
	var/static_power_usage = 0
	var/power_channel = AREA_USAGE_EQUIP
		//AREA_USAGE_EQUIP,AREA_USAGE_ENVIRON or AREA_USAGE_LIGHT
	///A combination of factors such as having power, not being broken and so on. Boolean.
	var/is_operational = TRUE
	var/wire_compatible = FALSE

	var/list/component_parts = null //list of all the parts used to build it, if made from certain kinds of frames.
	var/panel_open = FALSE
	var/state_open = FALSE
	var/critical_machine = FALSE //If this machine is critical to station operation and should have the area be excempted from power failures.
	var/list/occupant_typecache //if set, turned into typecache in Initialize, other wise, defaults to mob/living typecache
	var/atom/movable/occupant = null
	/// Viable flags to go here are START_PROCESSING_ON_INIT, or START_PROCESSING_MANUALLY. See code\__DEFINES\machines.dm for more information on these flags.
	var/processing_flags = START_PROCESSING_ON_INIT
	/// What subsystem this machine will use, which is generally SSmachines or SSfastprocess. By default all machinery use SSmachines. This fires a machine's process() roughly every 2 seconds.
	var/subsystem_type = /datum/controller/subsystem/machines
	var/obj/item/circuitboard/circuit // Circuit to be created and inserted when the machinery is created

	var/interaction_flags_machine = INTERACT_MACHINE_WIRES_IF_OPEN | INTERACT_MACHINE_ALLOW_SILICON | INTERACT_MACHINE_OPEN_SILICON | INTERACT_MACHINE_SET_MACHINE
	var/fair_market_price = 1
	var/market_verb = "Customer"
	var/payment_department = ACCOUNT_ENG

	/// Do we want to hook into on_enter_area and on_exit_area?
	/// Disables some optimizations
	var/always_area_sensitive = FALSE
	/// For storing and overriding ui id
	var/tgui_id // ID of TGUI interface
	/// What was our power state the last time we updated its appearance?
	/// TRUE for on, FALSE for off, -1 for never checked
	var/appearance_power_state = -1

/obj/machinery/Initialize(mapload)
	if(!armor)
		armor = list(MELEE = 25, BULLET = 10, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 0, RAD = 0, FIRE = 50, ACID = 70)
	. = ..()
	GLOB.machines += src

	if(ispath(circuit, /obj/item/circuitboard))
		circuit = new circuit(src)
		circuit.apply_default_parts(src)

	if(processing_flags & START_PROCESSING_ON_INIT)
		begin_processing()

	if(occupant_typecache)
		occupant_typecache = typecacheof(occupant_typecache)

	return INITIALIZE_HINT_LATELOAD

/obj/machinery/LateInitialize()
	. = ..()
	power_change()
	if(use_power == NO_POWER_USE)
		return

	update_current_power_usage()
	setup_area_power_relationship()

/obj/machinery/Destroy()
	GLOB.machines.Remove(src)
	end_processing()
	dump_inventory_contents()
	QDEL_LIST(component_parts)
	QDEL_NULL(circuit)
	unset_static_power()
	return ..()

/**
 * proc to call when the machine starts to require power after a duration of not requiring power
 * sets up power related connections to its area if it exists and becomes area sensitive
 * does not affect power usage itself
 *
 * Returns TRUE if it triggered a full registration, FALSE otherwise
 * We do this so machinery that want to sidestep the area sensitiveity optimization can
 */
/obj/machinery/proc/setup_area_power_relationship()
	var/area/our_area = get_area(src)
	if(our_area)
		RegisterSignal(our_area, COMSIG_AREA_POWER_CHANGE, PROC_REF(power_change))

	if(HAS_TRAIT_FROM(src, TRAIT_AREA_SENSITIVE, INNATE_TRAIT)) // If we for some reason have not lost our area sensitivity, there's no reason to set it back up
		return FALSE

	become_area_sensitive(INNATE_TRAIT)

	RegisterSignal(src, COMSIG_ENTER_AREA, PROC_REF(on_enter_area))
	RegisterSignal(src, COMSIG_EXIT_AREA, PROC_REF(on_exit_area))
	return TRUE

/**
 * proc to call when the machine stops requiring power after a duration of requiring power
 * saves memory by removing the power relationship with its area if it exists and loses area sensitivity
 * does not affect power usage itself
 */
/obj/machinery/proc/remove_area_power_relationship()
	var/area/our_area = get_area(src)
	if(our_area)
		UnregisterSignal(our_area, COMSIG_AREA_POWER_CHANGE)

	if(always_area_sensitive)
		return

	lose_area_sensitivity(INNATE_TRAIT)
	UnregisterSignal(src, COMSIG_ENTER_AREA)
	UnregisterSignal(src, COMSIG_EXIT_AREA)

/obj/machinery/proc/on_enter_area(datum/source, area/area_to_register)
	SIGNAL_HANDLER
	// If we're always area sensitive, and this is called while we have no power usage, do nothing and return
	if(always_area_sensitive && use_power == NO_POWER_USE)
		return
	update_current_power_usage()
	power_change()
	RegisterSignal(area_to_register, COMSIG_AREA_POWER_CHANGE, PROC_REF(power_change))

/obj/machinery/proc/on_exit_area(datum/source, area/area_to_unregister)
	SIGNAL_HANDLER
	// If we're always area sensitive, and this is called while we have no power usage, do nothing and return
	if(always_area_sensitive && use_power == NO_POWER_USE)
		return
	unset_static_power()
	UnregisterSignal(area_to_unregister, COMSIG_AREA_POWER_CHANGE)

/obj/machinery/proc/set_occupant(atom/movable/new_occupant)
	SHOULD_CALL_PARENT(TRUE)

	SEND_SIGNAL(src, COMSIG_MACHINERY_SET_OCCUPANT, new_occupant)
	occupant = new_occupant

/// Helper proc for telling a machine to start processing with the subsystem type that is located in its `subsystem_type` var.
/obj/machinery/proc/begin_processing()
	var/datum/controller/subsystem/processing/subsystem = locate(subsystem_type) in Master.subsystems
	START_PROCESSING(subsystem, src)

/// Helper proc for telling a machine to stop processing with the subsystem type that is located in its `subsystem_type` var.
/obj/machinery/proc/end_processing()
	var/datum/controller/subsystem/processing/subsystem = locate(subsystem_type) in Master.subsystems
	STOP_PROCESSING(subsystem, src)

/obj/machinery/proc/locate_machinery()
	return

/obj/machinery/process()//If you dont use process or power why are you here
	return PROCESS_KILL

/obj/machinery/proc/process_atmos()//If you dont use process why are you here
	return PROCESS_KILL


///Called when we want to change the value of the machine_stat variable. Holds bitflags.
/obj/machinery/proc/set_machine_stat(new_value)
	if(new_value == machine_stat)
		return
	. = machine_stat
	machine_stat = new_value
	on_set_machine_stat(.)


///Called when the value of `machine_stat` changes, so we can react to it.
/obj/machinery/proc/on_set_machine_stat(old_value)
	if(old_value & (NOPOWER|BROKEN|MAINT))
		if(!(machine_stat & (NOPOWER|BROKEN|MAINT))) //From off to on.
			set_is_operational(TRUE)
	else if(machine_stat & (NOPOWER|BROKEN|MAINT)) //From on to off.
		set_is_operational(FALSE)


/obj/machinery/emp_act(severity)
	. = ..()
	if(use_power && !machine_stat && !(. & EMP_PROTECT_SELF))
		use_power(7500/severity)
		new /obj/effect/temp_visual/emp(loc)

/**
 * Opens the machine.
 *
 * Will update the machine icon and any user interfaces currently open.
 * Arguments:
 * * drop - Boolean. Whether to drop any stored items in the machine. Does not include components.
 */
/obj/machinery/proc/open_machine(drop = TRUE)
	state_open = TRUE
	set_density(FALSE)
	if(drop)
		dump_inventory_contents()
	update_icon()
	updateUsrDialog()

/**
 * Drop every movable atom in the machine's contents list, including any components and circuit.
 */
/obj/machinery/dump_contents()
	// Start by calling the dump_inventory_contents proc. Will allow machines with special contents
	// to handle their dropping.
	dump_inventory_contents()

	// Then we can clean up and drop everything else.
	var/turf/this_turf = get_turf(src)
	for(var/atom/movable/movable_atom in contents)
		movable_atom.forceMove(this_turf)

	// We'll have dropped the occupant, circuit and component parts as part of this.
	set_occupant(null)
	circuit = null
	LAZYCLEARLIST(component_parts)

/**
 * Drop every movable atom in the machine's contents list that is not a component_part.
 *
 * Proc does not drop components and will skip over anything in the component_parts list.
 * Call dump_contents() to drop all contents including components.
 * Arguments:
 * * subset - If this is not null, only atoms that are also contained within the subset list will be dropped.
 */
/obj/machinery/proc/dump_inventory_contents(list/subset = null)
	var/turf/this_turf = get_turf(src)
	for(var/atom/movable/movable_atom in contents)
		if(subset && !(movable_atom in subset))
			continue

		if(movable_atom in component_parts)
			continue

		movable_atom.forceMove(this_turf)

		if(occupant == movable_atom)
			set_occupant(null)

/**
 * Puts passed object in to user's hand
 *
 * Puts the passed object in to the users hand if they are adjacent.
 * If the user is not adjacent then place the object on top of the machine.
 *
 * Vars:
 * * object (obj) The object to be moved in to the users hand.
 * * user (mob/living) The user to recive the object
 */
/obj/machinery/proc/try_put_in_hand(obj/object, mob/living/user)
	if(!issilicon(user) && in_range(src, user))
		user.put_in_hands(object)
	else
		object.forceMove(drop_location())

/obj/machinery/proc/can_be_occupant(atom/movable/am)
	return occupant_typecache ? is_type_in_typecache(am, occupant_typecache) : isliving(am)

/obj/machinery/proc/close_machine(atom/movable/target = null)
	state_open = FALSE
	set_density(TRUE)
	if(!target)
		for(var/am in loc)
			if (!(can_be_occupant(am)))
				continue
			var/atom/movable/AM = am
			if(AM.has_buckled_mobs())
				continue
			if(isliving(AM))
				var/mob/living/L = am
				if(L.buckled || L.mob_size >= MOB_SIZE_LARGE)
					continue
			target = am

	var/mob/living/mobtarget = target
	if(target && !target.has_buckled_mobs() && (!isliving(target) || !mobtarget.buckled))
		set_occupant(target)
		target.forceMove(src)
	updateUsrDialog()
	update_icon()

///updates the use_power var for this machine and updates its static power usage from its area to reflect the new value
/obj/machinery/proc/update_use_power(new_use_power)
	SHOULD_CALL_PARENT(TRUE)
	if(new_use_power == use_power)
		return FALSE

	unset_static_power()

	var/new_usage = 0
	switch(new_use_power)
		if(IDLE_POWER_USE)
			new_usage = idle_power_usage
		if(ACTIVE_POWER_USE)
			new_usage = active_power_usage

	if(use_power == NO_POWER_USE)
		setup_area_power_relationship()
	else if(new_use_power == NO_POWER_USE)
		remove_area_power_relationship()

	static_power_usage = new_usage

	if(new_usage)
		var/area/our_area = get_area(src)
		our_area?.addStaticPower(new_usage, DYNAMIC_TO_STATIC_CHANNEL(power_channel))

	use_power = new_use_power

	return TRUE

///updates the power channel this machine uses. removes the static power usage from the old channel and readds it to the new channel
/obj/machinery/proc/update_power_channel(new_power_channel)
	SHOULD_CALL_PARENT(TRUE)
	if(new_power_channel == power_channel)
		return FALSE

	var/usage = unset_static_power()

	var/area/our_area = get_area(src)

	if(our_area && usage)
		our_area.addStaticPower(usage, DYNAMIC_TO_STATIC_CHANNEL(new_power_channel))

	power_channel = new_power_channel

	return TRUE

///internal proc that removes all static power usage from the current area
/obj/machinery/proc/unset_static_power()
	SHOULD_NOT_OVERRIDE(TRUE)
	var/old_usage = static_power_usage

	var/area/our_area = get_area(src)

	if(our_area && old_usage)
		our_area.removeStaticPower(old_usage, DYNAMIC_TO_STATIC_CHANNEL(power_channel))
		static_power_usage = 0

	return old_usage

/**
 * sets the power_usage linked to the specified use_power_mode to new_usage
 * e.g. update_mode_power_usage(ACTIVE_POWER_USE, 10) sets active_power_use = 10 and updates its power draw from the machines area if use_power == ACTIVE_POWER_USE
 *
 * Arguments:
 * * use_power_mode - the use_power power mode to change. if IDLE_POWER_USE changes idle_power_usage, ACTIVE_POWER_USE changes active_power_usage
 * * new_usage - the new value to set the specified power mode var to
 */
/obj/machinery/proc/update_mode_power_usage(use_power_mode, new_usage)
	SHOULD_CALL_PARENT(TRUE)
	if(use_power_mode == NO_POWER_USE)
		stack_trace("trying to set the power usage associated with NO_POWER_USE in update_mode_power_usage()!")
		return FALSE

	unset_static_power() //completely remove our static_power_usage from our area, then readd new_usage

	switch(use_power_mode)
		if(IDLE_POWER_USE)
			idle_power_usage = new_usage
		if(ACTIVE_POWER_USE)
			active_power_usage = new_usage

	if(use_power_mode == use_power)
		static_power_usage = new_usage

	var/area/our_area = get_area(src)

	if(our_area)
		our_area.addStaticPower(static_power_usage, DYNAMIC_TO_STATIC_CHANNEL(power_channel))

	return TRUE

///makes this machine draw power from its area according to which use_power mode it is set to
/obj/machinery/proc/update_current_power_usage()
	if(static_power_usage)
		unset_static_power()

	var/area/our_area = get_area(src)
	if(!our_area)
		return FALSE

	switch(use_power)
		if(IDLE_POWER_USE)
			static_power_usage = idle_power_usage
		if(ACTIVE_POWER_USE)
			static_power_usage = active_power_usage
		if(NO_POWER_USE)
			return

	if(static_power_usage)
		our_area.addStaticPower(static_power_usage, DYNAMIC_TO_STATIC_CHANNEL(power_channel))

	return TRUE

///Called when we want to change the value of the `is_operational` variable. Boolean.
/obj/machinery/proc/set_is_operational(new_value)
	if(new_value == is_operational)
		return
	. = is_operational
	is_operational = new_value
	on_set_is_operational(.)


///Called when the value of `is_operational` changes, so we can react to it.
/obj/machinery/proc/on_set_is_operational(old_value)
	return

///Called when we want to change the value of the `panel_open` variable. Boolean.
/obj/machinery/proc/set_panel_open(new_value)
	if(panel_open == new_value)
		return
	var/old_value = panel_open
	panel_open = new_value
	on_set_panel_open(old_value)

///Called when the value of `panel_open` changes, so we can react to it.
/obj/machinery/proc/on_set_panel_open(old_value)
	return

/// Toggles the panel_open var. Defined for convienience
/obj/machinery/proc/toggle_panel_open()
	set_panel_open(!panel_open)

/obj/machinery/can_interact(mob/user)
	if((machine_stat & (NOPOWER|BROKEN)) && !(interaction_flags_machine & INTERACT_MACHINE_OFFLINE)) // Check if the machine is broken, and if we can still interact with it if so
		return FALSE

	if(isAdminGhostAI(user))
		return TRUE //if you're an admin, you probably know what you're doing (or at least have permission to do what you're doing)

	if(!isliving(user))
		return FALSE //no ghosts in the machine allowed, sorry

	var/mob/living/living_user = user

	if(check_for_assblast(user, ASSBLAST_SHOCKING))
		if(prob(25))
			living_user.electrocute_act(10, src, flags = SHOCK_TESLA)

	var/is_dextrous = FALSE
	if(isanimal(user))
		var/mob/living/simple_animal/user_as_animal = user
		if (user_as_animal.dextrous)
			is_dextrous = TRUE

	if(!issilicon(user) && !is_dextrous && !user.can_hold_items())
		return FALSE //spiders gtfo

	if(issilicon(user)) // If we are a silicon, make sure the machine allows silicons to interact with it
		if(!(interaction_flags_machine & INTERACT_MACHINE_ALLOW_SILICON))
			return FALSE

		if(panel_open && !(interaction_flags_machine & INTERACT_MACHINE_OPEN) && !(interaction_flags_machine & INTERACT_MACHINE_OPEN_SILICON))
			return FALSE

		return TRUE //silicons don't care about petty mortal concerns like needing to be next to a machine to use it

	if(living_user.incapacitated()) //idk why silicons aren't supposed to care about incapacitation when interacting with machines, but it was apparently like this before
		return FALSE

	if((interaction_flags_machine & INTERACT_MACHINE_REQUIRES_SIGHT) && user.is_blind())
		to_chat(user, span_warning("This machine requires sight to use."))
		return FALSE

	// machines have their own lit up display screens and LED buttons so we don't need to check for light
	if((interaction_flags_machine & INTERACT_MACHINE_REQUIRES_LITERACY) && !user.can_read(src, READING_CHECK_LITERACY))
		return FALSE

	if(panel_open && !(interaction_flags_machine & INTERACT_MACHINE_OPEN))
		return FALSE

	if(interaction_flags_machine & INTERACT_MACHINE_REQUIRES_SILICON) //if the user was a silicon, we'd have returned out earlier, so the user must not be a silicon
		return FALSE

	if(!Adjacent(user)) // Next make sure we are next to the machine unless we have telekinesis
		var/mob/living/carbon/carbon_user = living_user
		if(!istype(carbon_user) || !carbon_user.has_dna() || !carbon_user.dna.check_mutation(TK))
			return FALSE

	return TRUE // If we passed all of those checks, woohoo! We can interact with this machine.

/obj/machinery/proc/check_nap_violations()
	if(!SSeconomy.full_ancap)
		return TRUE
	if(occupant && !state_open)
		var/mob/living/L = occupant
		var/obj/item/card/id/I = L.get_idcard(TRUE)
		if(I)
			var/datum/bank_account/insurance = I.registered_account
			if(!insurance)
				say("[market_verb] NAP Violation: No bank account found.")
				nap_violation(L)
				return FALSE
			else
				if(!insurance.adjust_money(-fair_market_price))
					say("[market_verb] NAP Violation: Unable to pay.")
					nap_violation(L)
					return FALSE
				var/datum/bank_account/D = SSeconomy.get_dep_account(payment_department)
				if(D)
					D.adjust_money(fair_market_price)
		else
			say("[market_verb] NAP Violation: No ID card found.")
			nap_violation(L)
			return FALSE
	return TRUE

/obj/machinery/proc/nap_violation(mob/violator)
	return

////////////////////////////////////////////////////////////////////////////////////////////

//Return a non FALSE value to interrupt attack_hand propagation to subtypes.
/obj/machinery/interact(mob/user, special_state)
	if(interaction_flags_machine & INTERACT_MACHINE_SET_MACHINE)
		user.set_machine(src)

	. = ..()

/obj/machinery/ui_act(action, list/params)
	add_fingerprint(usr)
	return ..()

/obj/machinery/Topic(href, href_list)
	..()
	if(!can_interact(usr))
		return TRUE
	if(!usr.canUseTopic(src))
		return TRUE
	add_fingerprint(usr)
	return FALSE

////////////////////////////////////////////////////////////////////////////////////////////

/obj/machinery/attack_paw(mob/living/user)
	if(user.a_intent != INTENT_HARM)
		return attack_hand(user)
	else
		user.changeNext_move(CLICK_CD_MELEE)
		user.do_attack_animation(src, ATTACK_EFFECT_PUNCH)
		user.visible_message(span_danger("[user.name] smashes against [src.name] with its paws.") , null, null, COMBAT_MESSAGE_RANGE)
		take_damage(4, BRUTE, MELEE, 1)

/obj/machinery/attack_hulk(mob/living/carbon/user)
	. = ..()
	var/obj/item/bodypart/arm = user.hand_bodyparts[user.active_hand_index]
	if(!arm)
		return
	if(arm.bodypart_disabled)
		return
	var/damage = damage_deflection / 10
	arm.receive_damage(brute=damage, wound_bonus = CANT_WOUND)

/obj/machinery/attack_robot(mob/user)
	if(!(interaction_flags_machine & INTERACT_MACHINE_ALLOW_SILICON) && !isAdminGhostAI(user))
		return FALSE
	if(Adjacent(user) && can_buckle && has_buckled_mobs()) //so that borgs (but not AIs, sadly (perhaps in a future PR?)) can unbuckle people from machines
		if(buckled_mobs.len > 1)
			var/unbuckled = tgui_input_list(user, "Who do you wish to unbuckle?", "Unbuckle Who?", sort_names(buckled_mobs))
			if(user_unbuckle_mob(unbuckled,user))
				return TRUE
		else
			if(user_unbuckle_mob(buckled_mobs[1],user))
				return TRUE
	return _try_interact(user)

/obj/machinery/attack_ai(mob/user)
	if(!(interaction_flags_machine & INTERACT_MACHINE_ALLOW_SILICON) && !isAdminGhostAI(user))
		return FALSE
	if(iscyborg(user))// For some reason attack_robot doesn't work
		return attack_robot(user)
	else
		return _try_interact(user)

/obj/machinery/_try_interact(mob/user)
	if((interaction_flags_machine & INTERACT_MACHINE_WIRES_IF_OPEN) && panel_open && (attempt_wire_interaction(user) == WIRE_INTERACTION_BLOCK))
		return TRUE
	return ..()

/obj/machinery/CheckParts(list/parts_list)
	..()
	RefreshParts()

/obj/machinery/proc/RefreshParts()
	SHOULD_CALL_PARENT(TRUE)
	//reset to baseline
	idle_power_usage = initial(idle_power_usage)
	active_power_usage = initial(active_power_usage)
	if(!component_parts || !component_parts.len)
		return
	var/parts_energy_rating = 0
	for(var/obj/item/stock_parts/part in component_parts)
		parts_energy_rating += part.energy_rating

	idle_power_usage = initial(idle_power_usage) * (1 + parts_energy_rating)
	active_power_usage = initial(active_power_usage) * (1 + parts_energy_rating)
	update_current_power_usage()

/obj/machinery/proc/default_pry_open(obj/item/I)
	. = !(state_open || panel_open || is_operational || (flags_1 & NODECONSTRUCT_1)) && I.tool_behaviour == TOOL_CROWBAR
	if(.)
		I.play_tool_sound(src, 50)
		visible_message(span_notice("[usr] pries open <b>[src.name]</b>.") , span_notice("You pry open <b>[src.name]</b>."))
		open_machine()

/obj/machinery/proc/default_deconstruction_crowbar(obj/item/I, ignore_panel = 0, custom_deconstruct = FALSE)
	. = (panel_open || ignore_panel) && !(flags_1 & NODECONSTRUCT_1) && I.tool_behaviour == TOOL_CROWBAR
	if(. && !custom_deconstruct)
		I.play_tool_sound(src, 50)
		deconstruct(TRUE)

/obj/machinery/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		on_deconstruction()
		if(LAZYLEN(component_parts))
			spawn_frame(disassembled)
			for(var/obj/item/I in component_parts)
				I.forceMove(loc)
			LAZYCLEARLIST(component_parts)
	return ..()

/**
 * Spawns a frame where this machine is. If the machine was not disassmbled, the
 * frame is spawned damaged. If the frame couldn't exist on this turf, it's smashed
 * down to metal sheets.
 *
 * Arguments:
 * * disassembled - If FALSE, the machine was destroyed instead of disassembled and the frame spawns at reduced integrity.
 */
/obj/machinery/proc/spawn_frame(disassembled)
	var/obj/structure/frame/machine/new_frame = new /obj/structure/frame/machine(loc)

	new_frame.state = 2

	// If the new frame shouldn't be able to fit here due to the turf being blocked, spawn the frame deconstructed.
	if(isturf(loc))
		var/turf/machine_turf = loc
		// We're spawning a frame before this machine is qdeleted, so we want to ignore it. We've also just spawned a new frame, so ignore that too.
		if(machine_turf.is_blocked_turf(TRUE, source_atom = new_frame, ignore_atoms = list(src)))
			new_frame.deconstruct(disassembled)
			return

	new_frame.icon_state = "box_1"
	. = new_frame
	new_frame.set_anchored(anchored)
	if(!disassembled)
		new_frame.obj_integrity = new_frame.max_integrity * 0.5 //the frame is already half broken
	transfer_fingerprints_to(new_frame)


/obj/machinery/obj_break(damage_flag)
	SHOULD_CALL_PARENT(TRUE)
	. = ..()
	if(!(machine_stat & BROKEN) && !(flags_1 & NODECONSTRUCT_1))
		set_machine_stat(machine_stat | BROKEN)
		SEND_SIGNAL(src, COMSIG_MACHINERY_BROKEN, damage_flag)
		update_icon()
		return TRUE

/obj/machinery/contents_explosion(severity, target)
	if(!occupant)
		return

	switch(severity)
		if(EXPLODE_DEVASTATE)
			SSexplosions.high_mov_atom += occupant
		if(EXPLODE_HEAVY)
			SSexplosions.med_mov_atom += occupant
		if(EXPLODE_LIGHT)
			SSexplosions.low_mov_atom += occupant

/obj/machinery/handle_atom_del(atom/A)
	if(A == occupant)
		set_occupant(null)
		update_icon()
		updateUsrDialog()
		return ..()

	// The circuit should also be in component parts, so don't early return.
	if(A == circuit)
		circuit = null
	if((A in component_parts) && !QDELETED(src))
		component_parts.Remove(A)
		// It would be unusual for a component_part to be qdel'd ordinarily.
		deconstruct(FALSE)
	return ..()


/obj/machinery/proc/default_deconstruction_screwdriver(mob/user, icon_state_open, icon_state_closed, obj/item/screwdriver)
	if((flags_1 & NODECONSTRUCT_1) || screwdriver.tool_behaviour != TOOL_SCREWDRIVER)
		return FALSE

	screwdriver.play_tool_sound(src, 50)
	toggle_panel_open()
	if(panel_open)
		icon_state = icon_state_open
		to_chat(user, span_notice("Открываю техническую панель <b>[src]</b>."))
	else
		panel_open = FALSE
		icon_state = icon_state_closed
		to_chat(user, span_notice("Закрываю техническую панель <b>[src]</b>."))
	return TRUE

/obj/machinery/proc/default_change_direction_wrench(mob/user, obj/item/I)
	if(panel_open && I.tool_behaviour == TOOL_WRENCH)
		I.play_tool_sound(src, 50)
		setDir(turn(dir,-90))
		to_chat(user, span_notice("Поворачиваю <b>[src]</b>."))
		return TRUE
	return FALSE

/obj/proc/can_be_unfasten_wrench(mob/user, silent) //if we can unwrench this object; returns SUCCESSFUL_UNFASTEN and FAILED_UNFASTEN, which are both TRUE, or CANT_UNFASTEN, which isn't.
	if(!(isfloorturf(loc) || istype(loc, /turf/open/indestructible)) && !anchored)
		to_chat(user, span_warning("[capitalize(src.name)] needs to be on the floor to be secured!"))
		return FAILED_UNFASTEN
	return SUCCESSFUL_UNFASTEN

/obj/proc/default_unfasten_wrench(mob/user, obj/item/I, time = 20) //try to unwrench an object in a WONDERFUL DYNAMIC WAY
	if(!(flags_1 & NODECONSTRUCT_1) && I.tool_behaviour == TOOL_WRENCH)
		var/turf/ground = get_turf(src)
		if(!anchored && ground.is_blocked_turf(exclude_mobs = TRUE, source_atom = src))
			to_chat(user, span_notice("Не вышло прикрутить <b>[src.name]</b>."))
			return CANT_UNFASTEN
		var/can_be_unfasten = can_be_unfasten_wrench(user)
		if(!can_be_unfasten || can_be_unfasten == FAILED_UNFASTEN)
			return can_be_unfasten
		if(time)
			to_chat(user, span_notice("Начинаю [anchored ? "от" : "при"]кручивать <b>[src.name]</b>..."))
		I.play_tool_sound(src, 50)
		var/prev_anchored = anchored
		//as long as we're the same anchored state and we're either on a floor or are anchored, toggle our anchored state
		if(I.use_tool(src, user, time, extra_checks = CALLBACK(src, PROC_REF(unfasten_wrench_check), prev_anchored, user)))
			if(!anchored && ground.is_blocked_turf(exclude_mobs = TRUE, source_atom = src))
				to_chat(user, span_notice("Не вышло прикрутить <b>[src.name]</b>."))
				return CANT_UNFASTEN
			to_chat(user, span_notice("[anchored ? "От" : "При"]кручиваю <b>[src.name]</b>."))
			set_anchored(!anchored)
			playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
			SEND_SIGNAL(src, COMSIG_OBJ_DEFAULT_UNFASTEN_WRENCH, anchored)
			return SUCCESSFUL_UNFASTEN
		return FAILED_UNFASTEN
	return CANT_UNFASTEN

/obj/proc/unfasten_wrench_check(prev_anchored, mob/user) //for the do_after, this checks if unfastening conditions are still valid
	if(anchored != prev_anchored)
		return FALSE
	if(can_be_unfasten_wrench(user, TRUE) != SUCCESSFUL_UNFASTEN) //if we aren't explicitly successful, cancel the fuck out
		return FALSE
	return TRUE

/obj/machinery/proc/exchange_parts(mob/user, obj/item/storage/part_replacer/W)
	if(!istype(W))
		return FALSE
	if((flags_1 & NODECONSTRUCT_1) && !W.works_from_distance)
		return FALSE
	var/shouldplaysound = 0
	if(component_parts)
		if(panel_open || W.works_from_distance)
			var/obj/item/circuitboard/machine/CB = locate(/obj/item/circuitboard/machine) in component_parts
			var/required_type
			if(W.works_from_distance)
				to_chat(user, display_parts(user))
			if(!CB)
				return FALSE
			for(var/obj/item/A in component_parts)
				for(var/design_type in CB.req_components)
					if(ispath(A.type, design_type))
						required_type = design_type
						break
				for(var/obj/item/B in W.contents)
					if(istype(B, required_type) && istype(A, required_type))
						// If it's a corrupt or rigged cell, attempting to send it through Bluespace could have unforeseen consequences.
						if(istype(B, /obj/item/stock_parts/cell) && W.works_from_distance)
							var/obj/item/stock_parts/cell/checked_cell = B
							// If it's rigged or corrupted, max the charge. Then explode it.
							if(checked_cell.rigged || checked_cell.corrupted)
								checked_cell.charge = checked_cell.maxcharge
								checked_cell.explode()
						if(B.get_part_rating() > A.get_part_rating())
							if(istype(B,/obj/item/stack)) //conveniently this will mean A is also a stack and I will kill the first person to prove me wrong
								var/obj/item/stack/SA = A
								var/obj/item/stack/SB = B
								var/used_amt = SA.get_amount()
								if(!SB.use(used_amt))
									continue //if we don't have the exact amount to replace we don't
								var/obj/item/stack/SN = new SB.merge_type(null,used_amt)
								component_parts += SN
							else
								if(W.atom_storage.attempt_remove(B, src))
									component_parts += B
									B.forceMove(src)
							W.atom_storage.attempt_insert(A, user, TRUE)
							component_parts -= A
							to_chat(user, span_notice("[capitalize(A.name)] заменен на [B.name]."))
							shouldplaysound = 1 //Only play the sound when parts are actually replaced!
							break
			RefreshParts()
		else
			to_chat(user, display_parts(user))
		if(shouldplaysound)
			W.play_rped_sound()
		return TRUE
	return FALSE

/obj/machinery/proc/display_parts(mob/user)
	. = list()
	. += "<hr><span class='notice'>Содержит следующие компоненты:</span>"
	for(var/obj/item/C in component_parts)
		. += span_notice("[icon2html(C, user)] [C].")
	. = jointext(., "\n")

/obj/machinery/examine(mob/user)
	. = ..()
	if(machine_stat & BROKEN)
		. += "<hr><span class='notice'>Совсем сломано и не хочет работать.</span>"
	if(!(resistance_flags & INDESTRUCTIBLE))
		if(resistance_flags & ON_FIRE)
			. += "<hr><span class='warning'>Горит!</span>"
		var/healthpercent = (obj_integrity/max_integrity) * 100
		switch(healthpercent)
			if(50 to 99)
				. += "<hr>Виднеются небольшие царапины."
			if(25 to 50)
				. += "<hr>Выглядит серьёзно повреждённым."
			if(0 to 25)
				. += "<hr><span class='warning'>Вот-вот развалится!</span>"
	if(HAS_TRAIT(user, TRAIT_RESEARCH_SCANNER) && component_parts)
		. += display_parts(user, TRUE)

//called on machinery construction (i.e from frame to machinery) but not on initialization
/obj/machinery/proc/on_construction()
	return

//called on deconstruction before the final deletion
/obj/machinery/proc/on_deconstruction()
	return

/obj/machinery/proc/can_be_overridden()
	. = 1

/obj/machinery/zap_act(power, zap_flags)
	if(prob(85) && (zap_flags & ZAP_MACHINE_EXPLOSIVE) && !(resistance_flags & INDESTRUCTIBLE))
		explosion(src, devastation_range = 1, heavy_impact_range = 2, light_impact_range = 4, flame_range = 2, adminlog = FALSE, smoke = FALSE)
	else if(zap_flags & ZAP_OBJ_DAMAGE)
		take_damage(power * 0.0005, BURN, ENERGY)
		if(prob(40))
			emp_act(EMP_LIGHT)
		power -= power * 0.0005
	return ..()

/obj/machinery/Exited(atom/movable/AM, atom/newloc)
	. = ..()
	if(AM == occupant)
		set_occupant(null)
	if(AM == circuit)
		LAZYREMOVE(component_parts, AM)
		circuit = null

/obj/machinery/proc/adjust_item_drop_location(atom/movable/AM)	// Adjust item drop location to a 3x3 grid inside the tile, returns slot id from 0 to 8
	var/md5 = md5(AM.name)								// Oh, and it's deterministic too. A specific item will always drop from the same slot.
	for (var/i in 1 to 32)
		. += hex2num(md5[i])
	. = . % 9
	AM.pixel_x = -8 + ((.%3)*8)
	AM.pixel_y = -8 + (round( . / 3)*8)

/obj/machinery/rust_heretic_act()
	take_damage(500, BRUTE, MELEE, 1)

/obj/machinery/vv_edit_var(vname, vval)
	if(vname == "occupant")
		set_occupant(vval)
		datum_flags |= DF_VAR_EDITED
		return TRUE
	return ..()

/**
 * Alerts the AI that a hack is in progress.
 *
 * Sends all AIs a message that a hack is occurring.  Specifically used for space ninja tampering as this proc was originally in the ninja files.
 * However, the proc may also be used elsewhere.
 */
/obj/machinery/proc/AI_notify_hack()
	var/alertstr = span_userdanger("Network Alert: Hacking attempt detected[get_area(src)?" in [get_area_name(src, TRUE)]":". Unable to pinpoint location"].")
	for(var/mob/living/silicon/ai/AI in GLOB.player_list)
		to_chat(AI, alertstr)

