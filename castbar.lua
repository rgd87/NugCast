local addonName, ns = ...

NugCast = CreateFrame("Frame",nil,UIParent)

local NugCast = _G.NugCast
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local APILevel = math.floor(select(4,GetBuildInfo())/10000)
local isForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE


local GetUnitEmpowerStageDuration = GetUnitEmpowerStageDuration
local GetUnitEmpowerHoldAtMaxTime = GetUnitEmpowerHoldAtMaxTime

local NugCastDB

local LSM = LibStub("LibSharedMedia-3.0")
local LibCC -- = APILevel == 1 and LibStub("LibClassicCasterino", true)

LSM:Register("statusbar", "Aluminium", [[Interface\AddOns\NugCast\statusbar.tga]])

local npCastbars = {}
local npCastbarsByUnit = {}
local npCastbarsByGUID = {}
local MAX_NAMEPLATE_CASTBARS = 4
local anchors = {}

NugCast.L = setmetatable({}, {
    __index = function(t, k)
        -- print(string.format('L["%s"] = ""',k:gsub("\n","\\n")));
        return k
    end,
    __call = function(t,k) return t[k] end,
})
local L = NugCast.L

local defaultFont = "Friz Quadrata TT"
do
    local locale = GetLocale()
    if locale == "zhTW" or locale == "zhCN" or locale == "koKR" then
        defaultFont = LSM.DefaultMedia["font"]
        -- "預設" - zhTW
        -- "默认" - zhCN
        -- "기본 글꼴" - koKR
    end
end

local defaults = {
    global = {
        playerCastbar = true,
        targetCastbar = true,
        focusCastbar = false,
        nameplateCastbars = true,
    },
    profile = {
        anchors = {
            player = {
                point = "CENTER",
                parent = "UIParent",
                to = "CENTER",
                x = -100,
                y = -300,
            },
            target = {
                point = "CENTER",
                parent = "UIParent",
                to = "CENTER",
                x = -120,
                y = -100,
            },
            focus = {
                point = "CENTER",
                parent = "UIParent",
                to = "CENTER",
                x = -120,
                y = 0,
            },
            nameplates = {
                point = "CENTER",
                parent = "UIParent",
                to = "CENTER",
                x = -50,
                y = -137,
            },
        },
        player = {
            width = 200,
            height = 25,
            spellFontSize = 10,
            notext = true,
        },
        target = {
            width = 250,
            height = 27,
            spellFontSize = 13,
        },
        focus = {
            width = 250,
            height = 27,
            spellFontSize = 13,
        },
        nameplates = {
            width = 180,
            height = 18,
            spellFontSize = 10,
        },
        barTexture = "Aluminium",
        spellFont = defaultFont,
        timeFont = "Friz Quadrata TT",
        timeFontSize = 8,

        textColor = {1,1,1,0.5},
        castColor = { 0.6, 0, 1 },
        channelColor = {200/255,50/255,95/255 },
        highlightColor = { 206/255, 4/256, 56/256 },
        successColor = { 0.2, 0.7, 0.3 },
        failedColor = { 1, 0, 0 },
        notInterruptibleColorEnabled = false,
        notInterruptibleColor = { 0.5, 0.5, 0.5 },

        empowerStageColors = {
            { 1, 0.2, 0.3 },
            { 0.8, 0.4, 0.2 },
            { 1, 0.75, 0.3 },
        },

        nameplateExcludeTarget = true,
    }
}

local GetNearestPixelSize = PixelUtil.GetNearestPixelSize
local ppScaleRegion = UIParent
local function SetPixelPerfectScaleRegion(region)
    ppScaleRegion = region
end
local function pixelperfect(size, region)
    region = region or ppScaleRegion
    return GetNearestPixelSize(size, region:GetEffectiveScale())
end




NugCast:RegisterEvent("PLAYER_LOGIN")
NugCast:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

function NugCast:PLAYER_LOGIN()
    _G.NugCastDB = _G.NugCastDB or {}
    self:DoMigrations(_G.NugCastDB)
    self.db = LibStub("AceDB-3.0"):New("NugCastDB", defaults, "Default")
    -- NugCastDB = self.db

    self.db.RegisterCallback(self, "OnProfileChanged", "Reconfigure")
    self.db.RegisterCallback(self, "OnProfileCopied", "Reconfigure")
    self.db.RegisterCallback(self, "OnProfileReset", "Reconfigure")

    -- if APILevel == 1 then
        self.db.global.focusCastbar = false
        self.db.global.nameplateCastbars = false
    -- end

    if self.db.global.playerCastbar then
        local player = NugCast:SpawnCastBar("player", self.db.profile.player.width, self.db.profile.player.height)
        if self.db.profile.player.notext then
            player.spellText:Hide()
            player.timeText:Hide()
        end
        if PlayerCastingBarFrame then
            PlayerCastingBarFrame:UnregisterAllEvents()
            PlayerCastingBarFrame:Hide()
        end
        NugCastPlayer = player

        local player_anchor = self:CreateAnchor(self.db.profile.anchors["player"])
        player:SetPoint("TOPLEFT",player_anchor,"BOTTOMRIGHT",0,0)
        anchors["player"] = player_anchor
    end

    if self.db.global.targetCastbar then
        local target = NugCast:SpawnCastBar("target", self.db.profile.target.width, self.db.profile.target.height)
        target:RegisterEvent("PLAYER_TARGET_CHANGED")
        NugCast:AddMore(target)
        NugCastTarget = target

        if TargetFrameSpellBar then
            TargetFrameSpellBar:UnregisterAllEvents()
            TargetFrameSpellBar:Hide()
        end

        local target_anchor = self:CreateAnchor(self.db.profile.anchors["target"])
        target:SetPoint("TOPLEFT",target_anchor,"BOTTOMRIGHT",0,0)
        anchors["target"] = target_anchor
    end

    if self.db.global.focusCastbar then
        local focus = NugCast:SpawnCastBar("focus", self.db.profile.focus.width, self.db.profile.focus.height)
        focus:RegisterEvent("PLAYER_FOCUS_CHANGED")
        NugCast:AddMore(focus)
        NugCastFocus = focus

        if FocusFrameSpellBar then
            FocusFrameSpellBar:UnregisterAllEvents()
            FocusFrameSpellBar:Hide()
        end

        local focus_anchor = self:CreateAnchor(self.db.profile.anchors["focus"])
        focus:SetPoint("TOPLEFT",focus_anchor,"BOTTOMRIGHT",0,0)
        anchors["focus"] = focus_anchor
    end
    -- if oUF_Focus then focus:SetPoint("TOPRIGHT",oUF_Focus,"BOTTOMRIGHT", 0,-5)
    -- else focus:SetPoint("CENTER",UIParent,"CENTER", 0,300) end


    --[[
    if self.db.global.nameplateCastbars and not isClassic then
        local npheader = NugCast:CreateNameplateCastbars()
        NugCastPlayerNameplateHeader = npheader
        local nameplates_anchor = self:CreateAnchor(self.db.profile.anchors["nameplates"])
        npheader:SetPoint("TOPLEFT", nameplates_anchor,"BOTTOMRIGHT",0,0)
        -- npheader:SetPoint("CENTER", UIParent, "CENTER",0,0)
        anchors["nameplates"] = nameplates_anchor
    end
    ]]


    SLASH_NUGCAST1= "/nugcast"
    SlashCmdList["NUGCAST"] = NugCast.SlashCmd

    local f = CreateFrame('Frame', nil, SettingsPanel or InterfaceOptionsFrame)
    f:SetScript('OnShow', function(self)
        self:SetScript('OnShow', nil)

        if not NugCast.optionsPanel then
            local panelFrame, categoryID = NugCast:CreateGUI()
            NugCast.optionsPanel = panelFrame
            NugCast.settingsCategoryID = categoryID
        end
    end)
