/obj/item/tank
	name = "tank"
	icon = 'white/valtos/icons/tank.dmi'
	icon_preview = 'white/valtos/icons/tank.dmi'
	icon_state_preview = "generic"
	lefthand_file = 'icons/mob/inhands/equipment/tanks_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tanks_righthand.dmi'
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BACK
	worn_icon = 'icons/mob/clothing/back.dmi' //since these can also get thrown into suit storage slots. if something goes on the belt, set this to null.
	hitsound = 'sound/weapons/smash.ogg'
	drop_sound = 'white/valtos/sounds/ballon_drop.ogg'
	pressure_resistance = ONE_ATMOSPHERE * 5
	force = 5
	throwforce = 10
	throw_speed = 1
	throw_range = 4
	custom_materials = list(/datum/material/iron = 500)
	actions_types = list(/datum/action/item_action/set_internals)
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 10, BIO = 0, RAD = 0, FIRE = 80, ACID = 30)
	var/datum/gas_mixture/air_contents = null
	var/distribute_pressure = ONE_ATMOSPHERE
	var/integrity = 3
	var/volume = 70
	/// Icon state when in a tank holder. Null makes it incompatible with tank holder.
	var/tank_holder_icon_state = "holder_generic"
	/// Mob that is currently breathing from the tank.
	var/mob/living/carbon/breathing_mob = null

/obj/item/tank/dropped(mob/living/user, silent)
	. = ..()
	// Close open air tank if its current user got sent to the shadowrealm.
	if (QDELETED(breathing_mob))
		breathing_mob = null
		return
	// Close open air tank if it got dropped by it's current user.
	if (loc != breathing_mob)
		breathing_mob.cutoff_internals()

/// Closes the tank if given to another mob while open.
/obj/item/tank/equipped(mob/living/user, slot, initial)
	. = ..()
	// Close open air tank if it was equipped by a mob other than the current user.
	if (breathing_mob && (user != breathing_mob))
		breathing_mob.cutoff_internals()

/// Called by carbons after they connect the tank to their breathing apparatus.
/obj/item/tank/proc/after_internals_opened(mob/living/carbon/carbon_target)
	breathing_mob = carbon_target
	RegisterSignal(carbon_target, COMSIG_MOB_GET_STATUS_TAB_ITEMS, PROC_REF(get_status_tab_item))

/// Called by carbons after they disconnect the tank from their breathing apparatus.
/obj/item/tank/proc/after_internals_closed(mob/living/carbon/carbon_target)
	breathing_mob = null
	UnregisterSignal(carbon_target, COMSIG_MOB_GET_STATUS_TAB_ITEMS)

/obj/item/tank/proc/get_status_tab_item(mob/living/source, list/items)
	SIGNAL_HANDLER
	items += "Внутренняя атмосфера: [name]"
	items += "Давление: [air_contents.return_pressure()] кПа"
	items += "Подача: [distribute_pressure] кПа"

/// Attempts to toggle the mob's internals on or off using this tank. Returns TRUE if successful.
/obj/item/tank/proc/toggle_internals(mob/living/carbon/mob_target)
	return mob_target.toggle_internals(src)

/obj/item/tank/ui_action_click(mob/user)
	toggle_internals(user)

/obj/item/tank/Initialize(mapload)
	. = ..()

	air_contents = new(volume) //liters
	air_contents.set_temperature(T20C)

	populate_gas()

	START_PROCESSING(SSobj, src)

/obj/item/tank/proc/populate_gas()
	return

/obj/item/tank/Destroy()
	if(air_contents)
		QDEL_NULL(air_contents)
	STOP_PROCESSING(SSobj, src)
	. = ..()

/obj/item/tank/ComponentInitialize()
	. = ..()
	if(tank_holder_icon_state)
		AddComponent(/datum/component/container_item/tank_holder, tank_holder_icon_state)

