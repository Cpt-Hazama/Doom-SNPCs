AddCSLuaFile("shared.lua")

include('shared.lua')

ENT.NPCFaction = NPC_FACTION_DEMON
ENT.iClass = CLASS_DEMON
util.AddNPCClassAlly(CLASS_DEMON,"npc_guardian")
ENT.sModel = "models/doom/guardian.mdl"
ENT.m_fMaxYawMoveSpeed = 40
ENT.fMeleeDistance	= 75
ENT.fMeleeForwardDistance = 500
ENT.fRangeDistance = 1600
ENT.bFlinchOnDamage = true
ENT.m_bKnockDownable = false
ENT.UseCustomMovement = false
ENT.bIgnitable = false
ENT.bFreezable = false
ENT.possOffset = Vector(0,0,220)
ENT.tblIgnoreDamageTypes = {DMG_DISSOLVE}
ENT.bPlayDeathSequence = true
ENT.m_bForceDeathAnim = true
ENT.HullNav = HULL_LARGE
ENT.skName = "guardian"
ENT.CollisionBounds = Vector(120,120,200)
//ENT.SurvivalCollisionBounds = Vector(120,120,180)

ENT.DamageScales = {
	[DMG_BURN] = 0.3,
	[DMG_PARALYZE] = 0,
	[DMG_NERVEGAS] = 0,
	[DMG_POISON] = 0,
	[DMG_DIRECT] = 0.3,
	[DMG_ACID] = 0.5
}
ENT.sSoundDir = "npc/guardian/"

ENT.m_tbSounds = {
	["IdleAlert"] = "chatter_combat[1-3].mp3",
	["DeathImpact"] = "guardian_death_impact.mp3",
	["Idle"] = "chatter[1-3].mp3",
	["Sight"] = {"sight[1-3]_1.mp3","sight[1-3]_1.mp3"},
	["Fire"] = "guardian_fire_flare_up.mp3",
	["Foot"] = "foot/step[1-4].mp3",
	["Death"] = "guardian_death.mp3",
	["Pain"] = "pain[1-3].mp3"
}

ENT.tblFlinchActivities = {
	[HITBOX_GENERIC] = ACT_FLINCH_HEAD
}

function ENT:OnInit()
	self:SetNPCFaction(NPC_FACTION_DEMON,CLASS_DEMON)
	self:SetHullType(HULL_LARGE)
	self:SetHullSizeNormal()
	self:SetCollisionBounds(self.CollisionBounds,Vector(self.CollisionBounds.x *-1,self.CollisionBounds.y *-1,0))
	
	self:slvCapabilitiesAdd(bit.bor(CAP_MOVE_GROUND,CAP_OPEN_DOORS))
	self:slvSetHealth(GetConVarNumber("sk_" .. self.skName .. "_health"))
	self.m_nextRangeAttack = 0
	self.m_nextForwardAttack = 0
	self.m_tbSummons = {}
	self:SetSoundLevel(95)
	local att = self:LookupAttachment("tail")
	if(att != 0) then
		ParticleEffectAttach("smoke_gib_01",PATTACH_POINT_FOLLOW,self,att)
		ParticleEffectAttach("burning_engine_fire",PATTACH_POINT_FOLLOW,self,att)
		local light = ents.Create("light_dynamic")
		light:SetKeyValue("_light","255 50 0 200")
		light:SetKeyValue("brightness","0")
		light:SetKeyValue("distance","200")
		light:SetKeyValue("style","1")
		light:SetPos(self:GetPos())
		light:SetParent(self)
		light:Spawn()
		light:Activate()
		light:Fire("SetParentAttachment","tail")
		light:Fire("TurnOn","",0)
		self:DeleteOnRemove(light)
	end
	self:CreateShield()
end

function ENT:_PossPrimaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_RANGE_ATTACK1,false,fcDone)
end

function ENT:_PossSecondaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_MELEE_ATTACK1,false,fcDone)
end

