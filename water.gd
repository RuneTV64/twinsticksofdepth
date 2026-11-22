class_name Water
extends RefCounted
## How clean water is (owner, 21 Nov 2026). Carried water is an item with two numbers, as in life:
##   dirt   0 clear .. 1 thick with mud. You can see it. It is grit in a wound and it spoils chemicals.
##   bugs   0 safe .. 1 teeming. You can't see it: clear water can still make you ill. This is what
##          infects a wound washed with it and sickens whoever drinks it.
## Making it safe, each way doing what it really does:
##   heat (a fire)   kills the bugs. The mud stays in it.
##   chemicals       kill the bugs after a wait; in cloudy water much less well.
##   a filter        takes the dirt out and most of the bugs with it, not all.
## So muddy water wants filtering and then boiling or tablets; clear water wants only heat or tablets.
## Nobody is told the bugs: the label says how it looks and what has been done to it.
## All numbers are first guesses.

const SEALED := {"dirt": 0.0, "bugs": 0.0}          # a bottle as found, never opened
const SOURCES := {
	"rain": {"name": "rain barrel", "dirt": 0.15, "bugs": 0.45},
	"pond": {"name": "standing water", "dirt": 0.7, "bugs": 0.9},
	"tap": {"name": "tap", "dirt": 0.0, "bugs": 0.03},
}
const TAB_WAIT := 60.0        # s for tablets to work (a stand-in until the game has a clock)
const BOIL_TIME := 20.0       # s on the fire


static func dirt(item: Dictionary) -> float:
	return float(item.get("dirt", 0.0))


static func bugs(item: Dictionary) -> float:
	return float(item.get("bugs", 0.0))


## Fill a bottle from somewhere: it takes on that water (mixed with what was left in it).
static func fill(item: Dictionary, src_dirt: float, src_bugs: float, full := 4) -> void:
	var had := maxi(int(item.get("uses", 0)), 0)
	var k := float(had) / float(full)
	item["dirt"] = dirt(item) * k + src_dirt * (1.0 - k)
	item["bugs"] = bugs(item) * k + src_bugs * (1.0 - k)
	item["uses"] = full
	item.erase("done")
	item.erase("tab_t")


## Heat: the bugs die, the mud stays.
static func boil(item: Dictionary) -> void:
	item["bugs"] = 0.0
	item.erase("tab_t")
	_done(item, "boiled")


## Chemicals go in; they have done their work TAB_WAIT later (tick()).
static func tablet(item: Dictionary) -> void:
	item["tab_t"] = TAB_WAIT


## A filter: the dirt comes out and most of the bugs.
static func filter(item: Dictionary) -> void:
	item["dirt"] = dirt(item) * 0.05
	item["bugs"] = bugs(item) * 0.15
	_done(item, "filtered")


## Strained through cloth (a net curtain): most of the mud stays in the cloth; what lives in it doesn't.
static func strain(item: Dictionary) -> void:
	item["dirt"] = dirt(item) * 0.35
	item["bugs"] = bugs(item) * 0.9
	_done(item, "strained")


static func _done(item: Dictionary, what: String) -> void:
	var d: Array = item.get("done", [])
	if not d.has(what):
		d.append(what)
	item["done"] = d


## The slow clock: tablets working. Returns true when they have just finished.
static func tick(item: Dictionary, dt: float) -> bool:
	if not item.has("tab_t"):
		return false
	item["tab_t"] = float(item["tab_t"]) - dt
	if float(item["tab_t"]) > 0.0:
		return false
	item.erase("tab_t")
	item["bugs"] = bugs(item) * (0.35 if dirt(item) > 0.4 else 0.0)     # cloudy water shields them
	_done(item, "treated")
	return true


## How much dirt a wound is left with after being washed in this (0 = properly clean).
static func wash_germs(item: Dictionary) -> float:
	return clampf(bugs(item) * 0.8 + dirt(item) * 0.3, 0.0, 1.0)


## How it looks, and what you know has been done to it: "cloudy, boiled".
static func look(item: Dictionary) -> String:
	var d := dirt(item)
	var words: Array[String] = ["clear" if d < 0.12 else ("cloudy" if d < 0.45 else "muddy")]
	for w: String in item.get("done", []):
		words.append(w)
	if item.has("tab_t"):
		words.append("tablets working")
	return ", ".join(words)
