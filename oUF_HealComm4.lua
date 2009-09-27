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
--=============================================================================
local parent = debugstack():match[[\AddOns\(.-)\]]
local global = GetAddOnMetadata(parent, 'X-oUF')
local oUF = _G[global] or oUF
assert(oUF, 'oUF not loaded')

-- set texture and color here
local color = {
    r = 0,
    g = 1,
    b = 0,
    a = .25,
}

local oUF_HealComm = {}

local healcomm = LibStub("LibHealComm-4.0")

-- update a specific bar
local updateHealCommBar = function(frame, unitName, playerGUID)

	-- hide bars for any units with an unknown name
	if not unitName then
		frame.HealCommBar:Hide()
		return
	end

	local maxHP = UnitHealthMax(unitName) or 0

	-- hide if unknown max hp
	if maxHP == 0 or maxHP == 100 then
		frame.HealCommBar:Hide()
		return
	end

	local incHeals = healcomm:GetHealAmount(playerGUID, healcomm.ALL_HEALS) or 0

	-- hide if no heals inc
	if incHeals == 0 then
		frame.HealCommBar:Hide()
		return
	end

	-- apply heal modifier
	incHeals = incHeals * healcomm:GetHealModifier(playerGUID)

	frame.HealCommBar:Show()

	local percInc = incHeals / maxHP
	local curHP = UnitHealth(unitName)
	local percHP = curHP / maxHP

	-- slightly inefficient to set height here for the moment but it should
	-- fix different heights for units with/without a power bar
	-- Changing to be able to have vertical/horizontal bars will mean we
	-- have to do this here anyway...
	frame.HealCommBar:SetHeight(frame.Health:GetHeight())
	frame.HealCommBar:SetWidth(percInc * frame.Health:GetWidth())
	frame.HealCommBar:SetPoint("LEFT", frame.Health, "LEFT", frame.Health:GetWidth() * percHP, 0)
end

-- used by library callbacks, arguments should be list of units to update
local updateHealCommBars = function(...)
	local playerGUID, unit, frameGUID

	-- update the unitMap to make sure it is current
	local unitMap = healcomm:GetGuidUnitMapTable()

	for i = 1, select("#", ...) do
		playerGUID = select(i, ...)
		unit = unitMap[playerGUID]

		-- search current oUF frames for this unit
		for frame in pairs(oUF.units) do
			frameGUID = UnitGUID(frame)
			if frameGUID == playerGUID and not oUF.units[frame].ignoreHealComm then
				updateHealCommBar(oUF.units[frame], unit, playerGUID)
			end
		end
	end
end

local function hook(frame)
	if frame.ignoreHealComm then return end

	-- make sure some crap implementation using oUF
	-- for non-unit frames doesn't cause errors
	if not frame.Health then
		frame.ignoreHealComm = true
		return
	end

	-- create heal bar here and set initial values
	local hcb = CreateFrame("StatusBar")
	hcb:SetHeight(0) -- no initial height
	hcb:SetWidth(0) -- no initial width
	hcb:SetStatusBarTexture(frame.Health:GetStatusBarTexture():GetTexture())
	hcb:SetStatusBarColor(color.r, color.g, color.b, color.a)
	hcb:SetParent(frame)
	hcb:SetPoint("LEFT", frame.Health, "RIGHT") -- attach to immediate right of health bar to start
	hcb:Hide() -- hide it for now

	frame.HealCommBar = hcb

	local origPostUpdate = frame.PostUpdateHealth
	frame.PostUpdateHealth = function(...)
		if origPostUpdate then origPostUpdate(...) end
		local frameGUID = UnitGUID(frame.unit)
		updateHealCommBars(frameGUID) -- update the bar when unit's health is updated
	end
end

-- hook into all existing frames
for i, frame in ipairs(oUF.objects) do hook(frame) end

-- hook into new frames as they're created
oUF:RegisterInitCallback(hook)

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
