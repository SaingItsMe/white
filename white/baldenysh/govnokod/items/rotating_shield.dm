/obj/item/rotating_shield
	name = "RS controller"
	icon = 'white/baldenysh/icons/obj/rshield.dmi'
	icon_state = "type0"

	var/atom/movable/shielded_atom
	var/list/datum/rs_plate_layer/plate_layers = list()
	var/angle = 0
	var/angular_velocity = 30
	var/active = FALSE

/obj/item/rotating_shield/Initialize()
	. = ..()
	RegisterShielded(ismovable(loc) ? loc : src)
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, .proc/on_moved)

/obj/item/rotating_shield/Destroy()
	. = ..()
	UnregisterShielded()
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)

/obj/item/rotating_shield/proc/on_moved(datum/source, newloc, dir)
	UnregisterShielded()
	RegisterShielded(ismovable(loc) ? loc : src)

/obj/item/rotating_shield/proc/RegisterShielded(atom/movable/A)
	if(!istype(A))
		return
	shielded_atom = A
	RegisterSignal(A, COMSIG_MOVABLE_MOVED, .proc/on_shielded_moved)
	RegisterSignal(A, COMSIG_MOVABLE_UPDATE_GLIDE_SIZE, .proc/on_shielded_glide_size_update)
	on_shielded_moved()

	RegisterSignal(A, COMSIG_PARENT_ATTACKBY, .proc/on_shielded_attackby)
	RegisterSignal(A, COMSIG_ATOM_BULLET_ACT, .proc/on_shielded_bullet_act)
	RegisterSignal(A, COMSIG_ATOM_HITBY, .proc/on_shielded_hitby)

/obj/item/rotating_shield/proc/UnregisterShielded()
	UnregisterSignal(shielded_atom, COMSIG_MOVABLE_MOVED)
	UnregisterSignal(shielded_atom, COMSIG_MOVABLE_UPDATE_GLIDE_SIZE)

	UnregisterSignal(shielded_atom, COMSIG_PARENT_ATTACKBY)
	UnregisterSignal(shielded_atom, COMSIG_ATOM_BULLET_ACT)
	UnregisterSignal(shielded_atom, COMSIG_ATOM_HITBY)

////////////////////////////////////////////////////////////////////////перемещение/анимация

/obj/item/rotating_shield/proc/on_shielded_moved(datum/source, newloc, dir)
	if(!active)
		return
	var/turf/T = get_turf(loc)
	for(var/obj/structure/rs_plate/plate in get_plates())
		plate.forceMove(T)

/obj/item/rotating_shield/proc/on_shielded_glide_size_update(datum/source, new_glide_size)
	set_glide_size(new_glide_size)
	for(var/obj/structure/rs_plate/plate in get_plates())
		plate.set_glide_size(new_glide_size)

/obj/item/rotating_shield/Destroy(force, silent)
	. = ..()
	QDEL_LIST(plate_layers)

/obj/item/rotating_shield/process(delta_time)
	//var/last_angle = angle
	angle += angular_velocity * delta_time
	angle %= 360
	/*
	var/matrix/mtrx_from = new()
	var/matrix/mtrx_to = new()
	mtrx_from.Turn(last_angle)
	mtrx_to.Turn(angle)
	transform = mtrx_from
	animate(src, transform = mtrx_to, time = delta_time*10, flags = ANIMATION_END_NOW) //ето тупа для дэбага, убрать потом надо будет
	*/

	for(var/datum/rs_plate_layer/rspl in plate_layers)
		rspl.rotate_to(angle, delta_time)

/obj/item/rotating_shield/proc/activate()
	for(var/obj/structure/rs_plate/plate in get_plates())
		plate.forceMove(get_turf(shielded_atom))
		plate.control = src

	START_PROCESSING(SSfastprocess, src)
	active = TRUE

/obj/item/rotating_shield/proc/deactivate()
	for(var/obj/structure/rs_plate/plate in get_plates())
		plate.forceMove(src)
		plate.control = null

	STOP_PROCESSING(SSfastprocess, src)
	active = FALSE

////////////////////////////////////////////////////////////////////////защита

/obj/item/rotating_shield/proc/on_shielded_attackby(datum/source, obj/item/I, mob/user)

/obj/item/rotating_shield/proc/on_shielded_bullet_act(datum/source, obj/projectile/P, def_zone)

/obj/item/rotating_shield/proc/on_shielded_hitby(datum/source, atom/movable/AM, skipcatch = FALSE, hitpush = TRUE, blocked = FALSE, datum/thrownthing/throwingdatum)
/*
/obj/item/rotating_shield/proc/find_plate_by_angle(angle)
	for(var/l in plate_layers.len to 1)
		for(var/obj/structure/rs_plate/plate in plate_layers[l])
*/
////////////////////////////////////////////////////////////////////////