end

function NugCast:Reconfigure()
    self:UpdatePosition()
    self:Resize()
    self:ResizeText()
end


local defaultCastColor = { 0.6, 0, 1 }
local defaultChannelColor = {200/255,50/255,95/255 }
local highlightColor = { 206/255, 4/256, 56/256 }
local coloredSpells = {}

function NugCast.CAST_START(self,event, unit)
    if unit ~= self.unit then return end
    local name, displayName, textureID, startTime, endTime, isTradeskill, castGUID, notInterruptible, castingSpellID, castID, delayTimeMs = UnitCastingInfo(unit)
    local duration = UnitCastingDuration(unit)
    if isClassic and APILevel == 2 then
        -- spellID = notInterruptible
        notInterruptible = false
    end
    self.channeling = false
    self.empowered = false
    if self.fader:IsPlaying() then
        self.fader:Stop()
    end
    self:Show()
    self:SetAlpha(1)
    self:UpdateCastingInfo(name, textureID, startTime, duration, castID, notInterruptible)
end
NugCast.UNIT_SPELLCAST_START = NugCast.CAST_START
NugCast.UNIT_SPELLCAST_DELAYED = NugCast.CAST_START



local displayHoldArea = true
function NugCast.CHANNEL_START(self,event,unit)
    if unit ~= self.unit then return end
    local name, displayName, textureID, startTime, endTime, isTradeskill, notInterruptible, spellID, isEmpowered, numStages, castID = UnitChannelInfo(unit)
    local duration
    if isEmpowered then
        duration = UnitEmpoweredChannelDuration(unit, displayHoldArea)
        if not displayHoldArea then
            numStages = numStages - 1
        end
    else
        duration = UnitChannelDuration(unit)
    end

    if isClassic and APILevel == 2 then
        -- spellID = notInterruptible
        notInterruptible = false
    end
    -- self.channeling = true
    self.channeling = not isEmpowered
    self.empowered = isEmpowered
    if self.fader:IsPlaying() then
        self.fader:Stop()
    end
    self:Show()
    self:SetAlpha(1)
    self:UpdateCastingInfo(name, textureID, startTime, duration, castID, notInterruptible, isEmpowered, numStages)
end
NugCast.UNIT_SPELLCAST_CHANNEL_START = NugCast.CHANNEL_START
NugCast.UNIT_SPELLCAST_EMPOWER_START = NugCast.CHANNEL_START
NugCast.UNIT_SPELLCAST_CHANNEL_UPDATE = NugCast.CHANNEL_START
NugCast.UNIT_SPELLCAST_EMPOWER_UPDATE = NugCast.CHANNEL_START



function NugCast.CAST_STOP_INSTANT(self, event, unit)
    if unit ~= self.unit then return end
    self:Hide()
end
function NugCast.CAST_STOP(self, event, unit, castGUID, spellID, ...)
    if unit ~= self.unit then return end
    --[[
    if self.Deactivate then
        self:Deactivate()
        self:Hide()
        return
    end
    ]]

    local castID, interruptedBy, empowerComplete
	if(event == 'UNIT_SPELLCAST_STOP') then
		castID = ...
	elseif(event == 'UNIT_SPELLCAST_EMPOWER_STOP') then
		empowerComplete, interruptedBy, castID = ...
        if interruptedBy then
            self.bar:SetColor(unpack(NugCast.db.profile.failedColor))
        end
        if empowerComplete then
            self.bar:SetColor(unpack(NugCast.db.profile.successColor))
        end
	elseif(event == 'UNIT_SPELLCAST_CHANNEL_STOP') then
		interruptedBy, castID = ...
	end

    if self.castID ~= castID then return end

    self.bar:SetMinMaxValues(0,1)
    self.bar:SetValue(self.channeling and 0 or 1)
    self.fader:Play()
    -- self:Hide()
end
NugCast.UNIT_SPELLCAST_STOP = NugCast.CAST_STOP
NugCast.UNIT_SPELLCAST_CHANNEL_STOP = NugCast.CAST_STOP
NugCast.UNIT_SPELLCAST_EMPOWER_STOP = NugCast.CAST_STOP



function NugCast.CAST_FAILED(self, event, unit, _, spellID, ...)
    if unit ~= self.unit then return end

    local castID, interruptedBy
	if(event == 'UNIT_SPELLCAST_INTERRUPTED') then
		interruptedBy, castID = ...
	elseif(event == 'UNIT_SPELLCAST_FAILED') then
		castID = ...
	end

    if self.castID ~= castID then return end

    NugCast.UNIT_SPELLCAST_STOP(self, event, unit, castID)
    self.bar:SetColor(unpack(NugCast.db.profile.failedColor))
end
NugCast.UNIT_SPELLCAST_FAILED = NugCast.CAST_FAILED
NugCast.UNIT_SPELLCAST_INTERRUPTED = NugCast.CAST_FAILED



function NugCast.UNIT_SPELLCAST_INTERRUPTIBLE(self,event,unit)
    if unit ~= self.unit then return end
    self.shield:SetAlpha(0)
end
function NugCast.UNIT_SPELLCAST_NOT_INTERRUPTIBLE(self,event,unit)
    if unit ~= self.unit then return end
    self.shield:SetAlpha(1)
end


function NugCast.PLAYER_TARGET_CHANGED(self,event)
    if UnitExists("target") then
        if UnitCastingInfo("target") then return NugCast.UNIT_SPELLCAST_START(self,event,"target") end
        if UnitChannelInfo("target") then return NugCast.UNIT_SPELLCAST_CHANNEL_START(self,event,"target") end
    else
        NugCast.CAST_STOP_INSTANT(self, event, "target")
    end
end

function NugCast.PLAYER_FOCUS_CHANGED(self,event)
    if UnitExists("target") then
        if UnitCastingInfo("focus") then return NugCast.UNIT_SPELLCAST_START(self,event,"focus") end
        if UnitChannelInfo("focus") then return NugCast.UNIT_SPELLCAST_CHANNEL_START(self,event,"focus") end
    else
        NugCast.CAST_STOP_INSTANT(self, event, "focus")
    end
end

function NugCast.UNIT_SPELLCAST_SUCCEEDED(self, event, unit, castGUID, spellID, castID)
    if unit ~= self.unit then return end
    if self.channeling then return end
    if self.empowered then return end
    if self.castID == castID then
        NugCast.UNIT_SPELLCAST_STOP(self, event, unit, castID)
        self.bar:SetColor(unpack(NugCast.db.profile.successColor))
    end
end

local UpdateCastingInfo = function(self,name,texture,startTime,duration,castID, notInterruptible, isEmpowered, numStages)
        if not startTime then return end
        self.castID = castID -- this is castBarID, not castGUID, it shouldn't be secret
        self.startTime = startTime
        self.duration = duration
        numStages = numStages or 1

        local direction = self.channeling and 1 or 0
        self.bar:SetTimerDuration(duration, nil, direction)

        if isEmpowered then
            self:UpdateStageConfig(numStages)
        else
            self:HideMarksFrom(0)
        end
        -- local stageInterval = duration / numStages
        -- self.bar:SetMinMaxValues(self.startTime, self.endTime)
        self.icon:SetTexture(texture)
        self.spellText:SetText(name)
        -- if self.unit ~= "player" and NugCast.badSpells[name] then
        --     if self.shine:IsPlaying() then self.shine:Stop() end
        --     self.shine:Play()
        -- end
        local color = self.channeling and NugCast.db.profile.channelColor or NugCast.db.profile.castColor
        self.bar:SetColor(unpack(color))
        self.isActive = true
        self:Show()

        if self.shield then
            self.shield:Show()
            self.shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
        end
    end
