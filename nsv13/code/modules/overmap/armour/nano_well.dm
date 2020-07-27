/*
HOW 2 APNP/APNW?! - A Guide for M*ppers

General Checklist:
 - High Security Engineering Room
 - APNW x 1
 - APNP x 4 (using each of the pref definied quadrants)
 - 10 Iron Sheets
 - 10 Titanium Sheets

//ADDITION INFORMATION

High Security Engineering Room Requirements
	As this room controls ALL of the overmap repairing abilities of the ship, it is a great target for sabotage and damage in general.
	If destroyed it could swiftly lead to catastrophic mission failure.
	Things to consider:
						Reinforced Walls
						Reinforced Ceilings/Floors
						Motion Sensors
						Cameras Gallore
						Restricted Access
						Anything that makes this a real pain to get into (be creative)

Room Layout
	Each of the the APNPs and the APNW must be accessable, in addition to having a small material storage area/rack
	Things to consider:
						APNP and APNW sprites are approximately 1.5x2 tiles in size, spread them out to look better
						How far do you want to make the engineers run to manage all five devices?
						How are you going to integrate the room security features?

Power Considerations
	The APNP/APNW can be quite power intensive (Approximately 1.5MW total at maximum load), PLEASE DO NOT HAVE THE APC HOTWIRED INTO MAIN AT ROUND START.
	If engineers choose to do that during the round, then that is their decision.
	Things to consider:
						Large power draw to room
						Dedicated SMES Battery (remember they are 200KW per unit)
						Expanding current SMES bank handle higher loads

Starting Materials
	While it may seem tempting to give the engineers a massive pile of mats at round start, we are trying to encourage interdepartment cooperation.
	Additional materials can be scavenged from around the ship, acquired from mining or ordered from cargo (with the engineering budget card)
*/

#define RR_MAX 5000

/obj/machinery/armour_plating_nanorepair_well
	name = "Armour Plating Nano-repair Well"
	desc = "Central Well for the AP thingies" //KMC - Need a description
	icon = 'nsv13/icons/obj/machinery/armour_well.dmi'
	icon_state = "well"
	pixel_x = -16
	density = TRUE
	anchored = TRUE
	idle_power_usage = 50
	active_power_usage = 1000 //DOES THIS EVEN DO ANYTHING???
	circuit = /obj/item/circuitboard/machine/armour_plating_nanorepair_well
	layer = ABOVE_MOB_LAYER
	obj_integrity = 500
	var/obj/structure/overmap/OM //our parent ship
	var/list/apnp = list() //our child pumps
	var/resourcing_system = FALSE //System for generating additional RR
	var/repair_resources = 0 //Pool of liquid metal ready to be pumped out for repairs
	var/repair_resources_processing = FALSE
	var/repair_efficiency = 0 //modifier for how much repairs we get per cycle
	var/power_allocation = 0 //how much power we are pumping into the system
	var/system_allocation = 0 //the load on the system
	var/system_stress = 0 //how overloaded the system has been over time
	var/material_modifier = 0 //efficiency of our materials
	var/material_tier = 0 //The selected tier recipe producing RR
	var/apnw_id = null //The ID by which we identify our child devices - These should match the child devices and follow the formula: 1 - Main Ship, 2 - Secondary Ship, 3 - Syndie PvP Ship

/obj/machinery/armour_plating_nanorepair_well/Initialize()
	/*things we need to do here:
	- link to APNPs in the vacinity
	*/
	.=..()
	AddComponent(/datum/component/material_container,\
				list(/datum/material/iron,\
					/datum/material/silver,\
					/datum/material/titanium,\
					/datum/material/plasma),
					100000,
					FALSE,
					/obj/item/stack,
					null,
					null,
					FALSE)

	OM = get_overmap()
	addtimer(CALLBACK(src, .proc/handle_linking), 10 SECONDS)

/obj/machinery/armour_plating_nanorepair_well/process()

	if(is_operational())
		handle_system_stress()
		handle_repair_resources()
		handle_power_allocation()
		handle_repair_efficiency()
	update_icon()

/obj/machinery/armour_plating_nanorepair_well/proc/handle_repair_efficiency() //Sigmoidal Curve
	repair_efficiency = ((1 / (0.01 + (NUM_E ** (-0.00001 * power_allocation)))) * material_modifier) / 100