/obj/item/rotating_shield/proc/get_plates()
	. = list()
	for(var/datum/rs_plate_layer/rspl in plate_layers)
		for(var/obj/structure/rs_plate/plate in rspl.plates)
			. += plate

////////////////////////////////////////////////////////////////////////

#define CIRCUMFERENCE(r) 		(r*PI*2)
#define CHORD2CANGLE(c, r)		(2*arcsin(c/(2*r)))
#define CHORD2ARC(c, r)			(TORADIANS(CHORD2CANGLE(c, r))*r)

/datum/rs_plate_layer
	var/list/obj/structure/rs_plate/plates = list()
	var/angle = 0
	var/radius = 32

/datum/rs_plate_layer/proc/rotate_to(newangle, delta_time)
	for(var/obj/structure/rs_plate/plate in plates)
		var/matrix/p_mtrx_to = plate.transform
		p_mtrx_to.Turn(newangle - angle)
		animate(plate, transform = p_mtrx_to, time = delta_time*10, flags = ANIMATION_END_NOW)
	angle = newangle

/datum/rs_plate_layer/proc/get_total_arc_length()
	. = 0
	for(var/obj/structure/rs_plate/plate in plates)
		. += CHORD2ARC(plate.chord_length, radius)

/datum/rs_plate_layer/proc/set_radius(newradius)
	if(get_total_arc_length() >= CIRCUMFERENCE(newradius))
		return
	radius = newradius
	regen_visuals()

/datum/rs_plate_layer/proc/add_plate(obj/structure/rs_plate/plate)
	if(plate.chord_length > radius * 2)
		stack_trace("Попытка вставить пластину длиной больше диаметра. Хорда: [plate.chord_length], Радиус: [radius]")
		return
	if(get_total_arc_length() + CHORD2ARC(plate.chord_length, radius) >= CIRCUMFERENCE(radius))
		stack_trace("Попытка вставить пластину сверх лимита. ДО: [CIRCUMFERENCE(radius)], ИСП: [get_total_arc_length()], \
			Радиус: [radius], Хорда: [plate.chord_length], Угол: [CHORD2CANGLE(plate.chord_length, radius)], Дуга: [CHORD2ARC(plate.chord_length, radius)]")
		return
	plates.Add(plate)
	regen_visuals()

/datum/rs_plate_layer/proc/regen_visuals()
	if(!plates.len)
		return
	var/arc_between_plates = (CIRCUMFERENCE(radius) - get_total_arc_length())/plates.len
	var/cur_arc = angle
	for(var/obj/structure/rs_plate/plate in plates)
		animate(plate)
		var/matrix/p_mtrx = new()
		p_mtrx.Translate(0, radius) //мб надо ебнуть base_pixel_y и обновлять какта чтоб анимация ударов именно по пластинам была
		p_mtrx.Turn(cur_arc)
		plate.transform = p_mtrx
		cur_arc += (CHORD2ARC(plate.chord_length, radius) + arc_between_plates)

//datum/rs_plate_layer/proc/check_hit(angle)

#undef CHORD2ARC
#undef CHORD2CANGLE
#undef CIRCUMFERENCE

////////////////////////////////////////////////////////////////////////хрень для дебага хз че ето

/obj/item/rotating_shield/test
	name = "RSE-01"

/obj/item/rotating_shield/test/Initialize()
	. = ..()
	var/datum/rs_plate_layer/rspl1 = new
	rspl1.add_plate(new /obj/structure/rs_plate(src))
	rspl1.add_plate(new /obj/structure/rs_plate(src))

	var/datum/rs_plate_layer/rspl2 = new
	rspl2.radius = 48
	rspl2.add_plate(new /obj/structure/rs_plate(src))
	rspl2.add_plate(new /obj/structure/rs_plate(src))
	rspl2.add_plate(new /obj/structure/rs_plate(src))
	rspl2.add_plate(new /obj/structure/rs_plate(src))

	plate_layers.Add(rspl1)
	plate_layers.Add(rspl2)

	activate()

/////////////////

/obj/structure/rs_plate
	name = "impact plating"
	icon = 'white/baldenysh/icons/obj/rshield.dmi'
	icon_state = "type0"
	move_resist = INFINITY
	layer = ABOVE_ALL_MOB_LAYER
	appearance_flags = LONG_GLIDE
	max_integrity = 50
	var/obj/item/rotating_shield/control
	var/chord_length = 16
