local ADDON_NAME = "BetterWotLKBiS"
local DATA = BetterWotLKBiS_Data

local addon = CreateFrame("Frame", "BetterWotLKBiSCore")
BetterWotLKBiS = addon

local MAX_COLUMNS = DATA and DATA.maxColumns or 6
local ROW_HEIGHT = 48
local SLOT_LABEL_WIDTH = 92
local ITEM_SIZE = 40
local ITEM_GAP = 8
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local MINIMAP_BUTTON_RADIUS = 80
local MINIMAP_BUTTON_DRAG_THRESHOLD = 16

local DEFAULTS = {
    alertChannels = {
        say = true,
        whisper = true,
        guild = true,
        party = true,
        raid = true,
        channel = true,
    },
    popWindow = true,
    minimap = {
        show = true,
        angle = 220,
    },
    selectedClass = "Paladin",
    selectedSpec = "Holy",
    selectedPhase = "P4",
}

local CHAT_EVENT_TO_KEY = {
    CHAT_MSG_SAY = "say",
    CHAT_MSG_WHISPER = "whisper",
    CHAT_MSG_GUILD = "guild",
    CHAT_MSG_PARTY = "party",
    CHAT_MSG_PARTY_LEADER = "party",
    CHAT_MSG_RAID = "raid",
    CHAT_MSG_RAID_LEADER = "raid",
    CHAT_MSG_RAID_WARNING = "raid",
    CHAT_MSG_CHANNEL = "channel",
}

local CLASSLOOT_SPEC_KEYS = {
    DeathKnight = {
        Blood = { "DeathknightTank" },
        Frost = { "DeathknightDPS" },
        Unholy = { "DeathknightDPS" },
    },
    Druid = {
        Balance = { "DruidBalance" },
        FeralDPS = { "DruidFeral" },
        FeralTank = { "DruidFeral" },
        Restoration = { "DruidResto", "DruidHealing" },
    },
    Hunter = {
        BeastMastery = { "Hunter" },
        Marksmanship = { "Hunter" },
        Survival = { "Hunter" },
    },
    Mage = {
        Arcane = { "Mage" },
        Fire = { "Mage" },
        Frost = { "Mage" },
    },
    Paladin = {
        Holy = { "PaladinHoly", "PaladinHealing" },
        Protection = { "PaladinProt" },
        Retribution = { "PaladinRet", "PaladinDPS" },
    },
    Priest = {
        Discipline = { "PriestHeal", "Priest" },
        Holy = { "PriestHeal", "Priest" },
        Shadow = { "PriestDPS", "Priest" },
    },
    Rogue = {
        Assassination = { "Rogue" },
        Combat = { "Rogue" },
        Subtlety = { "Rogue" },
    },
    Shaman = {
        Elemental = { "ShamanElemental", "ShamanDPS" },
        Enhancement = { "ShamanEnhance", "ShamanDPS" },
        Restoration = { "ShamanResto", "ShamanHealing" },
    },
    Warlock = {
        Affliction = { "Warlock" },
        Demonology = { "Warlock" },
        Destruction = { "Warlock" },
    },
    Warrior = {
        Arms = { "WarriorDPS" },
        Fury = { "WarriorDPS" },
        Protection = { "WarriorProt", "WarriorTanking" },
    },
}

local EQUIP_LOC_TO_SLOT = {
    INVTYPE_HEAD = "Head",
    INVTYPE_NECK = "Neck",
    INVTYPE_SHOULDER = "Shoulder",
    INVTYPE_CLOAK = "Back",
    INVTYPE_CHEST = "Chest",
    INVTYPE_ROBE = "Chest",
    INVTYPE_WRIST = "Wrist",
    INVTYPE_HAND = "Hands",
    INVTYPE_WAIST = "Waist",
    INVTYPE_LEGS = "Legs",
    INVTYPE_FEET = "Feet",
    INVTYPE_FINGER = "Finger",
    INVTYPE_TRINKET = "Trinket",
    INVTYPE_WEAPON = "Weapon",
    INVTYPE_WEAPONMAINHAND = "Weapon",
    INVTYPE_2HWEAPON = "Two-hand",
    INVTYPE_WEAPONOFFHAND = "Off hand",
    INVTYPE_SHIELD = "Off hand",
    INVTYPE_HOLDABLE = "Off hand",
    INVTYPE_THROWN = "Ranged",
    INVTYPE_RELIC = "Relic",
    INVTYPE_RANGED = "Ranged",
    INVTYPE_RANGEDRIGHT = "Wand",
}

local SLOT_TO_INVENTORY = {
    Head = { 1 },
    Neck = { 2 },
    Shoulder = { 3 },
    Back = { 15 },
    Chest = { 5 },
    Wrist = { 9 },
    Hands = { 10 },
    Waist = { 6 },
    Legs = { 7 },
    Feet = { 8 },
    Finger = { 11, 12 },
    Trinket = { 13, 14 },
    Weapon = { 16 },
    ["Two-hand"] = { 16 },
    ["Off hand"] = { 17 },
    Ranged = { 18 },
    Relic = { 18 },
    Wand = { 18 },
}

