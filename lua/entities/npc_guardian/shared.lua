ENT.Base = "npc_creature_base"
ENT.Type = "ai"

ENT.PrintName = "Guardian"
ENT.Category = "Doom"
ENT.NPCID = "00066654"
ENT.HasSoundtrack = true

if(CLIENT) then
	language.Add("npc_guardian","Guardian")

	ENT.Tension = 200
	local mat = Material("effects/guardian_shield")
	ENT.nextBlend = 0
	ENT.flBlend = 1
	function ENT:Initialize()
		if(self.SetSoundtrack) then
			self:SetSoundtrack("music/bosstracks/theme_guardian.mp3")
			//self:SetSoundtrack("music/bosstracks/theme_guardian2.mp3")
		end
		local lifeTime = 2
		local deathDelay = CurTime() +lifeTime
		local iIndex = self:EntIndex()
		hook.Add("RenderScreenspaceEffects", "Effect_ShockroachPlasmaOverlay" .. iIndex, function()
			if !IsValid(self) then
				hook.Remove("RenderScreenspaceEffects", "Effect_ShockroachPlasmaOverlay" .. iIndex)
				return
			end
			local ent = self
			if !IsValid(ent) then return end
			if !ent:GetNWBool("SLVBase_Doom_Shield") then return end
			cam.Start3D(EyePos(),EyeAngles(),85)
				if util.IsValidModel(ent:GetModel()) then
					render.SetBlend(self.flBlend)
					render.MaterialOverride(mat)
					ent:DrawModel()
					render.MaterialOverride(0)
					render.SetBlend(1)
				end
			cam.End3D()
			-- if CurTime() >= self.nextBlend then
				-- self.nextBlend = CurTime() +0.05
				-- if self.flBlend > 0 then
					-- local flBlendAdd = 0.05
					-- if CurTime() >= deathDelay then
						-- flBlendAdd = flBlendAdd +math.Clamp(((CurTime() -deathDelay) /100), 0, 0.05)
					-- end
					-- self.flBlend = self.flBlend -(lifeTime /(lifeTime ^2)) *flBlendAdd
				-- end
			-- end
		end)
	end
	usermessage.Hook("guardian_shield",function(um)
		local ent = um:ReadEntity()
		if(!ent:IsValid()) then return end
		ent.m_tmShield = CurTime()
	end)
	-- local mat = Material("effects/guardian_shield")
	-- local tmShieldFade = 0.4
	-- function ENT:RenderOverride()
		-- self:DrawModel()
		-- if(self.m_tmShield) then
			-- local tmDiff = CurTime() -self.m_tmShield
			-- if(tmDiff >= tmShieldFade) then self.m_tmShield = nil
			-- else
				-- local a = tmShieldFade -tmDiff
				-- cam.Start3D(EyePos(),EyeAngles(),85)
					-- render.SetBlend(a)
					-- SetMaterialOverride(mat)
					-- // +Model scale
						-- self:DrawModel()
					-- SetMaterialOverride(0)
					-- render.SetBlend(1)
				-- cam.End3D()
			-- end
		-- end
	-- end
	local tracks,durations = {"music/theme_guardian.mp3"},{85.6}
	function ENT:GetSoundtracks()
		return tracks,durations
	end
end

