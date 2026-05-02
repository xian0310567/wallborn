# Wallborn Visual Baseline: Unrailed-first Diorama

Date: 2026-05-02 KST
Status: Baseline v1

## Decision

Wallborn's near-term visual target is not "generic low-poly tower defense". The target is:

**Start from an Unrailed-like low-poly/isometric diorama screen, then layer Wallborn's defense mechanics on top.**

This is a production constraint for the next visual pass. If a visual choice does not move the screen closer to that baseline, it should be deferred.

Reference source checked:
- Steam page for Unrailed: https://store.steampowered.com/app/1016920/Unrailed/
- Relevant reference traits from the page/store presentation: isometric, cute, voxel/low-poly feel, procedurally generated worlds, compact readable play area.

## Current Problem

The current Wallborn build has working 3D systems but the screen still reads as mixed prototype art:

- Procedural mesh tiles and imported isometric sprites are mixed.
- Terrain scale and object scale are not yet governed by one art rule.
- Map size is large, but visual composition is not yet structured into memorable chunks.
- HUD is still debug-heavy.
- Camera is improved, but the visible play chunk still needs a tighter diorama composition.

## Visual Pillars

### 1. Compact visible chunk

The player should feel like they are looking at a small, physical toy map segment, not a flat RTS board.

Rules:
- The default camera should show a meaningful local section, not the whole map.
- Max zoom-out should remain limited.
- Important play objects must be readable at default zoom.

### 2. Blocky terrain first

Terrain should establish the style before individual props.

Rules:
- Tiles should feel like connected terrain blocks.
- Grass, dirt, stone, and boundary pieces should use one palette.
- Grid readability is allowed, but the screen must not look like a debug checkerboard.

### 3. Dense but readable props

Decoration should create remembered places, not random clutter.

Rules:
- Use trees, rocks, cliffs, fences, camp props, and landmarks to form zones.
- Props should guide attention toward paths, choke points, and core defense areas.
- Avoid evenly scattered decorations.

### 4. Defense silhouettes are gameplay-first

Wallborn's unique object is the wall-turret. It must read clearly.

Rules:
- Defense unit must look like it blocks pathing.
- Turret part must be secondary but visible.
- Color should separate it from ground/props.

### 5. Enemies are small threat tokens

Enemies should be readable moving threats, not detailed characters.

Rules:
- Strong silhouette.
- High contrast against road/grass.
- Direction readable while moving.

### 6. HUD must stop looking like debug output

Rules:
- Debug strings should be removed from the main player view.
- Keep only wave/core/enemy/control information needed for playtesting.
- Use compact panels and icons later; text-only is acceptable only as a temporary baseline.

## Baseline Numeric Targets

These are implementation targets, not final art values.

- Camera: orthographic, fixed yaw, fixed pitch, no free rotation during normal play.
- Default visible area: local chunk of the 48x28 map, not entire map.
- Max zoom-out: limited enough that enemies/walls remain readable.
- Tile height: low, toy-block-like, minimal debug gap.
- Prop scale: trees/rocks must be secondary to path/wall/enemy readability.
- Wall-turret scale: should dominate one cell but not hide adjacent path.
- Enemy scale: readable at default zoom without crowding the path.

## Immediate Implementation Order

1. 154 — Unrailed 기준 카메라/구도 재확정
2. 155 — 타일/지형 블록 스케일 재정리
3. 156 — 색상 팔레트와 조명 톤 통일
4. 157 — 오브젝트 스케일 재조정
5. 158 — 장식 밀도와 랜드마크 재배치
6. 159 — HUD 디버그 느낌 제거 및 최소 플레이 HUD 정리

## Acceptance for Baseline v1

The build does not need to look final, but it must satisfy this:

- A first-time viewer should describe the screen as a cute low-poly/isometric diorama, not a debug prototype.
- The road, enemies, wall-turrets, and core direction should be readable at default zoom.
- The map should imply zones and progression, not an empty large grid.