local CHANNEL_LABELS = {
    { key = "say", label = "Say" },
    { key = "whisper", label = "Whisper" },
    { key = "guild", label = "Guild" },
    { key = "party", label = "Party" },
    { key = "raid", label = "Raid" },
    { key = "channel", label = "Custom/global channels" },
}

local scannerTooltip = CreateFrame("GameTooltip", "BetterWotLKBiSScannerTooltip", nil, "GameTooltipTemplate")
scannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function GetItemIDFromLink(link)
    if not link then
        return nil
    end
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if itemID then
        return itemID
    end
    return tonumber(string.match(link, "item=(%d+)"))
end

local function QueryItem(itemID)
    if itemID then
        scannerTooltip:SetHyperlink("item:" .. itemID)
    end
end

local function GetItemBasics(item)
    local name, link, quality, _, _, _, _, _, equipLoc, texture = GetItemInfo(item)
    if not name then
        local itemID = type(item) == "number" and item or GetItemIDFromLink(item)
        QueryItem(itemID)
        name, link, quality, _, _, _, _, _, equipLoc, texture = GetItemInfo(item)
    end
    return name, link, quality, equipLoc, texture
end

local function GetInventoryID(slotID)
    if GetInventoryItemID then
        return GetInventoryItemID("player", slotID)
    end
    return GetItemIDFromLink(GetInventoryItemLink("player", slotID))
end

local function GetClassLootAddon()
    if not LibStub then
        return nil
    end

    local aceAddon = LibStub("AceAddon-3.0", true)
    if not aceAddon then
        return nil
    end

    return aceAddon:GetAddon("ClassLoot", true)
end

local function IsTwoHandItem(item)
    local _, _, _, equipLoc = GetItemBasics(item)
    return equipLoc == "INVTYPE_2HWEAPON"
end

local function IsOffHandBlockedByTwoHand()
    local mainHandID = GetInventoryID(16)
    return mainHandID and IsTwoHandItem(mainHandID)
end

local function GetPhaseLabel(phaseKey)
    if not addon.phaseByKey or not addon.phaseByKey[phaseKey] then
        return phaseKey or ""
    end
    return addon.phaseByKey[phaseKey].label
end

local function GetComparisonScore(meta)
    return meta and (meta.globalScore or meta.score)
end

local function GetAtan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end

    return 0
end

local function GetMinimapCoordinates(angle)
    local radians = math.rad(angle or DEFAULTS.minimap.angle)
    return math.cos(radians) * MINIMAP_BUTTON_RADIUS, math.sin(radians) * MINIMAP_BUTTON_RADIUS
end

local function SetFrameBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    frame:SetBackdropColor(0.03, 0.025, 0.02, alpha or 0.94)
    frame:SetBackdropBorderColor(0.68, 0.47, 0.15, 1)
end

function addon:BuildLookups()
    self.phaseByKey = {}
    self.classByKey = {}
    self.specByClass = {}

    for index, phase in ipairs(DATA.phases) do
        phase.index = index
        self.phaseByKey[phase.key] = phase
    end

    for classIndex, classData in ipairs(DATA.classes) do
        classData.index = classIndex
        self.classByKey[classData.key] = classData
        self.specByClass[classData.key] = {}

        for specIndex, specData in ipairs(classData.specs) do
            specData.index = specIndex
            self.specByClass[classData.key][specData.key] = specData
        end
    end
end

function addon:BuildIndex()
    self.itemIndex = {}
    self.phaseItemIndex = {}

    for classKey, specs in pairs(DATA.lists) do
        self.itemIndex[classKey] = {}
        self.phaseItemIndex[classKey] = {}

        for specKey, phases in pairs(specs) do
            self.itemIndex[classKey][specKey] = {}
            self.phaseItemIndex[classKey][specKey] = {}

            for phaseIndex, phase in ipairs(DATA.phases) do
                local slots = phases[phase.key]
                if slots then
                    self.phaseItemIndex[classKey][specKey][phase.key] = self.phaseItemIndex[classKey][specKey][phase.key] or {}

                    for slotName, rows in pairs(slots) do
                        self.itemIndex[classKey][specKey][slotName] = self.itemIndex[classKey][specKey][slotName] or {}
                        self.phaseItemIndex[classKey][specKey][phase.key][slotName] = self.phaseItemIndex[classKey][specKey][phase.key][slotName] or {}

                        for rankIndex, row in ipairs(rows) do
                            local score = 1000 - rankIndex
                            local globalScore = phaseIndex * 1000 + score
                            for _, itemID in ipairs(row.ids) do
                                local meta = {
                                    score = score,
                                    globalScore = globalScore,
                                    phaseIndex = phaseIndex,
                                    phaseKey = phase.key,
                                    phaseLabel = phase.label,
                                    rankIndex = rankIndex,
                                    rankLabel = row.label,
                                    slotName = slotName,
                                    row = row,
                                }

                                local phaseCurrent = self.phaseItemIndex[classKey][specKey][phase.key][slotName][itemID]
                                if not phaseCurrent or score > phaseCurrent.score then
                                    self.phaseItemIndex[classKey][specKey][phase.key][slotName][itemID] = meta
                                end

                                local current = self.itemIndex[classKey][specKey][slotName][itemID]
                                if not current or globalScore > current.globalScore then
                                    self.itemIndex[classKey][specKey][slotName][itemID] = meta
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function addon:HasList(classKey, specKey)
    return DATA.lists[classKey] and DATA.lists[classKey][specKey]
