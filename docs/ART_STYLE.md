# Nebula Knockout — Art Style Spec

This is the authoritative visual style for all character and NPC art. Every
generated asset must match it so the 30-hero roster reads as one cohesive
game. Prompt template and the exact working ComfyUI workflow are at the
bottom — use them verbatim, only swapping the per-character block.

## Target style

**Chibi HD-2D brawler.** The reference point is the classic *Little Fighter
2* / Hong Kong beat-'em-up lineage, but rendered with more detail and color
richness than LF2's tiny sprites — think a modern mobile "HD chibi" arena
brawler. NOT anime, NOT manga, NOT semi-realistic, NOT painterly, NOT
photoreal.

### Proportions
- Chibi: **large head, short body, roughly 2.5–3 heads tall.**
- Short, chunky limbs; large hands/feet relative to the body.
- Silhouette must stay readable when the sprite is small on screen (MOBA
  zoom). If it only reads at full size, it's too detailed.

### Rendering
- Clean **cartoon cel shading**: flat base colors plus 1–2 soft shadow tones
  and subtle highlights. Soft enough to feel rounded, not a flat vector icon.
- **Bold, clean outlines** — present but not thick black blobs.
- **Vibrant, saturated palette.** Each hero gets a distinct dominant color
  identity (Kael = blue, Bastion = steel/red, Monk = warm earth/orange,
  Machinist = copper/teal) so teams read at a glance.
- Expressive **faces with clearly drawn eyes and eyebrows** — the face must
  never be blank. This was a failure mode of over-simplifying.
- Detailed-but-clean gear: armor plates, belts, gloves, boots, weapon.
  Recognizable, not photoreal detail.

### Framing (for asset generation)
- **Full body, head to toe, centered, standing in a readable pose.**
- **Plain solid light-grey background** (`#c8c8c8`-ish) so the sprite can be
  cleanly cut out later (background removal → transparent PNG) with a
  consistent matte for all 30 heroes.
- One character per image. No scene, no props, no ground shadow, no text.

## What to avoid (explicit)

`anime, manga, realistic, photorealistic, semi-realistic, painterly,
gradients, 3D render, CGI, chibi blob with no face, featureless icon,
oversized simple shapes with no clothing detail, text, watermark`

Note: Z-Image **Turbo** bakes CFG in and ignores negative prompts, so the
avoid-list lives in the positive prompt as "not X" clauses. If you switch to
Z-Image **Base** (CFG 4–7), move them into a real negative prompt.

## Working ComfyUI pipeline

Z-Image Turbo, **separate-component** path (no combined checkpoint needed):

| Component | Node | File |
|---|---|---|
| UNET | `UNETLoader` (`weight_dtype: default`) | `z_image_turbo_bf16.safetensors` |
| CLIP | `CLIPLoader` (`type: qwen_image`) | `qwen_3_4b.safetensors` |
| VAE | `VAELoader` | `z-image-ae.safetensors` |
| Conditioning | `TextEncodeZImageOmni` (positive + empty negative) | — |
| Sampler | `KSampler` | `dpmpp_sde` / `beta`, **10 steps, cfg 1.0** |
| Resolution | `EmptyLatentImage` | `832x1216` (portrait 5:8, divisible by 16) |

`z-image-ae.safetensors` is the only file that had to be fetched
(`Comfy-Org/z_image_turbo` → `split_files/vae/ae.safetensors`). It is NOT
Flux's `ae.safetensors` despite the same architecture — keep them separate.

Rough timing on the reference machine (AMD RX 9060 XT, 12 GB): first run
~170 s (model load), subsequent runs ~70 s.

## Prompt template

```
Chibi cartoon fighting game character sprite of {NAME}, {ONE_LINE_CONCEPT}.
Big head, short body, about three heads tall, cute stylized proportions.
Clearly drawn expressive face with big eyes and bold eyebrows, {HAIR}.
{WARDROBE_AND_WEAPON}. Style: clean cartoon cel shading with soft shading
and subtle highlights, bold clean outlines, vibrant saturated colors, simple
but detailed clothing and armor. Full body, centered, standing in a fighting
stance, plain solid light grey background. High quality 2D beat-em-up sprite
art, chibi HD brawler style. Not anime, not manga, not realistic, not
photorealistic, no text.
```

### Per-hero block (first four)

| Hero | `{ONE_LINE_CONCEPT}` | `{HAIR}` | `{WARDROBE_AND_WEAPON}` |
|---|---|---|---|
| Kael | a swift blademaster hero | black spiky hair | rich blue longcoat, detailed silver shoulder armor plates, wide belt, gloves, tall boots, holding a curved sword |
| Bastion | a heavy tower-shield tank hero | short dark hair | bulky steel plate armor with a red tabard, huge tower shield in one hand and a short mace in the other |
| Monk | a martial-artist healer hero | shaved head | warm orange and brown monk robes with a sash, wrapped forearms, simple sandals, open bare hands in a martial stance |
| Machinist | a gadgeteer drone-engineer hero | copper-red braided hair | teal and brass mechanic's jumpsuit, tool belt, goggles on forehead, one gloved hand holding a small remote with a floating drone beside her |

## Asset pipeline (per hero)

1. Generate the full-body sprite with the template above (ComfyUI Z-Image
   Turbo workflow in `docs/ARCHITECTURE.md` / this file).
2. Cut out the background → transparent PNG (`generate_image
   action:"remove_background"` via the `comfyui` MCP tool, BiRefNet).
3. (Later) bake `AnimatedSprite2D` `SpriteFrames` flipbooks for
   walk/dash/jump/hit/block/skills/ultimate from the same base, per
   `docs/ARCHITECTURE.md` Section 3.
4. (Optional, menu only) build the `Skeleton2D` showcase rig via
   `HeroRigImporter` from a rigging-metadata JSON, per Section 1 of
   `docs/deepseek_prompt.md`.
