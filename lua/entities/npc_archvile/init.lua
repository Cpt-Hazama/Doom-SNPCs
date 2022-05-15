AddCSLuaFile("shared.lua")

include('shared.lua')

ENT.NPCFaction = NPC_FACTION_DEMON
ENT.iClass = CLASS_DEMON
util.AddNPCClassAlly(CLASS_DEMON,"npc_archvile")
ENT.sModel = "models/doom/archvile.mdl"
ENT.fMeleeDistance	= 64
ENT.fRangeDistance = 1600
ENT.bFlinchOnDamage = true
ENT.m_bKnockDownable = false
ENT.skName = "archvile"
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
ENT.sSoundDir = "npc/archvile/"

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

AccessorFunc(ENT,"m_bSummon","CanSummon",FORCE_BOOL)
AccessorFunc(ENT,"m_bTeleport","CanTeleport",FORCE_BOOL)
function ENT:OnInit()
	self:SetNPCFaction(NPC_FACTION_DEMON,CLASS_DEMON)
	self:SetHullType(HULL_HUMAN)
	self:SetHullSizeNormal()
	self:SetCollisionBounds(self.CollisionBounds,Vector(self.CollisionBounds.x *-1,self.CollisionBounds.y *-1,0))
	
	self:slvCapabilitiesAdd(bit.bor(CAP_MOVE_GROUND,CAP_OPEN_DOORS))
	self:slvSetHealth(GetConVarNumber("sk_" .. self.skName .. "_health"))
	self.m_nextRangeAttack = 0
	self.m_nextSummon = 0
	self.m_nextResurrect = 0
	self.m_nextBreathe = 0
	self.m_nextTeleport = 0
	if(self.m_bSummon == nil) then self.m_bSummon = true end
	if(self.m_bTeleport == nil) then self.m_bTeleport = true end
	self.m_tbSummons = {}
end

function ENT:_PossPrimaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_RANGE_ATTACK2_LOW,false,fcDone)
end

function ENT:_PossSecondaryAttack(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_MELEE_ATTACK1,false,fcDone)
end

function ENT:_PossJump(entPossessor,fcDone)
	self:SLVPlayActivity(ACT_HL2MP_JUMP,false,fcDone)
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

function ENT:_PossDuck(entPossessor,fcDone)
	for i = #self.m_tbSummons,1,-1 do
		local ent = self.m_tbSummons[i]
		if(!ent:IsValid()) then
			table.remove(self.m_tbSummons,i)
		end
	end
	if(#self.m_tbSummons >= 2) then fcDone(true); return end
	self:SLVPlayActivity(ACT_RANGE_ATTACK2,false,fcDone)
end

function ENT:KeyValueHandle(key,val)
	if(key == "spawnflags") then
		local flags = tonumber(val)
		self:SetCanSummon(bit.band(flags,32768) == 0)
		self:SetCanTeleport(bit.band(flags,65536) == 0)
	end
end

function ENT:SetupRelationship(ent)
	if(ent:IsNPC()) then
		self:slvAddEntityRelationship(ent,D_LI,100)
		return true
	end
end

function ENT:OnThink()
	if(CurTime() >= self.m_nextBreathe && CurTime() >= self.m_tmLastSound +3) then
		self.m_nextBreathe = CurTime() +math.Rand(4,12)
		if(math.random(1,3) <= 2) then
			self:slvPlaySound("Breath")
		end
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
				ent:SetEntityOwner(self)
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
				local enemy
				if(!self:SLV_IsPossesed()) then enemy = self.entEnemy
				else enemy = self:FindPossessorTarget() end
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
		self:SummonCreature(table.Random({"npc_hellknight","npc_revenant"}),pos,ang)
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

function ENT:InitSandbox()
	if(!self:GetSquad()) then
		self:SetSquad(self:GetClass() .. "_sbsquad")
	end
end

function ENT:InitAftermath()
	self:SetDTBool(3,true)
	self.m_bAftermath = true
end

function ENT:SummonCreature(class,pos,ang)
	local ent = ents.Create(class)
	ent:SetAngles(ang)
	ent:SetPos(pos)
	ent:slvFadeIn(1)
	if(self:GetDTBool(3)) then
		ent:SetDTBool(3,true)
	end
	ent:Spawn()
	ent:Activate()
	ent:MoveToClearSpot(pos)
	local squad = self:GetSquad()
	if(squad) then ent:SetSquad(squad) end
	table.insert(self.m_tbSummons,ent)
	ParticleEffect("teleport_fx",ent:GetPos(),Angle(0,0,0),ent)
	sound.Play("fx/teleport_out.wav",ent:GetPos(),100,100)
	return ent
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
	self:SLVPlayActivity(ACT_SPECIAL_ATTACK1)
	self.m_nextTeleport = CurTime() +math.Rand(3,6)
end

function ENT:Summon()
	self:SLVPlayActivity(ACT_RANGE_ATTACK2)
end

function ENT:Resurrect()
	self:SLVPlayActivity(ACT_RANGE_ATTACK1_LOW)
end

function ENT:OnRemove()
	for _, ent in ipairs(self.m_tbSummons) do
		if(ent:IsValid()) then
			local dmginfo = DamageInfo()
			dmginfo:SetDamage(ent:Health() *10)
			dmginfo:SetAttacker(ent)
			dmginfo:SetInflictor(ent)
			dmginfo:SetDamageType(DMG_GENERIC)
			dmginfo:SetDamagePosition(ent:GetPos() +ent:OBBCenter())
			ent:TakeDamageInfo(dmginfo)
		end
	end
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
				if(math.random(1,2) == 1) then
					if(math.random(1,2) == 1) then self:Teleport(); return end
					self:SLVPlayActivity(ACT_HL2MP_JUMP)
					return
				end
			end
			if(dist <= self.fMeleeDistance || distPred <= self.fMeleeDistance) then
				self:SLVPlayActivity(ACT_MELEE_ATTACK1,true)
				return
			end
			if(dist <= self.fRangeDistance && CurTime() >= self.m_nextRangeAttack) then
				if(math.random(1,2) == 1) then
					if(math.random(1,3) == 1) then
						self.m_nextRangeAttack = CurTime() +math.Rand(3,6)
					end
					if(self:GetCanTeleport() && (CurTime() >= self.m_nextTeleport || dist > self.fRangeDistance)) then
						self.m_nextTeleport = CurTime() +math.Rand(3,6)
						if(math.random(1,5) == 1) then
							self:Teleport()
							return
						end
					end
					if(self:GetCanSummon() && CurTime() >= self.m_nextSummon) then
						self.m_nextSummon = CurTime() +math.Rand(2,5)
						for i = #self.m_tbSummons,1,-1 do
							local ent = self.m_tbSummons[i]
							if(!ent:IsValid()) then
								table.remove(self.m_tbSummons,i)
							end
						end
						local num = #self.m_tbSummons
						if(num < 2) then
							if((num == 0 && math.random(1,4) <= 3) || (num == 1 && math.random(1,4) == 1)) then
								self:Summon()
								return
							end
						end
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
