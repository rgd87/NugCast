local addonName, ns = ...

NugCast = CreateFrame("Frame",nil,UIParent)

local NugCast = _G.NugCast
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
if isClassic then
    UnitCastingInfo = CastingInfo
    UnitChannelInfo = ChannelInfo
end

local NugCastDB

local LSM = LibStub("LibSharedMedia-3.0")
local LibCC = isClassic and LibStub("LibClassicCasterino", true)

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
        nameplateExcludeTarget = true,
    }
}


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

    if isClassic then
        self.db.global.focusCastbar = false
        self.db.global.nameplateCastbars = false
    end

    if self.db.global.playerCastbar then
        local player = NugCast:SpawnCastBar("player", self.db.profile.player.width, self.db.profile.player.height)
        if self.db.profile.player.notext then
            player.spellText:Hide()
            player.timeText:Hide()
        end
        CastingBarFrame:UnregisterAllEvents()
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

        local target_anchor = self:CreateAnchor(self.db.profile.anchors["target"])
        target:SetPoint("TOPLEFT",target_anchor,"BOTTOMRIGHT",0,0)
        anchors["target"] = target_anchor
    end

    if self.db.global.focusCastbar and not isClassic then
        local focus = NugCast:SpawnCastBar("focus", self.db.profile.target.width, self.db.profile.target.height)
        focus:RegisterEvent("PLAYER_FOCUS_CHANGED")
        NugCast:AddMore(focus)
        NugCastFocus = focus

        local focus_anchor = self:CreateAnchor(self.db.profile.anchors["focus"])
        focus:SetPoint("TOPLEFT",focus_anchor,"BOTTOMRIGHT",0,0)
        anchors["focus"] = focus_anchor
    end
    -- if oUF_Focus then focus:SetPoint("TOPRIGHT",oUF_Focus,"BOTTOMRIGHT", 0,-5)
    -- else focus:SetPoint("CENTER",UIParent,"CENTER", 0,300) end


    if self.db.global.nameplateCastbars and not isClassic then
        local npheader = NugCast:CreateNameplateCastbars()
        NugCastPlayerNameplateHeader = npheader
        local nameplates_anchor = self:CreateAnchor(self.db.profile.anchors["nameplates"])
        npheader:SetPoint("TOPLEFT", nameplates_anchor,"BOTTOMRIGHT",0,0)
        -- npheader:SetPoint("CENTER", UIParent, "CENTER",0,0)
        anchors["nameplates"] = nameplates_anchor
    end


    SLASH_NUGCAST1= "/nugcast"
    SlashCmdList["NUGCAST"] = NugCast.SlashCmd

    local f = CreateFrame('Frame', nil, InterfaceOptionsFrame)
    f:SetScript('OnShow', function(self)
        self:SetScript('OnShow', nil)

        if not NugCast.optionsPanel then
            NugCast.optionsPanel = NugCast:CreateGUI()
        end
    end)
end

function NugCast:Reconfigure()
    self:UpdatePosition()
    self:Resize()
    self:ResizeText()
end

local TimerOnUpdate = function(self, elapsed)
    local v = self.elapsed + elapsed
    local remains = self.endTime - (v+self.startTime)
    self.elapsed = v

    if self.fadingStartTime then
        local t = GetTime() - self.fadingStartTime
        local a = 4* math.max(0, 0.25 - t)
        self:SetAlpha(a)
        self.bar:SetValue(self.endTime)
        if a < 0 then
            self:Hide()
        end
    else
        local val
        if self.channeling then val = self.startTime + remains
        else val = self.endTime - remains end
        self.bar:SetValue(val)
        self.timeText:SetFormattedText("%.1f",remains)
        if remains <= -0.5 then
            if self.Deactivate then self:Deactivate() end
            self:Hide()
        end
    end
end

local defaultCastColor = { 0.6, 0, 1 }
local defaultChannelColor = {200/255,50/255,95/255 }
local highlightColor = { 206/255, 4/256, 56/256 }
local coloredSpells = {}

function NugCast.UNIT_SPELLCAST_START(self,event,unit)
    if unit ~= self.unit then return end
    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
    self.channeling = false
    self.fadingStartTime = nil
    self:SetAlpha(1)
    self:UpdateCastingInfo(name,texture,startTime,endTime,castID, notInterruptible)
end
NugCast.UNIT_SPELLCAST_DELAYED = NugCast.UNIT_SPELLCAST_START
function NugCast.UNIT_SPELLCAST_CHANNEL_START(self,event,unit)
    if unit ~= self.unit then return end
    local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unit)
    self.channeling = true
    local castID = nil
    self.fadingStartTime = nil
    self:SetAlpha(1)
    self:UpdateCastingInfo(name,texture,startTime,endTime, castID, notInterruptible)
end
NugCast.UNIT_SPELLCAST_CHANNEL_UPDATE = NugCast.UNIT_SPELLCAST_CHANNEL_START


