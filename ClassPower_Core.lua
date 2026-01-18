-- ClassPower Core Framework
-- Modular buff management system for Turtle WoW (1.12.1)
-- Supports: Priest, Druid, Mage, Shaman (and more via modules)

ClassPower = {}
ClassPower.modules = {}
ClassPower.activeModule = nil
ClassPower.loadedModules = {}  -- Track which modules have been initialized (lazy load)
ClassPower.version = "2.0"

-- Saved Variables (Renamed from PriestPower)
CP_PerUser = CP_PerUser or {}
ClassPower_Assignments = ClassPower_Assignments or {}
ClassPower_LegacyAssignments = ClassPower_LegacyAssignments or {}

-- Configuration defaults
local DEFAULT_CONFIG = {
    scanfreq = 10,
    scanperframe = 1,
    smartbuffs = 1,
    Scale = 0.7,
    ConfigScale = 0.8,
}

-- Prefix for addon messages
CP_PREFIX = "CLPWR"

-- Debug
CP_DebugEnabled = false

function CP_Debug(msg)
    if CP_DebugEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CP Debug]|r "..tostring(msg))
    end
end

-----------------------------------------------------------------------------------
-- Module Registration System
-----------------------------------------------------------------------------------

function ClassPower:RegisterModule(classToken, module)
    self.modules[classToken] = module
    CP_Debug("Registered module for: "..classToken)
end

function ClassPower:GetModule(classToken)
    return self.modules[classToken]
end

function ClassPower:LoadActiveModule()
    local _, class = UnitClass("player")
    
    if self.modules[class] then
        self.activeModule = self.modules[class]
        self.playerClass = class
        
        if self.activeModule.OnLoad then
            self.activeModule:OnLoad()
        end
        self.loadedModules[class] = true  -- Mark as loaded
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r "..self.version.." loaded for |cffffffff"..class.."|r.")
        return true
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r "..self.version.." loaded. |cffff6600"..class.." module not yet implemented.|r")
        return false
    end
end

-- Lazy load a module (only called when needed)
function ClassPower:EnsureModuleLoaded(classToken)
    if self.loadedModules[classToken] then return true end
    
    local module = self.modules[classToken]
    if not module then return false end
    
    if module.OnLoad then
        CP_Debug("Lazy loading module: "..classToken)
        module:OnLoad()
    end
    self.loadedModules[classToken] = true
    return true
end

-- Switch to viewing a different module's config (for leaders/assists)
function ClassPower:SwitchViewModule(classToken)
    if not ClassPower_IsPromoted() and classToken ~= self.playerClass then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r: Requires leader/assist to view other classes.")
        return
    end
    
    -- Lazy load the module if not yet initialized
    if not self:EnsureModuleLoaded(classToken) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r: "..classToken.." module not available.")
        return
    end
    
    -- Hide all other config windows
    for token, mod in pairs(self.modules) do
        if mod.ConfigWindow and mod.ConfigWindow:IsVisible() then
            mod.ConfigWindow:Hide()
        end
    end
    
    -- Show target module's config
    local module = self.modules[classToken]
    if module.ShowConfig then
        module:ShowConfig()
    elseif module.ConfigWindow then
        module.ConfigWindow:Show()
        if module.UpdateConfigGrid then
            module:UpdateConfigGrid()
        end
    end
    
    -- Hide admin window if open
    if self.AdminWindow and self.AdminWindow:IsVisible() then
        self.AdminWindow:Hide()
    end
end

-- Show the admin window (for leaders/assists)
function ClassPower:ShowAdminWindow()
    if not self.AdminWindow then
        self:CreateAdminWindow()
    end
    self.AdminWindow:Show()
end

-----------------------------------------------------------------------------------
-- Permission Helpers (Reusable)
-----------------------------------------------------------------------------------

function ClassPower_IsPromoted(name)
    if not name then name = UnitName("player") end
    
    if GetNumRaidMembers() > 0 then
        for i=1, GetNumRaidMembers() do
            local n, rank = GetRaidRosterInfo(i)
            if n == name then
                return (rank > 0)
            end
        end
    elseif GetNumPartyMembers() > 0 then
        if name == UnitName("player") then
            return IsPartyLeader()
        else
            local index = GetPartyLeaderIndex()
            if index > 0 then
                return (name == UnitName("party"..index))
            end
        end
    end
    return false