end

function addon:GetFirstClass()
    return DATA.classes[1]
end

function addon:GetFirstSpec(classKey)
    local classData = self.classByKey[classKey] or self:GetFirstClass()
    return classData.specs[1]
end

function addon:GetPlayerClassKey()
    local _, classToken = UnitClass("player")
    if not classToken then
        return nil
    end

    for _, classData in ipairs(DATA.classes) do
        if classData.token == classToken then
            return classData.key
        end
    end

    return nil
end

function addon:GetDetectedSpecKey(classKey)
    local classData = self.classByKey[classKey]
    if not classData then
        return nil
    end

    local bestTab, bestPoints = nil, -1
    if GetNumTalentTabs and GetTalentTabInfo then
        for tabIndex = 1, GetNumTalentTabs() do
            local _, _, pointsSpent = GetTalentTabInfo(tabIndex)
            pointsSpent = tonumber(pointsSpent) or 0
            if pointsSpent > bestPoints then
                bestPoints = pointsSpent
                bestTab = tabIndex
            end
        end
    end

    local selectedSpec = self.db
        and self.db.selectedClass == classKey
        and self.specByClass[classKey]
        and self.specByClass[classKey][self.db.selectedSpec]
    if selectedSpec and selectedSpec.talentTab == bestTab then
        return selectedSpec.key
    end

    for _, specData in ipairs(classData.specs) do
        if specData.talentTab == bestTab then
            return specData.key
        end
    end

    return classData.specs[1].key
end

function addon:GetComparisonClassSpec()
    local classKey = self:GetPlayerClassKey()
    if not classKey then
        return nil, nil
    end

    local specKey = self:GetDetectedSpecKey(classKey)
    if self:HasList(classKey, specKey) then
        return classKey, specKey
    end

    return nil, nil
end

