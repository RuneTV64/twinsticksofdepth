class_name BodyHealth
extends RefCounted
## A person's body: where they are hurt, how much blood they have, and how much it hurts. Part of the character
## sheet (character_sheet.gd, `sheet.body`).
##
##   wounds   each is on one of six parts (the same six the zombie model has), of a kind: bruise, cut, deep cut,
##            bite, gunshot, break. A wound has a severity, may bleed, and hurts.
##   blood    100 is full. Bleeding wounds drain it. Too little and you are slow, then faint, then dead: blood is
##            what kills quickly. It comes back slowly once nothing is bleeding.
##   pain     adds up from every wound. It slows you (legs most) and spoils your aim (arms most). Adrenaline hides
##            it for a while.
##   medical  knowing medicine is seeing. With none, you know only that a part hurts or is bleeding. With some,
##            what kind of wound it is and how bad. With more, how long you have. Nobody ever gets an exact number:
##            you can tell you are close to death, not how close; medical gives the best guess.
##
## Small wounds clot and close on their own, slowly; bad ones keep bleeding until they are seen to (the treatment
## screen, to come). Everything moves on the sheet's slow clock, not per tick.

const PARTS: Array[String] = ["Head", "Torso", "ArmL", "ArmR", "LegL", "LegR"]
const NAMES := {"Head": "Head", "Torso": "Chest", "ArmL": "Left arm", "ArmR": "Right arm",
	"LegL": "Left leg", "LegR": "Right leg"}

## kind -> [what it is called, blood % a second at full severity, pain at full severity]
const KINDS := {
	"bruise": ["bruise", 0.0, 0.25],
	"cut": ["cut", 0.12, 0.3],
	"deep cut": ["deep cut", 0.3, 0.55],
	"bite": ["bite", 0.15, 0.6],
	"gunshot": ["gunshot wound", 0.3, 0.8],
	"break": ["break", 0.0, 0.9],
}

var blood := 100.0
var wounds: Array[Dictionary] = []
## Medical knowledge, 0 to 10. A stand-in number until skills exist (set it on the character page).
var medical := 0

# ---- tuning
var clot_time := 60.0        # s for a wound's bleeding to halve by itself
var deep := 0.55             # severity from which a wound won't stop bleeding by itself
# ... it only eases to this share of its bleeding. 0 for now: until wounds can be treated, everything clots in
# the end, or any firefight would be a death sentence. Set it to about 0.35 when the treatment screen exists.
var deep_floor := 0.0
var close_time := 150.0      # s for a wound that has stopped bleeding to close (a stand-in until time and treatment exist)
var blood_back := 0.06       # blood % a second coming back when nothing is bleeding
var dead_at := 35.0          # blood at which you die

# What it all adds up to, rebuilt on tick(). The sheet multiplies these in.
var pain := 0.0              # 0 none .. 1 overwhelming
var leg_pain := 0.0
var arm_pain := 0.0
var bleeding := 0.0          # blood % a second being lost now
var bitten := false


func reset() -> void:
	blood = 100.0
	wounds.clear()
	_sum()


## A new wound. `amount` is the damage that caused it (40 or more is as bad as that kind gets).
func hurt(kind: String, part: String, amount: float) -> void:
	var sev := clampf(amount / 40.0, 0.1, 1.0)
	# A second hit on a part already hurt the same way makes that wound worse; it doesn't make a second one.
	for w in wounds:
		if w["part"] == part and w["kind"] == kind:
			w["sev"] = minf(float(w["sev"]) + sev * 0.7, 1.0)
			w["bleed"] = float(KINDS[kind][1]) * float(w["sev"])
			w["closing"] = 0.0
			_sum()
			return
	wounds.append({"part": part, "kind": kind, "sev": sev, "bleed": float(KINDS[kind][1]) * sev, "closing": 0.0})
	_sum()


