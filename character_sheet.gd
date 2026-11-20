class_name CharacterSheet
extends RefCounted
## What a person is made of, as numbers: a cross between a survival RPG's attributes and The Sims' needs.
## The Player has one; raiders and other players are meant to get one too.
##
##   attributes   seven numbers, 1 to 20, 10 is an ordinary adult. They set what the body can do.
##   needs        food, water, rest: 100 is satisfied, 0 is empty. They run down with time and bring conditions.
##   composure    100 is calm, 0 is panic. Danger wears it down; quiet (and cover) brings it back.
##   conditions   what is affecting you right now, each with its effect. Worked out from the above.
##   traits       things true of this person all the time.
##
## Nothing here is worked out every tick (the owner's rule for slow things). The owner of the sheet calls tick()
## a few times a second; conditions and the multipliers below are rebuilt then, and whoever needs them reads them.

const ATTRS: Array[String] = ["strength", "dexterity", "endurance", "constitution", "intelligence", "wisdom", "charisma"]
const SHORT := {"strength": "STR", "dexterity": "DEX", "endurance": "END", "constitution": "CON",
	"intelligence": "INT", "wisdom": "WIS", "charisma": "CHA"}
## What each attribute does in the game today.
const GOVERNS := {
	"strength": "What you can carry before it slows you, barging doors, punches, shoves",
	"dexterity": "Aimed-shot damage, headshot chance, reload speed, how wild blind fire is",
	"endurance": "Stamina, how fast it comes back, top speed",
	"constitution": "Health, how fast you heal",
	"intelligence": "",
	"wisdom": "Awareness around you, how well you keep your head in danger",
	"charisma": "",
}
## What each is meant to do once the game has it. Not wired.
const LATER := {
	"strength": "melee weapons, hauling bodies and furniture",
	"dexterity": "lockpicking, quiet movement",
	"endurance": "how far you can travel in a day",
	"constitution": "fighting off infection and illness, going hungry longer",
	"intelligence": "learning skills faster, crafting, medicine, repairs",
	"wisdom": "hearing things sooner, reading people",
	"charisma": "trading, recruiting, talking raiders down, group morale",
}
const ATTR_MIN := 1.0
const ATTR_MAX := 20.0

const NEEDS: Array[String] = ["food", "water", "rest"]
const NEED_NAMES := {"food": "Food", "water": "Water", "rest": "Rest"}
## Points lost per game hour, awake. Stand-ins until the time system: food lasts about a day, water about 16
## hours, rest about 20.
const NEED_DRAIN := {"food": 4.0, "water": 6.0, "rest": 5.0}

var attrs := {}
var needs := {}
## Where they are hurt, their blood and their pain (body_health.gd).
var body := BodyHealth.new()
var composure := 100.0
## Game hours per real second. 0 = needs don't run down: there is no clock and nothing to eat yet. The time
## system sets this.
var needs_rate := 0.0
## Innate to every person. Picked traits (good and bad, chosen at character creation) are to come.
var traits: Array[Dictionary] = [
	{"name": "Fight-or-flight", "text": "Grabbed or hurt, adrenaline hits: faster, tireless, pain ignored. Then the crash."},
]

## Right now: [{name, text, bad}] for the page and the HUD.
var conditions: Array[Dictionary] = []
# What the conditions add up to. The Player multiplies these in where it moves, tires, heals and shoots.
var speed_mult := 1.0
var stamina_regen_mult := 1.0
var stamina_cost_mult := 1.0
var aim_mult := 1.0        # scales the aimed-shot bonus and headshot chance
var spread_mult := 1.0     # scales blind fire's spread
var heal_mult := 1.0

# ---- composure tuning
var threat_loss := 3.0       # composure lost per second for one zombie right on top of you
var threat_loss_max := 12.0  # ... and for a whole crowd
var held_loss := 8.0         # per second while something has hold of you
var calm_delay := 2.0        # s with no threat before it starts coming back
var calm_gain := 5.0         # per second, calm
var hidden_gain := 2.0       # times that, hunkered behind cover
var hurt_loss := 0.6         # composure lost per 1% of full health taken
# ---- adrenaline tuning
var adrenaline_time := 8.0
var crash_time := 15.0
var adrenaline_rest := 60.0  # s before it can hit again

