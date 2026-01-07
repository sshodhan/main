# OpenAI Sora Integration Architecture

This document explains how the current codebase wires up OpenAI Sora video generation and playback, and outlines the guardrails and templates you should use to verify the integration end to end.

## 0) Policy & Product Constraints

- **Consent & likeness rights:** Never generate or reproduce a real person (you, kids, users) without explicit consent/rights. The Service Terms prohibit likeness reproduction without consent; expect stricter gating for real-people depictions.
- **Reference image quality:** Keep lighting consistent, background neutral, and the face unobstructed. Avoid mixing ages/filters/makeup/angles or multiple characters per clip. Maintain a stable identity set; do not re-upload frequently to avoid drift.
- **Locked prompt schema:** Keep the two-layer prompting approach stable. The server assembles a locked **Identity + Style Bible** (identity anchor, wardrobe rules—including the mandatory lower-body garment—and visual style: clean, PG, kid-safe, no logos/text). Each request only supplies the **Scene Spec** (location, weather, outfit items, vibe, optional dialog).
- **Video template (image → video friendly):** Always structure scene prompts like:
  \`\`\`
  SUBJECT: Same person as reference images. Preserve likeness and facial structure.
  OUTFIT (4-piece, include lower-body):
  Base layer: [ ]
  Lower-body (mandatory): [ ]
  Outerwear: [ ]
  Footwear + accessory: [ ]

  SCENE: [location], [time of day], [weather], [background simple].
  CAMERA: Vertical 9:16, medium shot → full body → close-up detail, smooth tracking.
  MOTION: 6–10s runway walk, subtle cloth movement, natural gait, no jump cuts.
  LIGHTING: Soft natural light, realistic skin tones.
  AUDIO/DIALOG (optional): [persona line], natural voice, short.
  NEGATIVE / AVOID: No face morphing, no extra people, no costume masks, no text.
  CONSISTENCY: Match hair, face, and body proportions to reference images.
  \`\`\`

## 1) System Boundaries & Ownership

- **Server-side prompt + Sora call:** `app/actions/openai-video-actions.ts` builds the Sora prompt, enforces outfit/reference requirements, and calls OpenAI’s `/videos` APIs via the shared client.
- **HTTP client + retries:** `services/videoApiClient.ts` wraps `createVideo`, `retrieveVideo` polling, and `downloadVideoContent` with retries, backoff, and timeout handling.
- **Config:** `lib/openai/config.ts` centralizes `OPENAI_API_KEY`, base URL overrides, model defaults (`sora-2`, `sora-2-pro`), and portrait resolutions.
- **UI orchestration:** `components/VisualizeTab.tsx` validates prerequisites (outfit, weather, reference images, lower-body garment), drives the Sora status messages (`Dreaming Fit`), and switches to playback when a URL is available.
- **Playback controller:** `components/VideoPlayerModal.tsx` handles play/pause, looped playback, download, and prompt display for any video URL (data URL or remote).
- **Legacy helper (optional):** `components/OpenAIAnimationPanel.tsx` demonstrates payload shaping and prompt construction but currently returns a placeholder video URL; the architecture below focuses on the primary VisualizeTab flow.

## 2) Request Lifecycle (OpenAI Sora)

1. **Prerequisite checks (client):** `VisualizeTab.handleGenerateSoraAnimation` aborts if outfit, weather, or reference images are missing. It enforces the lower-body garment rule and collects up to two reference photos (generated thumbnails first, saved references second, user photo as fallback).
2. **Identity + motion setup (client):** Movement defaults to runway walk, and the identity anchor is derived from stored profile info and/or `userPhoto`. Dialogue source tracks whether the user provided a voice prompt.
3. **Status + telemetry (client):** UI flags `isSoraGenerating` and `motionRequestState` move through `submitting → polling → success/error` while emitting “Dreaming Fit” status messages and debug logs.
4. **Prompt assembly (server):** `generateOpenAIVideoAction` builds an enhanced prompt that encodes identity, outfit guardrails, weather cues, persona keywords, storyboard shots, and cinematography constraints. It requires at least one reference photo, a valid `outfitJson` (top, bottom, outerwear, footwear), and a lower-body garment.
5. **API invocation (server):** The action calls `createVideo` with `model` (default `sora-2`) and the assembled prompt, then polls `retrieveVideo` until completion and downloads content via `downloadVideoContent`. Failures throw typed errors (`VideoApiError`, `VideoTimeoutError`, `VideoContentError`).
6. **Result handoff (server → client):** The action returns a `MotionGenerationResult` containing a base64 data URL, prompt, model, generation time, and resolution metadata.
7. **Playback (client):** On success, `VisualizeTab` sets `generatedVideoUrl` and opens `VideoPlayerModal`, which autoplays the video, exposes play/pause controls, and offers an mp4 download while showing the prompt context.

## 3) Integration Checklist

Use this list to confirm the Sora integration is correct:

- **Env/config:** `OPENAI_API_KEY` is present; optional `OPENAI_API_BASE_URL`/`OPENAI_BASE_URL` point to the desired Sora endpoint. Model defaults (`sora-2`/`sora-2-pro`) and portrait resolutions from `lib/openai/config.ts` are honored.
- **Input validation:** `VisualizeTab` blocks generation without outfit, weather, reference images, or a lower-body garment; `openai-video-actions` re-validates `outfitJson` and reference photos.
- **Prompt fidelity:** The prompt includes identity anchors, mandatory four-piece outfit, weather/story/persona cues, storyboard shots, and cinematography guardrails. Maintain the locked schema (Identity + Style Bible) plus the per-request Scene Spec template above.
- **API flow:** `services/videoApiClient.ts` calls `/videos`, polls status with backoff, handles retryable errors, enforces timeouts, and downloads binary content.
- **Status UX:** UI shows “Dreaming Fit: Initializing/Calibrating/Rendering/Delivered” in order and sets `motionRequestState` accordingly. Errors surface via `setError` and halt the flow.
- **Playback:** `VideoPlayerModal` accepts data URLs or remote URLs, loops by default, exposes play/pause and download actions, and logs playback errors for diagnostics.
- **Identity safety:** Reference selection prioritizes generated thumbnails and saved references, then user photo (if consented). Do not mix inconsistent identity sets; keep stable references to preserve likeness.

## 4) Extending or Auditing

- **Adding voice or dialog:** Respect `dialogueSource` (`user` vs `persona`) and ensure audio/text stays within PG, no-logo constraints from the locked Style Bible.
- **Alternate presets/resolutions:** Update `lib/openai/config.ts` and surface preset choices in the UI; ensure the prompt’s camera block matches the selected aspect ratio.
- **Observability:** Continue logging the state transitions in `VisualizeTab` and leverage typed errors from `videoApiClient` to feed user-friendly status updates.