function ENT:_PossJump(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_RANGE_ATTACK1_LOW,false,fcDone)
end

function ENT:ShouldCollide(ent)
	if(ent:IsNPC()) then return false end
end

function ENT:LookAtTarget(pos)
	local bone = self:LookupBone("neck_4")
	if(!bone) then return end
	local ppYaw = self:GetPoseParameter("head_yaw")
	local ppPitch = self:GetPoseParameter("head_pitch")
	local posBone = self:GetBonePosition(bone)
	local dir = (pos -posBone):GetNormal()
	local ang = dir:Angle()
	local angCur = self:GetAngles()
	angCur.y = angCur.y +ppYaw
	angCur.p = angCur.p +ppPitch
	local angDiff = ang -angCur
	if(math.abs(math.AngleDifference(ppYaw,angDiff.y)) > 6) then
		ppYaw = math.ApproachAngle(ppYaw,angDiff.y,3)
		self:SetPoseParameter("head_yaw",ppYaw)
	end
	if(math.abs(math.AngleDifference(ppPitch,angDiff.p)) > 6) then
		ppPitch = math.ApproachAngle(ppPitch,angDiff.p,3)
		self:SetPoseParameter("head_pitch",ppPitch)
	end
end

local cvMusic = GetConVar("sk_guardian_chance_music")
function ENT:InitSandbox()
	if(!self:GetSquad()) then self:SetSquad(self:GetClass() .. "_sbsquad") end
	local f = cvMusic:GetFloat()
	if(f == 0) then return end
	if(math.Rand(0,1) <= f && !SLVBase_Fixed.IsSoundtrackNPCActive(self)) then self:slvPlaySoundtrack() end
end

function ENT:OnThink()
	self:UpdateLastEnemyPositions()
	if(IsValid(self.entEnemy) && self:CanSee(self.entEnemy)) then
		self:LookAtTarget(self.entEnemy:GetHeadPos())
	end
	self:NextThink(CurTime())
	return true
end

function ENT:Regenerate()
	self:SLVPlayActivity(ACT_IDLE_ANGRY)
	timer.Simple(0.5,function()
		if(self:IsValid() && self:Alive()) then
			self:RegenerateShield()
		end
	end)
end

function ENT:RegenerateShield()
	self.m_shieldPower = 250
	self:SetNWBool("SLVBase_Doom_Shield",true)
	self.m_nextShieldRestore = nil
	self.m_shieldRestoreDamage = nil
	self.cspShieldLoop:Play()
	if(!IsValid(self.m_entShieldParticle)) then
		local att = self:GetAttachment(self:LookupAttachment("generatora"))
		local entA = self.m_tbTransformers[1]
		local entB = self.m_tbTransformers[2]
		if(!entA:IsValid() || !entB:IsValid() || !att) then return end
		self.m_entShieldParticle = util.ParticleEffectTracer("guardian_electrical_fx",att.Pos,{{ent=entB,att="arc"}},Angle(0,0,0),entA,"arc",false)
		self:DeleteOnRemove(self.m_entShieldParticle)
	end
	umsg.Start("guardian_shield")
		umsg.Entity(self)
	umsg.End()
end

function ENT:CreateShield()
	if(self.m_bHasShield) then return end
	self.m_bHasShield = true
	self:SetNWBool("SLVBase_Doom_Shield",true)
	self.m_tbTransformers = {}
	for i = 1,2 do
		local strAtt = "generator" .. (i == 1 && "a" || "b")
		local attID = self:LookupAttachment(strAtt)
		local att = self:GetAttachment(attID)
		local ent = ents.Create("prop_dynamic_override")
		ent:SetModel("models/doom/transformer.mdl")
		ent:SetPos(att.Pos)
		ent:SetParent(self)
		ent:Spawn()
		ent:Activate()
		ent:Fire("SetParentAttachment",strAtt,0)
		table.insert(self.m_tbTransformers,ent)
		self:DeleteOnRemove(ent)
	end
	self.cspShieldLoop = CreateSound(self,"ambient/machines/electric_machine.wav")
	self:StopSoundOnDeath(self.cspShieldLoop)
	self:RegenerateShield()
