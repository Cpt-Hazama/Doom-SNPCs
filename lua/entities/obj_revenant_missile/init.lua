AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

ENT.Model = "models/fallout/ammo/rocket.mdl"
ENT.ParticleTrail = "redglare_trail"
ENT.ParticleTrailSmoke = "redglare_smoke_trail"
function ENT:Initialize()
	self.BaseClass.Initialize(self)
	self:SetSpeed(400)
	self:SetHeatSeeking(true)
end

function ENT:PhysicsCollide(data, physobj)
	self:DoExplode(16,120,IsValid(self.entOwner) && self.entOwner)
	return true
end

function ENT:Think()
	local phys = self:GetPhysicsObject()
	if(!phys:IsValid()) then return end
	local b
	if(IsValid(self.entOwner) && self:GetHeatSeeking()) then
		if(!IsValid(self.entTgt) || !self.entTgt:Alive()) then self.entTgt = self:LookForTarget() end
		if(self.entTgt:IsValid()) then
			local dir = self:GetForward()
			local ang = ((self.entTgt:GetCenter() +self.entTgt:GetVelocity() *0.3) -(self:GetPos() +self:OBBCenter())):Angle()
			local dirTgt = ang:Forward()
			local dotProd = dir:DotProduct(dirTgt)
			if(dotProd <= 0) then self:SetHeatSeeking(false)
			else
				self:TurnDegree(1,ang,true)
				self:NextThink(CurTime())
				b = true
			end
		end
	end
	phys:SetVelocity(self:GetForward() *self:GetSpeed())
	return b
end