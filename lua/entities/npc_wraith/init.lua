AddCSLuaFile("shared.lua")

include('shared.lua')

ENT.NPCFaction = NPC_FACTION_DEMON
ENT.iClass = CLASS_DEMON
util.AddNPCClassAlly(CLASS_DEMON,"npc_wraith")
ENT.sModel = "models/doom/wraith.mdl"
ENT.bRemoveOnDeath = true
ENT.fMeleeDistance	= 64
ENT.fRangeDistance = 1600
ENT.bFlinchOnDamage = true
ENT.m_bKnockDownable = false
ENT.skName = "wraith"
ENT.CollisionBounds = Vector(26,26,54)
ENT.tblAlertAct = {ACT_IDLE_ANGRY}
ENT.AlertChance = 25

ENT.DamageScales = {
	[DMG_BURN] = 0.3,
	[DMG_PARALYZE] = 0,
	[DMG_NERVEGAS] = 0,
	[DMG_POISON] = 0,
	[DMG_DIRECT] = 0.3,
	[DMG_ACID] = 0.5
}
ENT.sSoundDir = "npc/wraith/"

ENT.m_tbSounds = {
	["Idle"] = "Wraith_Idle",
	["Alert"] = {"Wraith_Sight[1-2].wav"},
	["Attack"] = "Wraith_Attack[1-3].wav",
	["Foot"] = "Wraith_footstep[1-5].wav",
	["Death"] = "Wraith_death_0[1-4].wav",
	["Pain"] = "Wraith_Pain_0[1-5].wav"
}

ENT.tblFlinchActivities = {
	[HITBOX_GENERIC] = ACT_GESTURE_FLINCH_HEAD,
	[HITBOX_HEAD] = ACT_GESTURE_FLINCH_HEAD,
	[HITBOX_STOMACH] = ACT_GESTURE_FLINCH_HEAD,
	[HITBOX_CHEST] = ACT_GESTURE_FLINCH_HEAD,
	[HITBOX_LEFTARM] = ACT_GESTURE_FLINCH_LEFTARM,
	[HITBOX_RIGHTARM] = ACT_GESTURE_FLINCH_RIGHTARM
}

AccessorFunc(ENT,"m_bTeleport","CanTeleport",FORCE_BOOL)
function ENT:OnInit()
	self:SetNPCFaction(NPC_FACTION_DEMON,CLASS_DEMON)
	self:SetHullType(HULL_HUMAN)
	self:SetHullSizeNormal()
	self:SetCollisionBounds(self.CollisionBounds,Vector(self.CollisionBounds.x *-1,self.CollisionBounds.y *-1,0))
	
	self:slvCapabilitiesAdd(bit.bor(CAP_MOVE_GROUND,CAP_OPEN_DOORS))
	self:slvSetHealth(250)
	self.m_nextTeleport = 0
	if(self.m_bTeleport == nil) then self.m_bTeleport = true end
end

function ENT:_PossReload(entPossessor,fcDone)
	ParticleEffect("teleport_fx",self:GetPos(),Angle(0,0,0),self)
	local posTgt = entPossessor:GetPossessionEyeTrace().HitPos
	self:MoveToClearSpot(posTgt)
	local pos = self:GetPos()
	self:slvFadeIn(1)
	sound.Play("fx/teleport_out.wav",pos,100,100)
	ParticleEffect("teleport_fx",pos,Angle(0,0,0),self)
	self:SLVPlayActivity(ACT_IDLE_ANGRY,false,fcDone)
end

function ENT:KeyValueHandle(key,val)
	if(key == "spawnflags") then
		local flags = tonumber(val)
		self:SetCanTeleport(bit.band(flags,65536) == 0)
	end
end

function ENT:SetupRelationship(ent)
	if(ent:IsNPC()) then
		self:slvAddEntityRelationship(ent,D_LI,100)
		return true
	end
end

function ENT:OnThink() end