/obj/item/tank/examine(mob/user)
	var/obj/icon = src
	. = ..()
	if(istype(src.loc, /obj/item/assembly))
		icon = src.loc
	if(!in_range(src, user) && !isobserver(user))
		if(icon == src)
			. += "<hr><span class='notice'>If you want any more information you'll need to get closer.</span>"
		return

	. += "<hr><span class='notice'>The pressure gauge reads [round(src.air_contents.return_pressure(),0.01)] kPa.</span>"

	var/celsius_temperature = src.air_contents.return_temperature()-T0C
	var/descriptive

	if (celsius_temperature < 20)
		descriptive = "cold"
	else if (celsius_temperature < 40)
		descriptive = "room temperature"
	else if (celsius_temperature < 80)
		descriptive = "lukewarm"
	else if (celsius_temperature < 100)
		descriptive = "warm"
	else if (celsius_temperature < 300)
		descriptive = "hot"
	else
		descriptive = "furiously hot"

	. += span_notice("It feels [descriptive].")

/obj/item/tank/blob_act(obj/structure/blob/B)
	if(B && B.loc == loc)
		var/turf/location = get_turf(src)
		if(!location)
			qdel(src)

		if(air_contents)
			location.assume_air(air_contents)

		qdel(src)

/obj/item/tank/deconstruct(disassembled = TRUE)
	if(!disassembled)
		var/turf/T = get_turf(src)
		if(T)
			T.assume_air(air_contents)
			air_update_turf()
		playsound(src.loc, 'sound/effects/spray.ogg', 10, TRUE, -3)
	qdel(src)

/obj/item/tank/suicide_act(mob/user)
	var/mob/living/carbon/human/H = user
	user.visible_message(span_suicide("[user] is putting [src] valve to [user.ru_ego()] lips! It looks like [user.p_theyre()] trying to commit suicide!"))
	playsound(loc, 'sound/effects/spray.ogg', 10, TRUE, -3)
	if(!QDELETED(H) && air_contents && air_contents.return_pressure() >= 1000)
		ADD_TRAIT(H, TRAIT_DISFIGURED, TRAIT_GENERIC)
		H.inflate_gib()
		return MANUAL_SUICIDE
	else
		to_chat(user, span_warning("There isn't enough pressure in [src] to commit suicide with..."))
	return SHAME

/obj/item/tank/attackby(obj/item/W, mob/user, params)
	add_fingerprint(user)
	if(istype(W, /obj/item/assembly_holder))
		bomb_assemble(W,user)
	else
		. = ..()

/obj/item/tank/ui_state(mob/user)
	return GLOB.hands_state

/obj/item/tank/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Tank", name)
		ui.open()

/obj/item/tank/ui_static_data(mob/user)
	. = list (
		"defaultReleasePressure" = round(TANK_DEFAULT_RELEASE_PRESSURE),
		"minReleasePressure" = round(TANK_MIN_RELEASE_PRESSURE),
		"maxReleasePressure" = round(TANK_MAX_RELEASE_PRESSURE),
		"leakPressure" = round(TANK_LEAK_PRESSURE),
		"fragmentPressure" = round(TANK_FRAGMENT_PRESSURE)
	)

/obj/item/tank/ui_data(mob/user)
	. = list(
		"tankPressure" = round(air_contents.return_pressure()),
		"releasePressure" = round(distribute_pressure)
	)

	var/mob/living/carbon/C = user
	if(!istype(C))
		C = loc.loc
	if(istype(C) && C.internal == src)
		.["connected"] = TRUE

/obj/item/tank/ui_act(action, params)
	. = ..()
	if(.)
		return
	switch(action)
		if("pressure")
			var/pressure = params["pressure"]
			if(pressure == "reset")
				pressure = initial(distribute_pressure)
				. = TRUE
			else if(pressure == "min")
				pressure = TANK_MIN_RELEASE_PRESSURE
				. = TRUE
			else if(pressure == "max")
				pressure = TANK_MAX_RELEASE_PRESSURE
				. = TRUE
			else if(text2num(pressure) != null)
				pressure = text2num(pressure)
				. = TRUE
			if(.)
				distribute_pressure = clamp(round(pressure), TANK_MIN_RELEASE_PRESSURE, TANK_MAX_RELEASE_PRESSURE)

