local addonName, ns = ...
ns.version = C_AddOns.GetAddOnMetadata(..., "Version")

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")
local HL = LibStub("AceAddon-3.0"):NewAddon("UniversalExplorer", "AceEvent-3.0")
ns.HL = HL
ns.icon = "Interface\\Addons\\" .. addonName .. "\\icon"

---------------------------------------------------------------------------------------------------
--	Plugin Handlers to HandyNotes
---------------------------------------------------------------------------------------------------
local HLHandler = {}
local tip = {}
local info = {}
ns.points = {}
local horizontal_line = CreateAtlasMarkup("Timer-Fill", 275, 1)

local db
local defaults = {profile = {icon_scale = 1.0, icon_alpha = 1.0}}

local options = {
    type = "group",
    name = "UniversalExplorer",
    desc = "UniversalExplorer",
    get = function(info) return db[info[#info]] end,
    set = function(info, v)
        db[info[#info]] = v
        HL:SendMessage("HandyNotes_NotifyUpdate", "UniversalExplorer")
    end,
    args = {
        desc = {
            name = "These settings control the look and feel of the icon.",
            type = "description",
            order = 0
        },
        icon_scale = {
            type = "range",
            name = "Icon Scale",
            desc = "The scale of the icons",
            min = 0.25,
            max = 2,
            step = 0.01,
            arg = "icon_scale",
            order = 10
        },
        icon_alpha = {
            type = "range",
            name = "Icon Alpha",
            desc = "The alpha transparency of the icons",
            min = 0,
            max = 1,
            step = 0.01,
            arg = "icon_alpha",
            order = 20
        }

    }
}

---------------------------------------------------------------------------------------------------
--	Debug functions
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--	Print text to the General Chat
---------------------------------------------------------------------------------------------------
local function DebugPrint(message)
    if DEFAULT_CHAT_FRAME then
        -- enable this line for debugging information
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[" .. addonName .. "]|r: " ..
                                          message)
    end
end

---------------------------------------------------------------------------------------------------
--	Turn any Table into something printable
---------------------------------------------------------------------------------------------------
local function TableToString(tbl, indent)
    if not indent then indent = 0 end
    local toprint = string.rep(" ", indent) .. "{\n"
    indent = indent + 2
    for k, v in pairs(tbl) do
        toprint = toprint .. string.rep(" ", indent)
        if (type(k) == "number") then
            toprint = toprint .. "[" .. k .. "] = "
        elseif (type(k) == "string") then
            toprint = toprint .. k .. "= "
        end
        if (type(v) == "number") then
            toprint = toprint .. v .. ",\n"
        elseif (type(v) == "string") then
            toprint = toprint .. "\"" .. v .. "\",\n"
        elseif (type(v) == "table") then
            toprint = toprint .. TableToString(v, indent + 2) .. ",\n"
        else
            toprint = toprint .. "\"" .. tostring(v) .. "\",\n"
        end
    end
    toprint = toprint .. string.rep(" ", indent - 2) .. "}"
    return toprint
end

---------------------------------------------------------------------------------------------------
--	Plugin Functions
---------------------------------------------------------------------------------------------------

------------------------------------------
--	Create TomTom Way Point
------------------------------------------
local function addTomTomWaypoint(button, uiMapID, coord)
    DebugPrint("Adding TomTom Waypoint")
    if TomTom then
        local x, y = HandyNotes:getXY(coord)
        TomTom:AddWaypoint(uiMapID, x, y, {
            title = tip.title,
            persistent = nil,
            minimap = true,
            world = true
        })
    end
end

------------------------------------------
--	Create Blizzard Way Point
------------------------------------------
local function addBlizzardWaypoint(button, uMapID, coord)
    DebugPrint("Adding Blizzard Waypoint")
    local x, y = HandyNotes:getXY(coord)
    local parentMapID = C_Map.GetMapInfo(uMapID)["parentMapID"]
    if (not C_Map.CanSetUserWaypointOnMap(uMapID)) then
        local wx, wy = HBD:GetWorldCoordinatesFromZone(x, y, uMapID)
        uMapID = parentMapID
        x, y = HBD:GetZoneCoordinatesFromWorld(wx, wy, parentMapID)
    end

    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(uMapID, x, y))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end

------------------------------------------
--	Close Context Menu 
------------------------------------------
local function closeAllDropdowns() CloseDropDownMenus(1) end

------------------------------------------
--	Create Context Menu
------------------------------------------
do
    DebugPrint("Creating Context Menu")
    local currentMapID, currentCoord = nil, nil
    local function generateMenu(button, level)
        if (not level) then return end

        wipe(info)
        if (level == 1) then
            ------------------------------------------
            --	Create Context Menu Title
            ------------------------------------------
            info.isTitle = 1
            info.text =
                "|cff3399ff" .. "HandyNotes Universal Explorer" .. "|r" ..
                    "|cffFFFFFF " .. ns.version .. "|r"
            info.notCheckable = 1
            UIDropDownMenu_AddButton(info, level)
            wipe(info)

            ------------------------------------------
            --	Create Blizzard Waypoint Menu item
            ------------------------------------------
            info.text = "Create Blizzard Waypoint"
            info.notCheckable = 1
            info.func = addBlizzardWaypoint
            info.arg1 = currentMapID
            info.arg2 = currentCoord
            UIDropDownMenu_AddButton(info, level)
            wipe(info)
            ------------------------------------------
            --	Create TomTom Waypoint Menu item
            ------------------------------------------
            if (C_AddOns.IsAddOnLoaded("TomTom")) then
                info.text = "Create TomTom Waypoint"
                info.notCheckable = 1
                info.func = addTomTomWaypoint
                info.arg1 = currentMapID
                info.arg2 = currentCoord
                UIDropDownMenu_AddButton(info, level)
                wipe(info)
            end

            ------------------------------------------
            --	Close Menu
            ------------------------------------------
            info.text = "Close"
            info.notCheckable = 1
            info.func = closeAllDropdowns
            info.arg1 = currentMapID
            info.arg2 = currentCoord

            UIDropDownMenu_AddButton(info, level)
            wipe(info)
        end
    end
    ------------------------------------------
    --	Initialize Context Menu
    ------------------------------------------
    local HL_Dropdown = CreateFrame("Frame", addonName .. "DropdownMenu")
    HL_Dropdown.displayMode = "MENU"
    HL_Dropdown.initialize = generateMenu
    ------------------------------------------
    --	Initialize Context Menu
    ------------------------------------------
    function HLHandler:OnClick(button, down, uiMapID, coord)
        DebugPrint("Clicking Event")
        currentMapID, currentCoord = uiMapID, coord
        if button == "RightButton" and not down then
            ToggleDropDownMenu(1, nil, HL_Dropdown, self, 0, 0)
        end
    end
end

------------------------------------------
--	Create Pin Point
------------------------------------------
do
    DebugPrint("Creating Pin Point")
    local function iter(t, prestate)
        if not t then return nil end

        local state, value = next(t, prestate)

        while state do
            if value then
                ------------------------------------------
                --	Create Icon
                ------------------------------------------
                local icon, alpha, scale
                scale = (value.scale or 1) * db.icon_scale
                alpha = (value.alpha or 1) * db.icon_alpha

                if value.achievement then
                    local playerName = UnitName("player") or nil
                    local playerNameFromAchievement = select(6,
                                                             GetAchievementCriteriaInfoByID(
                                                                 value.achievement,
                                                                 value.criteria)) or
                                                          nil

                    if (playerName ~= playerNameFromAchievement) then
                        DebugPrint("setting icon")
                        icon = ns.icon
                    end

                end
                ------------------------------------------
                --	Get next data
                ------------------------------------------
                return state, nil, icon, scale, alpha
            end
            state, value = next(t, state)
        end
        return nil, nil, nil, nil
    end

    ------------------------------------------
    --	Get Nodes
    ------------------------------------------
    function HLHandler:GetNodes2(uiMapID, minimap)
        DebugPrint("GetNodes2")
        return iter, ns.points[uiMapID], nil
    end

end

------------------------------------------
--	Create Tooltip
------------------------------------------
function HLHandler:OnEnter(uiMapID, coord)
    DebugPrint("OnEnter")
    local tooltip = GameTooltip
    if (self:GetCenter() > UIParent:GetCenter()) then -- compare X coordinate
        tooltip:SetOwner(self, "ANCHOR_LEFT")
    else
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
    end

    local value = ns.points[uiMapID][coord]
    if not value then return nil end
    if value.achievement then
        tip.x = tonumber(string.sub(coord, 1, 4)) / 100
        tip.y = tonumber(string.sub(coord, 5, 8)) / 100

        tip.criteriaid = value.criteria
        tip.criteriaidText = WrapTextInColorCode(
                                 " id: " .. value.criteria .. "",
                                 "ff" .. "FFCC00")
        tip.cirteria = select(1, GetAchievementCriteriaInfoByID(
                                  value.achievement, value.criteria))

        tip.achievementid = value.achievement
        tip.achievementidText = WrapTextInColorCode(
                                    " id: " .. value.achievement .. "",
                                    "ff" .. "FFFFFF")
        tip.achievement = select(2, GetAchievementInfo(value.achievement))

        tip.description = value.description or
                              "Revealing the covered areas of the world map."

        tip.coord = value.coord or tip.x .. "," .. tip.y

        tip.note = value.note
        tip.source = value.source or "Wowhead"
        tip.thanks = value.thanks or "Tykes"
    end

    ------------------------------------------------------------------------------------
    if tip.criteriaid then
        if (value.criteria == 0) then tip.cirteria = value.criteriaName end

        if tip.coord then
            tooltip:AddDoubleLine(tip.cirteria, tip.coord, 0.2, 0.6, 1, 1, 1, 1)
        else
            tooltip:AddLine(tip.cirteria, 0.2, 0.6, 1, true)
        end

        tooltip:AddLine(horizontal_line)

        if tip.achievement then
            tooltip:AddLine(tip.achievement, 0.2, 0.6, 1)
        end

        if tip.description then
            tooltip:AddLine(" ")
            tooltip:AddLine(tip.description .. " ", 1, 1, 1, true)
        end

        tooltip:AddLine(" ")
        tooltip:AddLine("Right click to open menu")

        tooltip:AddLine(horizontal_line)
        tooltip:AddDoubleLine("|cffFFFFFFAchievement id:|r " ..
                                  tip.achievementid, (value.criteria == 0) and
                                  "" or "|cffFFFFFFCriteria id:|r " ..
                                  tip.criteriaid)
        tooltip:AddLine(" ")
        if tip.source then
            tooltip:AddDoubleLine("Source:", tip.source, 1, 1, 1, 0.2, 0.6, 1)
        end
        if tip.thanks then
            tooltip:AddDoubleLine("Thanks to:", tip.thanks, 1, 1, 1)
        end
    end
    tooltip:Show()
end

function HLHandler:OnLeave(uiMapID, coord)
    DebugPrint("OnLeave")
    GameTooltip:Hide() -- This will hide the tooltip when the mouse leaves the node
end

---------------------------------------------------------------------------------------------------
--	Plugin initialization, enabling and disabling
---------------------------------------------------------------------------------------------------
function HL:OnInitialize()
    DebugPrint("OnInitialize")
    -- Set up our database
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults)
    db = self.db.profile
    ns.hidden = self.db.char.hidden
    -- Initialize our database with HandyNotes
    HandyNotes:RegisterPluginDB("UniversalExplorer", HLHandler, options)

    self:RegisterEvent("ZONE_CHANGED", "Refresh")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Refresh")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "Refresh")
    self:RegisterEvent("CRITERIA_UPDATE", "Refresh")
    self:RegisterEvent("CRITERIA_EARNED", "Refresh")
    self:RegisterEvent("CRITERIA_COMPLETE", "Refresh")
    self:RegisterEvent("ACHIEVEMENT_EARNED", "Refresh")

end

function HL:Refresh()
    DebugPrint("Refresh")
    self:SendMessage("HandyNotes_NotifyUpdate",
                     addonName:gsub("HandyNotes_", ""))
end
