
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

AccessorFunc(ENT,"m_dmg","Damage",FORCE_NUMBER)
AccessorFunc(ENT,"m_radius","Radius",FORCE_NUMBER)
AccessorFunc(ENT,"m_target","Target")
AccessorFunc(ENT,"m_speed","Speed",FORCE_NUMBER)
function ENT:Initialize()
	self:DrawShadow(false)
	self:InitPhysics()
	self.delayRemove = CurTime() +4.6
	ParticleEffectAttach("hellknight_plasma",PATTACH_ABSORIGIN_FOLLOW,self,0)
	self.m_speed = self.m_speed || 200
	self.m_radius = self.m_radius || 50
	self.m_dmg = self.m_dmg || 38
	
	self.cspSound = CreateSound(self,"npc/nihilanth/nil_teleattack1.wav")
	self.cspSound:Play()
	
	local light = ents.Create("light_dynamic")
	light:SetKeyValue("_light","0 126 255 200")
	light:SetKeyValue("brightness","0")
	light:SetKeyValue("distance","2000")
	light:SetKeyValue("style","0")
	light:SetPos(self:GetPos())
	light:SetParent(self)
	light:Spawn()
	light:Activate()
	light:Fire("TurnOn","",0)
	self:DeleteOnRemove(light)
end

function ENT:InitPhysics()
	self:SetMoveCollide(COLLISION_GROUP_PROJECTILE)
	self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
	self:PhysicsInitSphere(8)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	if(phys:IsValid()) then
		phys:Wake()
		phys:EnableGravity(false)
		phys:SetBuoyancyRatio(0)
		phys:SetMass(0.5)
	end
end

function ENT:SetEntityOwner(ent)
	self:SetOwner(ent)
	self.entOwner = ent
end

function ENT:OnRemove()
	self.cspSound:Stop()
end

function ENT:Think()
	local ent = self:GetTarget()
	if(IsValid(ent) && ent:Alive()) then
		local phys = self:GetPhysicsObject()
		if(phys:IsValid()) then
			local pos = ent:GetCenter() +ent:GetVelocity() *0.5
			local dirVel = self:GetVelocity():GetNormal()
			local dir = (pos -self:GetPos()):GetNormal()
			local dotProd = dir:DotProduct(dirVel)
			if(dotProd <= 0) then phys:SetVelocity(phys:GetVelocity() *0.75) end
			phys:ApplyForceCenter((pos -self:GetPos()):GetNormal() *self:GetSpeed())
		end
	end
	if(CurTime() < self.delayRemove) then return end
	self:Remove()
end

function ENT:PhysicsCollide(data,physobj)
	if(data.HitEntity:IsWorld()) then return end
	local pos = self:GetPos()
	local valid = IsValid(self.entOwner)
	sound.Play("npc/controller/electro4.wav",pos,75,100)
	local tbEnts = util.DealBlastDamage(pos,self:GetRadius(),self:GetDamage(),vector_origin,valid && self.entOwner || self,self,false,DMG_SHOCK)
	self:Remove()
	return true
end