function NugCast.UNIT_SPELLCAST_STOP(self, event, unit, castID)
    if unit ~= self.unit then return end
    if self.Deactivate then
        self:Deactivate()
        self:Hide()
        return
    end
    self.fadingStartTime = self.fadingStartTime or GetTime()
    -- self:Hide()
end
function NugCast.UNIT_SPELLCAST_FAILED(self, event, unit, castID)
    if unit ~= self.unit then return end
    if self.castID == castID then
        NugCast.UNIT_SPELLCAST_STOP(self, event, unit, castID)
        self.bar:SetColor(unpack(NugCast.db.profile.failedColor))
    end
end
NugCast.UNIT_SPELLCAST_INTERRUPTED = NugCast.UNIT_SPELLCAST_FAILED
NugCast.UNIT_SPELLCAST_CHANNEL_STOP = NugCast.UNIT_SPELLCAST_STOP


function NugCast.UNIT_SPELLCAST_INTERRUPTIBLE(self,event,unit)
    if unit ~= self.unit then return end
    self.shield:Hide()
end
function NugCast.UNIT_SPELLCAST_NOT_INTERRUPTIBLE(self,event,unit)
    if unit ~= self.unit then return end
    self.shield:Show()
end


function NugCast.PLAYER_TARGET_CHANGED(self,event)
    if UnitCastingInfo("target") then return NugCast.UNIT_SPELLCAST_START(self,event,"target") end
    if UnitChannelInfo("target") then return NugCast.UNIT_SPELLCAST_CHANNEL_START(self,event,"target") end
    NugCast.UNIT_SPELLCAST_STOP(self,event,"target")
end

function NugCast.PLAYER_FOCUS_CHANGED(self,event)
    if UnitCastingInfo("focus") then return NugCast.UNIT_SPELLCAST_START(self,event,"focus") end
    if UnitChannelInfo("focus") then return NugCast.UNIT_SPELLCAST_CHANNEL_START(self,event,"focus") end
    NugCast.UNIT_SPELLCAST_STOP(self,event,"focus")
end

function NugCast.UNIT_SPELLCAST_SUCCEEDED(self, event, unit, castID)
    if unit ~= self.unit then return end
    if self.channeling then return end
    if self.castID == castID then
        NugCast.UNIT_SPELLCAST_STOP(self, event, unit, castID)
        self.bar:SetColor(unpack(NugCast.db.profile.successColor))
    end
end


local UpdateCastingInfo = function(self,name,texture,startTime,endTime,castID, notInterruptible)
        if not startTime then return end
        self.castID = castID
        self.startTime = startTime / 1000
        self.endTime = endTime / 1000
        self.bar:SetMinMaxValues(self.startTime, self.endTime)
        self.elapsed = GetTime() - self.startTime
        self.icon:SetTexture(texture)
        self.spellText:SetText(name)
        -- if self.unit ~= "player" and NugCast.badSpells[name] then
        --     if self.shine:IsPlaying() then self.shine:Stop() end
        --     self.shine:Play()
        -- end
        local color = coloredSpells[name] or (self.channeling and NugCast.db.profile.channelColor or NugCast.db.profile.castColor)
        self.bar:SetColor(unpack(color))
        self.isActive = true
        self:Show()

        if self.shield then
            if notInterruptible then
                self.shield:Show()
                if NugCast.db.profile.notInterruptibleColorEnabled then
                    self.bar:SetColor(unpack(NugCast.db.profile.notInterruptibleColor))
                end
            else
                self.shield:Hide()
            end
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

    if LibCC then
        local CastbarEventHandler = function(event, ...)
            local self = f
            return NugCast[event](self, event, ...)
        end
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_START", CastbarEventHandler)
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_DELAYED", CastbarEventHandler) -- only for player
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_STOP", CastbarEventHandler)
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_FAILED", CastbarEventHandler)
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_INTERRUPTED", CastbarEventHandler)
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_SUCCEEDED", CastbarEventHandler)
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_CHANNEL_START", CastbarEventHandler)
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_CHANNEL_UPDATE", CastbarEventHandler) -- only for player
        LibCC.RegisterCallback(f,"UNIT_SPELLCAST_CHANNEL_STOP", CastbarEventHandler)
        UnitCastingInfo = function(unit)
            return LibCC:UnitCastingInfo(unit)
        end
        UnitChannelInfo = function(unit)
            return LibCC:UnitChannelInfo(unit)
        end
    else
        f:RegisterEvent("UNIT_SPELLCAST_START")
        f:RegisterEvent("UNIT_SPELLCAST_DELAYED")
        f:RegisterEvent("UNIT_SPELLCAST_STOP")
        f:RegisterEvent("UNIT_SPELLCAST_FAILED")
        f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    end
    -- f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    -- f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    f:SetScript("OnEvent", function(self, event, ...)
        return NugCast[event](self, event, ...)
    end)
    f.UpdateCastingInfo = UpdateCastingInfo

    return f
