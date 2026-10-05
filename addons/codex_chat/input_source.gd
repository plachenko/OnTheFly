@tool
extends RefCounted

static func context(dictated: bool) -> String:
	if not dictated:
		return "\nInput source (metadata): typed text.\n"
	return "\nInput source (metadata): speech dictation, possibly edited or combined with typed text. Speech recognition can mishear words, names and punctuation. Treat unclear wording as a possible transcription error; use conversation and project context to interpret it. If the intended meaning remains uncertain, ask a brief clarification before making changes that depend on it. Do not invent a meaning or silently rewrite the user's request.\n"

static func speaker(dictated: bool) -> String:
	return "You (dictatated)" if dictated else "You"

static func command(text: String, dictated: bool) -> String:
	return text.strip_edges() + (" (dictatated)" if dictated else "")
