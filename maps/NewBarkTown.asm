	object_const_def
	const NEWBARKTOWN_TEACHER
	const NEWBARKTOWN_FISHER
	const NEWBARKTOWN_SILVER
	const NEWBARKTOWN_CELEBI

NewBarkTown_MapScripts:
	def_scene_scripts
	scene_script .DummyScene0 ; SCENE_NEWBARKTOWN_NOTHING
	scene_script .DummyScene1 ; SCENE_NEWBARKTOWN_MEET_CELEBI

	def_callbacks
	callback MAPCALLBACK_NEWMAP, .FlyPoint
	callback MAPCALLBACK_OBJECTS, .HideCelebi

.DummyScene0:
	end

.DummyScene1:
	end

.FlyPoint:
	setflag ENGINE_FLYPOINT_NEW_BARK
	clearevent EVENT_FIRST_TIME_BANKING_WITH_MOM
	endcallback

; Celebi is only ever shown by the intro cutscene (via appear). Keep it hidden
; by default on every map load so it can't linger as a stray object -- this also
; covers save files made before the cutscene existed, where its flag is clear.
.HideCelebi:
	setevent EVENT_NEW_BARK_TOWN_CELEBI
	endcallback

NewBarkTown_TeacherStopsYouScene1:
	playmusic MUSIC_MOM
	turnobject NEWBARKTOWN_TEACHER, LEFT
	opentext
	writetext Text_WaitPlayer
	waitbutton
	closetext
	turnobject PLAYER, RIGHT
	applymovement NEWBARKTOWN_TEACHER, NewBarkTown_TeacherRunsToYouMovement1
	opentext
	writetext Text_WhatDoYouThinkYoureDoing
	waitbutton
	closetext
	follow NEWBARKTOWN_TEACHER, PLAYER
	applymovement NEWBARKTOWN_TEACHER, NewBarkTown_TeacherBringsYouBackMovement1
	stopfollow
	opentext
	writetext Text_ItsDangerousToGoAlone
	waitbutton
	closetext
	special RestartMapMusic
	end

NewBarkTown_TeacherStopsYouScene2:
	playmusic MUSIC_MOM
	turnobject NEWBARKTOWN_TEACHER, LEFT
	opentext
	writetext Text_WaitPlayer
	waitbutton
	closetext
	turnobject PLAYER, RIGHT
	applymovement NEWBARKTOWN_TEACHER, NewBarkTown_TeacherRunsToYouMovement2
	turnobject PLAYER, UP
	opentext
	writetext Text_WhatDoYouThinkYoureDoing
	waitbutton
	closetext
	follow NEWBARKTOWN_TEACHER, PLAYER
	applymovement NEWBARKTOWN_TEACHER, NewBarkTown_TeacherBringsYouBackMovement2
	stopfollow
	opentext
	writetext Text_ItsDangerousToGoAlone
	waitbutton
	closetext
	special RestartMapMusic
	end

NewBarkTownTeacherScript:
	faceplayer
	opentext
	checkevent EVENT_TALKED_TO_MOM_AFTER_MYSTERY_EGG_QUEST
	iftrue .CallMom
	checkevent EVENT_GAVE_MYSTERY_EGG_TO_ELM
	iftrue .TellMomYoureLeaving
	checkevent EVENT_GOT_A_POKEMON_FROM_ELM
	iftrue .MonIsAdorable
	writetext Text_GearIsImpressive
	waitbutton
	closetext
	end

.MonIsAdorable:
	writetext Text_YourMonIsAdorable
	waitbutton
	closetext
	end

.TellMomYoureLeaving:
	writetext Text_TellMomIfLeaving
	waitbutton
	closetext
	end

.CallMom:
	writetext Text_CallMomOnGear
	waitbutton
	closetext
	end

NewBarkTownFisherScript:
	jumptextfaceplayer Text_ElmDiscoveredNewMon

NewBarkTownSilverScript:
	opentext
	writetext NewBarkTownRivalText1
	waitbutton
	closetext
	turnobject NEWBARKTOWN_SILVER, LEFT
	opentext
	writetext NewBarkTownRivalText2
	waitbutton
	closetext
	follow PLAYER, NEWBARKTOWN_SILVER
	applymovement PLAYER, NewBarkTown_SilverPushesYouAwayMovement
	stopfollow
	pause 5
	turnobject NEWBARKTOWN_SILVER, DOWN
	pause 5
	playsound SFX_TACKLE
	applymovement PLAYER, NewBarkTown_SilverShovesYouOutMovement
	applymovement NEWBARKTOWN_SILVER, NewBarkTown_SilverReturnsToTheShadowsMovement
	end

