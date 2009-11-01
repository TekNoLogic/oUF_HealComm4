--==============================================================================
--
-- oUF_HealComm4
--
-- Uses data from LibHealComm-4.0 to add incoming heal estimate bars onto units
-- health bars.
--
-- * currently won't update the frame if max HP is unknown (ie, restricted to
--   players/pets in your group that are in range), hides the bar for these
-- * can define frame.ignoreHealComm in layout to not have the bars appear on
--   that frame
--
-- - allowOverflow - If set, healcomm bars may overflow the Health bar when an overheal will occur
--
-- This addon is based on the original oUF_HealComm by Krage
--
--=============================================================================
local parent = debugstack():match[[\AddOns\(.-)\]]
local global = GetAddOnMetadata(parent, 'X-oUF')
local oUF = _G[global] or oUF
assert(oUF, 'oUF not loaded')

local healcomm = LibStub("LibHealComm-4.0")

local oUF_HealComm = {}

local unitMap = healcomm:GetGUIDUnitMapTable()

local function noIncomingHeals(frame)
	if frame.HealCommBar then frame.HealCommBar:Hide() end
	if frame.HealCommText then frame.HealCommText:SetText(nil) end
end

-- update a specific bar
local function updateHealCommBar(frame, unitName, playerGUID)
	-- hide bars for any units with an unknown name
	if not unitName then
		noIncomingHeals(frame)
		return
	end

	-- hide bars on DC'd or dead units
	if (not UnitIsConnected(unitName)) or UnitIsDeadOrGhost(unitName) then
		noIncomingHeals(frame)
		return
	end

	local maxHP = UnitHealthMax(unitName) or 0

	-- hide if unknown max hp
	if maxHP == 0 or maxHP == 100 then
		noIncomingHeals(frame)
		return
	end

	local incHeals = healcomm:GetHealAmount(playerGUID, healcomm.ALL_HEALS) or 0

	-- hide if no heals inc
	if incHeals == 0 then
		noIncomingHeals(frame)
		return
	end

	-- apply heal modifier
	incHeals = incHeals * healcomm:GetHealModifier(playerGUID)

	-- update the incoming heal bar
	if frame.HealCommBar then
		frame.HealCommBar:Show()

		local curHP = UnitHealth(unitName)
		local percHP = curHP / maxHP
		local percInc = (frame.allowOverflow and incHeals or math.min(incHeals, maxHP-curHP)) / maxHP

		frame.HealCommBar:ClearAllPoints()

		if frame.Health:GetOrientation() == "VERTICAL" then
			frame.HealCommBar:SetHeight(percInc * frame.Health:GetHeight())
			frame.HealCommBar:SetWidth(frame.Health:GetWidth())
			frame.HealCommBar:SetPoint("BOTTOM", frame.Health, "BOTTOM", 0, frame.Health:GetHeight() * percHP)
		else
			frame.HealCommBar:SetHeight(frame.Health:GetHeight())
			frame.HealCommBar:SetWidth(percInc * frame.Health:GetWidth())
			frame.HealCommBar:SetPoint("LEFT", frame.Health, "LEFT", frame.Health:GetWidth() * percHP, 0)
		end
	end

	-- update the incoming heal text
	if frame.HealCommText then
		frame.HealCommText:SetText(frame.HealCommTextFormat and frame.HealCommTextFormat(incHeals) or format("%d", incHeals))
	end
end

local function hook(frame)
	local origPostUpdate = frame.PostUpdateHealth
	frame.PostUpdateHealth = function(...)
		if origPostUpdate then origPostUpdate(...) end
		local frameGUID = UnitGUID(frame.unit)
		unitMap = healcomm:GetGUIDUnitMapTable()
		updateHealCommBar(frame, unitMap[frameGUID], frameGUID) -- update the bar when unit's health is updated
	end
end

-- hook into all existing frames
for i, frame in ipairs(oUF.objects) do hook(frame) end

-- hook into new frames as they're created
oUF:RegisterInitCallback(hook)


-- used by library callbacks, arguments should be list of units to update
local function updateHealCommBars(...)
	-- update the unitMap to make sure it is current
	unitMap = healcomm:GetGUIDUnitMapTable()

	for i=1,select("#", ...) do
		local playerGUID = select(i, ...)
		for i,frame in ipairs(oUF.objects) do
			if frame.unit and (frame.HealCommBar or frame.HealCommText) and UnitGUID(frame.unit) == playerGUID then updateHealCommBar(frame, unitMap[playerGUID], playerGUID) end
		end
	end
end

-- set up LibHealComm callbacks
function oUF_HealComm:HealComm_Heal_Update(event, casterGUID, spellID, healType, _, ...)
	updateHealCommBars(...)
end

function oUF_HealComm:HealComm_Modified(event, guid)
	updateHealCommBars(guid)
end

healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealStarted", "HealComm_Heal_Update")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealUpdated", "HealComm_Heal_Update")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealDelayed", "HealComm_Heal_Update")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealStopped", "HealComm_Heal_Update")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_ModifierChanged", "HealComm_Modified")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_GUIDDisappeared", "HealComm_Modified")