function addon:GetComparisonPhaseKey()
    if self.db and self.phaseByKey and self.phaseByKey[self.db.selectedPhase] then
        return self.db.selectedPhase
    end

    return DATA.phases[#DATA.phases].key
end

function addon:GetClassLootRating(classKey, specKey, itemID)
    local classLoot = GetClassLootAddon()
    local itemInfo = classLoot and classLoot.CD and classLoot.CD[itemID]
    if not itemInfo then
        return nil
    end

    local specKeys = CLASSLOOT_SPEC_KEYS[classKey] and CLASSLOOT_SPEC_KEYS[classKey][specKey]
    if not specKeys then
        return nil
    end

    local bestRating = 0
    for _, classLootKey in ipairs(specKeys) do
        local rating = tonumber(itemInfo[classLootKey])
        if rating and rating > bestRating then
            bestRating = rating
        end
    end

    return bestRating
end

function addon:NormalizeSelection()
    if not self.classByKey[self.db.selectedClass] then
        self.db.selectedClass = self:GetFirstClass().key
    end

    if not self.specByClass[self.db.selectedClass][self.db.selectedSpec] then
        self.db.selectedSpec = self:GetFirstSpec(self.db.selectedClass).key
    end

    if not self.phaseByKey[self.db.selectedPhase] then
        self.db.selectedPhase = DATA.phases[#DATA.phases].key
    end
end

function addon:SelectPlayerList()
    local classKey = self:GetPlayerClassKey()
    if not classKey then
        self:NormalizeSelection()
        return
    end

    self.db.selectedClass = classKey
    self.db.selectedSpec = self:GetDetectedSpecKey(classKey) or self:GetFirstSpec(classKey).key
    self:NormalizeSelection()
end

function addon:GetItemMeta(classKey, specKey, slotName, itemID, phaseKey)
    local rootIndex = phaseKey and self.phaseItemIndex or self.itemIndex
    local classIndex = rootIndex and rootIndex[classKey]
    local specIndex = classIndex and classIndex[specKey]
    if phaseKey then
        specIndex = specIndex and specIndex[phaseKey]
    end
    local slotIndex = specIndex and specIndex[slotName]
    return slotIndex and slotIndex[itemID]
end

function addon:FindKnownSlot(classKey, specKey, itemID, phaseKey)
    local rootIndex = phaseKey and self.phaseItemIndex or self.itemIndex
    local classIndex = rootIndex and rootIndex[classKey]
    local specIndex = classIndex and classIndex[specKey]
    if phaseKey then
        specIndex = specIndex and specIndex[phaseKey]
    end
    local bestSlot, bestMeta = nil, nil
    local bestScore = nil

    if not specIndex then
        return nil, nil
    end

    for slotName, slotIndex in pairs(specIndex) do
        local meta = slotIndex[itemID]
        local score = meta and (phaseKey and meta.score or meta.globalScore or meta.score)
        if meta and (not bestScore or score > bestScore) then
            bestSlot = slotName
            bestMeta = meta
            bestScore = score
        end
    end

    return bestSlot, bestMeta
end

function addon:GetSlotForItem(classKey, specKey, itemID, itemLink, phaseKey)
    local _, _, _, equipLoc = GetItemBasics(itemLink or itemID)
    local slotName = equipLoc and EQUIP_LOC_TO_SLOT[equipLoc]

    if slotName and self:GetItemMeta(classKey, specKey, slotName, itemID, phaseKey) then
        return slotName
    end

    local knownSlot = self:FindKnownSlot(classKey, specKey, itemID, phaseKey)
    return knownSlot or slotName
end

function addon:IsAnyEquipped(itemIDs)
    for _, itemID in ipairs(itemIDs) do
        for slotID = 1, 18 do
            if GetInventoryID(slotID) == itemID then
                return true
            end
        end
    end

    return false
end

function addon:GetUpgradeInfo(itemID, itemLink)
    local classKey, specKey = self:GetComparisonClassSpec()
    if not classKey or not specKey then
        return nil
    end

    local phaseKey = self:GetComparisonPhaseKey()
    local linkedClassLootRating = self:GetClassLootRating(classKey, specKey, itemID)
    if linkedClassLootRating == 0 then
        return nil
    end

    local slotName = self:GetSlotForItem(classKey, specKey, itemID, itemLink, phaseKey)
    if not slotName then
        return nil
    end

    local linkedMeta = self:GetItemMeta(classKey, specKey, slotName, itemID, phaseKey)
    if not linkedMeta then
        local knownSlot, knownMeta = self:FindKnownSlot(classKey, specKey, itemID, phaseKey)
        slotName = knownSlot
        linkedMeta = knownMeta
    end

    if not slotName or not linkedMeta then
        return nil
    end

    local inventorySlots = SLOT_TO_INVENTORY[slotName]
    if not inventorySlots then
        return nil
    end

    local hasSameItem = false
    local emptySlot = false
    local worstScore = 1000000
    local worstID, worstMeta = nil, nil
    local offHandBlockedByTwoHand = slotName == "Off hand" and IsOffHandBlockedByTwoHand()
    local linkedScore = GetComparisonScore(linkedMeta)

    for _, inventorySlot in ipairs(inventorySlots) do
        local equippedID = GetInventoryID(inventorySlot)
        if not equippedID then
            if not (inventorySlot == 17 and offHandBlockedByTwoHand) then
                emptySlot = true
            end
        elseif equippedID == itemID then
            hasSameItem = true
        else
            -- Equipped items are compared by their best known all-phase ranking so later-phase gear
            -- suppresses older-phase links even when the selected alert phase is earlier.
            local equippedMeta = self:GetItemMeta(classKey, specKey, slotName, equippedID)
            if equippedMeta then
                local equippedScore = GetComparisonScore(equippedMeta)
                if equippedScore < worstScore then
                    worstScore = equippedScore
                    worstID = equippedID
                    worstMeta = equippedMeta
                end
            end
        end
    end

    if hasSameItem then
        return nil
    end

    if emptySlot or (worstID and linkedScore and linkedScore > worstScore) then
        return {
            classKey = classKey,
            specKey = specKey,
            phaseKey = phaseKey,
            slotName = slotName,
            linkedMeta = linkedMeta,
            currentItemID = worstID,
            currentMeta = worstMeta,
            linkedClassLootRating = linkedClassLootRating,
        }
    end

    return nil
end

function addon:FireAlert(itemID, itemLink, upgradeInfo)
    local itemName, resolvedLink = GetItemBasics(itemLink or itemID)
    local displayName = itemName or ("item:" .. itemID)
    local message = "BetterWotLKBiS upgrade: " .. displayName .. " (" .. upgradeInfo.slotName .. ")"

    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(message, 1, 0.82, 0)
    end

    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo.RAID_WARNING)
    end

    if PlaySoundFile then
        PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
    elseif PlaySound then
        PlaySound("RaidWarning")
    end

    if self.db.popWindow then
        self:ShowAlertWindow(itemID, resolvedLink or itemLink, upgradeInfo)
    end
end

function addon:IsChatEventEnabled(event)
    local key = CHAT_EVENT_TO_KEY[event]
    return key and self.db.alertChannels[key]
end

function addon:OnChatEvent(event, message)
    if not self:IsChatEventEnabled(event) or not message then
        return
    end

    local seen = {}

    local function inspectLink(link)
        local itemID = GetItemIDFromLink(link)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            local upgradeInfo = self:GetUpgradeInfo(itemID, link)
            if upgradeInfo then
                self:FireAlert(itemID, link, upgradeInfo)
            end
        end
    end

    for link in string.gmatch(message, "(|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h%[[^%]]+%]|h|r)") do
        inspectLink(link)
    end

    for link in string.gmatch(message, "(|Hitem:[^|]+|h%[[^%]]+%]|h)") do
        inspectLink(link)
    end
end

function addon:OpenItem(itemID, itemLink)
    local _, resolvedLink = GetItemBasics(itemLink or itemID)
    local link = resolvedLink or itemLink or ("item:" .. itemID)

    if IsModifiedClick() and HandleModifiedItemClick and HandleModifiedItemClick(link) then
        return
    end

    if SetItemRef then
        SetItemRef(link, link, "LeftButton")
    end
end

function addon:ShowItemTooltip(button)
    if not button.itemID then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(button.itemLink or ("item:" .. button.itemID))

    if button.rowData then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("BetterWotLKBiS", button.slotName or "", 1, 0.82, 0, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine(button.phaseLabel or "", button.rowData.label or "", 0.8, 0.8, 0.8, 1, 1, 1)

        if button.rowData.ids and #button.rowData.ids > 1 then
            GameTooltip:AddLine("Equivalent items:", 0.7, 0.7, 0.7)
            for _, itemID in ipairs(button.rowData.ids) do
                local name, link = GetItemBasics(itemID)
                GameTooltip:AddLine(link or name or ("item:" .. itemID), 1, 1, 1)
            end
        end
    end

    GameTooltip:Show()
end

function addon:CreateItemButton(parent, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(ITEM_SIZE)
    button:SetHeight(ITEM_SIZE)
    button:SetPoint("LEFT", parent, "LEFT", SLOT_LABEL_WIDTH + (index - 1) * (ITEM_SIZE + ITEM_GAP), 0)

    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetAllPoints(button)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.border:SetBlendMode("ADD")
    button.border:SetWidth(62)
    button.border:SetHeight(62)
    button.border:SetPoint("CENTER", button, "CENTER", 0, 0)

    button.rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.rank:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.rank:SetTextColor(1, 0.82, 0)

    button.check = button:CreateTexture(nil, "OVERLAY")
    button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button.check:SetWidth(22)
    button.check:SetHeight(22)
    button.check:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, 6)

    button:SetScript("OnEnter", function(self) addon:ShowItemTooltip(self) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self) addon:OpenItem(self.itemID, self.itemLink) end)

    return button
end

function addon:CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(450)
    row:SetHeight(ROW_HEIGHT)

    row.slotText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.slotText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.slotText:SetWidth(SLOT_LABEL_WIDTH - 8)
    row.slotText:SetJustifyH("LEFT")

    row.items = {}
    for itemIndex = 1, MAX_COLUMNS do
        row.items[itemIndex] = self:CreateItemButton(row, itemIndex)
    end

    return row
end

function addon:ConfigureItemButton(button, rowData, displayIndex, slotName, phaseLabel)
    if not rowData then
        button:Hide()
        return
    end

    local itemID = rowData.ids[1]
    local name, link, quality, _, texture = GetItemBasics(itemID)
    local r, g, b = 0.55, 0.55, 0.55

    if quality and GetItemQualityColor then
        r, g, b = GetItemQualityColor(quality)
    end

    button.itemID = itemID
    button.itemLink = link
    button.rowData = rowData
    button.slotName = slotName
    button.phaseLabel = phaseLabel
    button.icon:SetTexture(texture or QUESTION_MARK)
    button.border:SetVertexColor(r, g, b, 0.85)
    button.rank:SetText(displayIndex)
    if self:IsAnyEquipped(rowData.ids) then
        button.check:Show()
    else
        button.check:Hide()
    end
    button:SetScript("OnUpdate", nil)

    if not name then
        QueryItem(itemID)
    end

    button:Show()
end

function addon:RefreshDropdowns()
    local frame = self.mainFrame
    if not frame then
        return
    end

    local classData = self.classByKey[self.db.selectedClass] or self:GetFirstClass()
    local specData = self.specByClass[classData.key][self.db.selectedSpec] or self:GetFirstSpec(classData.key)
    local phaseData = self.phaseByKey[self.db.selectedPhase] or DATA.phases[#DATA.phases]

    UIDropDownMenu_SetSelectedValue(frame.classDropDown, classData.key)
    UIDropDownMenu_SetText(frame.classDropDown, classData.label)
    UIDropDownMenu_SetSelectedValue(frame.specDropDown, specData.key)
    UIDropDownMenu_SetText(frame.specDropDown, specData.label)
    UIDropDownMenu_SetSelectedValue(frame.phaseDropDown, phaseData.key)
    UIDropDownMenu_SetText(frame.phaseDropDown, phaseData.short)
end

function addon:RefreshMainFrame()
    local frame = self.mainFrame
    if not frame then
        return
    end

    self:NormalizeSelection()
    self:RefreshDropdowns()

    local list = DATA.lists[self.db.selectedClass][self.db.selectedSpec][self.db.selectedPhase]
    local phaseLabel = GetPhaseLabel(self.db.selectedPhase)
    local rowIndex = 0

    self.rowFrames = self.rowFrames or {}

    for _, row in ipairs(self.rowFrames) do
        row:Hide()
    end

    for _, slotName in ipairs(DATA.slotOrder) do
        local rows = list[slotName]
        if rows then
            rowIndex = rowIndex + 1
            local row = self.rowFrames[rowIndex]
            if not row then
                row = self:CreateRow(frame.content, rowIndex)
                self.rowFrames[rowIndex] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -((rowIndex - 1) * ROW_HEIGHT))
            row.slotText:SetText(slotName)

            for itemIndex = 1, MAX_COLUMNS do
                self:ConfigureItemButton(row.items[itemIndex], rows[itemIndex], itemIndex, slotName, phaseLabel)
            end

            row:Show()
        end
    end

    frame.content:SetHeight(math.max(1, rowIndex * ROW_HEIGHT + 8))

    local source = DATA.sources[self.db.selectedClass]
        and DATA.sources[self.db.selectedClass][self.db.selectedSpec]
        and DATA.sources[self.db.selectedClass][self.db.selectedSpec][self.db.selectedPhase]
    frame.sourceText:SetText(source or "")
end

function addon:InitializeClassDropDown()
    local info
    for _, classData in ipairs(DATA.classes) do
        info = UIDropDownMenu_CreateInfo()
        info.text = classData.label
        info.value = classData.key
        info.checked = self.db.selectedClass == classData.key
        info.func = function(button)
            addon.db.selectedClass = button.value
            addon.db.selectedSpec = addon:GetFirstSpec(button.value).key
            addon:RefreshMainFrame()
        end
        UIDropDownMenu_AddButton(info)
    end
end

function addon:InitializeSpecDropDown()
    local classData = self.classByKey[self.db.selectedClass] or self:GetFirstClass()
    local info

    for _, specData in ipairs(classData.specs) do
        info = UIDropDownMenu_CreateInfo()
        info.text = specData.label
        info.value = specData.key
        info.checked = self.db.selectedSpec == specData.key
        info.func = function(button)
            addon.db.selectedSpec = button.value
            addon:RefreshMainFrame()
        end
        UIDropDownMenu_AddButton(info)
    end
end

function addon:InitializePhaseDropDown()
    local info
    for _, phaseData in ipairs(DATA.phases) do
        info = UIDropDownMenu_CreateInfo()
        info.text = phaseData.label
        info.value = phaseData.key
        info.checked = self.db.selectedPhase == phaseData.key
        info.func = function(button)
            addon.db.selectedPhase = button.value
            addon:RefreshMainFrame()
        end
        UIDropDownMenu_AddButton(info)
    end
end

function addon:CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(18)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    header:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    local slot = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    slot:SetPoint("LEFT", header, "LEFT", 0, 0)
    slot:SetTextColor(0.72, 0.72, 0.72)
    slot:SetText("Slot")

    for index = 1, MAX_COLUMNS do
        local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        text:SetPoint("LEFT", header, "LEFT", SLOT_LABEL_WIDTH + (index - 1) * (ITEM_SIZE + ITEM_GAP), 0)
        text:SetWidth(ITEM_SIZE)
        text:SetJustifyH("CENTER")
        text:SetTextColor(0.72, 0.72, 0.72)
        text:SetText("Top " .. index)
    end

    return header
end

function addon:PositionMinimapButton()
    if not self.minimapButton or not Minimap then
        return
    end

    local angle = self.db and self.db.minimap and self.db.minimap.angle or DEFAULTS.minimap.angle
    local x, y = GetMinimapCoordinates(angle)

    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function addon:UpdateMinimapButtonDrag(button)
    if not button.isMouseDown or not Minimap or not GetCursorPosition then
        return
    end

    local rawX, rawY = GetCursorPosition()
    if not rawX or not rawY then
        return
    end

    local moveX = rawX - (button.downX or rawX)
    local moveY = rawY - (button.downY or rawY)
    if not button.isDragging and (moveX * moveX + moveY * moveY) < MINIMAP_BUTTON_DRAG_THRESHOLD then
        return
    end

    button.isDragging = true

    local mapX, mapY = Minimap:GetCenter()
    if not mapX or not mapY then
        return
    end

    local scale = Minimap:GetEffectiveScale() or 1
    if scale == 0 then
        scale = 1
    end

    local cursorX, cursorY = rawX / scale, rawY / scale
    local angle = math.deg(GetAtan2(cursorY - mapY, cursorX - mapX))
    if angle < 0 then
        angle = angle + 360
    end

    self.db.minimap.angle = angle
    self:PositionMinimapButton()
end

function addon:RefreshMinimapButton()
    if not self.minimapButton then
        self:CreateMinimapButton()
    end

    if not self.minimapButton then
        return
    end

    self:PositionMinimapButton()

    if self.db.minimap.show then
        self.minimapButton:Show()
    else
        self.minimapButton:Hide()
    end
end

function addon:CreateMinimapButton()
    if self.minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "BetterWotLKBiSMinimapButton", Minimap)
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetFrameStrata("MEDIUM")
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetWidth(20)
    background:SetHeight(20)
    background:SetPoint("CENTER", button, "CENTER", 0, 0)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button.icon = icon
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end

        self.isMouseDown = true
        self.isDragging = false
        self.downX, self.downY = GetCursorPosition()
        self:SetScript("OnUpdate", function(dragButton) addon:UpdateMinimapButtonDrag(dragButton) end)
    end)

    button:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            if self.isMouseDown and not self.isDragging and GetCursorPosition then
                local upX, upY = GetCursorPosition()
                local moveX = upX and self.downX and (upX - self.downX) or 0
                local moveY = upY and self.downY and (upY - self.downY) or 0
                if (moveX * moveX + moveY * moveY) >= MINIMAP_BUTTON_DRAG_THRESHOLD then
                    addon:UpdateMinimapButtonDrag(self)
                end
            end

            local wasDragging = self.isDragging
            self.isMouseDown = false
            self.isDragging = false
            self:SetScript("OnUpdate", nil)

            if not wasDragging then
                addon:CreateMainFrame()
            end
        elseif mouseButton == "RightButton" then
            addon:OpenOptions()
        end
    end)

    button:SetScript("OnHide", function(self)
        self.isMouseDown = false
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("BetterWotLKBiS", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: Open BiS list", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Options", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: Move button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.minimapButton = button
    self:PositionMinimapButton()
end

function addon:CreateMainFrame()
    if self.mainFrame then
        if self.mainFrame:IsShown() then
            self.mainFrame:Hide()
        else
            self:RefreshMainFrame()
            self.mainFrame:Show()
        end
        return
    end

    local frame = CreateFrame("Frame", "BetterWotLKBiSFrame", UIParent)
    frame:SetWidth(530)
    frame:SetHeight(580)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    SetFrameBackdrop(frame)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -13)
    title:SetTextColor(1, 0.82, 0)
    title:SetText("BetterWotLKBiS")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame.classDropDown = CreateFrame("Frame", "BetterWotLKBiSClassDropDown", frame, "UIDropDownMenuTemplate")
    frame.classDropDown:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -34)
    UIDropDownMenu_SetWidth(frame.classDropDown, 118)
    UIDropDownMenu_Initialize(frame.classDropDown, function() addon:InitializeClassDropDown() end)

    frame.specDropDown = CreateFrame("Frame", "BetterWotLKBiSSpecDropDown", frame, "UIDropDownMenuTemplate")
    frame.specDropDown:SetPoint("LEFT", frame.classDropDown, "RIGHT", -4, 0)
    UIDropDownMenu_SetWidth(frame.specDropDown, 158)
    UIDropDownMenu_Initialize(frame.specDropDown, function() addon:InitializeSpecDropDown() end)

    frame.phaseDropDown = CreateFrame("Frame", "BetterWotLKBiSPhaseDropDown", frame, "UIDropDownMenuTemplate")
    frame.phaseDropDown:SetPoint("LEFT", frame.specDropDown, "RIGHT", -4, 0)
    UIDropDownMenu_SetWidth(frame.phaseDropDown, 82)
    UIDropDownMenu_Initialize(frame.phaseDropDown, function() addon:InitializePhaseDropDown() end)

    frame.header = self:CreateHeader(frame)
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -75)
    frame.header:SetPoint("RIGHT", frame, "RIGHT", -38, 0)

    frame.scroll = CreateFrame("ScrollFrame", "BetterWotLKBiSScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -96)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 54)

    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetWidth(450)
    frame.content:SetHeight(1)
    frame.scroll:SetScrollChild(frame.content)

    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetWidth(110)
    refresh:SetHeight(22)
    refresh:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function() addon:RefreshMainFrame() end)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetWidth(90)
    closeButton:SetHeight(22)
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.sourceText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.sourceText:SetPoint("LEFT", refresh, "RIGHT", 12, 0)
    frame.sourceText:SetPoint("RIGHT", closeButton, "LEFT", -12, 0)
    frame.sourceText:SetJustifyH("LEFT")
    frame.sourceText:SetTextColor(1, 0.82, 0)

    self.mainFrame = frame
    self:RefreshMainFrame()
    frame:Show()
