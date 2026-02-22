extends RefCounted

enum Kind {
	ASCII,
	BRITISH,
	DANISH,
	DEC_SPECIAL_GRAPHICS,
	DEC_SUPPLEMENTAL,
	DUTCH,
	FINNISH,
	FRENCH,
	FRENCH_CANADIAN,
	GERMAN,
	ITALIAN,
	SPANISH,
	SWEDISH,
	SWISS,
}

var _kind: int = Kind.ASCII
var _designations: PackedInt32Array = PackedInt32Array([66])

func _init(kind: int = Kind.ASCII, designations: PackedInt32Array = PackedInt32Array([66])) -> void:
	_kind = int(kind)
	_designations = designations

static func valueOf(designation) -> RefCounted:
	var dcp := 0
	if typeof(designation) == TYPE_INT:
		dcp = int(designation)
	else:
		var s := String(designation)
		dcp = int(s.unicode_at(0)) if s.length() > 0 else 0

	for cs in _values():
		if cs._is_designation(dcp):
			return cs
	return _values()[0] # ASCII

func map(index: int) -> int:
	var i := int(index)
	match _kind:
		Kind.ASCII:
			return -1
		Kind.BRITISH:
			return 0x00a3 if i == 3 else -1
		Kind.DANISH:
			match i:
				32: return 0x00c4
				59: return 0x00c6
				60: return 0x00d8
				61: return 0x00c5
				62: return 0x00dc
				64: return 0x00e4
				91: return 0x00e6
				92: return 0x00f8
				93: return 0x00e5
				94: return 0x00fc
				_: return -1
		Kind.DEC_SPECIAL_GRAPHICS:
			if i >= 64 and i < 96:
				var CharacterSets := load("res://addons/jediterm/terminal/emulator/charset/character_sets.gd")
				if CharacterSets != null and CharacterSets.has_method("_get_dec_special_char_light"):
					return int(CharacterSets._get_dec_special_char_light(i - 64))
			return -1
		Kind.DEC_SUPPLEMENTAL:
			return i + 160 if i >= 0 and i < 64 else -1
		Kind.DUTCH:
			match i:
				3: return 0x00a3
				32: return 0x00be
				59: return 0x0133
				60: return 0x00bd
				61: return int("|".unicode_at(0))
				91: return 0x00a8
				92: return 0x0192
				93: return 0x00bc
				94: return 0x00b4
				_: return -1
		Kind.FINNISH:
			match i:
				59: return 0x00c4
				60: return 0x00d4
				61: return 0x00c5
				62: return 0x00dc
				64: return 0x00e9
				91: return 0x00e4
				92: return 0x00f6
				93: return 0x00e5
				94: return 0x00fc
				_: return -1
		Kind.FRENCH:
			match i:
				3: return 0x00a3
				32: return 0x00e0
				59: return 0x00b0
				60: return 0x00e7
				61: return 0x00a6
				91: return 0x00e9
				92: return 0x00f9
				93: return 0x00e8
				94: return 0x00a8
				_: return -1
		Kind.FRENCH_CANADIAN:
			match i:
				32: return 0x00e0
				59: return 0x00e2
				60: return 0x00e7
				61: return 0x00ea
				62: return 0x00ee
				91: return 0x00e9
				92: return 0x00f9
				93: return 0x00e8
				94: return 0x00fb
				_: return -1
		Kind.GERMAN:
			match i:
				32: return 0x00a7
				59: return 0x00c4
				60: return 0x00d6
				61: return 0x00dc
				91: return 0x00e4
				92: return 0x00f6
				93: return 0x00fc
				94: return 0x00df
				_: return -1
		Kind.ITALIAN:
			match i:
				3: return 0x00a3
				32: return 0x00a7
				59: return 0x00ba
				60: return 0x00e7
				61: return 0x00e9
				91: return 0x00e0
				92: return 0x00f2
				93: return 0x00e8
				94: return 0x00ec
				_: return -1
		Kind.SPANISH:
			match i:
				3: return 0x00a3
				32: return 0x00a7
				59: return 0x00a1
				60: return 0x00d1
				61: return 0x00bf
				91: return 0x00b0
				92: return 0x00f1
				93: return 0x00e7
				_: return -1
		Kind.SWEDISH:
			match i:
				32: return 0x00c9
				59: return 0x00c4
				60: return 0x00d6
				61: return 0x00c5
				62: return 0x00dc
				64: return 0x00e9
				91: return 0x00e4
				92: return 0x00f6
				93: return 0x00e5
				94: return 0x00fc
				_: return -1
		Kind.SWISS:
			match i:
				3: return 0x00f9
				32: return 0x00e0
				59: return 0x00e9
				60: return 0x00e7
				61: return 0x00ea
				62: return 0x00ee
				63: return 0x00e8
				64: return 0x00f4
				91: return 0x00e4
				92: return 0x00f6
				93: return 0x00fc
				94: return 0x00fb
				_: return -1
		_:
			return -1

func _is_designation(dcp: int) -> bool:
	for v in _designations:
		if int(v) == int(dcp):
			return true
	return false

static func _values() -> Array:
	# Mirrors upstream enum value list order (ASCII first).
	return [
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.ASCII, PackedInt32Array([int("B".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.BRITISH, PackedInt32Array([int("A".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.DANISH, PackedInt32Array([int("E".unicode_at(0)), int("6".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.DEC_SPECIAL_GRAPHICS, PackedInt32Array([int("0".unicode_at(0)), int("2".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.DEC_SUPPLEMENTAL, PackedInt32Array([int("U".unicode_at(0)), int("<".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.DUTCH, PackedInt32Array([int("4".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.FINNISH, PackedInt32Array([int("C".unicode_at(0)), int("5".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.FRENCH, PackedInt32Array([int("R".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.FRENCH_CANADIAN, PackedInt32Array([int("Q".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.GERMAN, PackedInt32Array([int("K".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.ITALIAN, PackedInt32Array([int("Y".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.SPANISH, PackedInt32Array([int("Z".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.SWEDISH, PackedInt32Array([int("H".unicode_at(0)), int("7".unicode_at(0))])),
		load("res://addons/jediterm/terminal/emulator/charset/character_set.gd").new(Kind.SWISS, PackedInt32Array([int("=".unicode_at(0))])),
	]
