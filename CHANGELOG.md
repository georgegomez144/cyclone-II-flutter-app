# Changelog

## 1.27.2
- Widen the ship's yummy pickup collection radius.

## 1.27.1
- Spawn yummy pickups 10% more frequently, increasing frequency by another 2% every 10 levels.

## 1.27.0
- Freeze active spark mines harmlessly and detonate them one at a time, nearest to the destroyed castle first.

## 1.26.0
- Animate intact castle shield segments flying apart one at a time while the ship flickers and slowly explodes.

## 1.25.2
- Remove greenish yellow tones from the castle explosion and soften its rings with lighter, blurred warm glows.

## 1.25.1
- Intensify the castle explosion with more, faster and brighter sparks, a central flash, glowing thicker rings and a fifth outer shockwave.

## 1.25.0
- Dim the living mines' dandelion sparks and add bright sparks when mines explode.

## 1.24.0
- Add sparks and staggered exploding rings when the castle is destroyed.

## 1.23.1
- Tighten mine sparks into a short, radial dandelion puff.

## 1.23.0
- Add mini spark bursts when player bullets destroy castle shield segments.

## 1.22.0
- Show pickup shield strength as a blue HUD meter and restore the ship shield meter when depleted.

## 1.21.1
- Center the mine sparks on the mine graphic.

## 1.21.0
- Make all mines spin faster and continuously emit bright mini sparks.

## 1.20.4
- Hide the HUD during Mine Challenge, keep its title and mine counter visible, and use the standard amber title color.

## 1.20.3
- Show the ship's stationary sprite on initial load and when starting a new game; show boosters only while movement input is active.

## 1.20.2
- Show only the starfield behind the main menu by clearing all banners, effects, pickups and intro visuals and rendering a clean frame before pausing.

## 1.20.1
- Remove Mine Challenge firing limits and make touch firing immediate; increase ship rotation speed by 10% during the challenge.
- Defer Flame lifecycle processing until after component-tree updates to prevent concurrent modification errors.

## 1.20.0
- Add a main-menu button to play a standalone Mine Challenge.

## 1.19.3
- Dim the background starfield by 30%.
- Ensure the player ship respawns correctly when starting a new game after quitting.

## 1.19.2
- Make the Mine Challenge yummy available after level 9, prevent yummy spawns during the challenge, and document the challenge on the instructions screen.

## 1.19.1
- Prevent the player ship from entering the castle's outer shield ring, including through destroyed segments.

## 1.19.0
- Add the purple Mine Challenge yummy and a 20-mine bonus round after victory.

## 1.18.5
- Restrict castle blasts to its forward-facing nose.

## 1.18.4
- Prevent the player ship from firing while the castle and rings respawn after victory.

## 1.18.3
- Ensure castle blasts pass through shield rings without being intercepted.
- Prevent player bullets from passing through shield rings and ensure hits destroy the castle.

## 1.18.2
- Keep the macOS HUD on a single row, scaling it down to fit narrow windows.

## 1.18.1
- Prevent the ship from getting trapped between shield rings and account for ring motion when bouncing.
- Ignore shield collision sweeps across screen wraps.

## 1.17.0
- Make intact castle shield segments block and bounce the player's ship, with a bright impact flash.

## 1.17.1
- Keep spark mines riding on the polygon edges of enemy shield rings.

## 1.17.2
- Make castle blasts fire only through openings that can clear all three shield rings.

## 1.18.0
- Animate the remaining time bonus counting down as it is added to the score after a victory.