end

function ENT:GetShieldPower() return self:HasShield() && self.m_shieldPower || 0 end

function ENT:HasShield() return self.m_bHasShield || false end

function ENT:DestroyShield()
	if(!self:HasShield()) then return end
	self.m_shieldPower = 0
	self:SetNWBool("SLVBase_Doom_Shield",false)
	self.cspShieldLoop:Stop()
	self:EmitSound("ambient/levels/labs/electric_explosion" .. math.random(1,5) .. ".wav",100,100)
	self:DontDeleteOnRemove(self.m_entShieldParticle)
	if(IsValid(self.m_entShieldParticle)) then self.m_entShieldParticle:Remove() end
	self.m_entShieldParticle = nil
	self.m_nextShieldRestore = CurTime() +math.Rand(8,16)
	self.m_shieldRestoreDamage = math.random(250,750)
	for i = 1, 2 do
		local ent = self.m_tbTransformers[i]
		if(IsValid(ent)) then
			local att = ent:GetAttachment(ent:LookupAttachment("arc"))
			if(att) then
				ParticleEffect("hunter_projectile_explosion_1",att.Pos,Angle(0,0,0),ent)
			end
		end
	end
	self:Flinch(HITBOX_GENERIC)
	self:slvPlaySound("Pain")
end

function ENT:DamageHandle(dmginfo)
	local dmg = dmginfo:GetDamage()
	if(self:GetShieldPower() == 0) then
		if(self.m_shieldRestoreDamage && self.m_shieldRestoreDamage > 0) then
			self.m_shieldRestoreDamage = self.m_shieldRestoreDamage -dmg
			if(self.m_shieldRestoreDamage <= 0) then
				self:Regenerate()
			end
		end
		return
	end
	local pos = dmginfo:GetDamagePosition()
	local posTransformer
	local dist = math.huge
	for i = 1, 2 do
		local ent = self.m_tbTransformers[i]
		if(IsValid(ent)) then
			local posPoint = ent:NearestPoint(pos)
			local distEnt = posPoint:Distance(pos)
			if(distEnt < dist) then
				posTransformer = posPoint
				dist = distEnt
			end
		end
	end
	if(dist <= 70) then
		local effectdata = EffectData()
		effectdata:SetStart(posTransformer)
		effectdata:SetOrigin(posTransformer)
		effectdata:SetScale(1)
		util.Effect("ManhackSparks",effectdata)
		self.m_shieldPower = math.max(self.m_shieldPower -dmg,0)
		if(self.m_shieldPower == 0) then
			self:DestroyShield()
			return
		end
	end
	dmginfo:SetDamage(0)
	local pos = dmginfo:GetDamagePosition()
	if(pos != vector_origin) then
		local ang = Angle(0,0,0)
		ParticleEffect("hunter_shield_impact",pos,ang,self)
		ParticleEffect("hunter_shield_impact2",pos,ang,self)
		ParticleEffect("hunter_shield_impactglow",pos,ang,self)
		umsg.Start("guardian_shield")
			umsg.Entity(self)
		umsg.End()
	end
	local r = math.random(1,11)
	r = string.rep("0",2 -string.len(r)) .. r
	self:EmitSound("ambient/energy/NewSpark" .. r .. ".wav",75,100)
end

function ENT:BloodSplash(vecPos)
	if(self:GetShieldPower() > 0) then return end
	if vecPos == Vector(0,0,0) || !self.iBloodType then return false end
	local particle = self:GetBloodParticle()
	if !particle then return false end
	util.ParticleEffect(particle, vecPos, self:GetAngles(), self)
	return true
end