/obj/machinery/armour_plating_nanorepair_well/proc/handle_system_stress()
	system_allocation = 0
	for(var/obj/machinery/armour_plating_nanorepair_pump/P in apnp)
		if(P.armour_allocation > 0 || P.structure_allocation > 0)
			system_allocation += P.armour_allocation
			system_allocation += P.structure_allocation

	switch(system_allocation)
		if(0 to 100)
			system_stress --
			if(system_stress <= 0)
				system_stress = 0
		if(100 to INFINITY)
			system_stress += (system_allocation/100)

	if(system_stress >= 100)
		var/turf/open/L = get_turf(src)
		if(!istype(L) || !(L.air))
			return
		var/datum/gas_mixture/env = L.return_air()
		var/current_temp = env.return_temperature()
		env.set_temperature(current_temp + 1)
		air_update_turf()
		if(prob(system_stress - 100))
			var/list/overload_candidate = list()
			for(var/obj/machinery/armour_plating_nanorepair_pump/oc_apnp in apnp)
				if(oc_apnp.armour_allocation > 0 || oc_apnp.structure_allocation > 0)
					overload_candidate += oc_apnp
			if(overload_candidate.len > 0)
				var/obj/machinery/armour_plating_nanorepair_pump/target_apnp = pick(overload_candidate)
				if(target_apnp.last_restart < world.time + 60 SECONDS)
					target_apnp.stress_shutdown = TRUE


/obj/machinery/armour_plating_nanorepair_well/proc/handle_power_allocation()
	idle_power_usage = power_allocation

/obj/machinery/armour_plating_nanorepair_well/proc/handle_repair_resources()
	if(resourcing_system)
		if(repair_resources >= RR_MAX)
			repair_resources_processing = FALSE
			return
		else if(repair_resources < RR_MAX)
			switch(material_tier)
				if(0) //None Selected
					return
				if(1) //Iron
					var/datum/component/material_container/materials = GetComponent(/datum/component/material_container)
					var/iron_amount = min(100, (RR_MAX - repair_resources))
					if(materials.has_enough_of_material(/datum/material/iron, iron_amount)) //KMC [has_enough_of_material] isn't working as intended
						materials.use_amount_mat(iron_amount, /datum/material/iron)
						repair_resources += iron_amount / 2
						material_modifier = 0.125 //Very Low modifier
						repair_resources_processing = TRUE
				if(2) //Ferrotitanium
					var/datum/component/material_container/materials = GetComponent(/datum/component/material_container)
					var/iron_amount = min(25, (RR_MAX - repair_resources) * 0.25)
					var/titanium_amount = min(75, (RR_MAX - repair_resources) * 0.75)
					if(materials.has_enough_of_material(/datum/material/iron, iron_amount) && materials.has_enough_of_material(/datum/material/titanium, titanium_amount))
						materials.use_amount_mat(iron_amount, /datum/material/iron)
						materials.use_amount_mat(titanium_amount, /datum/material/titanium)
						repair_resources += (iron_amount + titanium_amount) / 2
						material_modifier = 0.33 //Low Modifier
						repair_resources_processing = TRUE
				if(3) //Durasteel
					var/datum/component/material_container/materials = GetComponent(/datum/component/material_container)
					var/iron_amount = min(20, (RR_MAX - repair_resources) * 0.20)
					var/silver_amount = min(15, (RR_MAX -  repair_resources) * 0.15)
					var/titanium_amount = min(65, (RR_MAX - repair_resources) * 0.65)
					if(materials.has_enough_of_material(/datum/material/iron, iron_amount) && materials.has_enough_of_material(/datum/material/silver, silver_amount) && materials.has_enough_of_material(/datum/material/titanium, titanium_amount))
						materials.use_amount_mat(iron_amount, /datum/material/iron)
						materials.use_amount_mat(silver_amount, /datum/material/silver)
						materials.use_amount_mat(titanium_amount, /datum/material/titanium)
						repair_resources += (iron_amount + silver_amount + titanium_amount) / 2
						material_modifier = 0.66 //Moderate Modifier
						repair_resources_processing = TRUE
				if(4) //Duranium
					var/datum/component/material_container/materials = GetComponent(/datum/component/material_container)
					var/iron_amount = min(17.5, (RR_MAX - repair_resources) * 0.175)
					var/silver_amount = min(15, (RR_MAX -  repair_resources) * 0.15)
					var/plasma_amount = min(5, (RR_MAX - repair_resources) * 0.05)
					var/titanium_amount = min(62.5, (RR_MAX - repair_resources) * 0.625)
					if(materials.has_enough_of_material(/datum/material/iron, iron_amount) && materials.has_enough_of_material(/datum/material/silver, silver_amount) && materials.has_enough_of_material(/datum/material/plasma, plasma_amount) && materials.has_enough_of_material(/datum/material/titanium, titanium_amount))
						materials.use_amount_mat(iron_amount, /datum/material/iron)
						materials.use_amount_mat(silver_amount, /datum/material/silver)
						materials.use_amount_mat(plasma_amount, /datum/material/plasma)
						materials.use_amount_mat(titanium_amount, /datum/material/titanium)
						repair_resources += (iron_amount + silver_amount + plasma_amount + titanium_amount) / 2
						material_modifier = 1 //High Modifier
						repair_resources_processing = TRUE

