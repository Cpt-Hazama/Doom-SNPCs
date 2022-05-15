AddCSLuaFile("shared.lua")

include('shared.lua')

ENT.NPCFaction = NPC_FACTION_DEMON
ENT.iClass = CLASS_DEMON
util.AddNPCClassAlly(CLASS_DEMON,"npc_hellknight")
ENT.sModel = "models/doom/hellknight.mdl"
ENT.fRangeDistance = 2000
ENT.fMeleeDistance	= 80
ENT.bFlinchOnDamage = true
ENT.m_bKnockDownable = false
ENT.bIgnitable = false
ENT.bFreezable = false
ENT.skName = "hellknight"
ENT.CollisionBounds = Vector(30,30,120)
//ENT.SurvivalCollisionBounds = Vector(26,26,90)

ENT.DamageScales = {
	[DMG_BURN] = 1.5,
	[DMG_PARALYZE] = 0,
	[DMG_NERVEGAS] = 0,
	[DMG_POISON] = 0,
	[DMG_DIRECT] = 1.5
}
ENT.sSoundDir = "npc/hellknight/"

ENT.m_tbSounds = {
	["Chomp"] = "chomp[1-3].mp3",
	["Alert"] = {"sight1_[1-2].mp3","sight2_[1-3].mp3","sight3_[1-2].mp3"},
	["Foot"] = "foot/step[1-4].mp3",
	["Death"] = "die[1-3].mp3",
	["Pain"] = "hk_pain_0[1-3].mp3"
}

ENT.tblFlinchActivities = {
	[HITBOX_GENERIC] = ACT_SMALL_FLINCH,
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
end

function ENT:_PossPrimaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_RANGE_ATTACK1,false,fcDone)
end

function ENT:_PossSecondaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_MELEE_ATTACK1,false,fcDone)
end

function ENT:SetupRelationship(ent)
	if(ent:IsNPC()) then
		self:slvAddEntityRelationship(ent,D_LI,100)
		return true
	end
end

function ENT:OnFoundEnemy(iEnemies)
	if(math.random(1,4) == 1) then
		self:SLVPlayActivity(ACT_IDLE_ANGRY)
	end
end

function ENT:FindPossessorTarget()
	local entClosest
	local dotProdClosest = math.huge
	local possessor = self:GetPossessor()
	local dirPossessor = possessor:GetAimVector()
	local pos = possessor:GetPossessionCamPos()
	for _,ent in ipairs(ents.GetAll()) do
		if((ent:IsNPC() || ent:IsPlayer()) && ent != self && ent:Alive() && ent != possessor) then
			local disp = self:slvDisposition(ent)
			if(disp == D_HT || disp == D_FR) then
				if(self:CanSee(ent)) then
					local dotProd = (pos -ent:GetCenter()):GetNormal():DotProduct(dirPossessor)
					print(ent,dotProd)
					if(dotProd < dotProdClosest) then
						dotProdClosest = dotProd
						entClosest = ent
					end
				end
			end
		end
	end
	return entClosest
end

function ENT:EventHandle(...)
	local event = select(1,...)
	if(event == "mattack") then
		local dist = self.fMeleeDistance
		local skDmg = "sk_" .. self.skName .. "_dmg"
		local force
		local ang
		local atk = select(2,...)
		if(atk == "bite") then
			skDmg = skDmg .. "_bite"
			force = Vector(120,0,0)
			ang = Angle(30,0,0)
		elseif(atk == "right") then
			skDmg = skDmg .. "_slash"
			force = Vector(480,0,60)
			ang = Angle(-8,-48,5)
		elseif(atk == "left") then
			skDmg = skDmg .. "_slash"
			force = Vector(480,0,60)
			ang = Angle(-8,48,-5)
		end
		self:DealMeleeDamage(dist,GetConVarNumber(skDmg),ang,force,DMG_SLASH)
		return true
	end
	if(event == "rattack") then
		local atk = select(2,...)
		if(atk == "start") then
			local attID = self:LookupAttachment("rhand")
			local att = self:GetAttachment(attID)
			local ent = ents.Create("obj_hellknight_plasma")
			ent:SetPos(att.Pos)
			ent:SetParent(self)
			ent:SetEntityOwner(self)
			ent:Spawn()
			ent:Activate()
			self:NoCollide(ent)
			ent:Fire("setparentattachment","rhand",0)
			self:DeleteOnRemove(ent)
			self.m_entParticle = ent
		elseif(atk == "throw") then
			local ent = self.m_entParticle
			if(!ent:IsValid()) then return true end
			self:DontDeleteOnRemove(ent)
			local enemy
			if(self:SLV_IsPossesed()) then enemy = self:FindPossessorTarget()
			else enemy = self.entEnemy end
			ent:SetParent()
			ent:InitPhysics()
			ent:SetTarget(enemy)
			self.m_entParticle = nil
			local speed = 400
			local dir
			if(!IsValid(enemy)) then dir = self:GetForward()
			else dir = (enemy:GetCenter() -ent:GetPos()):GetNormal() end
			local phys = ent:GetPhysicsObject()
			if(phys:IsValid()) then
				phys:ApplyForceCenter(dir *speed)
			end
		end
		return true
	end
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
	if(disp == D_HT) then
		if(self:CanSee(self.entEnemy)) then
			if(dist <= self.fMeleeDistance || distPred <= self.fMeleeDistance) then
				self:SLVPlayActivity(ACT_MELEE_ATTACK1)
				return
			end
			if(dist <= self.fRangeDistance && CurTime() >= self.m_nextRangeAttack) then
				self.m_nextRangeAttack = CurTime() +math.Rand(2,4)
				if(math.random(1,5) <= 4) then
					self:SLVPlayActivity(ACT_RANGE_ATTACK1)
					return
				end
			end
		end
		self:ChaseEnemy()
	elseif(disp == D_FR) then
		self:Hide()
	end
end
