extends RefCounted

# Mirrors upstream `com.jediterm.core.input.Event` modifier masks.
const SHIFT_MASK := 1
const CTRL_MASK := 1 << 1
const META_MASK := 1 << 2
const ALT_MASK := 1 << 3
