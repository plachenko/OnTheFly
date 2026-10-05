# Codex game menu

## First version

- Double-tap LB opens a bottom-center menu and plays a chime without starting dictation.
- D-pad Up starts local Whisper dictation: tap to record until the next tap; hold for at least 500 ms to record until release. The middle Dictate button and text field highlight during recording; an upward notch animates toward the field. D-pad Left cancels dictation and closes the menu. RB sends a ready message or captures frames when the draft is empty.
- The menu offers a 150–800 ms double-tap delay, saved locally. Single-tap capture waits for that window to expire; a double tap takes no accidental photo.
- Gameplay continues. Existing screenshot, replay, and profiling actions receive single taps and holds outside the menu.
- Recording has the existing 30-second limit. At the limit, transcription creates a draft; RB still controls sending.
- No sequence attachments are sent in this version.

## Later work

- Queue deliberate LB screenshots and LB hold sequences captured before opening Codex. This is a list of intentional captures, not an automatic rolling buffer.
- Navigate the queue with D-pad Up/Down; select, trim, remove, reorder, and attach multiple captures to one message.
- Preserve queued captures and unfinished drafts across menu closure; define an explicit discard action.
- Use right face button B/Circle for confirmation and left face button X/Square for cancellation within queue editing.
- Double-tap D-pad Down toggles live capture mode, with a visible indication that LB now captures frames and microphone audio together.
- Use shared timestamps for live frames and raw audio; retain transcription segment or word timings for context alignment.
- Directional shortcuts are contextual: Up/Left dictate/cancel only inside the open Codex menu; Right/Down select rendered frames/physics ticks only during profile capture or while reviewing a captured profile. Outside those contexts, D-pad navigation passes through normally. Resolve future note navigation/live capture controls against these bindings.
- Decide screenshot burst versus video sequence formats, capture rates, storage limits, and retention policy.
- Add delivery acknowledgment, connection state, and Codex response display to the game menu.
- Validate real controller timing, microphone input, chime feedback, and visual layout in a live game session.

## TODO: note mode

- Implemented Save Note / D-pad Down inside the Codex menu. It finishes active dictation/capture, saves text and frame references with timestamps/camera metadata to `user://codex_notes`, and preserves the current draft without sending to Codex.

- Implemented initial frame collection: empty-draft RB tap captures one frame; RB hold records a sequence at up to 5 frames/second for 30 seconds. Captures appear above the message with first-frame thumbnails, survive menu closure, and attach with camera metadata when a message is sent.

- Add an explicit note mode for collecting videos, screenshots, dictation segments, and profiling data into one draft note.
- Let users review, edit, remove, and reorder collected items, and preserve the unfinished note until explicitly discarded.
- Keep capture timestamps and camera/profile metadata with each item so Codex can correlate evidence.
- Add browsing and reopening saved notes; send the compiled note and selected attachments to Codex only when the user chooses to.
