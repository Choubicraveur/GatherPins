-- GatherPins.lua
local ICON_SIZE = 12
local ADDON_NAME = ...

-- Tables
local mapIcons = {}

-- Valeurs par défaut
local defaultFilter = { currentFilterIndex = 1, progressMode = "Global" }

-- Variables runtime
local filterOptions = {"All", "Found", "NotFound", "None"}
local currentFilterIndex = 1
local currentFilter = "All"
local progressMode = "Global"

-- Sauvegarde du mode zone précédent
local lastZoneProgressMode = nil

--------------------------------------------------
-- FONCTIONS SAUVEGARDE
--------------------------------------------------
local function GetSavedState(zone, id)
    GatherPinsDB[zone] = GatherPinsDB[zone] or {}
    return GatherPinsDB[zone][id] or false
end

local function SetSavedState(zone, id, value)
    GatherPinsDB[zone] = GatherPinsDB[zone] or {}
    GatherPinsDB[zone][id] = value
end

--------------------------------------------------
-- CHARGEMENT ADDON
--------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end

    GatherPinsDB = GatherPinsDB or {}
    GatherPinsFilterDB = GatherPinsFilterDB or CopyTable(defaultFilter)

    currentFilterIndex = GatherPinsFilterDB.currentFilterIndex or 1
    currentFilter = filterOptions[currentFilterIndex]
    progressMode = GatherPinsFilterDB.progressMode or "Global"

    CreateAllMapIcons()
    CreateUI()
    UpdateWorldMapIcons()

    self:UnregisterEvent("ADDON_LOADED")
end)

--------------------------------------------------
-- CREATION ICONES
--------------------------------------------------
function CreateAllMapIcons()
    for zoneName, points in pairs(points_by_zone) do
        mapIcons[zoneName] = {}
        for i, point in ipairs(points) do
            local frame = CreateFrame("Button", nil, WorldMapButton)
            frame:SetSize(ICON_SIZE, ICON_SIZE)
            frame:SetFrameLevel(100)
            frame.pointData = point
            frame.zoneName = zoneName

            local found = GetSavedState(zoneName, point.id)

            local tex = frame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(frame)
            tex:SetTexture(found and "Interface\\Icons\\INV_Crate_07" or "Interface\\Icons\\INV_Misc_Map_01")
            frame.texture = tex

            frame:SetScript("OnClick", function(self)
                local newState = not GetSavedState(self.zoneName, self.pointData.id)
                for zone, pts in pairs(points_by_zone) do
                    for _, pt in ipairs(pts) do
                        if pt.id == self.pointData.id then
                            SetSavedState(zone, pt.id, newState)
                            if pt.frame and pt.frame:IsShown() then
                                pt.frame.texture:SetTexture(newState and "Interface\\Icons\\INV_Crate_07" or "Interface\\Icons\\INV_Misc_Map_01")
                            end
                        end
                    end
                end
                UpdateProgressBar()
            end)

            frame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(self.pointData.name, 1,1,1)
                if self.pointData.comment and self.pointData.comment ~= "" then
                    GameTooltip:AddLine(self.pointData.comment, 0.8,0.8,0.8,true)
                end
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

            frame:Hide()
            mapIcons[zoneName][i] = frame
            point.frame = frame
        end
    end
end

--------------------------------------------------
-- MISE A JOUR DE LA MAP
--------------------------------------------------
function UpdateWorldMapIcons()
    local mapName = GetMapInfo()
    if not mapName then return end

    local width = WorldMapDetailFrame:GetWidth()
    local height = WorldMapDetailFrame:GetHeight()

    for _, frames in pairs(mapIcons) do
        for _, f in ipairs(frames) do f:Hide() end
    end

    local activePoints = mapIcons[mapName]
    if activePoints then
        for _, frame in ipairs(activePoints) do
            local point = frame.pointData
            local found = GetSavedState(mapName, point.id)

            local show = true
            if currentFilter == "Found" then show = found
            elseif currentFilter == "NotFound" then show = not found
            elseif currentFilter == "None" then show = false end

            if show then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT",
                    point.x / 100 * width - ICON_SIZE/2,
                    -point.y / 100 * height + ICON_SIZE/2)
                frame.texture:SetTexture(found and "Interface\\Icons\\INV_Crate_07" or "Interface\\Icons\\INV_Misc_Map_01")
                frame:Show()
            end
        end
    end

    UpdateProgressBar()
end