end

function ClassPower_IsLeader()
    if IsPartyLeader() then return true end
    if IsRaidLeader() then return true end
    if GetPartyLeaderIndex() == 0 then return true end
    return false
end

-----------------------------------------------------------------------------------
-- Addon Message System (Reusable)
-----------------------------------------------------------------------------------

function ClassPower_SendMessage(msg)
    if GetNumRaidMembers() > 0 then
        SendAddonMessage(CP_PREFIX, msg, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage(CP_PREFIX, msg, "PARTY")
    end
end

function ClassPower_RequestSync()
    ClassPower_SendMessage("REQ")
end

-----------------------------------------------------------------------------------
-- UI Constructor Functions (Reusable)
-----------------------------------------------------------------------------------

function CP_CreateSubButton(parent, name)
    local btn = CreateFrame("Button", name, parent)
    btn:SetWidth(24); btn:SetHeight(24)
    
    local bg = btn:CreateTexture(btn:GetName().."Background", "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetTexture(0.1, 0.1, 0.1, 0.5)
    
    local icon = btn:CreateTexture(btn:GetName().."Icon", "OVERLAY")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    
    local txt = btn:CreateFontString(btn:GetName().."Text", "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
    txt:SetJustifyH("CENTER")
    
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    return btn
end

function CP_CreateCapabilityIcon(parent, name)
    local btn = CreateFrame("Button", name, parent)
    btn:SetWidth(18); btn:SetHeight(18)
    
    local icon = btn:CreateTexture(btn:GetName().."Icon", "OVERLAY")
    icon:SetWidth(16); icon:SetHeight(16)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    
    local rank = btn:CreateFontString(btn:GetName().."Rank", "OVERLAY", "GameFontHighlightSmall")
    rank:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
    
    btn:SetScript("OnEnter", function()
        if this.tooltipText then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.tooltipText)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    return btn
end

function CP_CreateClearButton(parent, name)
    local btn = CreateFrame("Button", name, parent)
    btn:SetWidth(14); btn:SetHeight(14)
    btn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    btn:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
    local ht = btn:GetHighlightTexture()
    if ht then ht:SetBlendMode("ADD") end
    
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clear Assignments")
        GameTooltip:AddLine("Requires Leader/Assist", 1, 0, 0)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    return btn
end

function CP_CreateResizeGrip(parent, name)
    local btn = CreateFrame("Button", name, parent)
    btn:SetWidth(16); btn:SetHeight(16)
    
    btn:SetScript("OnMouseDown", function() 
        if arg1 == "LeftButton" then
            local p = this:GetParent()
            p.isResizing = true
            p.startScale = p:GetScale()
            p.cursorStartX, p.cursorStartY = GetCursorPosition()
            this:SetScript("OnUpdate", CP_OnScaleUpdate)
        end
    end)
    btn:SetScript("OnMouseUp", function() 
        local p = this:GetParent()
        p.isResizing = false
        this:SetScript("OnUpdate", nil)
    end)
    return btn
end

function CP_OnScaleUpdate()
    local p = this:GetParent()
    if not p.isResizing then return end
    
    local cursorX, cursorY = GetCursorPosition()
    local diff = (cursorX - p.cursorStartX)
    diff = diff / UIParent:GetEffectiveScale()
    
    local newScale = p.startScale + (diff * 0.002)
    if newScale < 0.5 then newScale = 0.5 end
    if newScale > 2.0 then newScale = 2.0 end
    
    p:SetScale(newScale)
end

function CP_CreateHUDButton(parent, name)
    local btn = CreateFrame("Button", name, parent)
    btn:SetWidth(30); btn:SetHeight(30)
    
    local icon = btn:CreateTexture(btn:GetName().."Icon", "BACKGROUND")
    icon:SetAllPoints(btn)
    
    local txt = btn:CreateFontString(btn:GetName().."Text", "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
    
    local nt = btn:CreateTexture(btn:GetName().."NormalTexture")
    nt:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    nt:SetWidth(54); nt:SetHeight(54)
    nt:SetPoint("CENTER", btn, "CENTER", 0, -1)
    btn:SetNormalTexture(nt)
    
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnEnter", function()
        if this.tooltipText then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.tooltipText)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    btn:Hide()
    return btn
end

-----------------------------------------------------------------------------------
-- Slash Command Handler
-----------------------------------------------------------------------------------

function ClassPower_SlashHandler(msg)
    if msg == "debug" then
        CP_DebugEnabled = not CP_DebugEnabled
        if CP_DebugEnabled then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r Debug Enabled.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r Debug Disabled.")
        end
    elseif msg == "reset" then
        CP_PerUser = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r Settings reset.")
    elseif msg == "admin" then
        if ClassPower_IsPromoted() then
            ClassPower:ShowAdminWindow()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r: Admin requires leader/assist.")
        end
    elseif msg == "priest" then
        ClassPower:SwitchViewModule("PRIEST")
    elseif msg == "paladin" then
        ClassPower:SwitchViewModule("PALADIN")
    elseif msg == "druid" then
        ClassPower:SwitchViewModule("DRUID")
    else
        -- Pass to active module
        if ClassPower.activeModule and ClassPower.activeModule.OnSlashCommand then
            ClassPower.activeModule:OnSlashCommand(msg)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ClassPower|r: No active module or unknown command.")
        end
    end
end

-----------------------------------------------------------------------------------
-- Event Handler
-----------------------------------------------------------------------------------

function ClassPower_OnEvent(event)
    if event == "PLAYER_LOGIN" then
        -- Initialize saved vars
        if not CP_PerUser then
            CP_PerUser = {}
            for k, v in pairs(DEFAULT_CONFIG) do
                CP_PerUser[k] = v
            end
        end
        
        -- Load the appropriate module
        ClassPower:LoadActiveModule()
        
    elseif event == "CHAT_MSG_ADDON" then
        if arg1 == CP_PREFIX then
            -- Route to ALL loaded modules (for cross-class admin feature)
            for classToken, loaded in pairs(ClassPower.loadedModules) do
                if loaded then
                    local module = ClassPower.modules[classToken]
                    if module and module.OnAddonMessage then
                        module:OnAddonMessage(arg4, arg2)
                    end
                end
            end
        end
    else
        -- Pass other events to active module
        if ClassPower.activeModule and ClassPower.activeModule.OnEvent then
            ClassPower.activeModule:OnEvent(event)
        end
    end
end

function ClassPower_OnUpdate(elapsed)
    if ClassPower.activeModule and ClassPower.activeModule.OnUpdate then
        ClassPower.activeModule:OnUpdate(elapsed)
    end
end

-----------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "ClassPowerEventFrame", UIParent)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")

eventFrame:SetScript("OnEvent", function() ClassPower_OnEvent(event) end)
eventFrame:SetScript("OnUpdate", function() ClassPower_OnUpdate(arg1) end)

-- Register slash commands
SlashCmdList["CLASSPOWER"] = ClassPower_SlashHandler
SLASH_CLASSPOWER1 = "/cp"
SLASH_CLASSPOWER2 = "/classpower"
SLASH_CLASSPOWER3 = "/prip"
SLASH_CLASSPOWER4 = "/prp"
SLASH_CLASSPOWER5 = "/priestpower"

-- Create dropdown frame for menus
if not getglobal("ClassPowerDropDown") then
    CreateFrame("Frame", "ClassPowerDropDown", UIParent, "UIDropDownMenuTemplate")
end

-----------------------------------------------------------------------------------
-- Admin Window (for leaders/assists to view all class modules)
-----------------------------------------------------------------------------------

function ClassPower:CreateAdminWindow()
    if self.AdminWindow then return end
    
    local f = CreateFrame("Frame", "ClassPowerAdminWindow", UIParent)
    f:SetWidth(280)
    f:SetHeight(140)
    f:SetPoint("CENTER", 0, 100)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -20)
    title:SetText("ClassPower Admin")
    
    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetText("Select a class module to configure")
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    
    f:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then this:StartMoving() end
    end)
    f:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
    
    -- Class buttons
    local classes = {
        {token = "PRIEST", label = "Priests", icon = "Interface\\Icons\\Spell_Holy_WordFortitude"},
        {token = "DRUID", label = "Druids", icon = "Interface\\Icons\\Spell_Nature_Regeneration"},
        {token = "PALADIN", label = "Paladins", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom"},
    }
    
    local buttonWidth = 70
    local buttonHeight = 50
    local startX = 30
    
    for i, class in ipairs(classes) do
        local btn = CreateFrame("Button", f:GetName()..class.token, f)
        btn:SetWidth(buttonWidth)
        btn:SetHeight(buttonHeight)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", startX + (i-1) * (buttonWidth + 10), -60)
        
        -- Background
        local bg = btn:CreateTexture(btn:GetName().."Bg", "BACKGROUND")
        bg:SetAllPoints(btn)
        bg:SetTexture(0.1, 0.1, 0.1, 0.7)
        
        -- Icon
        local icon = btn:CreateTexture(btn:GetName().."Icon", "ARTWORK")
        icon:SetWidth(32)
        icon:SetHeight(32)
        icon:SetPoint("TOP", btn, "TOP", 0, -4)
        icon:SetTexture(class.icon)
        
        -- Label
        local label = btn:CreateFontString(btn:GetName().."Label", "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOM", btn, "BOTTOM", 0, 4)
        label:SetText(class.label)
        
        -- Highlight
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        local ht = btn:GetHighlightTexture()
        if ht then ht:SetBlendMode("ADD") end
        
        btn.classToken = class.token
        btn:SetScript("OnClick", function()
            ClassPower:SwitchViewModule(this.classToken)
        end)
        
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText("Open "..class.label.." Configuration")
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    
    f:Hide()
    self.AdminWindow = f
end

-----------------------------------------------------------------------------------
-- Minimap Button
-----------------------------------------------------------------------------------

function ClassPower_CreateMinimapButton()
    if getglobal("ClassPowerMinimapButton") then return end
    
    local btn = CreateFrame("Button", "ClassPowerMinimapButton", Minimap)
    btn:SetWidth(31)
    btn:SetHeight(31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:SetMovable(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    
    -- Icon
    local icon = btn:CreateTexture(btn:GetName().."Icon", "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\PriestPower\\Media\\cpwr")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    
    -- Border
    local border = btn:CreateTexture(btn:GetName().."Border", "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(56)
    border:SetHeight(56)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    
    -- Highlight
    local highlight = btn:CreateTexture(btn:GetName().."Highlight", "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetWidth(25)
    highlight:SetHeight(25)
    highlight:SetPoint("CENTER", btn, "CENTER", 0, 0)
    
    -- Position around minimap (angle in degrees)
    local function UpdatePosition(angle)
        local radius = 80
        local x = math.cos(math.rad(angle)) * radius
        local y = math.sin(math.rad(angle)) * radius
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
        CP_PerUser.MinimapAngle = angle
    end
    
    -- Load saved position or default to top-right
    local savedAngle = CP_PerUser and CP_PerUser.MinimapAngle or 45
    UpdatePosition(savedAngle)
    
    -- Dragging
    btn:SetScript("OnDragStart", function()
        this.isDragging = true
    end)
    
    btn:SetScript("OnDragStop", function()
        this.isDragging = false
    end)
    
    btn:SetScript("OnUpdate", function()
        if not this.isDragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        UpdatePosition(angle)
    end)
    
    -- Click handlers
    btn:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            ClassPower_SlashHandler("")
        elseif arg1 == "RightButton" then
            -- Right-click could show a menu or toggle HUD
            if ClassPower.activeModule and ClassPower.activeModule.BuffBar then
                if ClassPower.activeModule.BuffBar:IsVisible() then
                    ClassPower.activeModule.BuffBar:Hide()
                else
                    ClassPower.activeModule.BuffBar:Show()
                end
            end
        end
    end)
    
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("ClassPower")
        GameTooltip:AddLine("Left-click: Open Config", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: Toggle HUD", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Create minimap button after a short delay (ensure Minimap exists)
local minimapInitFrame = CreateFrame("Frame")
minimapInitFrame:RegisterEvent("PLAYER_LOGIN")
minimapInitFrame:SetScript("OnEvent", function()
    ClassPower_CreateMinimapButton()
end)

CP_Debug("ClassPower Core loaded.")