NewBarkTownCelebiScene:
	special FadeOutMusic
	pause 20
	appear NEWBARKTOWN_CELEBI
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatDown
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatLeft
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatDown
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatDown
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatRight
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatRight
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatDown
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatDown
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatDown
	playsound SFX_FLY
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiFloatLeft
	turnobject NEWBARKTOWN_CELEBI, UP
	pause 10
	turnobject PLAYER, DOWN
	showemote EMOTE_SHOCK, PLAYER, 20
	pause 20
	opentext
	writetext CelebiSceneText
	waitbutton
	closetext
	pause 20
	playsound SFX_WARP_TO
	applymovement NEWBARKTOWN_CELEBI, NewBarkTown_CelebiTeleportsAwayMovement
	disappear NEWBARKTOWN_CELEBI
	waitsfx
	setscene SCENE_NEWBARKTOWN_NOTHING
	special RestartMapMusic
	end

NewBarkTownSign:
	jumptext NewBarkTownSignText

NewBarkTownPlayersHouseSign:
	jumptext NewBarkTownPlayersHouseSignText

NewBarkTownElmsLabSign:
	jumptext NewBarkTownElmsLabSignText

NewBarkTownElmsHouseSign:
	jumptext NewBarkTownElmsHouseSignText

NewBarkTown_TeacherRunsToYouMovement1:
	step LEFT
	step LEFT
	step LEFT
	step LEFT
	step_end

NewBarkTown_TeacherRunsToYouMovement2:
	step LEFT
	step LEFT
	step LEFT
	step LEFT
	step LEFT
	turn_head DOWN
	step_end

NewBarkTown_TeacherBringsYouBackMovement1:
	step RIGHT
	step RIGHT
	step RIGHT
	step RIGHT
	turn_head LEFT
	step_end

NewBarkTown_TeacherBringsYouBackMovement2:
	step RIGHT
	step RIGHT
	step RIGHT
	step RIGHT
	step RIGHT
	turn_head LEFT
	step_end

NewBarkTown_SilverPushesYouAwayMovement:
	turn_head UP
	step DOWN
	step_end

NewBarkTown_SilverShovesYouOutMovement:
	turn_head UP
	fix_facing
	jump_step DOWN
	remove_fixed_facing
	step_end

NewBarkTown_SilverReturnsToTheShadowsMovement:
	step RIGHT
	step_end

NewBarkTown_CelebiFloatDown:
	slow_step DOWN
	step_end

NewBarkTown_CelebiFloatLeft:
	slow_step LEFT
	step_end

NewBarkTown_CelebiFloatRight:
	slow_step RIGHT
	step_end

NewBarkTown_CelebiTeleportsAwayMovement:
	fast_slide_step UP
	fast_slide_step UP
	fast_slide_step UP
	fast_slide_step UP
	fast_slide_step UP
	fast_slide_step UP
	fast_slide_step UP
	step_end

Text_GearIsImpressive:
	text "Wow, your #GEAR"
	line "is impressive!"

	para "Did your mom get"
	line "it for you?"
	done

Text_WaitPlayer:
	text "Wait, <PLAY_G>!"
	done

Text_WhatDoYouThinkYoureDoing:
	text "What do you think"
	line "you're doing?"
	done

Text_ItsDangerousToGoAlone:
	text "It's dangerous to"
	line "go out without a"
	cont "#MON!"

	para "Wild #MON"
	line "jump out of the"

	para "grass on the way"
	line "to the next town."
	done

Text_YourMonIsAdorable:
	text "Oh! Your #MON"
	line "is adorable!"
	cont "I wish I had one!"
	done

Text_TellMomIfLeaving:
	text "Hi, <PLAY_G>!"
	line "Leaving again?"

	para "You should tell"
	line "your mom if you"
	cont "are leaving."
	done

Text_CallMomOnGear:
	text "Call your mom on"
	line "your #GEAR to"

	para "let her know how"
	line "you're doing."
	done

