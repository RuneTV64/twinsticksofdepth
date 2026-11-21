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
	"stump": ["stump", 0.6, 1.0],
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

# ---- the bite (stand-in times until the game has a clock: a game day will be 2 to 4 real hours)
## A zombie's bite infects. It starts in the part that was bitten and spreads to the body; once it is in the body
## it runs its course and you turn. Only taking the limb off before it has spread cures it, and that takes luck.
## Nobody is told any of these numbers: Medical gives the best guess.
var takes_chance := 0.92     # a bite that doesn't take is the other kind of luck
var turn_time := 900.0       # s from the bite to turning, untreated
var spread_time := {"ArmL": 200.0, "ArmR": 200.0, "LegL": 280.0, "LegR": 280.0}   # s to reach the body; head and chest: at once
var steroid_time := 240.0    # s one dose holds it back for
var steroid_slow := 0.4      # ... to this share of its pace
var infected := false        # it took
var infect_part := ""        # where it went in
var spread := 0.0            # 0 just bitten .. 1 it is in the body
var sickness := 0.0          # 0 .. 1 you turn
var steroid_t := 0.0
# ---- ordinary infection (owner, 21 Nov 2026). Not the zombie kind: it can kill you, it never turns you.
## Dirt gets into an open wound (`germs`), most of all through a cut foot walked on (soil()). Left there it
## takes hold (`inf` 0 to 1); washed in time, it doesn't. A wound it has taken hold of poisons the blood
## (`septic` 0 to 1), and at 1 you die of it. Washed and dressed, the body slowly beats it. Stand-in times.
## Every wound collects dirt and grime just by being a wound, and has to be cleaned from time to time (owner,
## 21 Nov 2026); feet collect it far faster, by being walked on (Player._step_in_it). A little the body
## shrugs off; past that it starts to go bad.
var open_grime := 1.0 / 1800.0     # germs a second in an open wound
var dressed_grime := 1.0 / 7200.0  # ... under a dressing: slower, but a dressing gets dirty too
var shrug := 0.1             # germs the body deals with by itself in an open wound
var dressed_shrug := 0.25    # ... and under a dressing
var infect_time := 90.0      # s for a filthy wound (germs 1) to go bad; a little dirt takes much longer
var hold := 0.5              # from here it has taken hold: washing no longer simply rinses it away
var fight_time := 300.0      # s for a washed, dressed wound to clear an infection that had taken hold
var septic_time := 720.0     # s from one wound gone fully bad to dying of it
var septic_back := 900.0     # s to get over it once no wound is bad
var blood_takes := 0.3       # chance fresh zombie blood in an open wound infects you as a bite would
var septic := 0.0
## Limbs that are gone: "ArmL", "LegR"...
var missing: Array[String] = []

# What it all adds up to, rebuilt on tick(). The sheet multiplies these in.
var pain := 0.0              # 0 none .. 1 overwhelming
var leg_pain := 0.0
var arm_pain := 0.0
var bleeding := 0.0          # blood % a second being lost now
var bitten := false


func reset() -> void:
	blood = 100.0
	painkiller_t = 0.0
	steroid_t = 0.0
	infected = false
	infect_part = ""
	spread = 0.0
	sickness = 0.0
	septic = 0.0
	gut = 0.0
	gut_coming = 0.0
	missing.clear()
	wounds.clear()
	_sum()


