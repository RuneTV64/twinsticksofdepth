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
## Small wounds clot and close on their own, slowly; bad ones keep bleeding until they are seen to.
## Everything moves on the sheet's slow clock, not per tick.
##
## Seeing to a wound (the treatment screen, treatment_screen.gd, does these by hand), in order:
##   press    on the bleeder: it clots many times faster, down to what a deep wound won't go below by itself
##   clean    pick out what is in it (pull_debris), then wash it (wash)
##   close    stitches along it (stitch). Enough of them, evenly placed, and a deep wound stops for good
##   dress    a bandage (or a rag, poorer) over it: it only oozes, and it stays clean
## A wound closed or dressed with dirt still in it festers: it goes on hurting and closes slowly. (What festering
## leads to comes with sickness.)

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
# ... it only eases to this share of its bleeding, until it is stitched or dressed.
var deep_floor := 0.35
var well_up_time := 30.0     # s for a deep wound you stopped pressing on to bleed as before
var ooze := 0.025            # bleeding this slow costs no blood
var painkiller_time := 180.0 # s one dose dulls pain for
var painkiller_t := 0.0
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
	painkiller_t = 0.0
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
			# It tears open: stitches go, the dressing is soaked through, and it is dirty again.
			w["stitches"] = []
			w["dressed"] = ""
			w["clean"] = false
			_sum()
			return
	# What is in it: a bullet, a tooth, grit and cloth. More likely the worse it is.
	var debris := 0
	if kind == "gunshot":
		debris = 1 if randf() < 0.6 else 0
	elif kind == "bite":
		debris = 1 if randf() < 0.3 else 0
	elif kind == "cut" or kind == "deep cut":
		debris = (1 if randf() < sev else 0) + (1 if randf() < sev * 0.5 else 0)
	wounds.append({"part": part, "kind": kind, "sev": sev, "bleed": float(KINDS[kind][1]) * sev, "closing": 0.0,
		"debris": debris, "clean": false, "stitches": [], "dressed": "", "fester": false, "seed": randi() % 100000})
	_sum()


# ---------------------------------------------------------------- seeing to a wound
## Is there anything to be done for it by hand? (Not for a bruise; a break needs a splint, which is to come.)
static func treatable(w: Dictionary) -> bool:
	return w["kind"] != "bruise" and w["kind"] != "break"


## How many stitches it wants. None for a slight cut, and a bite is left open.
static func stitches_needed(w: Dictionary) -> int:
	if w["kind"] == "bite" or not treatable(w) or float(w["sev"]) < 0.3:
		return 0
	return 2 if w["kind"] == "gunshot" else clampi(ceili(float(w["sev"]) * 7.0), 2, 7)


## How well it is stitched, 0 to 1: the share of the places a stitch should be that have one near enough.
static func closed_frac(w: Dictionary) -> float:
	var need := stitches_needed(w)
	if need == 0:
		return 0.0
	var got := 0
	for i in need:
		var ideal := (i + 0.5) / need
		for s in w["stitches"]:
			if absf(float(s) - ideal) <= 0.55 / need:
				got += 1
				break
	return float(got) / need


## The least it will bleed without more being done: nothing for a small wound; a deep one keeps on, less the
## better it is stitched, and much less under a dressing.
func least_bleed(w: Dictionary) -> float:
	if float(w["sev"]) < deep:
		return 0.0
	var least: float = float(KINDS[w["kind"]][1]) * float(w["sev"]) * deep_floor * (1.0 - closed_frac(w))
	if w["dressed"] == "bandage":
		least *= 0.2
	elif w["dressed"] == "rag":
		least *= 0.5
	return least


## Pressing on it for dt seconds. `good` 0 to 1: how nearly on the bleeder. A rag does it faster than a hand.
func press(w: Dictionary, dt: float, good: float, rag: bool) -> void:
	var half := (3.0 if rag else 5.0) / maxf(good, 0.1)
	# Pressure holds a deep wound well below what it bleeds left alone; let go, and it wells up again (tick).
	w["bleed"] = maxf(float(w["bleed"]) * exp(-dt * 0.693 / half), least_bleed(w) * 0.2)
	if float(w["bleed"]) < 0.01:
		w["bleed"] = 0.0
	_sum()


func pull_debris(w: Dictionary) -> void:
	w["debris"] = maxi(int(w["debris"]) - 1, 0)


func wash(w: Dictionary) -> void:
	w["clean"] = true


## A stitch, `at` 0 to 1 along the wound.
func stitch(w: Dictionary, at: float) -> void:
	w["stitches"].append(clampf(at, 0.0, 1.0))
	_shut_in(w)
	w["bleed"] = minf(float(w["bleed"]), maxf(least_bleed(w), float(w["bleed"]) * 0.8))
	_sum()


## `with`: "bandage" or "rag".
func dress(w: Dictionary, with: String) -> void:
	w["dressed"] = with
	_shut_in(w)
	w["bleed"] = minf(float(w["bleed"]), maxf(least_bleed(w), float(w["bleed"]) * (0.3 if with == "bandage" else 0.6)))
	_sum()


func undress(w: Dictionary) -> void:
	w["dressed"] = ""
	_sum()