end

function addon:ShowAlertWindow(itemID, itemLink, upgradeInfo)
    if not self.alertFrame then
        local frame = CreateFrame("Frame", "BetterWotLKBiSAlertFrame", UIParent)
        frame:SetWidth(350)
        frame:SetHeight(118)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        SetFrameBackdrop(frame, 0.96)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() frame:Hide() end)

        frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
        frame.title:SetTextColor(1, 0.82, 0)
        frame.title:SetText("BiS Upgrade Detected")

        frame.iconButton = CreateFrame("Button", nil, frame)
        frame.iconButton:SetWidth(48)
        frame.iconButton:SetHeight(48)
        frame.iconButton:SetPoint("LEFT", frame, "LEFT", 20, -10)
        frame.icon = frame.iconButton:CreateTexture(nil, "BORDER")
        frame.icon:SetAllPoints(frame.iconButton)
        frame.iconButton:SetScript("OnClick", function(self) addon:OpenItem(self.itemID, self.itemLink) end)
        frame.iconButton:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink or ("item:" .. self.itemID))
                GameTooltip:Show()
            end
        end)
        frame.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

        frame.itemText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        frame.itemText:SetPoint("TOPLEFT", frame.iconButton, "TOPRIGHT", 12, 2)
        frame.itemText:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
        frame.itemText:SetJustifyH("LEFT")

        frame.detailText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        frame.detailText:SetPoint("TOPLEFT", frame.itemText, "BOTTOMLEFT", 0, -8)
        frame.detailText:SetPoint("RIGHT", frame.itemText, "RIGHT", 0, 0)
        frame.detailText:SetJustifyH("LEFT")
        frame.detailText:SetTextColor(0.8, 0.8, 0.8)

        self.alertFrame = frame
    end

    local frame = self.alertFrame
    local itemName, resolvedLink, _, _, texture = GetItemBasics(itemLink or itemID)
    frame.icon:SetTexture(texture or QUESTION_MARK)
    frame.iconButton.itemID = itemID
    frame.iconButton.itemLink = resolvedLink or itemLink
    frame.itemText:SetText(resolvedLink or itemName or ("item:" .. itemID))

    local currentText = "Equipped slot is empty or not ranked"
    if upgradeInfo.currentItemID then
        local currentName, currentLink = GetItemBasics(upgradeInfo.currentItemID)
        currentText = "Equipped: " .. (currentLink or currentName or ("item:" .. upgradeInfo.currentItemID))
    end

    frame.detailText:SetText(upgradeInfo.slotName .. " - " .. upgradeInfo.linkedMeta.phaseLabel .. " - " .. upgradeInfo.linkedMeta.rankLabel .. "\n" .. currentText)
    frame:Show()