## A new wound. `amount` is the damage that caused it (40 or more is as bad as that kind gets).
## `where` says more about the place: "foot" is the sole of that leg's foot (it gets walked on).
## Returns the wound.
func hurt(kind: String, part: String, amount: float, where := "") -> Dictionary:
	if missing.has(part):
		part = "Torso"       # there is nothing there to hit
		where = ""
	if kind == "bite":
		_bitten(part)
	var sev := clampf(amount / 40.0, 0.1, 1.0)
	# A second hit on a part already hurt the same way makes that wound worse; it doesn't make a second one.
	for w in wounds:
		if w["part"] == part and w["kind"] == kind and str(w.get("where", "")) == where:
			w["sev"] = minf(float(w["sev"]) + sev * 0.7, 1.0)
			w["bleed"] = float(KINDS[kind][1]) * float(w["sev"])
			w["closing"] = 0.0
			# It tears open: stitches go, the dressing is soaked through, and it is dirty again.
			w["stitches"] = []
			w["dressed"] = ""
			w["clean"] = false
			_sum()
			return w
	# What is in it: a bullet, a tooth, grit and cloth. More likely the worse it is.
	var debris := 0
	if kind == "gunshot":
		debris = 1 if randf() < 0.6 else 0
	elif kind == "bite":
		debris = 1 if randf() < 0.3 else 0
	elif kind == "cut" or kind == "deep cut":
		debris = (1 if randf() < sev else 0) + (1 if randf() < sev * 0.5 else 0)
	wounds.append({"part": part, "kind": kind, "sev": sev, "bleed": float(KINDS[kind][1]) * sev, "closing": 0.0,
		"debris": debris, "clean": false, "stitches": [], "dressed": "", "fester": false, "seed": randi() % 100000,
		"where": where, "glass": 0, "germs": 0.0, "inf": 0.0})
	_sum()
	return wounds[wounds.size() - 1]


# ---------------------------------------------------------------- dirt, and ordinary infection
## A shard of glass goes into this wound and stays there until it is drawn out.
func glass_in(w: Dictionary) -> void:
	w["debris"] = int(w["debris"]) + 1
	w["glass"] = int(w.get("glass", 0)) + 1


## Is it open to the world: not dressed, not yet closed?
static func open(w: Dictionary) -> bool:
	return w["dressed"] == "" and float(w["closing"]) < 0.8 and w["kind"] != "bruise" and w["kind"] != "break"