local matDirt = {
	MAT_FOLIAGE,
	MAT_SAND,
	MAT_WOOD,
	MAT_DIRT
}
function ENT:Impact(pos)
	local tr = util.TraceLine({
		start = pos +Vector(0,0,20),
		endpos = pos -Vector(0,0,80),
		filter = self,
		mask = MASK_NPCWORLDSTATIC
	})
	if(!tr.Hit) then return end
	pos = tr.HitPos +Vector(0,0,20)
	if(table.HasValue(matDirt,tr.MatType)) then
		local effectdata = EffectData()
		effectdata:SetOrigin(pos)
		effectdata:SetScale(80)
		util.Effect("ThumperDust",effectdata)
	end
	sound.Play(self.sSoundDir .. "impact.mp3",pos,110,100)
	util.ScreenShake(pos,500,500,0.5,2500)
end

function ENT:CreatePlasmaProjectile(pos,dir)
	local ent = ents.Create("obj_archvile_plasma")
	ent:SetPos(pos)
	ent:SetEntityOwner(self)
	ent:SetDamage(3)
	ent:Spawn()
	ent:Activate()
	self:NoCollide(ent)
	ent:InitPhysics()
	ent:SetTarget(self.entEnemy)
	local speed = 500
	ent:SetSpeed(speed)
	local phys = ent:GetPhysicsObject()
	if(phys:IsValid()) then
		phys:ApplyForceCenter(dir *speed)
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
		if(atk == "left" || atk == "right") then
			if(!IsValid(self.entEnemy)) then return true end
			local att = self:GetAttachment(self:LookupAttachment(atk == "left" && "lhand" || "rhand"))
			if(att) then
				self:Impact(att.Pos)
				local ang = self:GetAngles()
				ang.y = ang.y -60
				for y = ang.y,ang.y +120,30 do
					ang.y = y
					self:CreatePlasmaProjectile(att.Pos +Vector(0,0,15),ang:Forward())
				end
			end
			return true
		elseif(atk == "headbutt") then
			dist = self.fMeleeForwardDistance
			ang = Angle(-60,0,0)
			force = vector_origin
		end
		local posSelf = self:GetPos()
		self:DealMeleeDamage(dist,GetConVarNumber(skDmg),ang,force,DMG_SLASH,nil,false,nil,function(ent,dmginfo)
			local vel = (ent:GetPos() -posSelf):GetNormal() *1000 +Vector(0,0,500)
			if(false) then //ent:IsPlayer() && ent.KnockDown) then
				ent:KnockDown(8)
				local ragdoll = ent:GetRagdollEntity()
				if(IsValid(ragdoll)) then ragdoll:slvAddVelocity(vel)
				else ent:SetVelocity(vel) end
			else ent:SetVelocity(vel) end
		end)
		return true
	end
	if(event == "rattack") then
		local attA = self:GetAttachment(self:LookupAttachment("lhand"))
		local attB = self:GetAttachment(self:LookupAttachment("rhand"))
		if(!attA || !attB) then return true end
		local pos = attA.Pos +(attB.Pos -attA.Pos) *0.5
		self:Impact(pos)
		for i = #self.m_tbSummons,1,-1 do
			local ent = self.m_tbSummons[i]
			if(!ent:IsValid()) then
				table.remove(self.m_tbSummons,i)
			end
		end
		if(math.random(1,3) == 1 && #self.m_tbSummons < 3) then
			local pos = self:GetPos() +self:GetForward() *200 +Vector(0,0,50)
			local ang = self:GetAngles()
			local classes = {"npc_hellknight","npc_revenant"}
			local bHasArchvile
			for _,ent in ipairs(self.m_tbSummons) do
				if(ent:GetClass() == "npc_archvile") then bHasArchvile = true; break end
			end
			if(!bHasArchvile) then table.insert(classes,"npc_archvile") end // Only allow him to have one archvile at a time, otherwise it gets to a clusterfuck
			local class = table.Random(classes)
			self:SummonCreature(class,pos,ang)
			return true
		end
		local ang = self:GetAngles()
		if(math.random(1,2) == 1 && (!IsValid(self.entEnemy) || self:OBBDistance(self.entEnemy) <= 1500)) then
			local ent = ents.Create("obj_guardian_firetrail")
			ent:SetPos(pos)
			ent:SetAngles(ang)
			ent:SetEntityOwner(self)
			ent:Spawn()
			ent:Activate()
			return true
		end
		for y = ang.y,ang.y +315,45 do
			ang.y = y
			self:CreatePlasmaProjectile(pos +Vector(0,0,15),ang:Forward())
		end
		return true
	end
	if(event == "foot") then
		local att = select(2,...)
		att = self:GetAttachment(self:LookupAttachment(att))
		if(att) then self:Impact(att.Pos) end
		return true
	end
end

function ENT:OnDeath(dmginfo)
	for _, ent in ipairs(self.m_tbSummons) do
		if(ent:IsValid()) then
			ent:slvDissolve(self,self,3)
		end
	end
end

function ENT:InitAftermath()
	self:SetDTBool(3,true)
	self.m_bAftermath = true
end

function ENT:SetupRelationship(ent)
	if(ent:IsNPC()) then
		self:slvAddEntityRelationship(ent,D_LI,100)
		return true
	end
end

function ENT:SummonCreature(class,pos,ang)
	local ent = ents.Create(class)
	ent:SetAngles(ang)
	ent:SetPos(pos)
	ent:slvFadeIn(1)
	ent:NoCollide(self)
	if(self:GetDTBool(3)) then
		ent:SetDTBool(3,true)
	end
	ent:Spawn()
	ent:Activate()
	ent:MoveToClearSpot(pos)
	local squad = self:GetSquad()
	if(squad) then ent:SetSquad(squad) end
	table.insert(self.m_tbSummons,ent)
	sound.Play("fx/teleport_out.wav",pos,110,100)
	ParticleEffect("teleport_fx",ent:GetPos(),ang,ent)
	return ent
end

function ENT:AttackMelee(ent)
	self:SetTarget(ent)
	self:SLVPlayActivity(ACT_MELEE_ATTACK1,2)
end

function ENT:OnInterrupt()
	if(IsValid(self.m_entParticle)) then
		self.m_entParticle:Remove()
		self.m_entParticle = nil
	end
end

function ENT:SelectScheduleHandle(enemy,dist,distPred,disp)
	if(self.m_nextShieldRestore && CurTime() >= self.m_nextShieldRestore) then
		self:Regenerate()
		return
	end
	if(disp == D_HT) then
		if(self:CanSee(enemy)) then
			if(dist <= self.fMeleeDistance || distPred <= self.fMeleeDistance) then
				self:SLVPlayActivity(ACT_MELEE_ATTACK1,true)
				return
			end
			if(CurTime() >= self.m_nextForwardAttack) then
				local ang = self:GetAngleToPos(enemy:GetPos())
				if(ang.y <= 20 || ang.y >= 340) then
					local fTimeToGoal = self:GetMoveTimeToTarget(enemy)
					//MsgPrint(fTimeToGoal)
					if(self.bDirectChase && fTimeToGoal <= 1 && fTimeToGoal >= 0.1 && distPred <= self.fMeleeForwardDistance) then
						self:SLVPlayActivity(ACT_RANGE_ATTACK1_LOW)
						self.m_nextForwardAttack = CurTime() +math.Rand(1,4)
						return
					end
				end
			end
			if(dist <= self.fRangeDistance && CurTime() >= self.m_nextRangeAttack) then
				if(math.random(1,3) == 1) then
					if(math.random(1,3) == 1) then
						self.m_nextRangeAttack = CurTime() +math.Rand(3,6)
					end
					if(math.random(1,2) == 1) then
						self:SLVPlayActivity(ACT_RANGE_ATTACK1,true)
						return
					end
					self:SLVPlayActivity(ACT_MELEE_ATTACK2,true)
					return
				end
			end
		end
		self:ChaseEnemy()
	elseif(disp == D_FR) then
		self:Hide()
	end
end