end

function addon:CreateCheckbox(parent, key, label, x, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetWidth(24)
    check:SetHeight(24)
    check.key = key

    check.text = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    check.text:SetPoint("LEFT", check, "RIGHT", 3, 0)
    check.text:SetText(label)

    check:SetScript("OnClick", function(self)
        addon.db.alertChannels[self.key] = self:GetChecked() and true or false
    end)

    return check
end

function addon:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "BetterWotLKBiSOptionsPanel", UIParent)
    panel.name = "BetterWotLKBiS"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("BetterWotLKBiS")

    local channels = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channels:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -22)
    channels:SetText("Alert chat channels")

    self.optionChecks = {}
    local y = -64
    for _, option in ipairs(CHANNEL_LABELS) do
        local check = self:CreateCheckbox(panel, option.key, option.label, 18, y)
        self.optionChecks[option.key] = check
        y = y - 28
    end

    local pop = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    pop:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, y - 8)
    pop:SetWidth(24)
    pop:SetHeight(24)
    pop.text = pop:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pop.text:SetPoint("LEFT", pop, "RIGHT", 3, 0)
    pop.text:SetText("Pop center window")
    pop:SetScript("OnClick", function(self)
        addon.db.popWindow = self:GetChecked() and true or false
    end)
    self.popCheck = pop

    local minimap = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimap:SetPoint("TOPLEFT", pop, "BOTTOMLEFT", 0, -8)
    minimap:SetWidth(24)
    minimap:SetHeight(24)
    minimap.text = minimap:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    minimap.text:SetPoint("LEFT", minimap, "RIGHT", 3, 0)
    minimap.text:SetText("Show minimap button")
    minimap:SetScript("OnClick", function(self)
        addon.db.minimap.show = self:GetChecked() and true or false
        addon:RefreshMinimapButton()
    end)
    self.minimapCheck = minimap

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetWidth(130)
    open:SetHeight(24)
    open:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -20)
    open:SetText("Open BiS List")
    open:SetScript("OnClick", function() addon:CreateMainFrame() end)

    panel:SetScript("OnShow", function()
        for key, check in pairs(addon.optionChecks) do
            check:SetChecked(addon.db.alertChannels[key])
        end
        addon.popCheck:SetChecked(addon.db.popWindow)
        addon.minimapCheck:SetChecked(addon.db.minimap.show)
    end)

    InterfaceOptions_AddCategory(panel)
    self.optionsPanel = panel