## The open wounds on the soles of your feet; or, with `all`, every open wound (for someone crawling).
func open_feet(all := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in wounds:
		if (all or str(w.get("where", "")) == "foot") and open(w):
			out.append(w)
	return out


## The wounds on the soles of your feet that are dressed and not yet closed.
func dressed_feet() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in wounds:
		if str(w.get("where", "")) == "foot" and w["dressed"] != "" and float(w["closing"]) < 0.8:
			out.append(w)
	return out


## You have put an open wound in something: `amount` 0 to 1 is how foul it was.
func soil(w: Dictionary, amount: float) -> void:
	w["germs"] = minf(float(w.get("germs", 0.0)) + amount, 1.0)
	w["clean"] = false


## Fresh zombie blood in an open wound: it may take, as a bite does.
func blood_in(part: String) -> void:
	if randf() < blood_takes / maxf(takes_chance, 0.01):
		_bitten(part)


func _tick_infection(dt: float) -> void:
	var bad := 0
	for w in wounds:
		var germs := float(w.get("germs", 0.0))
		var inf := float(w.get("inf", 0.0))
		var covered: bool = w["dressed"] != ""
		# It gathers grime, open or dressed, until it has closed.
		if treatable(w) and float(w["closing"]) < 0.8:
			germs = minf(germs + dt * (dressed_grime if covered else open_grime), 1.0)
			w["germs"] = germs
		var over := germs - (dressed_shrug if covered else shrug)
		if over > 0.0:
			w["clean"] = false                           # it wants washing again
		if inf >= hold and not (over <= 0.0 and covered):
			inf = minf(inf + dt * maxf(over, 0.3) / infect_time, 1.0)    # it has taken hold: it feeds itself
		elif over > 0.0:
			inf = minf(inf + dt * over / infect_time, 1.0)
		elif inf > 0.0:
			inf = maxf(inf - dt / fight_time, 0.0)      # clean enough, and the body gets on top of it
		w["inf"] = inf
		if inf >= 1.0:
			bad += 1
	if bad > 0:
		septic = minf(septic + dt * minf(bad, 2.0) / septic_time, 1.0)
	else:
		septic = maxf(septic - dt / septic_back, 0.0)


func dead_from_sepsis() -> bool:
	return septic >= 1.0


# ---------------------------------------------------------------- the bite
func _bitten(part: String) -> void:
	if infected:
		# Bitten again somewhere nearer the body: it gets there sooner.
		if not spread_time.has(part):
			spread = 1.0
		return
	if randf() >= takes_chance:
		return
	infected = true
	infect_part = part
	spread = 0.0 if spread_time.has(part) else 1.0
	sickness = 0.0


func _tick_bite(dt: float) -> void:
	steroid_t = maxf(steroid_t - dt, 0.0)
	if not infected:
		return
	var pace := steroid_slow if steroid_t > 0.0 else 1.0
	if spread < 1.0:
		spread = minf(spread + dt * pace / float(spread_time[infect_part]), 1.0)
	sickness = minf(sickness + dt * pace / turn_time, 1.0)


func turned() -> bool:
	return infected and sickness >= 1.0


func take_steroid() -> void:
	steroid_t = steroid_time


## Can this part come off? (An arm or a leg that is still there.)
func can_amputate(part: String) -> bool:
	return spread_time.has(part) and not missing.has(part)


## The limb comes off. If the infection went in there and hasn't reached the body, this may cure it: nearly
## sure early, a coin toss late, a little better on steroids. `tied`: a tourniquet was on, so it bleeds far less.
func amputate(part: String, tied: bool) -> void:
	var i := 0
	while i < wounds.size():
		if wounds[i]["part"] == part:
			wounds.remove_at(i)
		else:
			i += 1
	missing.append(part)
	if infected and infect_part == part and spread < 1.0:
		var chance := clampf(1.0 - spread * spread + (0.1 if steroid_t > 0.0 else 0.0), 0.0, 0.97)
		if randf() < chance:
			infected = false
			sickness = 0.0
			spread = 0.0
		else:
			spread = 1.0
	wounds.append({"part": part, "kind": "stump", "sev": 1.0, "bleed": 0.6 * (0.4 if tied else 1.0), "closing": 0.0,
		"debris": 0, "clean": false, "stitches": [], "dressed": "", "fester": false, "seed": randi() % 100000, "tied": tied,
		"where": "", "glass": 0, "germs": 0.0, "inf": 0.0})
	_sum()


## How you feel from the infection: never a number.
## A fever feels the same whichever infection it is: the zombie's or an ordinary one. Only knowing medicine
## tells them apart (describe(), bite_guess()).
func fever_feel() -> String:
	var ill := maxf(sickness if infected else 0.0, septic)
	if ill < 0.2:
		return ""
	if ill < 0.45:
		return "Feverish"
	if ill < 0.75:
		return "Sick"
	return "Failing"


## What you can tell about the bite, by what you know; "" if nothing.
func bite_guess() -> String:
	var has_bite := false
	for w in wounds:
		has_bite = has_bite or w["kind"] == "bite"
	if not has_bite and not (infected and sickness >= 0.2):
		return ""
	if medical < 2:
		return "You have been bitten. You know what that means." if has_bite else ""
	if not infected:
		return "The bite looks clean so far. It may not have taken." if medical >= 4 and has_bite else "You have been bitten. Too soon to tell if it has taken."
	if medical < 4:
		return "The bite is infected." + (" If it is still in the limb, the limb could come off." if spread_time.has(infect_part) and not missing.has(infect_part) else "")
	if spread < 1.0:
		return "The infection is still in the %s: %s. Take it off and you may live." % [str(NAMES[infect_part]).to_lower(),
			"it has barely started" if spread < 0.35 else ("it is climbing" if spread < 0.7 else "it is nearly at the body")]
	return "The infection is in your body. Nothing cuts it out now."


# ---------------------------------------------------------------- seeing to a wound
## Is there anything to be done for it by hand? (Not for a bruise; a break needs a splint, which is to come.)
static func treatable(w: Dictionary) -> bool:
	return w["kind"] != "bruise" and w["kind"] != "break"


## How many stitches it wants. None for a slight cut, and a bite is left open.
static func stitches_needed(w: Dictionary) -> int:
	if w["kind"] == "bite" or w["kind"] == "stump" or not treatable(w) or float(w["sev"]) < 0.3:
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
	if w.get("tied", false):
		least *= 0.3
	return least


## Pressing on it for dt seconds. `good` 0 to 1: how nearly on the bleeder. A rag does it faster than a hand.
func press(w: Dictionary, dt: float, good: float, rag: bool) -> void:
	var half := (3.0 if rag else 5.0) / maxf(good, 0.1)
	# Pressure holds a deep wound well below what it bleeds left alone; let go, and it wells up again (tick).
	w["bleed"] = maxf(float(w["bleed"]) * exp(-dt * 0.693 / half), least_bleed(w) * 0.2)
	if float(w["bleed"]) < 0.01:
		w["bleed"] = 0.0
	_sum()


## Draw one thing out of it. Returns what it was: "glass", or "" for anything else.
func pull_debris(w: Dictionary) -> String:
	w["debris"] = maxi(int(w["debris"]) - 1, 0)
	if int(w.get("glass", 0)) > 0:
		w["glass"] = int(w["glass"]) - 1
		return "glass"
	return ""


## Washing rinses the dirt out. In time, that is the end of it; once it has taken hold it only stops it
## getting worse, and the wound must be kept covered while the body fights it. `left` is the dirt the wash
## itself leaves behind: 0 for spirits or clean water, more for dirty water (Water.wash_germs), which can
## leave a wound worse than it found it. Returns true if the wound is clean after it.
func wash(w: Dictionary, left := 0.0) -> bool:
	w["germs"] = left
	w["clean"] = left <= shrug
	if w["clean"] and float(w.get("inf", 0.0)) < hold:
		w["inf"] = 0.0
	return w["clean"]


# ---------------------------------------------------------------- the gut: bad water
## Drinking water with things living in it may make you ill: not at once, and not always. It passes in time;
## at its worst it can kill, by the same slow poisoning a wound gone bad does. It never turns you.
var gut := 0.0               # 0 well .. 1 as ill as it gets
var gut_coming := 0.0        # swallowed, not yet felt
var gut_onset := 90.0        # s for what you drank to make itself felt
var gut_over := 600.0        # s to get over it from the worst


func drink(bugs: float) -> void:
	if randf() < bugs:
		gut_coming = minf(gut_coming + 0.3 + 0.6 * bugs, 1.0)


func _tick_gut(dt: float) -> void:
	if gut_coming > 0.0:
		var d := minf(dt / gut_onset, gut_coming)
		gut_coming -= d
		gut = minf(gut + d, 1.0)
	else:
		gut = maxf(gut - dt / gut_over, 0.0)
	if gut > 0.8:
		septic = minf(septic + dt / (septic_time * 2.0), 1.0)


func gut_feel() -> String:
	if gut < 0.15:
		return ""
	if gut < 0.45:
		return "Queasy"
	if gut < 0.8:
		return "Sick to the stomach"
	return "Wretched"


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
		w["germs"] = maxf(float(w.get("germs", 0.0)), 0.6)     # and what is shut in goes bad


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
	elif w["kind"] == "stump":
		out.append(["Close it", "a stump is dressed, not stitched", true])
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
			if float(w.get("inf", 0.0)) >= hold:
				rate *= 0.2
			w["closing"] = minf(float(w["closing"]) + dt * rate / close_time, 1.0)
			if float(w["closing"]) >= 1.0 and float(w.get("inf", 0.0)) < hold and int(w["debris"]) == 0:
				wounds.remove_at(i)
				continue
		i += 1
	painkiller_t = maxf(painkiller_t - dt, 0.0)
	_tick_bite(dt)
	_tick_infection(dt)
	_tick_gut(dt)
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
		p += 0.25 * float(w.get("inf", 0.0))        # a wound going bad throbs, however small it was
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
			if float(w.get("germs", 0.0)) > 0.3:
				s += ", dirty"
			if float(w.get("inf", 0.0)) >= 1.0:
				s += ", hot and swollen"
			if str(w.get("where", "")) == "foot":
				s = "Foot: " + s.to_lower()
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
			if str(w.get("where", "")) == "foot":
				s2 += ", on the sole of the foot"
			var inf := float(w.get("inf", 0.0))
			if inf >= 1.0:
				s2 += " (infected: wash it, cover it, keep off it)"
			elif inf >= hold or (medical >= 3 and inf > 0.15):
				s2 += " (going bad)"
			elif float(w.get("germs", 0.0)) > 0.5:
				s2 += " (filthy: wash it now)"
			elif float(w.get("germs", 0.0)) > (dressed_shrug if w["dressed"] != "" else shrug):
				s2 += " (dirty: the dressing wants changing)" if w["dressed"] != "" else " (dirty: it wants washing)"
			if medical >= 2 and int(w.get("glass", 0)) > 0:
				s2 += " (glass in it)"
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