function NugCast.SpawnCastBar(self,unit,width,height)
    local f = CreateFrame("Frame",nil,UIParent)
    f.unit = unit

    -- if unit == "player" then
        -- self:MakeDoubleCastbar(f,width,height)

    local addSpark
    if unit == "player" or unit == "target" then
        addSpark = true
    end
    -- else
        self:FillFrame(f, width,height, unit, addSpark)
    -- end

    f:Hide()
    f:RegisterEvent("UNIT_SPELLCAST_START")
    f:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    f:RegisterEvent("UNIT_SPELLCAST_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_FAILED")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    -- These two are only for target and focus
    -- f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    -- f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    f:SetScript("OnEvent", function(self, event, ...)
        return NugCast[event](self, event, ...)
    end)
    f.UpdateCastingInfo = UpdateCastingInfo

    return f
end

NugCast.AddMore = function(self, f)
    if APILevel >= 4 then
        f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
        f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    end
    local height = f:GetHeight()
    local shield = f.icon:GetParent():CreateTexture(nil,"ARTWORK",nil,2)
    shield:SetTexture([[Interface\AchievementFrame\UI-Achievement-IconFrame]])
    shield:SetTexCoord(0,0.5625,0,0.5625)
    shield:SetWidth(height*1.8)
    shield:SetHeight(height*1.8)
    shield:SetPoint("CENTER",f.icon,"CENTER",0,0)
    shield:Hide()
    f.shield = shield

    local at = f.icon:GetParent():CreateTexture(nil,"OVERLAY")
    at:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    at:SetTexCoord(0.00781250,0.50781250,0.27734375,0.52734375)
    at:SetWidth(height*1.8)
    at:SetHeight(height*1.8)
    at:SetPoint("CENTER",f.icon,"CENTER",0,0)
    at:SetAlpha(0)

    -- local sag = at:CreateAnimationGroup()
    -- local sa1 = sag:CreateAnimation("Alpha")
    -- sa1:SetToAlpha(1)
    -- sa1:SetDuration(0.3)
    -- sa1:SetOrder(1)
    -- local sa2 = sag:CreateAnimation("Alpha")
    -- sa2:SetToAlpha(0)
    -- sa2:SetDuration(0.5)
    -- sa2:SetSmoothing("OUT")
    -- sa2:SetOrder(2)

    -- f.shine = sag
end

local ResizeFunc = function(self, width, height)
    local texture = LSM:Fetch("statusbar", NugCast.db.profile.barTexture)
    self.bar:SetStatusBarTexture(texture)
    self.bar.bg:SetTexture(texture)

    self:SetWidth(width)
    self:SetHeight(height)
    self.bar:SetWidth(width - height - 1)
    self.bar:SetHeight(height)
    if self.shield then
        self.shield:SetWidth(height*1.8)
        self.shield:SetHeight(height*1.8)
    end
    if self.bar.spark then
        local spark = self.bar.spark
        spark:SetWidth(height*2)
        spark:SetHeight(height)
    end
    self.spellText:SetWidth(width/4*3 -12)
    self.spellText:SetHeight(height/2+1)
    local ic = self.icon:GetParent()
    ic:SetWidth(height)
    ic:SetHeight(height)
end

local ResizeTextFunc = function(self, spellFontSize)
    self.timeText:SetFont(LSM:Fetch("font", NugCast.db.profile.timeFont), NugCast.db.profile.timeFontSize)
    self.timeText:SetTextColor(unpack(NugCast.db.profile.textColor))

    self.spellText:SetFont(LSM:Fetch("font", NugCast.db.profile.spellFont), spellFontSize)
    self.spellText:SetTextColor(unpack(NugCast.db.profile.textColor))
end

local MakeBorder = function(self, tex, left, right, top, bottom, level)
    local t = self:CreateTexture(nil,"BORDER",nil,level)
    t:SetTexture(tex)
    t:SetPoint("TOPLEFT", self, "TOPLEFT", left, -top)
    t:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -right, bottom)
    return t
end

local function Mark_UpdatePosition(self, progress)
    local parent = self:GetParent()
    self:SetHeight(parent:GetHeight()*0.9)
    local parentWidth = parent:GetWidth()
    self:SetPoint("CENTER", parent, "LEFT", progress*parentWidth, 0)
end
local function CastBar_CreateMark(self)
    local parent = self.bar

    -- local m = CreateFrame("Frame",nil, parent)
    -- m:SetWidth(8)
    -- m:SetHeight(parent:GetHeight()*0.9)
    -- m:SetFrameLevel(4)
    -- m:SetAlpha(0.6)
    -- m:SetPoint("CENTER", parent, "LEFT",10,0)

    local white = "Interface\\BUTTONS\\WHITE8X8"
    local markTexPath = "Interface\\AddOns\\NugCast\\mark"
    local texture = parent:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(white)
    texture:SetWidth(pixelperfect(2, parent))
    texture:SetVertexColor(1,1,1,0.3)
    -- m.texture = texture

    --[[

    local spark = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetAlpha(0)
    spark:SetWidth(20)
    spark:SetHeight(16*4)
    -- spark:SetPoint("CENTER",m)
    spark:SetBlendMode('ADD')
    spark.mark = m
    spark.CatchUp = function(self)
        local p1, f, p2, x, y = self.mark:GetPoint()
        self:SetPoint(p1, f, p2, x, y)
    end
    spark:CatchUp()
    m.spark = spark

    local ag = spark:CreateAnimationGroup()
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(0)
    a1:SetToAlpha(1)
    a1:SetDuration(0.2)
    a1:SetOrder(1)
    local a2 = ag:CreateAnimation("Alpha")
    a2:SetFromAlpha(1)
    a2:SetToAlpha(0)
    a2:SetDuration(0.4)
    a2:SetOrder(2)

    ag:SetScript("OnFinished", function(self)
        self:GetParent():CatchUp()
    end)

    m.Anim = ag

    m.UpdatePosition = Mark_UpdatePosition


    return m
    ]]
    texture.UpdatePosition = Mark_UpdatePosition
    return texture
end

local function CastBar_HideMarksFrom(self, numStages)
    if not self.stages then return end
    for i=numStages+1,#self.stages do
        -- print("hiding", i)
        local mark = self.stages[i]
        mark:Hide()
    end
end
local function CastBar_UpdateStageConfig(self, numStages)
    self.stages = self.stages or {}
    self.numStages = numStages
    self.curStage = nil
    local unit = self.unit
    local percentages = UnitEmpoweredStagePercentages(self.unit, displayHoldArea)

    local stageTime = 0


    local lastOffset = 0
    local lastMarkPerc = 0
    for i=1,numStages do
        -- print("showing", i)
        self.stages[i] = self.stages[i] or CastBar_CreateMark(self)
        local mark = self.stages[i]
        mark:Show()

        local stageSection = percentages[i]
        -- local offset = lastOffset + (parentSize * stageSection)
		-- lastOffset = offset

        local markPerc = lastMarkPerc + stageSection
        lastMarkPerc = markPerc

        -- local stageDuration = GetUnitEmpowerStageDuration(unit, i-1)/1000
        -- stageTime = stageTime + stageDuration
        -- mark.stageTime = stageTime
        mark:UpdatePosition(markPerc)
    end

    self:HideMarksFrom(numStages)
end
local math_floor = math.floor

