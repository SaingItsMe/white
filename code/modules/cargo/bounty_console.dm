#define PRINTER_TIMEOUT 10

/obj/machinery/computer/bounty
	name = "\improper Консоль заказов НТ"
	desc = "Используется для проверки и выполнений заказов ЦК"
	icon_screen = "bounty"
	circuit = /obj/item/circuitboard/computer/bounty
	light_color = "#E2853D"//orange
	var/printer_ready = 0 //cooldown var
	var/static/datum/bank_account/cargocash

/obj/machinery/computer/bounty/Initialize()
	. = ..()
	printer_ready = world.time + PRINTER_TIMEOUT
	cargocash = SSeconomy.get_dep_account(ACCOUNT_CAR)

/obj/machinery/computer/bounty/proc/print_paper()
	new /obj/item/paper/bounty_printout(loc)

/obj/item/paper/bounty_printout
	name = "Лист с заказами ЦК"

/obj/item/paper/bounty_printout/Initialize()
	. = ..()
	info = "<h2>Заказы НТ</h2></br>"
	update_icon()

	for(var/datum/bounty/B in GLOB.bounties_list)
		if(B.claimed)
			continue
		info += {"<h3>[B.name]</h3>
		<ul><li>Награда: [B.reward_string()]</li>
		<li>Выполнено: [B.completion_string()]</li></ul>"}

/obj/machinery/computer/bounty/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state)
	if(!GLOB.bounties_list.len)
		setup_bounties()
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "CargoBountyConsole", name, 750, 600, master_ui, state)
		ui.open()

/obj/machinery/computer/bounty/ui_data(mob/user)
	var/list/data = list()
	var/list/bountyinfo = list()
	for(var/datum/bounty/B in GLOB.bounties_list)
		bountyinfo += list(list("name" = B.name, "description" = B.description, "reward_string" = B.reward_string(), "completion_string" = B.completion_string() , "claimed" = B.claimed, "can_claim" = B.can_claim(), "priority" = B.high_priority, "bounty_ref" = REF(B)))
	data["stored_cash"] = cargocash.account_balance
	data["bountydata"] = bountyinfo
	return data

/obj/machinery/computer/bounty/ui_act(action,params)
	if(..())
		return
	switch(action)
		if("ClaimBounty")
			var/datum/bounty/cashmoney = locate(params["bounty"]) in GLOB.bounties_list
			if(cashmoney)
				cashmoney.claim()
			return TRUE
		if("Print")
			if(printer_ready < world.time)
				printer_ready = world.time + PRINTER_TIMEOUT
				print_paper()
				return
