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

local unitMap = {}

-- update a specific bar
local updateHealCommBar = function(frame, playerGUID)

	unitMap = healcomm:GetGuidUnitMapTable() -- doing this every time??? blargh
	local unitName = playerGUID and unitMap[playerGUID]

	if not unitName then return end

	local maxHP = UnitHealthMax(unitName)

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

	frame.HealCommBar:Show()

	local percInc = incHeals / maxHP
	local curHP = UnitHealth(unitName)
	local percHP = curHP / maxHP

	frame.HealCommBar:SetWidth(percInc * frame.Health:GetWidth())
	frame.HealCommBar:SetPoint("LEFT", frame.Health, "LEFT", frame.Health:GetWidth() * percHP, 0)
end

-- used by library callbacks, arguments should be list of units to update
local updateHealCommBars = function(...)
	local playerGUID, frameGUID
	for i = 1, select("#", ...) do
		playerGUID = select(i, ...)

		-- search current oUF frames for this unit
		for frame in pairs(oUF.units) do
			frameGUID = UnitGUID(frame)
			if frameGUID == playerGUID and not oUF.units[frame].ignoreHealComm then
				updateHealCommBar(oUF.units[frame], frameGUID)
			end
		end
	end
end

local function hook(frame)
	if frame.ignoreHealComm then return end

	-- create heal bar here and set initial values
	local hcb = CreateFrame("StatusBar")
	hcb:SetHeight(frame.Health:GetHeight()) -- same height as health bar
	hcb:SetWidth(0) -- no initial width
	hcb:SetStatusBarTexture(frame.Health:GetStatusBarTexture():GetTexture())
	hcb:SetStatusBarColor(color.r, color.g, color.b, color.a)
	hcb:SetParent(frame)
	hcb:SetPoint("LEFT", frame.Health, "RIGHT") -- attach to immediate right of health bar to start
	hcb:Hide() -- hide it for now

	frame.HealCommBar = hcb

	local o = frame.PostUpdateHealth
	frame.PostUpdateHealth = function(...)
		if o then o(...) end
		local frameGUID = UnitGUID(frame.unit)
		updateHealCommBar(frame, frameGUID) -- update the bar when unit's health is updated
	end
end

-- hook into all existing frames
for i, frame in ipairs(oUF.objects) do hook(frame) end

-- hook into new frames as they're created
oUF:RegisterInitCallback(hook)

-- set up LibHealComm callbacks
function oUF_HealComm:HealComm_Heal_Update(_, _, _, _, ...)
	updateHealCommBars(...)
end

function oUF_HealComm:HealComm_Modifier_Changed(guid, _)
	updateHealCommBars(guid)
end

healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealStarted", "HealComm_Heal_Update")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealUpdated", "HealComm_Heal_Update")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealDelayed", "HealComm_Heal_Update")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealStopped", "HealComm_Heal_Update")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_ModifierChanged", "HealComm_Modifier_Changed")
