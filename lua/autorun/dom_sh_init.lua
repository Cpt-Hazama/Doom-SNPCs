if(!SLVBase_Fixed) then
	include("slvbase/slvbase.lua")
	if(!SLVBase_Fixed) then return end
end
local addon = "Doom"
if(SLVBase_Fixed.AddonInitialized(addon)) then return end
SLVBase_Fixed.AddDerivedAddon(addon,{tag = "Doom"})
if(SERVER) then
	AddCSLuaFile("autorun/dom_sh_init.lua")
	AddCSLuaFile("autorun/slvbase/slvbase.lua")
	AddCSLuaFile("autorun/client/cl_dom_workshop_generatefgd.lua")
	Add_NPC_Class("CLASS_DEMON")
end

game.AddParticles("particles/archvile_beam.pcf")
game.AddParticles("particles/archvile_plasma.pcf")
game.AddParticles("particles/doom_teleport.pcf")
game.AddParticles("particles/guardian_electrical_fx.pcf")
game.AddParticles("particles/hellknight.pcf")
game.AddParticles("particles/redglare_smoke_trail.pcf")
game.AddParticles("particles/redglare_trail.pcf")
game.AddParticles("particles/hunter_shield_impact.pcf")
game.AddParticles("particles/vman_explosion.pcf")
for _, particle in pairs({
		"archvile_beam",
		"teleport_fx",
		"smoke_gib_01",
		"burning_engine_fire",
		"guardian_electrical_fx",
		"hunter_projectile_explosion_1",
		"hunter_shield_impact",
		"hunter_shield_impact2",
		"hunter_shield_impactglow",
		"archvile_plasma",
		"fire_large_01",
		"hellknight_plasma"
	}) do
	PrecacheParticleSystem(particle)
end

SLVBase_Fixed.InitLua("dom_init")

local Category = "Doom"
SLVBase_Fixed.AddNPC(Category,"Hellknight","npc_hellknight")
SLVBase_Fixed.AddNPC(Category,"Archvile","npc_archvile")
-- SLVBase_Fixed.AddNPC(Category,"Cyberdemon","npc_cyberdemon")
SLVBase_Fixed.AddNPC(Category,"Guardian","npc_guardian")
-- SLVBase_Fixed.AddNPC(Category,"Imp","npc_imp")
SLVBase_Fixed.AddNPC(Category,"Revenant","npc_revenant")
SLVBase_Fixed.AddNPC(Category,"Wraith","npc_wraith")