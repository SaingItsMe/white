///меня часто просят выпилить это говно, но потом просят вернуть, в пизду, боьше не трону

/mob
	var/dancing_potency =  15
	var/dancing_tolerance = 100
	var/dancing = 0
	var/multidances = 0
	var/dancing_period = 0
	var/last_dancer
	var/last_dancing

/mob/list_interaction_attributes()
	var/dat = ..()
	if(dancing_period)
		dat += "<br>...не голоден."
	if(is_literally_ready_to_dance())
		dat += "<br>...голый."
		if(gender == FEMALE)
			dat += "<br>...имеет горы."
			dat += "<br>...имеет пельмени."
		if(gender == MALE)
			dat += "<br>...имеет стан-батон."
		dat += "<br>...имеет шоколад."
	else
		dat += "<br>...в одежде."
	return dat

/mob/living/Life()
	if(dancing_period)
		dancing_period--
	return ..()

/datum/interaction/get_action_link_for(var/mob/user, var/mob/target)
	return "<font color='#FF0000'><b>ТАНЦЫ:</b></font> [..()]"

#define DANCE_TARGET_MOUTH "mouth"
#define DANCE_TARGET_THROAT "throat"
#define DANCE_TARGET_DANCERESS "danceress"
#define DANCE_TARGET_DANCOR "dancor"
#define DANCE_TARGET_HAND "hand"
#define DANCE_TARGET_CHEST "chest"
#define DANCING_FACE_WITH_DANCOR "facedancor"
#define DANCING_FACE_WITH_FEET "facefeet"
#define DANCING_MOUTH_WITH_FEET "mouthfeet"
#define DANCE_TO_FACE "danceface"
#define THIGH_DANCE "thighs"
