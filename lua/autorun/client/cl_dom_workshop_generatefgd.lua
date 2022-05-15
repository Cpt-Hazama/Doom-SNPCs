// Since garry doesn't allow uploading txt-files to the workshop, we'll have to create them when the addon is initialized.
// Stupid as hell, but there's no other way.

file.CreateDir("wrench")
file.CreateDir("wrench/fgd")

local f = "wrench/fgd/doom.txt"
if(file.Exists(f,"DATA")) then return end
file.Write(f,[[@include "base.fgd"
@BaseClass base(BaseNPC) color(0 200 200) = BaseNPCSlv
[
	
]

@NPCClass base(BaseNPCSlv) studio("models/doom/guardian.mdl") = npc_guardian : "Guardian"
[
	health(integer) : "Health" : 2300 : 
        "Health of this NPC. " +
	"Default: 2300"
]

@NPCClass base(BaseNPCSlv) studio("models/doom/archvile.mdl") = npc_archvile : "Archvile"
[
	health(integer) : "Health" : 280 : 
        "Health of this NPC. " +
	"Default: 280"
	spawnflags(flags) =
	[
		32768 : "Don't summon allies" : 0
		65536 : "Don't teleport" : 0
	]
]

@NPCClass base(BaseNPCSlv) studio("models/doom/hellknight.mdl") = npc_hellknight : "Hellknight"
[
	health(integer) : "Health" : 580 : 
        "Health of this NPC. " +
	"Default: 580"
]

@NPCClass base(BaseNPCSlv) studio("models/doom/revenant.mdl") = npc_revenant : "Revenant"
[
	health(integer) : "Health" : 420 : 
        "Health of this NPC. " +
	"Default: 420"
	spawnflags(flags) =
	[
		32768 : "Don't use missiles" : 0
		65536 : "Don't teleport" : 0
		131072 : "Don't use homing missiles (Regular missiles only)" : 0
	]
]
]])