/obj/item/tank/remove_air(amount)
	return air_contents.remove(amount)

/obj/item/tank/remove_air_ratio(ratio)
	return air_contents.remove_ratio(ratio)

/obj/item/tank/return_air()
	return air_contents

/obj/item/tank/return_analyzable_air()
	return air_contents

/obj/item/tank/assume_air(datum/gas_mixture/giver)
	air_contents.merge(giver)

	check_status()
	return 1

/obj/item/tank/assume_air_moles(datum/gas_mixture/giver, moles)
	giver.transfer_to(air_contents, moles)

	check_status()
	return 1

/obj/item/tank/assume_air_ratio(datum/gas_mixture/giver, ratio)
	giver.transfer_ratio_to(air_contents, ratio)

	check_status()
	return 1

/obj/item/tank/proc/remove_air_volume(volume_to_return)
	if(!air_contents)
		return null

	var/tank_pressure = air_contents.return_pressure()
	if(tank_pressure < distribute_pressure)
		distribute_pressure = tank_pressure

	var/moles_needed = distribute_pressure*volume_to_return/(R_IDEAL_GAS_EQUATION*air_contents.return_temperature())

	return remove_air(moles_needed)

/obj/item/tank/process()
	//Allow for reactions
	air_contents.react(src)
	check_status()

/obj/item/tank/proc/check_status()
	//Handle exploding, leaking, and rupturing of the tank

	if(!air_contents)
		return 0

	var/pressure = air_contents.return_pressure()
	var/temperature = air_contents.return_temperature()

	if(pressure > TANK_FRAGMENT_PRESSURE)
		if(!istype(src.loc, /obj/item/transfer_valve))
			log_bomber(get_mob_by_key(fingerprintslast), "was last key to touch", src, "which ruptured explosively")
		//Give the gas a chance to build up more pressure through reacting
		air_contents.react(src)
		pressure = air_contents.return_pressure()
		var/range = (pressure-TANK_FRAGMENT_PRESSURE)/TANK_FRAGMENT_SCALE
		var/turf/epicenter = get_turf(loc)

		var/mob/bombasta_masta = get_mob_by_key(fingerprintslast)
		if(istype(src.loc, /obj/item/transfer_valve))
			var/obj/item/transfer_valve/funni = src.loc
			bombasta_masta = get_mob_by_key(funni.fingerprintslast)

		explosion(epicenter, round(range*0.25), round(range*0.5), round(range), round(range*1.5), explosion_cause = bombasta_masta)
		if(istype(src.loc, /obj/item/transfer_valve))
			qdel(src.loc)
		else
			qdel(src)

	else if(pressure > TANK_RUPTURE_PRESSURE || temperature > TANK_MELT_TEMPERATURE)
		if(integrity <= 0)
			var/turf/T = get_turf(src)
			if(!T)
				return
			T.assume_air(air_contents)
			playsound(src.loc, 'sound/effects/spray.ogg', 10, TRUE, -3)
			qdel(src)
		else
			integrity--

	else if(pressure > TANK_LEAK_PRESSURE)
		if(integrity <= 0)
			var/turf/T = get_turf(src)
			if(!T)
				return
			var/datum/gas_mixture/leaked_gas = air_contents.remove_ratio(0.25)
			T.assume_air(leaked_gas)
		else
			integrity--

	else if(integrity < 3)
		integrity++

/obj/item/tank/rad_act(strength)
	. = ..()
	if (air_contents.get_moles(GAS_CO2) && air_contents.get_moles(GAS_O2))
		strength = min(strength,air_contents.get_moles(GAS_CO2)*1000,air_contents.get_moles(GAS_O2)*2000) //Ensures matter is conserved properly
		air_contents.set_moles(GAS_CO2, max(air_contents.get_moles(GAS_CO2)-(strength * 0.001),0))
		air_contents.set_moles(GAS_O2, max(air_contents.get_moles(GAS_O2)-(strength * 0.0005),0))
		air_contents.adjust_moles(GAS_PLUOXIUM, strength * 0.004)
		air_update_turf()
