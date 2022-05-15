AddCSLuaFile("shared.lua")

include('shared.lua')

ENT.NPCFaction = NPC_FACTION_DEMON
ENT.iClass = CLASS_DEMON
util.AddNPCClassAlly(CLASS_DEMON,"npc_revenant")
ENT.sModel = "models/doom/revenant.mdl"
ENT.fMeleeDistance	= 64
ENT.fRangeDistance = 1600
ENT.bFlinchOnDamage = true
ENT.bIgnitable = false
ENT.m_bKnockDownable = false
ENT.skName = "revenant"
ENT.CollisionBounds = Vector(26,26,78)
ENT.sSoundDir = "npc/revenant/"

ENT.m_tbSounds = {
	["IdleAlert"] = "chatter_combat[1-3].mp3",
	["Idle"] = "chatter[1-4].mp3",
	["Death"] = "die[1-3]_alt1.mp3",
	["Pain"] = "pain[1-3]_alt1.mp3",
	["Alert"] = {"sight1_[1-2]_alt1.mp3","sight2_[1-2]_alt1.mp3","sight1_1.mp3"},
	["Foot"] = "foot/step[1-4].mp3"
}

ENT.tblFlinchActivities = {
	[HITBOX_GENERIC] = ACT_FLINCH_CHEST,
	[HITBOX_HEAD] = ACT_FLINCH_HEAD,
	[HITBOX_LEFTARM] = ACT_FLINCH_LEFTARM,
	[HITBOX_RIGHTARM] = ACT_FLINCH_RIGHTARM
}

AccessorFunc(ENT,"m_bTeleport","CanTeleport",FORCE_BOOL)
AccessorFunc(ENT,"m_bRockets","CanUseRockets",FORCE_BOOL)
AccessorFunc(ENT,"m_bHoming","HomingRockets",FORCE_BOOL)
function ENT:OnInit()
	self:SetNPCFaction(NPC_FACTION_DEMON,CLASS_DEMON)
	self:SetHullType(HULL_HUMAN)
	self:SetHullSizeNormal()
	self:SetCollisionBounds(self.CollisionBounds,Vector(self.CollisionBounds.x *-1,self.CollisionBounds.y *-1,0))
	
	self:slvCapabilitiesAdd(bit.bor(CAP_MOVE_GROUND,CAP_OPEN_DOORS))
	self:slvSetHealth(GetConVarNumber("sk_" .. self.skName .. "_health"))
	self.m_nextRangeAttack = 0
	self.m_nextTeleport = 0
	if(self.m_bTeleport == nil) then self.m_bTeleport = true end
	if(self.m_bRockets == nil) then self.m_bRockets = true end
	if(self.m_bHoming == nil) then self.m_bHoming = true end
end

function ENT:_PossPrimaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_RANGE_ATTACK1,false,fcDone)
end

function ENT:_PossSecondaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_MELEE_ATTACK1,false,fcDone)
end

function ENT:_PossReload(entPossessor,fcDone)
	ParticleEffect("teleport_fx",self:GetPos(),Angle(0,0,0),self)
	local posTgt = entPossessor:GetPossessionEyeTrace().HitPos
	self:MoveToClearSpot(posTgt)
	local pos = self:GetPos()
	self:slvFadeIn(1)
	sound.Play("fx/teleport_out.wav",pos,100,100)
	ParticleEffect("teleport_fx",pos,Angle(0,0,0),self)
	self:SLVPlayActivity(ACT_SPECIAL_ATTACK1,false,fcDone)
end

function ENT:_PossJump(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_HL2MP_JUMP,false,fcDone)
end

function ENT:KeyValueHandle(key,val)
	if(key == "spawnflags") then
		local flags = tonumber(val)
		self:SetCanUseRockets(bit.band(flags,32768) == 0)
		self:SetCanTeleport(bit.band(flags,65536) == 0)
		self:SetHomingRockets(bit.band(flags,131072) == 0)
	end
end

function ENT:SetupRelationship(ent)
	if(ent:IsNPC()) then
		self:slvAddEntityRelationship(ent,D_LI,100)
		return true
	end
end

function ENT:EventHandle(...)
	local event = select(1,...)
	if(event == "mattack") then
		local dist = self.fMeleeDistance
		local skDmg = "sk_" .. self.skName .. "_dmg_slash"
		local force
		local ang
		local atk = select(2,...)
		if(atk == "left") then
			force = Vector(360,0,60)
			ang = Angle(38,20,-3)
		elseif(atk == "righta") then
			force = Vector(360,0,60)
			ang = Angle(38,-20,3)
		elseif(atk == "rightb") then
			force = Vector(360,0,60)
			ang = Angle(-38,20,-3)
		end
		self:DealMeleeDamage(dist,GetConVarNumber(skDmg),ang,force,DMG_SLASH)
		return true
	end
	if(event == "rattack") then
		local att = select(2,...)
		att = self:LookupAttachment(att)
		att = self:GetAttachment(att)
		if(!att) then return true end
		local pos = att.Pos
		local ent = self.entEnemy
		local posTgt
		if(IsValid(ent)) then posTgt = ent:GetCenter()
		else posTgt = att.Pos +self:GetForward() *100 end
		local dir = (posTgt -pos):GetNormal()
		local ang = dir:Angle()
		local entMissile = ents.Create("obj_revenant_missile")
		entMissile:SetAngles(ang)
		entMissile:SetPos(pos)
		entMissile:SetEntityOwner(self)
		entMissile:Spawn()
		entMissile:Activate()
		entMissile:SetHeatSeeking(self:GetHomingRockets())
		local phys = entMissile:GetPhysicsObject()
		if(phys:IsValid()) then
			phys:SetVelocity(ang:Forward() *400)
		end
		return true
	end
end

function ENT:AttackMelee(ent)
	self:SetTarget(ent)
	self:SLVPlayActivity(ACT_MELEE_ATTACK1,2)
end

function ENT:OnDamaged(dmgTaken,attacker,inflictor,dmginfo)
	self.m_tmEvade = CurTime()
end

function ENT:OnInterrupt()
	if(IsValid(self.m_entParticle)) then
		self.m_entParticle:Remove()
		self.m_entParticle = nil
	end
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
	self:SLVPlayActivity(ACT_SPECIAL_ATTACK1)
	self.m_nextTeleport = CurTime() +math.Rand(3,6)
end

function ENT:SelectScheduleHandle(enemy,dist,distPred,disp)
	if(disp == D_HT) then
		if(self:CanSee(self.entEnemy)) then
			if(self.m_tmEvade && (CurTime() -self.m_tmEvade) <= 2) then
				self.m_tmEvade = nil
				if(math.random(1,3) == 1) then
					self:SLVPlayActivity(ACT_HL2MP_JUMP)
					return
				end
			end
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
			if(self:GetCanUseRockets() && (dist <= self.fRangeDistance && CurTime() >= self.m_nextRangeAttack)) then
				if(math.random(1,4) <= 3) then
					self.m_nextRangeAttack = CurTime() +math.Rand(3,6)
				end
				if(math.random(1,2) == 1) then
					self:SLVPlayActivity(ACT_RANGE_ATTACK1,true)
					return
				end
			end
		end
		self:ChaseEnemy()
	elseif(disp == D_FR) then
		self:Hide()
	end
end