## A slip of the hand in the wound: it bleeds a little more.
func fumble(w: Dictionary) -> void:
	w["bleed"] = minf(float(w["bleed"]) + 0.03, float(KINDS[w["kind"]][1]) * float(w["sev"]))
	_sum()


func take_painkiller() -> void:
	painkiller_t = painkiller_time
	_sum()


# Closed or covered with dirt still in it: it festers.
func _shut_in(w: Dictionary) -> void:
	if int(w["debris"]) > 0 or not w["clean"]:
		w["fester"] = true


## What has been done and what is left, for the treatment screen: [[name, state, done]].
func steps(w: Dictionary) -> Array:
	var out: Array = []
	var bl: float = w["bleed"]
	out.append(["Stop the bleeding: press on it", "done" if bl <= ooze and least_bleed(w) <= ooze else ("held, but it will well up again" if bl < least_bleed(w) else ("slowing" if bl < 0.1 else "bleeding")), bl <= ooze])
	var what := "can't tell what is in it"
	if medical >= 2:
		what = "nothing in it" if int(w["debris"]) == 0 else "%d thing%s in it" % [int(w["debris"]), "" if int(w["debris"]) == 1 else "s"]
	out.append(["Clean it: pick it out, wash it", ("washed" if w["clean"] else "not washed") + ", " + what, bool(w["clean"]) and int(w["debris"]) == 0])
	var need := stitches_needed(w)
	if need > 0:
		var n: int = w["stitches"].size()
		out.append(["Close it: stitches", ("%d of about %d" % [n, need]) if medical >= 3 else ("%d stitch%s" % [n, "" if n == 1 else "es"]), closed_frac(w) >= 0.99])
	elif w["kind"] == "bite":
		out.append(["Close it", "a bite is left open", true])
	out.append(["Dress it", "bandaged" if w["dressed"] == "bandage" else ("rag tied on" if w["dressed"] == "rag" else "open"), w["dressed"] != ""])
	return out


## The sheet's slow clock.
func tick(dt: float) -> void:
	var i := 0
	while i < wounds.size():
		var w := wounds[i]
		if float(w["bleed"]) > 0.0:
			# It clots: a small wound right down to nothing, a deep one only so far.
			var least := least_bleed(w)
			if float(w["bleed"]) < least:
				# Held down by pressing a while ago: it comes back over about half a minute.
				w["bleed"] = minf(float(w["bleed"]) + least * dt / well_up_time, least)
			else:
				w["bleed"] = maxf(float(w["bleed"]) * exp(-dt * 0.693 / clot_time), least)
				if float(w["bleed"]) < 0.01 and least < 0.01:
					w["bleed"] = 0.0
		if float(w["bleed"]) <= ooze:
			# It closes: faster stitched and dressed, slowly while it still oozes or festers.
			var rate := (1.0 + closed_frac(w)) * (1.25 if w["dressed"] != "" else 1.0)
			if float(w["bleed"]) > 0.0:
				rate *= 0.25
			if w["fester"]:
				rate *= 0.4
			w["closing"] = float(w["closing"]) + dt * rate / close_time
			if float(w["closing"]) >= 1.0:
				wounds.remove_at(i)
				continue
		i += 1
	painkiller_t = maxf(painkiller_t - dt, 0.0)
	_sum()
	if bleeding > ooze:
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
		var p: float = float(KINDS[w["kind"]][2]) * float(w["sev"]) * (1.0 - 0.6 * float(w["closing"]) * (0.0 if w["fester"] else 1.0))
		if painkiller_t > 0.0:
			p *= 0.5
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
			if bl > ooze:
				s += ", bleeding"
			if w["dressed"] != "":
				s += ", dressed"
			out.append(s)
		else:
			var how := "slight" if sev < 0.3 else ("nasty" if sev < 0.65 else "severe")
			var s2 := "%s %s" % [how.capitalize(), KINDS[w["kind"]][0]]
			if bl > 0.25:
				s2 += ", bleeding badly"
			elif bl > ooze:
				s2 += ", bleeding"
			elif bl > 0.0:
				s2 += ", oozing"
			elif float(w["closing"]) > 0.0:
				s2 += ", closing" if medical >= 3 else ""
			if w["dressed"] != "":
				s2 += ", dressed"
			if medical >= 4 and least_bleed(w) > ooze:
				s2 += " (won't stop on its own)"
			if medical >= 3 and w["fester"]:
				s2 += " (festering: shut in dirty)"
			out.append(s2)
	return out


## The best guess at how long you have, if you know enough to make one; else "". Never exact: the less you know,
## the rougher it is (and it is wrong by up to that much).
func time_left_guess() -> String:
	if medical < 4 or bleeding <= ooze:
		return ""
	var secs := (blood - dead_at) / bleeding
	var rough := lerpf(0.5, 0.1, clampf((medical - 4) / 6.0, 0.0, 1.0))
	secs *= 1.0 + rough * sin(float(wounds.size()) * 12.9898 + blood * 0.37)
	if secs > 1800.0:
		return "It is slow: you have a long while, if nothing gets worse."
	if secs > 120.0:
		return "At this rate you have about %d minutes." % roundi(secs / 60.0)
	return "At this rate you have a minute or two at most."
