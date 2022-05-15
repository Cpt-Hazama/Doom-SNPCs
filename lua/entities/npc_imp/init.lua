AddCSLuaFile("shared.lua")

include('shared.lua')

ENT.NPCFaction = NPC_FACTION_DEMON
ENT.iClass = CLASS_DEMON
util.AddNPCClassAlly(CLASS_DEMON,"npc_imp")
ENT.sModel = "models/doom/imp.mdl"
ENT.fMeleeDistance	= 64
ENT.fRangeDistance = 1600
ENT.bFlinchOnDamage = true
ENT.m_bKnockDownable = false
ENT.skName = "imp"
ENT.CollisionBounds = Vector(26,26,78)
//ENT.SurvivalCollisionBounds = Vector(26,26,90)

ENT.DamageScales = {
	[DMG_BURN] = 0.3,
	[DMG_PARALYZE] = 0,
	[DMG_NERVEGAS] = 0,
	[DMG_POISON] = 0,
	[DMG_DIRECT] = 0.3,
	[DMG_ACID] = 0.5
}
ENT.sSoundDir = "npc/imp/"

ENT.m_tbSounds = {
	["Breath"] = "breath[1-3].mp3",
	["Alert"] = {"cin_sight.wav","sight2_[1-3].mp3","sight1[1-3].mp3"},
	["Fire"] = "fire_0[1-5].wav",
	["Resurrection"] = "resurrection.mp3",
	["Foot"] = "foot/step[1-4].mp3",
	["Death"] = "die[1-4].mp3",
	["Pain"] = "pain[1-4].mp3"
}

ENT.tblFlinchActivities = {
	[HITBOX_GENERIC] = ACT_FLINCH_CHEST,
	[HITBOX_HEAD] = ACT_FLINCH_HEAD,
	[HITBOX_STOMACH] = ACT_FLINCH_CHEST,
	[HITBOX_CHEST] = ACT_FLINCH_CHEST,
	[HITBOX_LEFTARM] = ACT_FLINCH_LEFTARM,
	[HITBOX_RIGHTARM] = ACT_FLINCH_RIGHTARM
}

function ENT:OnInit()
	self:SetNPCFaction(NPC_FACTION_DEMON,CLASS_DEMON)
	self:SetHullType(HULL_HUMAN)
	self:SetHullSizeNormal()
	self:SetCollisionBounds(self.CollisionBounds,Vector(self.CollisionBounds.x *-1,self.CollisionBounds.y *-1,0))
	
	self:slvCapabilitiesAdd(bit.bor(CAP_MOVE_GROUND,CAP_OPEN_DOORS))
	self:slvSetHealth(GetConVarNumber("sk_" .. self.skName .. "_health"))
	self.m_nextRangeAttack = 0
	self.m_nextBreathe = 0
end

function ENT:OnThink()
	if(CurTime() >= self.m_nextBreathe && CurTime() >= self.m_tmLastSound +3) then
		self.m_nextBreathe = CurTime() +math.Rand(4,12)
		if(math.random(1,3) <= 2) then
			self:slvPlaySound("Breath")
		end
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
		if(atk == "rhand") then
			force = Vector(360,0,60)
			ang = Angle(38,-20,3)
		elseif(atk == "rhandb") then
			force = Vector(360,0,60)
			ang = Angle(38,28,-3)
		elseif(atk == "lhand") then
			force = Vector(360,0,60)
			ang = Angle(-36,-28,3)
		end
		self:DealMeleeDamage(dist,GetConVarNumber(skDmg),ang,force,DMG_SLASH)
		return true
	end
	if(event == "rattack") then
		local type = select(2,...)
		if(type == "plasma") then
			local atk = select(3,...)
			if(atk == "start") then
				local strAtt = select(4,...)
				local attID = self:LookupAttachment(strAtt)
				local att = self:GetAttachment(attID)
				local ent = ents.Create("obj_archvile_plasma")
				ent:SetPos(att.Pos)
				ent:SetParent(self)
				ent:Spawn()
				ent:Activate()
				self:NoCollide(ent)
				ent:Fire("setparentattachment",strAtt,0)
				self:DeleteOnRemove(ent)
				self.m_entParticle = ent
			elseif(atk == "throw") then
				local ent = self.m_entParticle
				if(!ent:IsValid()) then return true end
				self:slvPlaySound("Fire")
				self:DontDeleteOnRemove(ent)
				local enemy = self.entEnemy
				ent:SetParent()
				ent:InitPhysics()
				ent:SetTarget(enemy)
				self.m_entParticle = nil
				local speed = 100
				local dir
				if(!IsValid(enemy)) then dir = self:GetForward()
				else dir = (enemy:GetCenter() -ent:GetPos()):GetNormal() end
				local phys = ent:GetPhysicsObject()
				if(phys:IsValid()) then
					phys:ApplyForceCenter(dir *speed)
				end
			end
		elseif(type == "beam") then
			local atk = select(3,...)
			if(atk == "start") then
				local att = self:LookupAttachment("hands")
				local posAng = self:GetAttachment(att)
				local ent = util.ParticleEffectTracer("archvile_beam",posAng.Pos,self.entEnemy,Angle(0,0,0),self,"hands",false)
				
			elseif(atk == "end") then
				
			end
		end
		return true
	elseif(event == "summon") then
		local pos = self:GetPos()
		local ang = self:GetAngles()
		ang.y = ang.y +math.Rand(-40,40)
		local dir = ang:Forward()
		pos = pos +dir *math.Rand(80,140)
		self:SummonCreature("npc_hellknight",pos,ang)
		return true
	elseif(event == "resurrect") then
		local entRagdoll = ents.FindInSphere("prop_ragdoll")[1]
		if(!IsValid(entRagdoll)) then return true end
		local ent = self:SummonCreature("npc_hellknight",entRagdoll:GetPos(),entRagdoll:GetAngles())
		ent:slvSetHealth(ent:Health() *0.5)
		entRagdoll:Remove()
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
			if(dist <= self.fRangeDistance && CurTime() >= self.m_nextRangeAttack) then
				if(math.random(1,3) == 1) then
					if(math.random(1,3) == 1) then
						self.m_nextRangeAttack = CurTime() +math.Rand(3,6)
					end
					self:SLVPlayActivity(ACT_RANGE_ATTACK2_LOW,true)
					return
				end
			end
		end
		self:ChaseEnemy()
	elseif(disp == D_FR) then
		self:Hide()
	end
end