var adrenaline_t := 0.0
var crash_t := 0.0
var _adrenaline_cd := 0.0
var _calm_t := 0.0
var _health_frac := 1.0
var _winded := false
var _burden := 0.8


func _init() -> void:
	for a in ATTRS:
		attrs[a] = 10.0
	for n in NEEDS:
		needs[n] = 100.0
	_rebuild()


func attr(a: String) -> float:
	return attrs[a]


func set_attr(a: String, v: float) -> void:
	attrs[a] = clampf(v, ATTR_MIN, ATTR_MAX)


## How far an attribute is above (or below) an ordinary 10.
func bonus(a: String) -> float:
	return float(attrs[a]) - 10.0


func set_need(n: String, v: float) -> void:
	needs[n] = clampf(v, 0.0, 100.0)
	_rebuild()


## Call a few times a second. threat: 0 = nothing near, 1 = one zombie on top of you, more for a crowd.
func tick(dt: float, threat: float, held: bool, hidden: bool, health_frac: float, winded: bool, burden: float) -> void:
	_health_frac = health_frac
	_winded = winded
	_burden = burden
	# Needs run down with game time (not at all until the time system sets needs_rate).
	if needs_rate > 0.0:
		for n in NEEDS:
			needs[n] = maxf(float(needs[n]) - float(NEED_DRAIN[n]) * needs_rate * dt, 0.0)
	# Composure: danger wears it down, slower for the wise; quiet brings it back, faster behind cover.
	var steady := clampf(1.0 - 0.04 * bonus("wisdom"), 0.5, 1.5)
	var loss := minf(threat * threat_loss, threat_loss_max) + (held_loss if held else 0.0)
	if loss > 0.0:
		_calm_t = 0.0
		composure = maxf(composure - loss * steady * dt, 0.0)
	else:
		_calm_t += dt
		if _calm_t >= calm_delay:
			composure = minf(composure + calm_gain * (hidden_gain if hidden else 1.0) * dt, 100.0)
	body.tick(dt)
	adrenaline_t = maxf(adrenaline_t - dt, 0.0)
	if adrenaline_t <= 0.0 and crash_t > 0.0:
		crash_t = maxf(crash_t - dt, 0.0)
	_adrenaline_cd = maxf(_adrenaline_cd - dt, 0.0)
	_rebuild()


## Took damage: frac = how much of full health it was.
func hurt(frac: float) -> void:
	var steady := clampf(1.0 - 0.04 * bonus("wisdom"), 0.5, 1.5)
	composure = maxf(composure - frac * 100.0 * hurt_loss * steady, 0.0)
	_calm_t = 0.0
	startle()


## Something that sets off fight-or-flight (grabbed, hurt). It can't hit again until it has worn off and rested.
func startle() -> void:
	if adrenaline_t > 0.0 or crash_t > 0.0 or _adrenaline_cd > 0.0:
		return
	adrenaline_t = adrenaline_time
	crash_t = crash_time
	_adrenaline_cd = adrenaline_time + crash_time + adrenaline_rest
	_rebuild()


## Back to rested and calm (a respawn). Needs are left as they are.
func reset() -> void:
	composure = 100.0
	adrenaline_t = 0.0
	crash_t = 0.0
	_adrenaline_cd = 0.0
	_health_frac = 1.0
	_winded = false
	body.reset()
	_rebuild()


func _add(cond_name: String, text: String, bad := true) -> void:
	conditions.append({"name": cond_name, "text": text, "bad": bad})