/obj/machinery/armour_plating_nanorepair_well/proc/handle_linking()
	if(apnw_id) //If mappers set an ID)
		for(var/obj/machinery/armour_plating_nanorepair_pump/P in GLOB.machines)
			if(P.apnw_id == apnw_id)
				apnp += P

/obj/machinery/armour_plating_nanorepair_well/attackby(obj/item/I, mob/user, params)
	.=..()
	if(I.tool_behaviour == TOOL_MULTITOOL)
		if(!multitool_check_buffer(user, I))
			return
		var/obj/item/multitool/M = I
		M.buffer = src
		playsound(src, 'sound/items/flashlight_on.ogg', 100, TRUE)
		to_chat(user, "<span class='notice'>Buffer loaded</span>")

/obj/machinery/armour_plating_nanorepair_well/update_icon()
	cut_overlays()
	var/repair_resources_percent = (repair_resources / RR_MAX) * 100
	switch(repair_resources_percent)
		if(0 to 25)
			icon_state = "well_0"
		if(25 to 50)
			icon_state = "well_25"
		if(50 to 75)
			icon_state = "well_50"
		if(75 to 100)
			icon_state = "well_75"
		if(100 to INFINITY)
			icon_state = "well_100"

	if(system_stress > 100)
		add_overlay("stressed")
	else if(repair_resources_processing)
		add_overlay("active")

/obj/machinery/armour_plating_nanorepair_well/attack_hand(mob/living/carbon/user)
	.=..()
	ui_interact(user)

/obj/machinery/armour_plating_nanorepair_well/attack_ai(mob/user)
	.=..()
	ui_interact(user)

/obj/machinery/armour_plating_nanorepair_well/attack_robot(mob/user)
	.=..()
	ui_interact(user)

/obj/machinery/armour_plating_nanorepair_well/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state) // Remember to use the appropriate state.
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "ArmourPlatingNanorepairWell", name, 560, 600, master_ui, state)
		ui.open()

/obj/machinery/armour_plating_nanorepair_well/ui_act(action, params, datum/tgui/ui)
	if(..())
		return
	if(!in_range(src, usr))
		return
	var/adjust = text2num(params["adjust"])
	if(action == "power_allocation")
		if(adjust && isnum(adjust))
			power_allocation = adjust
			if(power_allocation > 1000000)
				power_allocation = 1000000
				return
			if(power_allocation < 0)
				power_allocation = 0
				return
	switch(action)
		if("iron")
			if(material_tier != 0)
				to_chat(usr, "<span class='notice'>Error: Resources must be purged from the Well before selecting a different alloy</span>")
				var/sound = pick('nsv13/sound/effects/computer/error.ogg','nsv13/sound/effects/computer/error2.ogg','nsv13/sound/effects/computer/error3.ogg')
				playsound(src, sound, 100, 1)
				return
			else
				material_tier = 1

		if("ferrotitanium")
			if(material_tier != 0)
				to_chat(usr, "<span class='notice'>Error: Resources must be purged from the Well before selecting a different alloy</span>")
				var/sound = pick('nsv13/sound/effects/computer/error.ogg','nsv13/sound/effects/computer/error2.ogg','nsv13/sound/effects/computer/error3.ogg')
				playsound(src, sound, 100, 1)
				return
			else
				material_tier = 2

		if("durasteel")
			if(material_tier != 0)
				to_chat(usr, "<span class='notice'>Error: Resources must be purged from the Well before selecting a different alloy</span>")
				var/sound = pick('nsv13/sound/effects/computer/error.ogg','nsv13/sound/effects/computer/error2.ogg','nsv13/sound/effects/computer/error3.ogg')
				playsound(src, sound, 100, 1)
				return
			else
				material_tier = 3

		if("duranium")
			if(material_tier != 0)
				to_chat(usr, "<span class='notice'>Error: Resources must be purged from the Well before selecting a different alloy</span>")
				var/sound = pick('nsv13/sound/effects/computer/error.ogg','nsv13/sound/effects/computer/error2.ogg','nsv13/sound/effects/computer/error3.ogg')
				playsound(src, sound, 100, 1)
				return
			else
				material_tier = 4

		if("purge")
			if(resourcing_system)
				to_chat(usr, "<span class='notice'>Error: Resource Processing must first be disabled before purging the Well</span>")
				var/sound = pick('nsv13/sound/effects/computer/error.ogg','nsv13/sound/effects/computer/error2.ogg','nsv13/sound/effects/computer/error3.ogg')
				playsound(src, sound, 100, 1)
				return

			else if(alert("Purging the Well will prevent APNPs from functioning until refilled, continue?",name,"Yes","No") != "No" && Adjacent(usr))
				to_chat(usr, "<span class='warning'>System purging repair resources</span>")
				playsound(src, 'sound/machines/clockcult/steam_whoosh.ogg', 100, 1)
				repair_resources = 0
				material_tier = 0
				var/turf/open/L = get_turf(src)
				if(!istype(L) || !(L.air))
					return
				var/datum/gas_mixture/env = L.return_air()
				var/current_temp = env.return_temperature()
				env.set_temperature(current_temp + 25)
				air_update_turf()

		if("unload")
			if(resourcing_system)
				to_chat(usr, "<span class='notice'>Error: Resource Processing must first be disabled before purging the Well</span>")
				var/sound = pick('nsv13/sound/effects/computer/error.ogg','nsv13/sound/effects/computer/error2.ogg','nsv13/sound/effects/computer/error3.ogg')
				playsound(src, sound, 100, 1)
				return
			else
				var/datum/component/material_container/materials = GetComponent(/datum/component/material_container)
				materials.retrieve_all(get_turf(usr))

		if("toggle")
			if(material_tier == 0)
				to_chat(usr, "<span class='notice'>Error: An alloy must be selected before commencing Resource Processing</span>")
				var/sound = pick('nsv13/sound/effects/computer/error.ogg','nsv13/sound/effects/computer/error2.ogg','nsv13/sound/effects/computer/error3.ogg')
				playsound(src, sound, 100, 1)
			else
				resourcing_system = !resourcing_system