function ENT:EventHandle(...)
	local event = select(1,...)
	if(event == "mattack") then
		local dist = self.fMeleeDistance
		local skDmg = 23
		local force
		local ang
		local atk = select(2,...)
		if(atk == "rhand") then
			force = Vector(360,0,60)
			ang = Angle(38,-20,3)
		elseif(atk == "top") then
			force = Vector(360,0,60)
			ang = Angle(38,28,-3)
		elseif(atk == "lhand") then
			force = Vector(360,0,60)
			ang = Angle(-36,-28,3)
		end
		self:DealMeleeDamage(dist,skDmg,ang,force,DMG_SLASH)
		return true
	end
end

function ENT:_PossPrimaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_MELEE_ATTACK1,false,fcDone)
end

local flinchTimes = {
	[ACT_GESTURE_FLINCH_HEAD] = 0.7,
	[ACT_GESTURE_FLINCH_LEFTARM] = 0.53,
	[ACT_GESTURE_FLINCH_RIGHTARM] = 0.53
}
function ENT:Flinch(hitgroup)
	local act = self.tblFlinchActivities[hitgroup] || self.tblFlinchActivities[HITGROUP_GENERIC] || self.tblFlinchActivities[HITBOX_GENERIC]
	if(!act) then return end
	self:RestartGesture(act)
	self:StopMoving()
	self:StopMoving()
	if(!flinchTimes[act]) then return end
	self.m_tStopMoving = CurTime() +flinchTimes[act]
end

function ENT:AttackMelee(ent)
	self:SetTarget(ent)
	self:SLVPlayActivity(ACT_MELEE_ATTACK1,2)
end

function ENT:Teleport()
	ParticleEffect("teleport_fx",self:GetPos(),Angle(0,0,0),self)
	local ent = self.entEnemy
	local dir = Angle(0,math.random(0,360),0):Forward()
	local posStart = ent:GetPos() +ent:OBBCenter()
	local posTgt = posStart +dir *math.Rand(120,820)
	local tr = util.TraceLine({
		start = posStart,
		endpos = posTgt,
		filter = {self,ent},
		mask = MASK_NPCWORLDSTATIC
	})
	if(tr.Hit) then posTgt = tr.HitPos -tr.Normal *30 end
	local ang = (ent:GetPos() -posTgt):Angle()
	ang.p = 0
	ang.r = 0
	local light = ents.Create("light_dynamic")
	light:SetKeyValue("_light","255 50 0 200")
	light:SetKeyValue("brightness","0")
	light:SetKeyValue("distance","800")
	light:SetKeyValue("style","1")
	light:SetPos(self:GetPos())
	-- light:SetParent(self)
	light:Spawn()
	light:Activate()
	light:Fire("TurnOn","",0)
	timer.Simple(0.8,function() if light:IsValid() then light:Remove() end end)
	self:SetAngles(Angle(0,ang.y,0))
	self:MoveToClearSpot(posTgt)
	
	local light2 = ents.Create("light_dynamic")
	light2:SetKeyValue("_light","255 50 0 200")
	light2:SetKeyValue("brightness","0")
	light2:SetKeyValue("distance","800")
	light2:SetKeyValue("style","1")
	light2:SetPos(posTgt)
	-- light2:SetParent(self)
	light2:Spawn()
	light2:Activate()
	light2:Fire("TurnOn","",0)
	timer.Simple(0.8,function() if light2:IsValid() then light2:Remove() end end)

	local pos = self:GetPos()
	self:slvFadeIn(1)
	sound.Play("fx/teleport_out.wav",pos,100,100)
	ParticleEffect("teleport_fx",pos,Angle(0,0,0),self)
	self:SLVPlayActivity(ACT_IDLE_ANGRY)
	self.m_nextTeleport = CurTime() +math.Rand(3,6)
end

function ENT:SelectScheduleHandle(enemy,dist,distPred,disp)
	if(disp == D_HT) then
		if(self:CanSee(self.entEnemy)) then
			if(dist <= self.fMeleeDistance || distPred <= self.fMeleeDistance) then
				self:SLVPlayActivity(ACT_MELEE_ATTACK1,true)
				return
			end
			if(self:GetCanTeleport() && (CurTime() >= self.m_nextTeleport || dist > self.fRangeDistance)) then
				self.m_nextTeleport = CurTime() +math.Rand(3,6)
				if(math.random(1,5) == 1) then
					self:Teleport()
					return
				end
			end
		end
		self:ChaseEnemy()
	elseif(disp == D_FR) then
		self:Hide()
	end
end