NugCast.FillFrame = function(self, f,width,height, unit, spark)
    f:SetWidth(width)
    f:SetHeight(height)

    local border = 2
    local outline = MakeBorder(f, "Interface\\BUTTONS\\WHITE8X8", -border, -border, -border, -border, -2)
    outline:SetVertexColor(0,0,0, 0.5)

    local ic = CreateFrame("Frame",nil,f)
    ic:SetPoint("TOPLEFT",f,"TOPLEFT", 0, 0)
    ic:SetWidth(height)
    ic:SetHeight(height)
    local ict = ic:CreateTexture(nil,"ARTWORK",nil,0)
    ict:SetTexCoord(.07, .93, .07, .93)
    ict:SetAllPoints(ic)
    f.icon = ict

    local texture = LSM:Fetch("statusbar", NugCast.db.profile.barTexture)

    local bar = CreateFrame("StatusBar",nil,f)
    f.bar = bar

    bar:SetFrameStrata("MEDIUM")
    bar:SetStatusBarTexture(texture)
    bar:SetHeight(height)
    bar:SetWidth(width - height - 1)
    bar:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)


    if spark then
    -- if true then
        local spark = bar:CreateTexture(nil, "ARTWORK", nil, 4)
        spark:SetBlendMode("ADD")
        spark:SetTexture("Interface\\AddOns\\NugCast\\spark.tga")
        spark:SetSize(bar:GetHeight()*2, bar:GetHeight())
        spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0,0)
        bar.spark = spark
    end


    f.Resize = ResizeFunc

    f.ResizeText = ResizeTextFunc


    local m = 0.4
    f.bar.SetColor = function(self, r,g,b)
        self:SetStatusBarColor(r,g,b)
        self.bg:SetVertexColor(r*m,g*m,b*m)
        if self.spark then
            self.spark:SetVertexColor(r,g,b)
        end
    end

    f.bar.bg = f.bar:CreateTexture(nil, "BACKGROUND")
	f.bar.bg:SetAllPoints(f.bar)
	f.bar.bg:SetTexture(texture)

    f.timeText = f.bar:CreateFontString();
    f.timeText:SetFont(LSM:Fetch("font", NugCast.db.profile.timeFont), NugCast.db.profile.timeFontSize)
    -- f.timeText:SetFont("Fonts\\FRIZQT___CYR.TTF",8)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetVertexColor(1,1,1)
    f.timeText:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",-6,0)
    f.timeText:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT",0,0)
    f.timeText:SetTextColor(unpack(NugCast.db.profile.textColor))

    local spellFontSize = NugCast.db.profile[unit].spellFontSize

    f.spellText = f.bar:CreateFontString();
    f.spellText:SetFont(LSM:Fetch("font", NugCast.db.profile.spellFont), spellFontSize)
    f.spellText:SetWidth(width/4*3 -12)
    f.spellText:SetHeight(height/2+1)
    f.spellText:SetJustifyH("CENTER")
    f.spellText:SetTextColor(unpack(NugCast.db.profile.textColor))
    f.spellText:SetPoint("LEFT", f.bar, "LEFT",6,0)
    -- f.spellText:SetAlpha(0.5)

    local faderGroup = f:CreateAnimationGroup()

    local fadeAnim = faderGroup:CreateAnimation("Alpha")
    fadeAnim:SetFromAlpha(1)
    fadeAnim:SetToAlpha(0)
    fadeAnim:SetDuration(0.5)
    faderGroup:SetScript("OnFinished", function(self)
        local parent = self:GetParent()
        parent:Hide()
    end)
    f.fader = faderGroup


    f.UpdateStageConfig = CastBar_UpdateStageConfig
    f.HideMarksFrom = CastBar_HideMarksFrom

    return f
end

NugCast.MakeDoubleCastbar = function(self, f,width,height)
    f:SetWidth(width)
    f:SetHeight(height)

    local border = 2
    local outline = MakeBorder(f, "Interface\\BUTTONS\\WHITE8X8", -border, -border, -border, -border, -2)
    outline:SetVertexColor(0,0,0, 0.5)

    local texture = LSM:Fetch("statusbar", NugCast.db.profile.barTexture)

    local ic = CreateFrame("Frame",nil,f)
    -- ic:SetPoint("TOPLEFT",f,"TOPLEFT", 0, 0)
    ic:SetPoint("CENTER",f,"CENTER", 0, 0)
    ic:SetWidth(height)
    ic:SetHeight(height)
    local ict = ic:CreateTexture(nil,"ARTWORK",nil,0)
    ict:SetTexCoord(.07, .93, .07, .93)
    ict:SetAllPoints(ic)
    f.icon = ict

    f.bar = CreateFrame("Frame",nil,f)
    f.bar:SetFrameStrata("MEDIUM")

    local left = CreateFrame("StatusBar",nil,f.bar)
    left:SetStatusBarTexture(texture)
    left:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    left:SetHeight(height)
    left:SetWidth((width - height)/2 - 2)
    left:SetPoint("TOPLEFT", f.bar, "TOPLEFT",0,0)
    local leftbg = left:CreateTexture(nil, "BORDER")
    leftbg:SetAllPoints(left)
    leftbg:SetTexture(texture)
    left.bg = leftbg

    local right = CreateFrame("StatusBar",nil,f.bar)
    right:SetStatusBarTexture(texture)
    right:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    right:SetHeight(height)
    right:SetWidth((width - height)/2 - 2)
    right:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",0,0)
    local rightbg = right:CreateTexture(nil, "BORDER")
    rightbg:SetAllPoints(right)
    rightbg:SetTexture(texture)
    right.bg = rightbg

    f.bar.left = left
    f.bar.right = right

    f.bar.SetMinMaxValues = function(self, min, max)
        self.min = min
        self.max = max
        self.left:SetMinMaxValues(min,max)
        self.right:SetMinMaxValues(min,max)
    end
    f.bar:SetMinMaxValues(0,100)

    f.bar.SetValue = function(self,v)
        self.left:SetValue(v)
        self.right:SetValue(self.max-v+self.min)
    end

    f.bar.SetStatusBarColor = function(self, ...)
        self.left:SetStatusBarColor(...)
        self.right:SetStatusBarColor(...)
    end

    local m = 0.5
    f.bar.SetColor = function(self, r,g,b)
        self.right:SetStatusBarColor(r,g,b)
        self.right.bg:SetVertexColor(r*m,g*m,b*m)
        self.left:SetStatusBarColor(r*m,g*m,b*m)
        self.left.bg:SetVertexColor(r,g,b)
    end

    -- f.bar:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)
    f.bar:SetAllPoints(f)

    -- f.bar.bg = f.bar:CreateTexture(nil, "BORDER")
    -- f.bar.bg:SetAllPoints(f.bar)
    -- f.bar.bg:SetTexture(texture)

    f.timeText = f.bar:CreateFontString();
    f.timeText:SetFont("Fonts\\FRIZQT___CYR.TTF",8)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetVertexColor(1,1,1)
    f.timeText:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",-6,0)
    f.timeText:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT",0,0)

    f.spellText = f.bar:CreateFontString();
    f.spellText:SetFont("Fonts\\FRIZQT___CYR.TTF",height/2)
    f.spellText:SetWidth(width/4*3 -12)
    f.spellText:SetHeight(height/2+1)
    f.spellText:SetJustifyH("CENTER")
    f.spellText:SetVertexColor(1,1,1)
    f.spellText:SetPoint("LEFT", f.bar, "LEFT",6,0)
    f.spellText:SetAlpha(0.5)


    return f
end


local function FindFreeCastbar()
    for i=1, MAX_NAMEPLATE_CASTBARS do
        local bar = npCastbars[i]
        if bar and not bar.isActive then
            return  bar
        end
    end
end
NugCast.FindFreeCastbar = FindFreeCastbar


local ordered_bars = {}
local function bar_sort_func(a,b)
    -- local ap = a.isTarget
    -- local bp = b.isTarget
    -- if ap == bp then
        return a.endTime < b.endTime
    -- else
        -- return ap > bp
    -- end
end

function NugCast:ArrangeNameplateTimers()

end

