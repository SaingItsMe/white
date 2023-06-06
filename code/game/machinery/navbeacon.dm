// Navigation beacon for AI robots
// No longer exists on the radio controller, it is managed by a global list.

/obj/machinery/navbeacon

	icon = 'icons/obj/objects.dmi'
	icon_state = "navbeacon0-f"
	name = "навигатор"
	desc = "Радиомаяк, используемый как для навигации, так и для определения маршрута."
	layer = LOW_OBJ_LAYER
	max_integrity = 500
	armor = list(MELEE = 70, BULLET = 70, LASER = 70, ENERGY = 70, BOMB = 0, BIO = 0, RAD = 0, FIRE = 80, ACID = 80)

	var/open = FALSE		// true if cover is open
	var/locked = TRUE		// true if controls are locked
	var/freq = FREQ_NAV_BEACON
	var/location = ""	// location response text
	var/list/codes		// assoc. list of transponder codes
	var/codes_txt = ""	// codes as set on map: "tag1;tag2" or "tag1=value;tag2=value"
	var/wayfinding = FALSE

	req_one_access = list(ACCESS_ENGINE, ACCESS_ROBOTICS)

/obj/machinery/navbeacon/Initialize(mapload)
	. = ..()

	if(wayfinding)
		if(!location)
			var/obj/machinery/door/airlock/A = locate(/obj/machinery/door/airlock) in loc
			if(A)
				location = A.name
			else
				location = get_area(src)
		codes_txt += "wayfinding=[location]"

	set_codes()

	glob_lists_register(init=TRUE)

	AddElement(/datum/element/undertile, TRAIT_T_RAY_VISIBLE)

/obj/machinery/navbeacon/Destroy()
	glob_lists_deregister()
	return ..()

/obj/machinery/navbeacon/on_changed_z_level(turf/old_turf, turf/new_turf, same_z_layer, notify_contents)
	if (GLOB.navbeacons["[old_turf?.z]"])
		GLOB.navbeacons["[old_turf?.z]"] -= src
	if (GLOB.navbeacons["[new_turf?.z]"])
		GLOB.navbeacons["[new_turf?.z]"] += src
	return ..()

// set the transponder codes assoc list from codes_txt
/obj/machinery/navbeacon/proc/set_codes()
	if(!codes_txt)
		return

	codes = new()

	var/list/entries = splittext(codes_txt, ";")	// entries are separated by semicolons

	for(var/e in entries)
		var/index = findtext(e, "=")		// format is "key=value"
		if(index)
			var/key = copytext(e, 1, index)
			var/val = copytext(e, index + length(e[index]))
			codes[key] = val
		else
			codes[e] = "1"

/obj/machinery/navbeacon/proc/glob_lists_deregister()
	if (GLOB.navbeacons["[z]"])
		GLOB.navbeacons["[z]"] -= src //Remove from beacon list, if in one.
	GLOB.deliverybeacons -= src
	GLOB.deliverybeacontags -= location
	GLOB.wayfindingbeacons -= src

/obj/machinery/navbeacon/proc/glob_lists_register(init=FALSE)
	if(!init)
		glob_lists_deregister()
	if(codes["patrol"])
		if(!GLOB.navbeacons["[z]"])
			GLOB.navbeacons["[z]"] = list()
		GLOB.navbeacons["[z]"] += src //Register with the patrol list!
	if(codes["delivery"])
		GLOB.deliverybeacons += src
		GLOB.deliverybeacontags += location
	if(codes["wayfinding"])
		GLOB.wayfindingbeacons += src

// update the icon_state
/obj/machinery/navbeacon/update_icon_state()
	. = ..()
	icon_state = "navbeacon[open]"