--------------------------------------------------
-- UI : BARRE + FILTRE
--------------------------------------------------
function CreateUI()
    -- Barre de progression
    progressBar = CreateFrame("StatusBar", "GatherPinsProgressBar", WorldMapFrame, "BackdropTemplate")
    progressBar:SetSize(150, 16)
    progressBar:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -10, -60)
    progressBar:SetFrameStrata("HIGH")

    -- Bordure + fond
    progressBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    progressBar:SetBackdropBorderColor(1, 1, 1, 0.9)
    progressBar:SetBackdropColor(0.15, 0.15, 0.15, 0.9)

    -- Texture interne
    local barTexture = progressBar:CreateTexture(nil, "BORDER")
    barTexture:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 2, -2)
    barTexture:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", -2, 2)
    barTexture:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    progressBar:SetStatusBarTexture(barTexture)
    progressBar:SetStatusBarColor(0.1, 0.9, 0.1, 0.9)

    -- Texte centré
    progressText = progressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressText:SetPoint("CENTER", progressBar, "CENTER")
    progressText:SetTextColor(1, 1, 1, 1)

    -- Cliquable
    progressBar:EnableMouse(true)
    progressBar:SetScript("OnMouseDown", function()
        progressMode = (progressMode == "Global") and "Zone" or "Global"
        GatherPinsFilterDB.progressMode = progressMode
        UpdateProgressBar()
    end)

    -- Bouton filtre
    filterButton = CreateFrame("Button", "GatherPinsFilterButton", WorldMapFrame, "UIPanelButtonTemplate")
    filterButton:SetSize(100,22)
    filterButton:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -10,-30)
    filterButton:SetText("Filter: "..currentFilter)
    filterButton:SetScript("OnClick", function(self)
        currentFilterIndex = currentFilterIndex + 1
        if currentFilterIndex > #filterOptions then currentFilterIndex = 1 end
        currentFilter = filterOptions[currentFilterIndex]
        GatherPinsFilterDB.currentFilterIndex = currentFilterIndex
        self:SetText("Filter: "..currentFilter)
        UpdateWorldMapIcons()
    end)

    -- Hooks carte
    WorldMapFrame:HookScript("OnShow", UpdateWorldMapIcons)
    WorldMapFrame:HookScript("OnSizeChanged", UpdateWorldMapIcons)
    local mapUpdater = CreateFrame("Frame")
    mapUpdater:RegisterEvent("WORLD_MAP_UPDATE")
    mapUpdater:SetScript("OnEvent", UpdateWorldMapIcons)
end

--------------------------------------------------
-- BARRE DE PROGRESSION
--------------------------------------------------
function UpdateProgressBar()
    if not progressBar then return end

    local mapName = GetMapInfo()
    local uniqueIDs, collectedIDs = {}, {}

    for _, points in pairs(points_by_zone) do
        for _, point in ipairs(points) do uniqueIDs[point.id] = true end
    end
    for zone, points in pairs(points_by_zone) do
        for _, point in ipairs(points) do
            if GetSavedState(zone, point.id) then collectedIDs[point.id] = true end
        end
    end

    local total, collected = 0, 0
    local zoneHasData = mapName and points_by_zone[mapName] and #points_by_zone[mapName] > 0

    -- Gestion du mode forcé si la zone est vide
    if progressMode == "Zone" and not zoneHasData then
        if not lastZoneProgressMode then
            lastZoneProgressMode = "Zone"
        end
        progressMode = "Global"
    elseif progressMode == "Global" and lastZoneProgressMode and zoneHasData then
        progressMode = lastZoneProgressMode
        lastZoneProgressMode = nil
    end

    -- Calcul du progrès
    if progressMode == "Global" then
        for _ in pairs(uniqueIDs) do total = total + 1 end
        for _ in pairs(collectedIDs) do collected = collected + 1 end
    elseif progressMode == "Zone" and zoneHasData then
        local zoneUnique, zoneCollected = {}, {}
        for _, point in ipairs(points_by_zone[mapName]) do
            zoneUnique[point.id] = true
            if GetSavedState(mapName, point.id) then zoneCollected[point.id] = true end
        end
        for _ in pairs(zoneUnique) do total = total + 1 end
        for _ in pairs(zoneCollected) do collected = collected + 1 end
    end

    -- Mise à jour barre
    progressBar:SetMinMaxValues(0, total > 0 and total or 1)
    progressBar:SetValue(collected)
    if not zoneHasData and progressMode == "Global" then
        progressText:SetText(collected.." / "..total.." ("..progressMode..")")
    else
        progressText:SetText(collected.." / "..total.." ("..progressMode..")")
    end
end