function NugCast:CreateNameplateCastbars()
    local npCastbarsHeader = CreateFrame("Frame", nil, UIParent)
    -- npCastbarsHeader:Hide()
    npCastbarsHeader:SetWidth(10)
    npCastbarsHeader:SetHeight(10)
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_START")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_STOP")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_FAILED")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

    npCastbarsHeader:RegisterEvent("PLAYER_TARGET_CHANGED")

    -- npCastbarsHeader:RegisterEvent("NAME_PLATE_CREATED")
    npCastbarsHeader:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    npCastbarsHeader:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    npCastbarsHeader.Arrange = function(self)
        table.wipe(ordered_bars)
        for i=1, MAX_NAMEPLATE_CASTBARS do
            local bar = npCastbars[i]
            if bar.isActive then--and not UnitIsUnit(bar.unit, "target") then
                bar.isTarget = UnitIsUnit(bar.unit, "target") and 1 or 0
                if bar.isTarget == 1 then
                    if NugCast.db.profile.nameplateExcludeTarget then
                        bar:Hide()
                    else
                        table.insert(ordered_bars, bar)
                        bar:Show()
                        bar.bar:SetColor(unpack(NugCast.db.profile.highlightColor))
                    end
                else
                    table.insert(ordered_bars, bar)
                    bar:Show()
                    if not NugCast.db.profile.nameplateExcludeTarget then
                        local color = (bar.channeling and NugCast.db.profile.channelColor or NugCast.db.profile.castColor)
                        bar.bar:SetColor(unpack(color))
                    end
                end

            end
        end

        table.sort(ordered_bars, bar_sort_func)
        local prev
        local gap = 0
        -- local xgap = 0
        -- local firstTimer = ordered_bars[1]
        -- local gotTarget = true
        -- if firstTimer and firstTimer.isTarget == 0 then
        --     gap = -5-firstTimer:GetHeight()
        --     gotTarget = false
        -- end
        for i, timer in ipairs(ordered_bars) do
            -- timer:ClearAllPoints()
            timer:SetPoint("TOPLEFT", prev or self, prev and "BOTTOMLEFT" or "TOPLEFT", 0, gap)
            gap = -5
            prev = timer
        end
    end

    npCastbarsHeader:SetScript("OnEvent", function(self, event, unit, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            return npCastbarsHeader:Arrange()
        end

        if not unit:match("nameplate") then return end
        if UnitIsUnit(unit, "player") then return end

        -- print('hello2',castbar, event, npCastbarsByUnit[unit])
        if event == "NAME_PLATE_UNIT_REMOVED" then
            local t = npCastbarsByUnit[unit]
            if t then
                t:Deactivate()
                t:Hide()
            end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            if UnitCastingInfo(unit) then
                event = "UNIT_SPELLCAST_START"
                local castbar = FindFreeCastbar()
                if castbar then
                    castbar.unit = unit
                    npCastbarsByUnit[unit] = castbar
                    NugCast[event](castbar, event, unit, ...)
                end
            elseif UnitChannelInfo(unit) then
                event = "UNIT_SPELLCAST_CHANNEL_START"
                local castbar = FindFreeCastbar()
                if castbar then
                    castbar.unit = unit
                    npCastbarsByUnit[unit] = castbar
                    NugCast[event](castbar, event, unit, ...)
                end
            end
        elseif (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") and not npCastbarsByUnit[unit] then
            if not UnitIsEnemy("player", unit) then return end
            local castbar = FindFreeCastbar()
            if castbar then
                castbar.unit = unit
                npCastbarsByUnit[unit] = castbar
                NugCast[event](castbar, event, unit, ...)
            end
        else
            local castbar = npCastbarsByUnit[unit]
            if castbar then
                NugCast[event](castbar, event, unit, ...)
            end
        end

        npCastbarsHeader:Arrange()
    end)

    for i=1, MAX_NAMEPLATE_CASTBARS do
        local f = CreateFrame("Frame", nil, npCastbarsHeader)
        self:FillFrame(f, NugCast.db.profile.nameplates.width, NugCast.db.profile.nameplates.height, "nameplates")
        -- self.bar:SetColor(unpack(nameplateBarColor))
        self:AddMore(f)

        f.Deactivate = function(self)
            if self.unit then
                npCastbarsByUnit[self.unit] = nil
                self.unit = nil
            end
            self.isActive = false
        end

        f.endTime = 0

        -- f:SetScript("OnHide", function(self)

        -- end)

        -- f:SetPoint("TOPLEFT", npCastbarsHeader, "TOPLEFT", 0, 0 + i*30)

        f:Hide()
        f.UpdateCastingInfo = UpdateCastingInfo
        table.insert(npCastbars, f)
    end

    return npCastbarsHeader
end













function NugCast:CreateAnchor(db_tbl)
    local f = CreateFrame("Frame",nil,UIParent)
    f:SetHeight(20)
    f:SetWidth(20)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetFrameStrata("HIGH")
    f:Hide()

    local t = f:CreateTexture(nil,"BACKGROUND")
    t:SetTexture("Interface\\Buttons\\UI-RadioButton")
    t:SetTexCoord(0,0.25,0,1)
    t:SetAllPoints(f)

    t = f:CreateTexture(nil,"BACKGROUND")
    t:SetTexture("Interface\\Buttons\\UI-RadioButton")
    t:SetTexCoord(0.25,0.49,0,1)
    t:SetVertexColor(1, 0, 0)
    t:SetAllPoints(f)

    f.UpdateAnchor = function(self, pos)
        self.db_tbl = pos
        self:SetPoint(pos.point, pos.parent, pos.to, pos.x, pos.y)
    end
    f:UpdateAnchor(db_tbl)

    f:SetScript("OnMouseDown",function(self)
        self:StartMoving()
    end)
    f:SetScript("OnMouseUp",function(self)
            local opts = self.db_tbl
            self:StopMovingOrSizing();
            local point,_,to,x,y = self:GetPoint(1)
            opts.point = point
            opts.parent = "UIParent"
            opts.to = to
            opts.x = x
            opts.y = y
    end)

    return f
end



local ParseOpts = function(str)
    local t = {}
    local capture = function(k,v)
        t[k:lower()] = tonumber(v) or v
        return ""
    end
    str:gsub("(%w+)%s*=%s*%[%[(.-)%]%]", capture):gsub("(%w+)%s*=%s*(%S+)", capture)
    return t
end
NugCast.Commands = {
    ["gui"] = function()
        if not NugCast.optionsPanel then
            local panelFrame, categoryID = NugCast:CreateGUI()
            NugCast.optionsPanel = panelFrame
            NugCast.settingsCategoryID = categoryID
        end
        if NugCast.optionsPanel and not InCombatLockdown() then
            Settings.OpenToCategory(NugCast.settingsCategoryID)
        end
    end,
    ["unlock"] = function()
        for unit, anchor in pairs(anchors) do
            anchor:Show()
        end
        local duration = C_DurationUtil.CreateDuration()

        local now = GetTime()
        duration:SetTimeFromStart(now, 20)

        NugCastPlayer:UpdateCastingInfo("Player","Interface\\Icons\\inv_misc_questionmark",now, duration, 1, true)
        if NugCastTarget then
            NugCastTarget:UpdateCastingInfo("Target","Interface\\Icons\\inv_misc_questionmark",now, duration, 1, true)
        end
        if NugCastFocus then
            NugCastFocus:UpdateCastingInfo("Focus","Interface\\Icons\\inv_misc_questionmark",now, duration, 1, true)
        end
        --[[
        for i=1, 3 do
            local castbar = NugCast.FindFreeCastbar()
            if not castbar then break end
            castbar.unit = "nameplate"..i
            castbar:UpdateCastingInfo("Nameplate"..i,"Interface\\Icons\\inv_misc_questionmark",now - 15000, now + 15000, 1, true)
        end
        if NugCastPlayerNameplateHeader then
            NugCastPlayerNameplateHeader:Arrange()
        end
        ]]
    end,
    ["lock"] = function()
        for unit, anchor in pairs(anchors) do
            anchor:Hide()
        end
        NugCastPlayer:Hide()
        if NugCastTarget then NugCastTarget:Hide() end
        if NugCastFocus then NugCastFocus:Hide() end
        for _, castbar in ipairs(npCastbars) do
            castbar:Deactivate()
            castbar:Hide()
        end
        if NugCastPlayerNameplateHeader then
            NugCastPlayerNameplateHeader:Arrange()
        end
    end,
    ["nameplatebars"] = function()
        NugCast.db.global.nameplateCastbars = not NugCast.db.global.nameplateCastbars
        print("Nameplate castbars turned "..(NugCast.db.global.nameplateCastbars and "on" or "off")..". Will take effect after /reload")
    end,

    ["excludetarget"] = function()
        NugCast.db.profile.nameplateExcludeTarget = not NugCast.db.profile.nameplateExcludeTarget
    end,

    ["targetcastbar"] = function()
        NugCast.db.global.targetCastbar = not NugCast.db.global.targetCastbar
        print("Target castbar turned "..(NugCast.db.global.targetCastbar and "on" or "off")..". Will take effect after /reload")
    end,

    ["set"] = function(v)
        local p = ParseOpts(v)
        local unit = p["unit"]
        if unit then
            if p.width then NugCast.db.profile[unit].width = p.width end
            if p.height then NugCast.db.profile[unit].height = p.height end

            if unit == "player" then
                NugCastPlayer:Resize(NugCast.db.profile.player.width, NugCast.db.profile.player.height)
            elseif unit == "target" then
                NugCastTarget:Resize(NugCast.db.profile.target.width, NugCast.db.profile.target.height)
            elseif unit == "nameplates" then
                for i, timer in ipairs(npCastbars) do
                    timer:Resize(NugCast.db.profile.nameplates.width, NugCast.db.profile.nameplates.height)
                end
            end
        end
    end,
}

function NugCast.SlashCmd(msg)
    local k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then print([[Usage:
      |cff00ff00/nugcast gui|r
      |cff00ff00/nugcast lock|r
      |cff00ff00/nugcast unlock|r
      |cff00ff00/nugcast excludetarget|r
      |cff00ff00/nugcast targetcastbar|r
      |cff00ff00/nugcast set|r unit=<player||target||nameplates> width=<num> height=<num>
      |cff00ff00/nugcast nameplatebars|r
    ]]
    )end
    if NugCast.Commands[k] then
        NugCast.Commands[k](v)
    end

end



function NugCast:UpdatePosition()
    for aname, anchor in pairs(anchors) do
        anchor:UpdateAnchor(self.db.profile.anchors[aname])
    end
end
function NugCast:Resize()
    if NugCastPlayer then
        NugCastPlayer:Resize(NugCast.db.profile.player.width, NugCast.db.profile.player.height)
        if self.db.profile.player.notext then
            NugCastPlayer.spellText:Hide()
            NugCastPlayer.timeText:Hide()
        else
            NugCastPlayer.spellText:Show()
            NugCastPlayer.timeText:Show()
        end
    end
    if NugCastTarget then
        NugCastTarget:Resize(NugCast.db.profile.target.width, NugCast.db.profile.target.height)
    end
    if NugCastFocus then
        NugCastFocus:Resize(NugCast.db.profile.focus.width, NugCast.db.profile.focus.height)
    end
    for i, timer in ipairs(npCastbars) do
        timer:Resize(NugCast.db.profile.nameplates.width, NugCast.db.profile.nameplates.height)
    end
end
function NugCast:ResizeText()
    if NugCastPlayer then
        NugCastPlayer:ResizeText(NugCast.db.profile.player.spellFontSize)
    end
    if NugCastTarget then
        NugCastTarget:ResizeText(NugCast.db.profile.target.spellFontSize)
    end
    if NugCastFocus then
        NugCastFocus:ResizeText(NugCast.db.profile.target.spellFontSize)
    end
    for i, timer in ipairs(npCastbars) do
        timer:ResizeText(NugCast.db.profile.nameplates.spellFontSize)
    end
end


function ns.GetProfileList(db)
    local profiles = db:GetProfiles()
    local t = {}
    for i,v in ipairs(profiles) do
        t[v] = v
    end
    return t
end
local GetProfileList = ns.GetProfileList

function NugCast:CreateGUI()
    local opt = {
        type = 'group',
        name = "NugCast Settings",
        order = 1,
        args = {
            unlock = {
                name = "Unlock",
                type = "execute",
                desc = "Unlock anchor for dragging",
                func = function() NugCast.Commands.unlock() end,
                order = 1,
            },
            lock = {
                name = "Lock",
                type = "execute",
                desc = "Lock anchor",
                func = function() NugCast.Commands.lock() end,
                order = 2,
            },
            resetToDefault = {
                name = "Restore Defaults",
                type = 'execute',
                func = function()
                    NugCast.db:ResetProfile()
                end,
                order = 3,
            },
            toggleGroup = {

                type = "group",
                guiInline = true,
                name = " ",
                order = 4,
                args = {
                    playerCastbar = {
                        name = "Player Castbar",
                        type = "toggle",
                        confirm = true,
						confirmText = "Warning: Requires UI reloading.",
                        order = 1,
                        get = function(info) return NugCast.db.global.playerCastbar end,
                        set = function(info, v)
                            NugCast.db.global.playerCastbar = not NugCast.db.global.playerCastbar
                            ReloadUI()
                        end
                    },
                    targetCastbar = {
                        name = "Target Castbar",
                        type = "toggle",
                        confirm = true,
						confirmText = "Warning: Requires UI reloading.",
                        order = 1,
                        get = function(info) return NugCast.db.global.targetCastbar end,
                        set = function(info, v)
                            NugCast.db.global.targetCastbar = not NugCast.db.global.targetCastbar
                            ReloadUI()
                        end
                    },
                    npCastbars = {
                        name = "Nameplate Castbars",
                        type = "toggle",
                        disabled = APILevel == 1,
                        confirm = true,
						confirmText = "Warning: Requires UI reloading.",
                        order = 2,
                        get = function(info) return NugCast.db.global.nameplateCastbars end,
                        set = function(info, v)
                            NugCast.db.global.nameplateCastbars = not NugCast.db.global.nameplateCastbars
                            ReloadUI()
                        end
                    },
                    focusCastbar = {
                        name = "Focus Castbar",
                        type = "toggle",
                        disabled = APILevel == 1,
                        confirm = true,
						confirmText = "Warning: Requires UI reloading.",
                        order = 4,
                        get = function(info) return NugCast.db.global.focusCastbar end,
                        set = function(info, v)
                            NugCast.db.global.focusCastbar = not NugCast.db.global.focusCastbar
                            ReloadUI()
                        end
                    },
                },
            },
            currentProfile = {
                type = 'group',
                order = 5,
                name = L"Current Profile",
                guiInline = true,
                args = {
                    curProfile = {
                        name = "",
                        type = 'select',
                        width = 1.5,
                        order = 1,
                        values = function()
                            return ns.GetProfileList(NugCast.db)
                        end,
                        get = function(info)
                            return NugCast.db:GetCurrentProfile()
                        end,
                        set = function(info, v)
                            NugCast.db:SetProfile(v)
                        end,
                    },
                    copyButton = {
                        name = L"Copy",
                        type = 'execute',
                        order = 2,
                        width = 0.5,
                        func = function(info)
                            local p = NugCast.db:GetCurrentProfile()
                            ns.storedProfile = p
                        end,
                    },
                    pasteButton = {
                        name = L"Paste",
                        type = 'execute',
                        order = 3,
                        width = 0.5,
                        disabled = function()
                            return ns.storedProfile == nil
                        end,
                        func = function(info)
                            if ns.storedProfile then
                                NugCast.db:CopyProfile(ns.storedProfile, true)
                            end
                        end,
                    },
                    deleteButton = {
                        name = L"Delete",
                        type = 'execute',
                        order = 4,
                        confirm = true,
                        confirmText = L"Are you sure?",
                        width = 0.5,
                        disabled = function()
                            return NugCast.db:GetCurrentProfile() == "Default"
                        end,
                        func = function(info)
                            local p = NugCast.db:GetCurrentProfile()
                            NugCast.db:SetProfile("Default")
                            NugCast.db:DeleteProfile(p, true)
                        end,
                    },
                    newProfileName = {
                        name = L"New Profile Name",
                        type = 'input',
                        order = 5,
                        width = 2,
                        get = function(info) return ns.newProfileName end,
                        set = function(info, v)
                            ns.newProfileName = v
                        end,
                    },
                    createButton = {
                        name = L"Create New Profile",
                        type = 'execute',
                        order = 6,
                        disabled = function()
                            return not ns.newProfileName
                            or strlenutf8(ns.newProfileName) == 0
                            or NugCast.db.profiles[ns.newProfileName]
                        end,
                        func = function(info)
                            if ns.newProfileName and strlenutf8(ns.newProfileName) > 0 then
                                NugCast.db:SetProfile(ns.newProfileName)
                                NugCast.db:CopyProfile("Default", true)
                                ns.newProfileName = ""
                            end
                        end,
                    },
                },
            },
            anchors = {
                type = "group",
                name = " ",
                guiInline = true,
                order = 6,
                args = {
                    colorGroup = {
                        type = "group",
                        name = "",
                        order = 1,
                        args = {
                            castColor = {
                                name = "Cast Color",
                                type = 'color',
                                get = function(info)
                                    local r,g,b = unpack(NugCast.db.profile.castColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugCast.db.profile.castColor = {r,g,b}
                                end,
                                order = 1,
                            },
                            channelColor = {
                                name = "Channel Color",
                                type = 'color',
                                order = 2,
                                get = function(info)
                                    local r,g,b = unpack(NugCast.db.profile.channelColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugCast.db.profile.channelColor = {r,g,b}
                                end,
                            },
                            highlightColor = {
                                name = "Highlight Color",
                                type = 'color',
                                disabled = APILevel == 1,
                                desc = "Used in nameplate castbars to mark current target when it's not excluded",
                                width = 1.3,
                                order = 3,
                                get = function(info)
                                    local r,g,b = unpack(NugCast.db.profile.highlightColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugCast.db.profile.highlightColor = {r,g,b}
                                end,
                            },
                            successColor = {
                                name = "Success Color",
                                type = 'color',
                                width = 1,
                                order = 3.1,
                                get = function(info)
                                    local r,g,b = unpack(NugCast.db.profile.successColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugCast.db.profile.successColor = {r,g,b}
                                end,
                            },
                            failedColor = {
                                name = "Failed Color",
                                type = 'color',
                                width = 0.85,
                                order = 3.2,
                                get = function(info)
                                    local r,g,b = unpack(NugCast.db.profile.failedColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugCast.db.profile.failedColor = {r,g,b}
                                end,
                            },
                            notInterruptibleColorEnabled = {
                                name = "",
                                width = 0.15,
                                type = "toggle",
                                order = 5,
                                get = function(info) return NugCast.db.profile.notInterruptibleColorEnabled end,
                                set = function(info, v)
                                    NugCast.db.profile.notInterruptibleColorEnabled = not NugCast.db.profile.notInterruptibleColorEnabled
                                end
                            },
                            notInterruptibleColor = {
                                name = "Non-Interruptible Color",
                                type = 'color',
                                width = 1,
                                disabled = function() return not NugCast.db.profile.notInterruptibleColorEnabled end,
                                order = 5.5,
                                get = function(info)
                                    local r,g,b,a = unpack(NugCast.db.profile.notInterruptibleColor)
                                    return r,g,b,a
                                end,
                                set = function(info, r, g, b, a)
                                    NugCast.db.profile.notInterruptibleColor = {r,g,b, a}
                                end,
                            },
                            textColor = {
                                name = "Text Color & Alpha",
                                type = 'color',
                                hasAlpha = true,
                                order = 6,
                                get = function(info)
                                    local r,g,b,a = unpack(NugCast.db.profile.textColor)
                                    return r,g,b,a
                                end,
                                set = function(info, r, g, b, a)
                                    NugCast.db.profile.textColor = {r,g,b, a}
                                    NugCast:ResizeText()
                                end,
                            },
                            texture = {
                                type = "select",
                                name = "Texture",
                                order = 10,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugCast.db.profile.barTexture end,
                                set = function(info, value)
                                    NugCast.db.profile.barTexture = value
                                    NugCast:Resize()
                                end,
                                values = LSM:HashTable("statusbar"),
                                dialogControl = "LSM30_Statusbar",
                            },
                        },
                    },
                    barGroup = {
                        type = "group",
                        name = " ",
                        order = 2,
                        args = {

                            playerWidth = {
                                name = "Player Bar Width",
                                type = "range",
                                get = function(info) return NugCast.db.profile.player.width end,
                                set = function(info, v)
                                    NugCast.db.profile.player.width = tonumber(v)
                                    NugCast:Resize()
                                end,
                                min = 30,
                                max = 1000,
                                step = 1,
                                order = 1,
                            },
                            playerHeight = {
                                name = "Player Bar Height",
                                type = "range",
                                get = function(info) return NugCast.db.profile.player.height end,
                                set = function(info, v)
                                    NugCast.db.profile.player.height = tonumber(v)
                                    NugCast:Resize()
                                end,
                                min = 10,
                                max = 100,
                                step = 1,
                                order = 2,
                            },
                            playerFontSize = {
                                name = "Player Font Size",
                                type = "range",
                                order = 3,
                                get = function(info) return NugCast.db.profile.player.spellFontSize end,
                                set = function(info, v)
                                    NugCast.db.profile.player.spellFontSize = tonumber(v)
                                    NugCast:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },

                            targetWidth = {
                                name = "Target Bar Width",
                                type = "range",
                                get = function(info) return NugCast.db.profile.target.width end,
                                set = function(info, v)
                                    NugCast.db.profile.target.width = tonumber(v)
                                    NugCast:Resize()
                                end,
                                min = 30,
                                max = 1000,
                                step = 1,
                                order = 4,
                            },
                            targetHeight = {
                                name = "Target Bar Height",
                                type = "range",
                                get = function(info) return NugCast.db.profile.target.height end,
                                set = function(info, v)
                                    NugCast.db.profile.target.height = tonumber(v)
                                    NugCast:Resize()
                                end,
                                min = 10,
                                max = 100,
                                step = 1,
                                order = 5,
                            },
                            targetFontSize = {
                                name = "Target Font Size",
                                type = "range",
                                order = 6,
                                get = function(info) return NugCast.db.profile.target.spellFontSize end,
                                set = function(info, v)
                                    NugCast.db.profile.target.spellFontSize = tonumber(v)
                                    NugCast:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },

                            focusWidth = {
                                name = "Focus Bar Width",
                                type = "range",
                                get = function(info) return NugCast.db.profile.focus.width end,
                                set = function(info, v)
                                    NugCast.db.profile.focus.width = tonumber(v)
                                    NugCast:Resize()
                                end,
                                min = 30,
                                max = 1000,
                                step = 1,
                                order = 6.1,
                            },
                            focusHeight = {
                                name = "Focus Bar Height",
                                type = "range",
                                get = function(info) return NugCast.db.profile.focus.height end,
                                set = function(info, v)
                                    NugCast.db.profile.focus.height = tonumber(v)
                                    NugCast:Resize()
                                end,
                                min = 10,
                                max = 100,
                                step = 1,
                                order = 6.2,
                            },
                            focusFontSize = {
                                name = "Focus Font Size",
                                type = "range",
                                order = 6.3,
                                get = function(info) return NugCast.db.profile.focus.spellFontSize end,
                                set = function(info, v)
                                    NugCast.db.profile.focus.spellFontSize = tonumber(v)
                                    NugCast:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },

                            nameplatesWidth = {
                                name = "Nameplates Bar Width",
                                type = "range",
                                disabled = APILevel == 1,
                                get = function(info) return NugCast.db.profile.nameplates.width end,
                                set = function(info, v)
                                    NugCast.db.profile.nameplates.width = tonumber(v)
                                    NugCast:Resize()
                                end,
                                min = 30,
                                max = 300,
                                step = 1,
                                order = 7,
                            },
                            nameplatesHeight = {
                                name = "Nameplates Bar Height",
                                type = "range",
                                disabled = APILevel == 1,
                                get = function(info) return NugCast.db.profile.nameplates.height end,
                                set = function(info, v)
                                    NugCast.db.profile.nameplates.height = tonumber(v)
                                    NugCast:Resize()
                                end,
                                min = 10,
                                max = 60,
                                step = 1,
                                order = 8,
                            },
                            nameplateFontSize = {
                                name = "Enemies Font Size",
                                type = "range",
                                disabled = APILevel == 1,
                                order = 9,
                                get = function(info) return NugCast.db.profile.nameplates.spellFontSize end,
                                set = function(info, v)
                                    NugCast.db.profile.nameplates.spellFontSize = tonumber(v)
                                    NugCast:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },

                        },
                    },

                    textGroup = {

                        type = "group",
                        name = " ",
                        order = 3,
                        args = {

                            font1 = {
                                type = "select",
                                name = "Spell Font",
                                order = 1,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugCast.db.profile.spellFont end,
                                set = function(info, value)
                                    NugCast.db.profile.spellFont = value
                                    NugCast:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },

                            font2 = {
                                type = "select",
                                name = "Time Font",
                                order = 3,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugCast.db.profile.timeFont end,
                                set = function(info, value)
                                    NugCast.db.profile.timeFont = value
                                    NugCast:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },
                            font2Size = {
                                name = "Time Font Size",
                                type = "range",
                                order = 4,
                                get = function(info) return NugCast.db.profile.timeFontSize end,
                                set = function(info, v)
                                    NugCast.db.profile.timeFontSize = tonumber(v)
                                    NugCast:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },
                        },
                    },
                    textOnPlayer = {
                        name = "Text on Player Castbar",
                        type = "toggle",
                        width = "full",
                        order = 19,
                        get = function(info) return not self.db.profile.player.notext end,
                        set = function(info, v)
                            self.db.profile.player.notext = not self.db.profile.player.notext
                            NugCast:Resize()
                        end
                    },
                    excludeTarget = {
                        name = "Nameplate Exclude Target",
                        desc = "from nameplate castbars",
                        type = "toggle",
                        disabled = APILevel == 1,
                        width = "full",
                        order = 20,
                        get = function(info) return NugCast.db.profile.nameplateExcludeTarget end,
                        set = function(info, v) NugCast.Commands.excludetarget() end
                    },

                },
            }, --
        },
    }

    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    AceConfigRegistry:RegisterOptionsTable("NugCastOptions", opt)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local panelFrame, categoryID = AceConfigDialog:AddToBlizOptions("NugCastOptions", "NugCast")

    return panelFrame, categoryID
end


do
    local SetCoord = function(self, left, right, top, bottom)
        self.left = left
        self.right = right
        self.top =  top
        self.bottom =  bottom
        self.t:SetTexCoord(left,right,top,bottom)
    end
    local SetStatusBarTexture = function (self, texture)
        self.t:SetTexture(texture)
    end
    local GetStatusBarTexture = function (self)
        return self.t:GetTexture()
    end
    local SetStatusBarColor = function(self, r,g,b,a)
        self.t:SetVertexColor(r,g,b,a)
    end

    local GetMinMaxValues = function(self)
        return self.minvalue, self.maxvalue
    end

    local SetMinMaxValues = function(self, min, max)
        if max > min then
            self.minvalue = min
            self.maxvalue = max
        else
            self.minvalue = 0
            self.maxvalue = 1
        end
    end

    local SetValue = function(self, val)
        if not val then return end

        local pos = (val-self.minvalue)/(self.maxvalue-self.minvalue)
        if pos == 0 then pos = 0.001 end
        if pos > 1 then pos = 1 end
        local h = self:GetWidth()*pos
        self.t:SetWidth(h)
        -- print ("pos: "..pos)
        -- print (string.format("min:%s max:%s",self.minvalue,self.maxvalue))
        -- print((self.bottom-self.top)*pos)
        -- print(string.format("coords: %s %s %s %s",self.left,self.right, self.bottom - (self.bottom-self.top)*pos , self.bottom))
        self.t:SetTexCoord(0, 1*pos, 0, 1)
    end

    function NugCast:CreateHorizontalBar(name, parent)
        local f = CreateFrame("Frame", name, parent)
        -- f.left = 0
        -- f.right = 1
        -- f.top =  0
        -- f.bottom =  1
        f.minvalue = 0
        f.maxvalue = 100

        local t = f:CreateTexture(nil, "ARTWORK")

        t:SetPoint("TOPLEFT", f, "TOPLEFT",0,0)
        t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT",0,0)

        f.t = t

        f.SetCoord = SetCoord
        f.SetStatusBarTexture = SetStatusBarTexture
        f.GetStatusBarTexture = GetStatusBarTexture
        f.SetStatusBarColor = SetStatusBarColor
        f.GetMinMaxValues = GetMinMaxValues
        f.SetMinMaxValues = SetMinMaxValues
        f.SetValue = SetValue

        f:Show()

        return f
    end
end


do
    local CURRENT_DB_VERSION = 1
    function NugCast:DoMigrations(db)
        if not next(db) or db.DB_VERSION == CURRENT_DB_VERSION then -- skip if db is empty or current
            db.DB_VERSION = CURRENT_DB_VERSION
            return
        end

        if db.DB_VERSION == nil then
            db.global = {}
            db.global.playerCastbar = db.playerCastbar
            db.global.targetCastbar = db.targetCastbar
            db.global.focusCastbar = db.focusCastbar
            db.global.nameplateCastbars = db.nameplateCastbars

            db.profiles = {
                Default = {}
            }
            local default_profile = db.profiles["Default"]

            default_profile.anchors = db.anchors
            default_profile.player = db.player
            default_profile.target = db.target
            default_profile.focus = db.focus
            default_profile.nameplates = db.nameplates
            default_profile.barTexture = db.barTexture
            default_profile.spellFont = db.spellFont
            default_profile.timeFont = db.timeFont
            default_profile.timeFontSize = db.timeFontSize
            default_profile.textColor = db.textColor
            default_profile.castColor = db.castColor
            default_profile.channelColor = db.channelColor
            default_profile.highlightColor = db.highlightColor
            default_profile.notInterruptibleColorEnabled = db.notInterruptibleColorEnabled
            default_profile.notInterruptibleColor = db.notInterruptibleColor
            default_profile.nameplateExcludeTarget = db.nameplateExcludeTarget


            db.DB_VERSION = 1
        end

        db.DB_VERSION = CURRENT_DB_VERSION
    end
end
