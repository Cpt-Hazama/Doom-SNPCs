local ConVars = {}
// HELLKNIGHT
ConVars["sk_hellknight_health"] = 580
ConVars["sk_hellknight_dmg_bite"] = 28
ConVars["sk_hellknight_dmg_slash"] = 32

// ARCHVILE
ConVars["sk_archvile_health"] = 280
ConVars["sk_archvile_dmg_slash"] = 13

// GUARDIAN
ConVars["sk_guardian_health"] = 2300
ConVars["sk_guardian_dmg_slash"] = 12
ConVars["sk_guardian_chance_music"] = 1

// REVENANT
ConVars["sk_revenant_health"] = 420
ConVars["sk_revenant_dmg_slash"] = 12

for cvar,val in pairs(ConVars) do
	CreateConVar(cvar,val,FCVAR_ARCHIVE)
end