## Conditions from where things stand, and the multipliers they add up to.
func _rebuild() -> void:
	conditions.clear()
	speed_mult = 1.0
	stamina_regen_mult = 1.0
	stamina_cost_mult = 1.0
	aim_mult = 1.0
	spread_mult = 1.0
	heal_mult = 1.0
	var rush := adrenaline_t > 0.0

	if rush:
		_add("Adrenaline", "+10% speed, effort costs 40% less, pain ignored", false)
		speed_mult *= 1.1
		stamina_cost_mult *= 0.6
	elif crash_t > 0.0:
		_add("Crash", "stamina comes back 30% slower")
		stamina_regen_mult *= 0.7

	# Hurt: slows you and spoils your aim, unless adrenaline is carrying you.
	if _health_frac < 0.25:
		_add("Badly hurt", "-20% speed, -15% aim" if not rush else "ignored for now")
		if not rush:
			speed_mult *= 0.8
			aim_mult *= 0.85
	elif _health_frac < 0.5:
		_add("Hurt", "-10% speed" if not rush else "ignored for now")
		if not rush:
			speed_mult *= 0.9

	# The body: bleeding, blood lost, pain. Adrenaline hides the pain, not the bleeding.
	if body.bleeding > 0.25:
		_add("Bleeding badly", "you are losing blood fast")
	elif body.bleeding > body.ooze:
		_add("Bleeding", "you are losing blood")
	var feel := body.blood_feel()
	if feel == "Pale":
		_add(feel, "stamina comes back 15% slower")
		stamina_regen_mult *= 0.85
	elif feel == "Light-headed":
		_add(feel, "-10% speed, -15% aim, stamina comes back 30% slower")
		speed_mult *= 0.9
		aim_mult *= 0.85
		stamina_regen_mult *= 0.7
	elif feel == "Faint":
		_add(feel, "-25% speed, -35% aim: you need to stop the bleeding")
		speed_mult *= 0.75
		aim_mult *= 0.65
		stamina_regen_mult *= 0.5
	elif feel == "Fading":
		_add(feel, "-45% speed, -60% aim: you are close to death")
		speed_mult *= 0.55
		aim_mult *= 0.4
		stamina_regen_mult *= 0.3
	if body.pain > 0.08:
		if rush:
			_add("In pain", "you don't feel it yet", false)
		else:
			_add("In agony" if body.pain > 0.6 else "In pain", "hurt legs slow you, hurt arms spoil your aim")
			speed_mult *= 1.0 - 0.35 * body.leg_pain - 0.08 * body.pain
			aim_mult *= 1.0 - 0.4 * body.arm_pain - 0.1 * body.pain
			spread_mult *= 1.0 + 0.5 * body.arm_pain
	if body.bitten:
		_add("Bitten", "what that means is still to come")

	if composure < 20.0:
		_add("Panicked", "-30% aim, blind fire 50% wilder")
		aim_mult *= 0.7
		spread_mult *= 1.5
	elif composure < 50.0:
		_add("Shaken", "-10% aim, blind fire 20% wilder")
		aim_mult *= 0.9
		spread_mult *= 1.2

	var food: float = needs["food"]
	if food < 10.0:
		_add("Starving", "stamina comes back 40% slower, no healing")
		stamina_regen_mult *= 0.6
		heal_mult = 0.0
	elif food < 25.0:
		_add("Very hungry", "stamina comes back 25% slower, healing halved")
		stamina_regen_mult *= 0.75
		heal_mult *= 0.5
	elif food < 50.0:
		_add("Hungry", "stamina comes back 10% slower")
		stamina_regen_mult *= 0.9

	var water: float = needs["water"]
	if water < 10.0:
		_add("Parched", "stamina comes back 40% slower, -15% speed")
		stamina_regen_mult *= 0.6
		speed_mult *= 0.85
	elif water < 25.0:
		_add("Very thirsty", "stamina comes back 25% slower, -5% speed")
		stamina_regen_mult *= 0.75
		speed_mult *= 0.95
	elif water < 50.0:
		_add("Thirsty", "stamina comes back 10% slower")
		stamina_regen_mult *= 0.9

	var rest: float = needs["rest"]
	if rest < 10.0:
		_add("Exhausted", "-40% aim, -10% speed")
		aim_mult *= 0.6
		speed_mult *= 0.9
	elif rest < 25.0:
		_add("Very tired", "-25% aim")
		aim_mult *= 0.75
	elif rest < 50.0:
		_add("Tired", "-10% aim")
		aim_mult *= 0.9

	if _burden > 1.0:
		_add("Overloaded", "carrying more than your strength handles: slower, effort costs more")
	if _winded:
		_add("Winded", "no running, dashing or shoving until you catch your breath")