end

function addon:OpenOptions()
    if InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end

function addon:RegisterChatEvents()
    for event in pairs(CHAT_EVENT_TO_KEY) do
        self:RegisterEvent(event)
    end
end

function addon:PrintHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00BetterWotLKBiS|r /bbis - open list, /bbis options - addon settings")
end

function addon:HandleSlashCommand(input)
    input = string.lower(input or "")

    if input == "options" or input == "config" then
        self:OpenOptions()
    elseif input == "help" then
        self:PrintHelp()
    else
        self:CreateMainFrame()
    end
end

function addon:ADDON_LOADED(addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    if type(BetterWotLKBiSDB) ~= "table" then
        BetterWotLKBiSDB = {}
    end

    self.db = BetterWotLKBiSDB
    ApplyDefaults(self.db, DEFAULTS)
    self:BuildLookups()
    self:BuildIndex()
    self:NormalizeSelection()
    self:CreateOptionsPanel()
    self:RefreshMinimapButton()
    self:RegisterChatEvents()

    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:RegisterEvent("PLAYER_TALENT_UPDATE")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    SLASH_BETTERWOTLKBIS1 = "/bbis"
    SLASH_BETTERWOTLKBIS2 = "/betterbis"
    SLASH_BETTERWOTLKBIS3 = "/wotlkbis"
    SlashCmdList.BETTERWOTLKBIS = function(input) addon:HandleSlashCommand(input) end
end

function addon:PLAYER_LOGIN()
    self:SelectPlayerList()
    self:RefreshMinimapButton()
    self:RefreshMainFrame()
end

function addon:PLAYER_EQUIPMENT_CHANGED()
    self:RefreshMainFrame()
end

function addon:PLAYER_TALENT_UPDATE()
    self:SelectPlayerList()
    self:RefreshMainFrame()
end

function addon:ACTIVE_TALENT_GROUP_CHANGED()
    self:SelectPlayerList()
    self:RefreshMainFrame()
end

function addon:GET_ITEM_INFO_RECEIVED()
    self:RefreshMainFrame()
end

addon:SetScript("OnEvent", function(self, event, ...)
    if CHAT_EVENT_TO_KEY[event] then
        self:OnChatEvent(event, ...)
        return
    end

    if self[event] then
        self[event](self, ...)
    end
end)

addon:RegisterEvent("ADDON_LOADED")