end

local OnValueChanged = function(self, v)
    local min, max = self:GetMinMaxValues()
    local total = max-min
    local p
    if total == 0 then
        p = 0
    else
        p = (v-min)/(max-min)
    end
    local len = p*self:GetWidth()
    -- OriginalSetValue(self, v)
    self.spark:SetPoint("CENTER", self, "LEFT", len, 0)
end

NugCast.AddSpark = function(self, bar)
    -- local bar = f.bar

    local spark = bar:CreateTexture(nil, "ARTWORK", nil, 4)
    spark:SetBlendMode("ADD")
    spark:SetTexture([[Interface\AddOns\NugCast\spark.tga]])
    spark:SetSize(bar:GetHeight()*2, bar:GetHeight())

    -- spark:SetPoint("CENTER", bar, "LEFT",0,0)
    -- spark:SetVertexColor(unpack(colors.health))
    bar.spark = spark

    -- bar:SetScript("OnValueChanged", OnValueChanged)
    local OriginalSetValue = bar.SetValue
    bar.SetValue = function(self, v)
        local min, max = self:GetMinMaxValues()
        local total = max-min
        local p
        if total == 0 then
            p = 0
        else
            p = (v-min)/(max-min)
        end
        local len = p*self:GetWidth()
        OriginalSetValue(self, v)
        self.spark:SetPoint("CENTER", self, "LEFT", len, 0)
    end

    local OriginalSetStatusBarColor = bar.SetStatusBarColor
    bar.SetStatusBarColor = function(self, r,g,b,a)
        self.spark:SetVertexColor(r,g,b,a)
        return OriginalSetStatusBarColor(self, r,g,b,a)
    end
end

NugCast.AddMore = function(self, f)
    if not isClassic then
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

    if not spark then
        f.bar = CreateFrame("StatusBar",nil,f)
    else
        -- no matter what StatusBar value is never synced with Spark on fast casts, as if delayed by a single frame
        -- so i'm making my own status bar with texcoord
        f.bar = self:CreateHorizontalBar(nil,f)
    end
    f.bar:SetFrameStrata("MEDIUM")
    f.bar:SetStatusBarTexture(texture)
    f.bar:SetHeight(height)
    f.bar:SetWidth(width - height - 1)
    f.bar:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)

    if spark then
        self:AddSpark(f.bar)
    end

    f.Resize = ResizeFunc

    f.ResizeText = ResizeTextFunc


    local m = 0.4
    f.bar.SetColor = function(self, r,g,b)
        self:SetStatusBarColor(r,g,b)
        self.bg:SetVertexColor(r*m,g*m,b*m)
    end

    f.bar.bg = f.bar:CreateTexture(nil, "BORDER")
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


    f:SetScript("OnUpdate",TimerOnUpdate)

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


    f:SetScript("OnUpdate",TimerOnUpdate)

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
            NugCast.optionsPanel = NugCast:CreateGUI()
        end
        InterfaceOptionsFrame_OpenToCategory("NugCast")
        InterfaceOptionsFrame_OpenToCategory("NugCast")
    end,
    ["unlock"] = function()
        for unit, anchor in pairs(anchors) do
            anchor:Show()
        end
        local now = GetTime() * 1000
        NugCastPlayer:UpdateCastingInfo("Player","Interface\\Icons\\inv_misc_questionmark",now - 150000, now + 150000, 1, true)
        if NugCastTarget then
            NugCastTarget:UpdateCastingInfo("Target","Interface\\Icons\\inv_misc_questionmark",now - 150000, now + 150000, 1, true)
        end
        if NugCastFocus then
            NugCastFocus:UpdateCastingInfo("Focus","Interface\\Icons\\inv_misc_questionmark",now - 150000, now + 150000, 1, true)
        end
        for i=1, 3 do
            local castbar = NugCast.FindFreeCastbar()
            if not castbar then break end
            castbar.unit = "nameplate"..i
            castbar:UpdateCastingInfo("Nameplate"..i,"Interface\\Icons\\inv_misc_questionmark",now - 15000, now + 15000, 1, true)
        end
        if NugCastPlayerNameplateHeader then
            NugCastPlayerNameplateHeader:Arrange()
        end
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
        NugCastFocus:Resize(NugCast.db.profile.target.width, NugCast.db.profile.target.height)
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
                        disabled = isClassic,
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
                        disabled = isClassic,
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
                                disabled = isClassic,
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

                            nameplatesWidth = {
                                name = "Nameplates Bar Width",
                                type = "range",
                                disabled = isClassic,
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
                                disabled = isClassic,
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
                                disabled = isClassic,
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
                        disabled = isClassic,
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
    local panelFrame = AceConfigDialog:AddToBlizOptions("NugCastOptions", "NugCast")

    return panelFrame
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
