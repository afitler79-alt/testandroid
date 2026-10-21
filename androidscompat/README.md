# CC:Androids Compatibility

Addon Forge 1.20.1 for the modpack in this workspace.

## What it fixes

CC:Androids exposes `attack()` as a melee task. NTGL, however, already has a
server-side `GunAttackGoal` for `PathfinderMob` entities holding an `IWeapon`.
This addon supplies the missing vanilla target to CC:Androids. NTGL then
handles aiming, shooting, ammo and reloading without Lua trying to emulate a
mouse click.

Create: Gunsmithing weapons are NTGL weapons, so they are covered automatically.
The adapter is intentionally based on NTGL's `IWeapon` interface rather than a
hard-coded list of item IDs, so other NTGL weapon mods are covered too.

## Aircraft combat

Immersive Aircraft 1.5.0 and Man of Many Planes 0.2.1 are supported through
their shared `VehicleEntity` API. Put an aircraft weapon in the aircraft's
weapon inventory and give it the required ammunition. Then:

1. Put the Android and an empty aircraft close to the player.
2. Run `/androidscompat mount`.
3. The Android becomes the first passenger, flies toward the nearest enemy
   aircraft when one is nearby, or toward hostile ground mobs otherwise.
4. Mounted aircraft weapons are fired server-side. A bomb bay drops bombs at
   ground targets; guns and other mounted weapons can engage aircraft.

Use `/androidscompat dismount` to remove the nearest mounted Android. The
aircraft AI only takes control when an Android is the first passenger, so
player-piloted aircraft are left alone.

### Aircraft roles

After mounting, select one role as the player:

- `/androidscompat mode combat` — engages nearby aircraft first, then hostile
  ground mobs, using all mounted weapons.
- `/androidscompat mode bomber` — ignores aircraft and fires only mounted Bomb
  Bays at hostile ground mobs.
- `/androidscompat mode transport` — does not target or fire; it keeps the
  aircraft moving for cargo transport.

The matching Lua launchers are `piloto_combate.lua`,
`bombardero.lua` and `transportador_cargas.lua`. They provide the role
status/refuelling loop; the Java addon remains responsible for flight and
weapons.

## Build

Run `gradlew.bat build` from this directory. The output JAR is written to
`build/libs/androidscompat-1.0.0.jar`.
