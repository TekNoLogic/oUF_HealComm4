--==============================================================================
--
-- oUF_HealComm4
--
-- Uses data from LibHealComm-4.0 to add incoming heal estimate bars onto units
-- health bars.
--
-- * currently won't update the frame if max HP is unknown (ie, restricted to
--   players/pets in your group that are in range), hides the bar for these
--
--	Elements handled:
--	 .ignoreHealComm [boolean] (optional) - enable/disable incoming heal bars
--	 .HealCommOthersOnly [boolean] (optional) - enable/disable showing heals cast by the player
--	 .HealCommText [fontstring] (optional) - enable a text display for incoming heal value
--	 allowOverflow - If set, healcomm bars may overflow the Health bar when an overheal will occur
--
--	Functions that can be overridden from within a layout:
--	 .HealCommTextFormat(value) - return formated string to display
--
-- This addon is based on the original oUF_HealComm by Krage
--
--=============================================================================
local parent = debugstack():match[[\AddOns\(.-)\]]
local global = GetAddOnMetadata(parent, 'X-oUF')
local oUF = _G[global] or oUF
assert(oUF, 'oUF not loaded')

local healcomm = LibStub("LibHealComm-4.0")
local unitMap = healcomm:GetGUIDUnitMapTable()

local function Hide(self)
	if self.HealCommBar then self.HealCommBar:Hide() end
	if self.HealCommText then self.HealCommText:SetText(nil) end
end


local function Update(self)
	if not self.unit or UnitIsDeadOrGhost(self.unit) or not UnitIsConnected(self.unit) then return Hide(self) end

	local maxHP = UnitHealthMax(self.unit) or 0
	if maxHP == 0 or maxHP == 100 then return Hide(self) end

	local guid = UnitGUID(self.unit)
	local incHeals = healcomm:GetHealAmount(guid, healcomm.ALL_HEALS) or 0
	local incHeals = self.HealCommOthersOnly and healcomm:GetOthersHealAmount(guid, healcomm.ALL_HEALS) or not self.HealCommOthersOnly and healcomm:GetHealAmount(guid, healcomm.ALL_HEALS) or 0
	if incHeals == 0 then return Hide(self) end

	incHeals = incHeals * healcomm:GetHealModifier(guid)

	if self.HealCommBar then
		local curHP = UnitHealth(self.unit)
		local percHP = curHP / maxHP
		local percInc = (self.allowOverflow and incHeals or math.min(incHeals, maxHP-curHP)) / maxHP

		self.HealCommBar:ClearAllPoints()

		if self.Health:GetOrientation() == "VERTICAL" then
			self.HealCommBar:SetHeight(percInc * self.Health:GetHeight())
			self.HealCommBar:SetWidth(self.Health:GetWidth())
			self.HealCommBar:SetPoint("BOTTOM", self.Health, "BOTTOM", 0, self.Health:GetHeight() * percHP)
		else
			self.HealCommBar:SetHeight(self.Health:GetHeight())
			self.HealCommBar:SetWidth(percInc * self.Health:GetWidth())
			self.HealCommBar:SetPoint("LEFT", self.Health, "LEFT", self.Health:GetWidth() * percHP, 0)
		end

		self.HealCommBar:Show()
	end

	if self.HealCommText then self.HealCommText:SetText(self.HealCommTextFormat and self.HealCommTextFormat(incHeals) or format("%d", incHeals)) end
end


local function Enable(self)
	local hcb, hct = self.HealCommBar, self.HealCommText
	if not hcb and not hct or not self.unit then return end

	if hcb then
		self:RegisterEvent("UNIT_HEALTH", Update)
		self:RegisterEvent("UNIT_MAXHEALTH", Update)

		if not hcb:GetStatusBarTexture() then hcb:SetStatusBarTexture[[Interface\TargetingFrame\UI-StatusBar]] end
	end

	return true
end


local function Disable(self)
	if self.unit and (self.HealCommBar or self.HealCommText) then
		self:UnregisterEvent("UNIT_HEALTH", Update)
		self:UnregisterEvent("UNIT_MAXHEALTH", Update)
	end
end


oUF:AddElement('HealComm4', Update, Enable, Disable)


local function MultiUpdate(...)
	for i=1,select("#", ...) do
		for i,frame in ipairs(oUF.objects) do
			if frame.unit and (frame.HealCommBar or frame.HealCommText) and UnitGUID(frame.unit) == select(i, ...) then Update(frame) end
		end
	end
end


local function HealComm_Heal_Update(event, casterGUID, spellID, healType, _, ...)
	MultiUpdate(...)
end


local function HealComm_Modified(event, guid)
	MultiUpdate(guid)
end

healcomm.RegisterCallback("oUF_HealComm4", "HealComm_HealStarted", HealComm_Heal_Update)
healcomm.RegisterCallback("oUF_HealComm4", "HealComm_HealUpdated", HealComm_Heal_Update)
healcomm.RegisterCallback("oUF_HealComm4", "HealComm_HealDelayed", HealComm_Heal_Update)
healcomm.RegisterCallback("oUF_HealComm4", "HealComm_HealStopped", HealComm_Heal_Update)
healcomm.RegisterCallback("oUF_HealComm4", "HealComm_ModifierChanged", HealComm_Modified)
healcomm.RegisterCallback("oUF_HealComm4", "HealComm_GUIDDisappeared", HealComm_Modified)
