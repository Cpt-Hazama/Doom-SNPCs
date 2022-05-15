AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

AccessorFunc(ENT,"m_fRadius","Radius",FORCE_NUMBER)
AccessorFunc(ENT,"m_fTTL","TimeToLive",FORCE_NUMBER)
function ENT:Initialize()
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_NONE)
	self:SetNoDraw(true)
	self:DrawShadow(false)
	local tr = util.TraceLine({
		start = self:GetPos(),
		endpos = self:GetPos() -Vector(0,0,32768),
		filter = self,
		mask = MASK_NPCWORLDSTATIC
	})
	self.m_nextMove = CurTime() +0.1
	self.m_numFlames = 1
	self.m_tmRemove = 12
	self:SetPos(self:GetFloorPos(self:GetPos()))
	self:SpawnFlames()
end

function ENT:SetEntityOwner(ent)
	self.entOwner = ent
	self:SetOwner(ent)
end

function ENT:GetEntityOwner() return self.entOwner || NULL end

function ENT:DealFlameDamage(pos)
	local owner = self:GetEntityOwner()
	local attacker = owner:IsValid() && owner || self
	for _, ent in ipairs(ents.FindInSphere(pos,80)) do
		if(ent != owner && (ent:IsNPC() || ent:IsPlayer())) then
			local bEnemy
			if(!owner:IsValid()) then bEnemy = true
			else
				local disp = owner:slvDisposition(ent)
				bEnemy = disp == D_HT || disp == D_FR
			end
			if(bEnemy) then
				local dur = ent:IsNPC() && 6 || 1.2
				ent:slvIgnite(dur,nil,attacker)
				local dmg = DamageInfo()
				dmg:SetAttacker(attacker)
				dmg:SetDamage(ent:IsNPC() && 24 || 18)
				dmg:SetDamageForce(vector_origin)
				dmg:SetDamagePosition(ent:NearestPoint(pos))
				dmg:SetDamageType(DMG_BURN)
				dmg:SetInflictor(self)
				self:TakeDamageInfo(dmg)
			end
		end
	end
end

function ENT:GetFloorPos(pos)
	local tr = util.TraceLine({
		start = pos +Vector(0,0,30),
		endpos = pos -Vector(0,0,150),
		filter = self,
		mask = MASK_NPCWORLDSTATIC
	})
	return tr.HitPos
end

function ENT:SpawnFlames()
	local pos = self:GetPos()
	local dir = self:GetRight()
	local offset = dir *100
	self:StopParticles()
	self:EmitSound("fx/fx_fire_gas_high0" .. math.random(1,2) .. ".wav",75,100)
	local ang = self:GetAngles()
	ParticleEffect("fire_large_01",pos,ang,self)
	self:DealFlameDamage(pos)
	for i = 1,self.m_numFlames -1 do
		local scDir
		if(i %2 == 0) then scDir = -1
		else scDir = 1 end
		local posTgt = self:GetFloorPos(pos +offset *scDir)
		ParticleEffect("fire_large_01",posTgt,ang,self)
		self:DealFlameDamage(posTgt)
		if(i %2 == 0) then offset = offset +dir *100 end
	end
	self.m_tmRemove = self.m_tmRemove -1
	if(self.m_tmRemove == 0) then self:Remove() end
end

function ENT:Think()
	if(CurTime() >= self.m_nextMove) then
		self:SetPos(self:GetPos() +self:GetForward() *120)
		self.m_nextMove = CurTime() +0.1
		self.m_numFlames = self.m_numFlames +2
		self:SpawnFlames()
	end
end