/obj/machinery/armour_plating_nanorepair_well/ui_data(mob/user)
	var/datum/component/material_container/materials = GetComponent(/datum/component/material_container)
	var/list/data = list()
	data["structural_integrity_current"] = OM.obj_integrity
	data["structural_integrity_max"] = OM.max_integrity
	data["quadrant_fs_armour_current"] = OM.armour_quadrants["forward_starboard"]["current_armour"]
	data["quadrant_fs_armour_max"] = OM.armour_quadrants["forward_starboard"]["max_armour"]
	data["quadrant_as_armour_current"] = OM.armour_quadrants["aft_starboard"]["current_armour"]
	data["quadrant_as_armour_max"] = OM.armour_quadrants["aft_starboard"]["max_armour"]
	data["quadrant_ap_armour_current"] = OM.armour_quadrants["aft_port"]["current_armour"]
	data["quadrant_ap_armour_max"] = OM.armour_quadrants["aft_port"]["max_armour"]
	data["quadrant_fp_armour_current"] = OM.armour_quadrants["forward_port"]["current_armour"]
	data["quadrant_fp_armour_max"] = OM.armour_quadrants["forward_port"]["max_armour"]
	data["repair_resources"] = repair_resources
	data["repair_resources_max"] = RR_MAX
	data["repair_efficiency"] = repair_efficiency
	data["system_allocation"] = system_allocation
	data["system_stress"] = system_stress
	data["power_allocation"] = power_allocation
	data["resourcing"] = resourcing_system
	data["iron"] = materials.get_material_amount(/datum/material/iron)
	data["titanium"] = materials.get_material_amount(/datum/material/titanium)
	data["silver"] = materials.get_material_amount(/datum/material/silver)
	data["plasma"] = materials.get_material_amount(/datum/material/plasma)
	switch(material_tier)
		if(0)
			data["alloy_t1"] = FALSE
			data["alloy_t2"] = FALSE
			data["alloy_t3"] = FALSE
			data["alloy_t4"] = FALSE
		if(1)
			data["alloy_t1"] = TRUE
			data["alloy_t2"] = FALSE
			data["alloy_t3"] = FALSE
			data["alloy_t4"] = FALSE
		if(2)
			data["alloy_t1"] = FALSE
			data["alloy_t2"] = TRUE
			data["alloy_t3"] = FALSE
			data["alloy_t4"] = FALSE
		if(3)
			data["alloy_t1"] = FALSE
			data["alloy_t2"] = FALSE
			data["alloy_t3"] = TRUE
			data["alloy_t4"] = FALSE
		if(4)
			data["alloy_t1"] = FALSE
			data["alloy_t2"] = FALSE
			data["alloy_t3"] = FALSE
			data["alloy_t4"] = TRUE
	return data

/obj/item/circuitboard/machine/armour_plating_nanorepair_well
	name = "Armour Plating Nano-repair Well (Machine Board)"
	build_path = /obj/machinery/armour_plating_nanorepair_well
	req_components = list(
		/obj/item/stock_parts/matter_bin = 10,
		/obj/item/stock_parts/manipulator = 5,
		/obj/item/stock_parts/scanning_module = 2,
		/obj/item/stock_parts/capacitor = 8,
		/obj/item/stock_parts/micro_laser = 2)

#undef RR_MAX