/obj/machinery/navbeacon/attackby(obj/item/I, mob/user, params)
	var/turf/T = loc
	if(T.intact)
		return		// prevent intraction when T-scanner revealed

	if(I.tool_behaviour == TOOL_SCREWDRIVER)
		open = !open

		user.visible_message(span_notice("[user] [open ? "открывает" : "закрывает"] крышку навигатора.") , span_notice("[open ? "Открываю" : "Закрываю"] крышку навигатора."))

		update_icon()

	else if (istype(I, /obj/item/card/id)||istype(I, /obj/item/modular_computer/tablet/pda))
		if(open)
			if (src.allowed(user))
				src.locked = !src.locked
				to_chat(user, span_notice("Доступ [src.locked ? "заблокирован" : "разблокирован"]."))
			else
				to_chat(user, span_danger("Доступ запрещён."))
			updateDialog()
		else
			to_chat(user, span_warning("Крышка закрыта!"))
	else
		return ..()

/obj/machinery/navbeacon/attack_ai(mob/user)
	interact(user, 1)

/obj/machinery/navbeacon/attack_paw()
	return

/obj/machinery/navbeacon/ui_interact(mob/user)
	. = ..()
	var/ai = isAI(user)
	var/turf/T = loc
	if(T.intact)
		return		// prevent intraction when T-scanner revealed

	if(!open && !ai)	// can't alter controls if not open, unless you're an AI
		to_chat(user, span_warning("Крышка закрыта!"))
		return


	var/t

	if(locked && !ai)
		t = {"<meta charset='utf-8'><TT><B>Навигатор</B><HR><BR>
<i>(проведите картой для разблокировки)</i><BR>
Место: [location ? location : "(Нету)"]</A><BR>
Коды транспондера:<UL>"}

		for(var/key in codes)
			t += "<LI>[key] ... [codes[key]]"
		t+= "<UL></TT>"

	else

		t = {"<meta charset='utf-8'><TT><B>Навигатор</B><HR><BR>
<i>(проведите картой для блокировки)</i><BR>

<HR>
Место: <A href='byond://?src=[REF(src)];locedit=1'>[location ? location : "Нету"]</A><BR>
Коды транспондера:<UL>"}

		for(var/key in codes)
			t += "<LI>[key] ... [codes[key]]"
			t += "	<A href='byond://?src=[REF(src)];edit=1;code=[key]'>Редактировать</A>"
			t += "	<A href='byond://?src=[REF(src)];delete=1;code=[key]'>Удалить</A><BR>"
		t += "	<A href='byond://?src=[REF(src)];add=1;'>Добавить</A><BR>"
		t+= "<UL></TT>"

	var/datum/browser/popup = new(user, "navbeacon", "Навигатор", 300, 400)
	popup.set_content(t)
	popup.open()
	return

/obj/machinery/navbeacon/Topic(href, href_list)
	if(..())
		return
	if(open && !locked)
		usr.set_machine(src)

		if(href_list["locedit"])
			var/newloc = stripped_input(usr, "Введите Новое Место", "Навигатор", location, MAX_MESSAGE_LEN)
			if(newloc)
				location = newloc
				glob_lists_register()
				updateDialog()

		else if(href_list["edit"])
			var/codekey = href_list["code"]

			var/newkey = stripped_input(usr, "Введите Коды Транспондера", "Навигатор", codekey)
			if(!newkey)
				return

			var/codeval = codes[codekey]
			var/newval = stripped_input(usr, "Введите Значение Кода Транспондера", "Навигатор", codeval)
			if(!newval)
				newval = codekey
				return

			codes.Remove(codekey)
			codes[newkey] = newval
			glob_lists_register()

			updateDialog()

		else if(href_list["delete"])
			var/codekey = href_list["code"]
			codes.Remove(codekey)
			glob_lists_register()
			updateDialog()

		else if(href_list["add"])

			var/newkey = stripped_input(usr, "Введите Новый Код Транспондера", "Навигатор")
			if(!newkey)
				return

			var/newval = stripped_input(usr, "Введите Новое Значение Кода Транспондера", "Навигатор")
			if(!newval)
				newval = "1"
				return

			if(!codes)
				codes = new()

			codes[newkey] = newval
			glob_lists_register()

			updateDialog()

/obj/machinery/navbeacon/wayfinding
	wayfinding = TRUE

/* Defining these here instead of relying on map edits because it makes it easier to place them */

//Command
/obj/machinery/navbeacon/wayfinding/bridge
	location = "Мостик"

/obj/machinery/navbeacon/wayfinding/hop
	location = "Офис Кадровика"

/obj/machinery/navbeacon/wayfinding/vault
	location = "Хранилище"

/obj/machinery/navbeacon/wayfinding/teleporter
	location = "Телепортер"

/obj/machinery/navbeacon/wayfinding/gateway
	location = "Врата"

/obj/machinery/navbeacon/wayfinding/eva
	location = "Хранилище ЕВА"

/obj/machinery/navbeacon/wayfinding/aiupload
	location = "Аплоад ИИ"

/obj/machinery/navbeacon/wayfinding/minisat_access_ai
	location = "Спутник ИИ"

/obj/machinery/navbeacon/wayfinding/minisat_access_tcomms
	location = "Телекомы спутника ИИ"

/obj/machinery/navbeacon/wayfinding/minisat_access_tcomms_ai
	location = "Вход в телекомы спутника ИИ"

/obj/machinery/navbeacon/wayfinding/tcomms
	location = "Телекомы"

//Departments
/obj/machinery/navbeacon/wayfinding/sec
	location = "Охрана"

/obj/machinery/navbeacon/wayfinding/det
	location = "Офис детектива"

/obj/machinery/navbeacon/wayfinding/research
	location = "Наука"

/obj/machinery/navbeacon/wayfinding/engineering
	location = "Инженерный"

/obj/machinery/navbeacon/wayfinding/techstorage
	location = "Склад"

/obj/machinery/navbeacon/wayfinding/atmos
	location = "Атмосферный"

/obj/machinery/navbeacon/wayfinding/med
	location = "Медбей"

/obj/machinery/navbeacon/wayfinding/chemfactory
	location = "Химический завод"

/obj/machinery/navbeacon/wayfinding/cargo
	location = "Снабжение"

//Common areas
/obj/machinery/navbeacon/wayfinding/bar
	location = "Бар"

/obj/machinery/navbeacon/wayfinding/dorms
	location = "Дормы"

/obj/machinery/navbeacon/wayfinding/court
	location = "Суд"

/obj/machinery/navbeacon/wayfinding/tools
	location = "Хранилище инструментов"

/obj/machinery/navbeacon/wayfinding/library
	location = "Библиотека"

/obj/machinery/navbeacon/wayfinding/chapel
	location = "Церковь"

/obj/machinery/navbeacon/wayfinding/minisat_access_chapel_library
	location = "Церковь и библиотека"

//Service
/obj/machinery/navbeacon/wayfinding/kitchen
	location = "Кухня"

/obj/machinery/navbeacon/wayfinding/hydro
	location = "Гидропоника"

/obj/machinery/navbeacon/wayfinding/janitor
	location = "Клозет уборщика"

/obj/machinery/navbeacon/wayfinding/lawyer
	location = "Офис адвоката"

//Shuttle docks
/obj/machinery/navbeacon/wayfinding/dockarrival
	location = "Прибытие"

/obj/machinery/navbeacon/wayfinding/dockesc
	location = "Эвакуационный док"

/obj/machinery/navbeacon/wayfinding/dockescpod
	location = "Спасательная капсула"

/obj/machinery/navbeacon/wayfinding/dockescpod1
	location = "Спасательная капсула 1"

/obj/machinery/navbeacon/wayfinding/dockescpod2
	location = "Спасательная капсула 2"

/obj/machinery/navbeacon/wayfinding/dockescpod3
	location = "Спасательная капсула 3"

/obj/machinery/navbeacon/wayfinding/dockescpod4
	location = "Спасательная капсула 4"

/obj/machinery/navbeacon/wayfinding/dockaux
	location = "Док"

//Maint
/obj/machinery/navbeacon/wayfinding/incinerator
	location = "Сжигатель"

/obj/machinery/navbeacon/wayfinding/disposals
	location = "Мусорка"