## The sheet's slow clock.
func tick(dt: float) -> void:
	var i := 0
	while i < wounds.size():
		var w := wounds[i]
		var full: float = float(KINDS[w["kind"]][1]) * float(w["sev"])
		if float(w["bleed"]) > 0.0:
			# It clots: a small wound right down to nothing, a deep one only so far.
			var least := full * deep_floor if float(w["sev"]) >= deep else 0.0
			w["bleed"] = maxf(float(w["bleed"]) * exp(-dt * 0.693 / clot_time), least)
			if float(w["bleed"]) < 0.01 and least == 0.0:
				w["bleed"] = 0.0
		else:
			w["closing"] = float(w["closing"]) + dt / close_time
			if float(w["closing"]) >= 1.0:
				wounds.remove_at(i)
				continue
		i += 1
	_sum()
	if bleeding > 0.0:
		blood = maxf(blood - bleeding * dt, 0.0)
	else:
		blood = minf(blood + blood_back * dt, 100.0)


func _sum() -> void:
	pain = 0.0
	leg_pain = 0.0
	arm_pain = 0.0
	bleeding = 0.0
	bitten = false
	for w in wounds:
		var p: float = float(KINDS[w["kind"]][2]) * float(w["sev"]) * (1.0 - 0.6 * float(w["closing"]))
		pain += p
		if (w["part"] as String).begins_with("Leg"):
			leg_pain += p
		elif (w["part"] as String).begins_with("Arm"):
			arm_pain += p
		bleeding += float(w["bleed"])
		if w["kind"] == "bite":
			bitten = true
	pain = minf(pain, 1.0)
	leg_pain = minf(leg_pain, 1.0)
	arm_pain = minf(arm_pain, 1.0)


func dead_from_blood() -> bool:
	return blood <= dead_at


## How you feel, from your blood: never a number.
func blood_feel() -> String:
	if blood > 85.0:
		return ""
	if blood > 70.0:
		return "Pale"
	if blood > 55.0:
		return "Light-headed"
	if blood > 45.0:
		return "Faint"
	return "Fading"


## What you can tell about one part, as lines for the character page. How much depends on what you know.
func describe(part: String) -> Array[String]:
	var out: Array[String] = []
	for w in wounds:
		if w["part"] != part:
			continue
		var sev: float = w["sev"]
		var bl: float = w["bleed"]
		if medical < 2:
			# Untrained: it hurts, and you can see blood.
			var s := "Hurts" if sev < 0.5 else "Hurts badly"
			if bl > 0.02:
				s += ", bleeding"
			out.append(s)
		else:
			var how := "slight" if sev < 0.3 else ("nasty" if sev < 0.65 else "severe")
			var s2 := "%s %s" % [how.capitalize(), KINDS[w["kind"]][0]]
			if bl > 0.25:
				s2 += ", bleeding badly"
			elif bl > 0.02:
				s2 += ", bleeding"
			elif float(w["closing"]) > 0.0:
				s2 += ", closing" if medical >= 3 else ""
			if medical >= 4 and sev >= deep and bl > 0.0 and deep_floor > 0.0:
				s2 += " (won't stop on its own)"
			out.append(s2)
	return out


## The best guess at how long you have, if you know enough to make one; else "". Never exact: the less you know,
## the rougher it is (and it is wrong by up to that much).
func time_left_guess() -> String:
	if medical < 4 or bleeding <= 0.005:
		return ""
	var secs := (blood - dead_at) / bleeding
	var rough := lerpf(0.5, 0.1, clampf((medical - 4) / 6.0, 0.0, 1.0))
	secs *= 1.0 + rough * sin(float(wounds.size()) * 12.9898 + blood * 0.37)
	if secs > 1800.0:
		return "It is slow: you have a long while, if nothing gets worse."
	if secs > 120.0:
		return "At this rate you have about %d minutes." % roundi(secs / 60.0)
	return "At this rate you have a minute or two at most."