Text_ElmDiscoveredNewMon:
	text "Yo, <PLAYER>!"

	para "I hear PROF.ELM"
	line "discovered some"
	cont "new #MON."
	done

NewBarkTownRivalText1:
	text "<……>"

	para "So this is the"
	line "famous ELM #MON"
	cont "LAB…"
	done

NewBarkTownRivalText2:
	text "…What are you"
	line "staring at?"
	done

CelebiSceneText:
	text "(…)"

	para "(…………………)"

	para "(A gentle, warm"
	line "light envelops"
	cont "your mind…)"

	para "(…Human…)"
	line "(…Hear my voice…)"

	para "(I am the"
	line "guardian of the"
	cont "temporal flows.)"

	para "(I have watched"
	line "your bond with"
	cont "#MON across"
	cont "the eras.)"

	para "(The threads of"
	line "time are"
	cont "delicate, yet"
	cont "I sense a great"
	cont "purpose within"
	cont "your heart.)"

	para "(I shall grant"
	line "you a fragment"
	cont "of my blessing…)"

	para "(Look upon your"
	line "#GEAR. It has"
	cont "been touched by"
	cont "the eternal"
	cont "winds of time.)"

	para "(You now hold"
	line "the power to"
	cont "shift the hours,"
	cont "to command the"
	cont "sun and the moon"
	cont "at your will.)"

	para "(But remember…"
	line "time is a river.)"

	para "(Use this gift"
	line "with wisdom"
	cont "and respect.)"

	para "(…………………)"

	para "(The voice fades"
	line "away, leaving a"
	cont "lingering"
	cont "warmth…)"
	done

NewBarkTownSignText:
	text "NEW BARK TOWN"

	para "The Town Where the"
	line "Winds of a New"
	cont "Beginning Blow"
	done

NewBarkTownPlayersHouseSignText:
	text "<PLAYER>'s HOUSE"
	done

NewBarkTownElmsLabSignText:
	text "ELM #MON LAB"
	done

NewBarkTownElmsHouseSignText:
	text "ELM'S HOUSE"
	done

NewBarkTown_MapEvents:
	db 0, 0 ; filler

	def_warp_events
	warp_event  6,  3, ELMS_LAB, 1
	warp_event 13,  5, PLAYERS_HOUSE_1F, 1
	warp_event  3, 11, PLAYERS_NEIGHBORS_HOUSE, 1
	warp_event 11, 13, ELMS_HOUSE, 1

	def_coord_events
	coord_event  1,  8, SCENE_DEFAULT, NewBarkTown_TeacherStopsYouScene1
	coord_event  1,  9, SCENE_DEFAULT, NewBarkTown_TeacherStopsYouScene2
	coord_event 13,  6, SCENE_NEWBARKTOWN_MEET_CELEBI, NewBarkTownCelebiScene

	def_bg_events
	bg_event  8,  8, BGEVENT_READ, NewBarkTownSign
	bg_event 11,  5, BGEVENT_READ, NewBarkTownPlayersHouseSign
	bg_event  3,  3, BGEVENT_READ, NewBarkTownElmsLabSign
	bg_event  9, 13, BGEVENT_READ, NewBarkTownElmsHouseSign

	def_object_events
	object_event  6,  8, SPRITE_TEACHER, SPRITEMOVEDATA_SPINRANDOM_SLOW, 1, 0, -1, -1, 0, OBJECTTYPE_SCRIPT, 0, NewBarkTownTeacherScript, -1
	object_event 12,  9, SPRITE_FISHER, SPRITEMOVEDATA_WALK_UP_DOWN, 0, 1, -1, -1, PAL_NPC_GREEN, OBJECTTYPE_SCRIPT, 0, NewBarkTownFisherScript, -1
	object_event  3,  2, SPRITE_SILVER, SPRITEMOVEDATA_STANDING_RIGHT, 0, 0, -1, -1, 0, OBJECTTYPE_SCRIPT, 0, NewBarkTownSilverScript, EVENT_RIVAL_NEW_BARK_TOWN
	object_event 13,  1, SPRITE_CELEBI, SPRITEMOVEDATA_STILL, 0, 0, -1, -1, 0, OBJECTTYPE_SCRIPT, 0, ObjectEvent, EVENT_NEW_BARK_TOWN_CELEBI
