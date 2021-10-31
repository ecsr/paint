# Paint
Lets players add paint on maps, with different colours and sizes. This can be useful in game modes like bhop, kz and surf.

## Configuration
By default everyone can see paint decals added by a player to change this you can set the `paint_sendtoall` ConVar to `0` in the plugin config.

## Commands

* `+paint` - Adds paint where the player is looking.
* `sm_paint` - Displays a menu where players can change paint colour and size.

These commands can be used by anyone if you want to restrict access to admins only use [SourceMod command overrides](https://wiki.alliedmods.net/Overriding_Command_Access_(Sourcemod)).

`r_cleardecals` can be used to remove all paint decals on the map (client-side).

## Credits

* SlidyBat for making the [original plugin](https://forums.alliedmods.net/showthread.php?p=2541664).
* Cabbage McGravel for making the texture.
