NugCast = CreateFrame("Frame",nil,UIParent)

local NugCast = _G.NugCast
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local isClassic = select(4,GetBuildInfo()) <= 19999
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

local defaults = {
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
    spellFont = "Friz Quadrata TT",
    timeFont = "Friz Quadrata TT",
    timeFontSize = 8,
    playerCastbar = true,
    targetCastbar = true,
    focusCastbar = false,
    textColor = {1,1,1,0.5},
    castColor = { 0.6, 0, 1 },
    channelColor = {200/255,50/255,95/255 },
    highlightColor = { 206/255, 4/256, 56/256 },
    nameplateExcludeTarget = true,
    nameplateCastbars = true,
    -- tex = "",
}

local function SetupDefaults(t, defaults)
    if not defaults then return end
    for k,v in pairs(defaults) do
        if type(v) == "table" then
            if t[k] == nil then
                t[k] = CopyTable(v)
            elseif t[k] == false then
                t[k] = false --pass
            else
                SetupDefaults(t[k], v)
            end
        else
            if t[k] == nil then t[k] = v end
        end
    end
end
local function RemoveDefaults(t, defaults)
    if not defaults then return end
    for k, v in pairs(defaults) do
        if type(t[k]) == 'table' and type(v) == 'table' then
            RemoveDefaults(t[k], v)
            if next(t[k]) == nil then
                t[k] = nil
            end
        elseif t[k] == v then
            t[k] = nil
        end
    end
    return t
end


NugCast:RegisterEvent("PLAYER_LOGIN")
NugCast:RegisterEvent("PLAYER_LOGOUT")
NugCast:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

function NugCast:PLAYER_LOGIN()
    _G.NugCastDB = _G.NugCastDB or {}
    NugCastDB = _G.NugCastDB
    SetupDefaults(NugCastDB, defaults)

    NugCastDB.focusCastbar = false
    NugCastDB.nameplateCastbars = false

    if NugCastDB.playerCastbar then
        local player = NugCast:SpawnCastBar("player", NugCastDB.player.width, NugCastDB.player.height)
        player.spellText:Hide()
        player.timeText:Hide()
        CastingBarFrame:UnregisterAllEvents()
        NugCastPlayer = player

        local player_anchor = self:CreateAnchor(NugCastDB.anchors["player"])
        player:SetPoint("TOPLEFT",player_anchor,"BOTTOMRIGHT",0,0)
        anchors["player"] = player_anchor
    end

    if NugCastDB.targetCastbar then
        local target = NugCast:SpawnCastBar("target", NugCastDB.target.width, NugCastDB.target.height)
        target:RegisterEvent("PLAYER_TARGET_CHANGED")
        NugCast:AddMore(target)
        NugCastTarget = target

        local target_anchor = self:CreateAnchor(NugCastDB.anchors["target"])
        target:SetPoint("TOPLEFT",target_anchor,"BOTTOMRIGHT",0,0)
        anchors["target"] = target_anchor
    end

    if NugCastDB.focusCastbar and not isClassic then
        local focus = NugCast:SpawnCastBar("focus", NugCastDB.target.width, NugCastDB.target.height)
        focus:RegisterEvent("PLAYER_FOCUS_CHANGED")
        NugCast:AddMore(focus)
        NugCastFocus = focus

        local focus_anchor = self:CreateAnchor(NugCastDB.anchors["focus"])
        focus:SetPoint("TOPLEFT",focus_anchor,"BOTTOMRIGHT",0,0)
        anchors["focus"] = focus_anchor
    end
    -- if oUF_Focus then focus:SetPoint("TOPRIGHT",oUF_Focus,"BOTTOMRIGHT", 0,-5)
    -- else focus:SetPoint("CENTER",UIParent,"CENTER", 0,300) end


    if NugCastDB.nameplateCastbars and not isClassic then
        local npheader = NugCast:CreateNameplateCastbars()
        NugCastPlayerNameplateHeader = npheader
        local nameplates_anchor = self:CreateAnchor(NugCastDB.anchors["nameplates"])
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

function NugCast:PLAYER_LOGOUT()
    RemoveDefaults(NugCastDB, defaults)
end

local TimerOnUpdate = function(self, elapsed)
    local v = self.elapsed + elapsed
    local beforeEnd = self.endTime - (v+self.startTime)
    self.elapsed = v

    local val
    if self.inverted then val = self.startTime + beforeEnd
    else val = self.endTime - beforeEnd end
    self.bar:SetValue(val)
    self.timeText:SetFormattedText("%.1f",beforeEnd)
    if beforeEnd <= 0 then
        if self.Deactivate then self:Deactivate() end
        self:Hide()
    end
end

local defaultCastColor = { 0.6, 0, 1 }
local defaultChannelColor = {200/255,50/255,95/255 }
local highlightColor = { 206/255, 4/256, 56/256 }
local coloredSpells = {}

function NugCast.UNIT_SPELLCAST_START(self,event,unit)
    if unit ~= self.unit then return end
    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
    self.inverted = false
    self:UpdateCastingInfo(name,texture,startTime,endTime,castID, notInterruptible)
end
NugCast.UNIT_SPELLCAST_DELAYED = NugCast.UNIT_SPELLCAST_START
function NugCast.UNIT_SPELLCAST_CHANNEL_START(self,event,unit)
    if unit ~= self.unit then return end
    local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unit)
    self.inverted = true
    self:UpdateCastingInfo(name,texture,startTime,endTime,castID, notInterruptible)
end
NugCast.UNIT_SPELLCAST_CHANNEL_UPDATE = NugCast.UNIT_SPELLCAST_CHANNEL_START


function NugCast.UNIT_SPELLCAST_STOP(self, event, unit)
    if unit ~= self.unit then return end
    if self.Deactivate then
        self:Deactivate()
    end
    self:Hide()
end
function NugCast.UNIT_SPELLCAST_FAILED(self, event, unit, castID)
    if unit ~= self.unit then return end
    if self.castID == castID then NugCast.UNIT_SPELLCAST_STOP(self, event, unit, spell) end
end
NugCast.UNIT_SPELLCAST_INTERRUPTED = NugCast.UNIT_SPELLCAST_STOP
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
        local color = coloredSpells[name] or (self.inverted and NugCastDB.channelColor or NugCastDB.castColor)
        self.bar:SetColor(unpack(color))
        self.isActive = true
        self:Show()

        if self.shield then
            if notInterruptible then
                self.shield:Show()
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
    local texture = LSM:Fetch("statusbar", NugCastDB.barTexture)
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
    self.timeText:SetFont(LSM:Fetch("font", NugCastDB.timeFont), NugCastDB.timeFontSize)
    self.timeText:SetTextColor(unpack(NugCastDB.textColor))

    self.spellText:SetFont(LSM:Fetch("font", NugCastDB.spellFont), spellFontSize)
    self.spellText:SetTextColor(unpack(NugCastDB.textColor))
end



NugCast.FillFrame = function(self, f,width,height, unit, spark)
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }

    f:SetWidth(width)
    f:SetHeight(height)

    f:SetBackdrop(backdrop)
	f:SetBackdropColor(0, 0, 0, 0.7)

    local ic = CreateFrame("Frame",nil,f)
    ic:SetPoint("TOPLEFT",f,"TOPLEFT", 0, 0)
    ic:SetWidth(height)
    ic:SetHeight(height)
    local ict = ic:CreateTexture(nil,"ARTWORK",nil,0)
    ict:SetTexCoord(.07, .93, .07, .93)
    ict:SetAllPoints(ic)
    f.icon = ict

    local texture = LSM:Fetch("statusbar", NugCastDB.barTexture)

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
    f.timeText:SetFont(LSM:Fetch("font", NugCastDB.timeFont), NugCastDB.timeFontSize)
    -- f.timeText:SetFont("Fonts\\FRIZQT___CYR.TTF",8)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetVertexColor(1,1,1)
    f.timeText:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",-6,0)
    f.timeText:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT",0,0)
    f.timeText:SetTextColor(unpack(NugCastDB.textColor))

    local spellFontSize = NugCastDB[unit].spellFontSize

    f.spellText = f.bar:CreateFontString();
    f.spellText:SetFont(LSM:Fetch("font", NugCastDB.spellFont), spellFontSize)
    f.spellText:SetWidth(width/4*3 -12)
    f.spellText:SetHeight(height/2+1)
    f.spellText:SetJustifyH("CENTER")
    f.spellText:SetTextColor(unpack(NugCastDB.textColor))
    f.spellText:SetPoint("LEFT", f.bar, "LEFT",6,0)
    -- f.spellText:SetAlpha(0.5)


    f:SetScript("OnUpdate",TimerOnUpdate)

    return f
end


NugCast.MakeDoubleCastbar = function(self, f,width,height)
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }

    f:SetWidth(width)
    f:SetHeight(height)

    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0, 0, 0, 0.7)

    local texture = LSM:Fetch("statusbar", NugCastDB.barTexture)

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
                    if NugCastDB.nameplateExcludeTarget then
                        bar:Hide()
                    else
                        table.insert(ordered_bars, bar)
                        bar:Show()
                        bar.bar:SetColor(unpack(NugCastDB.highlightColor))
                    end
                else
                    table.insert(ordered_bars, bar)
                    bar:Show()
                    if not NugCastDB.nameplateExcludeTarget then
                        local color = (bar.inverted and NugCastDB.channelColor or NugCastDB.castColor)
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
        self:FillFrame(f, NugCastDB.nameplates.width, NugCastDB.nameplates.height, "nameplates")
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

    f.db_tbl = db_tbl

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

    local pos = f.db_tbl
    f:SetPoint(pos.point, pos.parent, pos.to, pos.x, pos.y)
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
        NugCastDB.nameplateCastbars = not NugCastDB.nameplateCastbars
        print("Nameplate castbars turned "..(NugCastDB.nameplateCastbars and "on" or "off")..". Will take effect after /reload")
    end,

    ["excludetarget"] = function()
        NugCastDB.nameplateExcludeTarget = not NugCastDB.nameplateExcludeTarget
    end,

    ["targetcastbar"] = function()
        NugCastDB.targetCastbar = not NugCastDB.targetCastbar
        print("Target castbar turned "..(NugCastDB.targetCastbar and "on" or "off")..". Will take effect after /reload")
    end,

    ["set"] = function(v)
        local p = ParseOpts(v)
        local unit = p["unit"]
        if unit then
            if p.width then NugCastDB[unit].width = p.width end
            if p.height then NugCastDB[unit].height = p.height end

            if unit == "player" then
                NugCastPlayer:Resize(NugCastDB.player.width, NugCastDB.player.height)
            elseif unit == "target" then
                NugCastTarget:Resize(NugCastDB.target.width, NugCastDB.target.height)
            elseif unit == "nameplates" then
                for i, timer in ipairs(npCastbars) do
                    timer:Resize(NugCastDB.nameplates.width, NugCastDB.nameplates.height)
                end
            end
        end
    end,
}

function NugCast.SlashCmd(msg)
    local k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then print([[Usage:
      |cff00ff00/spg lock|r
      |cff00ff00/spg unlock|r
      |cff00ff00/spg excludetarget|r
      |cff00ff00/spg targetcastbar|r
      |cff00ff00/spg set|r unit=<player||target||nameplates> width=<num> height=<num>
      |cff00ff00/spg nameplatebars|r
    ]]
    )end
    if NugCast.Commands[k] then
        NugCast.Commands[k](v)
    end

end




function NugCast:Resize()

    NugCastPlayer:Resize(NugCastDB.player.width, NugCastDB.player.height)
    if NugCastTarget then
        NugCastTarget:Resize(NugCastDB.target.width, NugCastDB.target.height)
    end
    if NugCastFocus then
        NugCastFocus:Resize(NugCastDB.target.width, NugCastDB.target.height)
    end
    for i, timer in ipairs(npCastbars) do
        timer:Resize(NugCastDB.nameplates.width, NugCastDB.nameplates.height)
    end
end
function NugCast:ResizeText()
    NugCastPlayer:ResizeText(NugCastDB.player.spellFontSize)
    if NugCastTarget then
        NugCastTarget:ResizeText(NugCastDB.target.spellFontSize)
    end
    if NugCastFocus then
        NugCastFocus:ResizeText(NugCastDB.target.spellFontSize)
    end
    for i, timer in ipairs(npCastbars) do
        timer:ResizeText(NugCastDB.nameplates.spellFontSize)
    end
end


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
                    _G.NugCastDB = {}
                    SetupDefaults(_G.NugCastDB, defaults)
                    NugCastDB = _G.NugCastDB
                    NugCast:Resize()
                    NugCast:ResizeText()
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
                        get = function(info) return NugCastDB.playerCastbar end,
                        set = function(info, v)
                            NugCastDB.playerCastbar = not NugCastDB.playerCastbar
                            ReloadUI()
                        end
                    },
                    targetCastbar = {
                        name = "Target Castbar",
                        type = "toggle",
                        confirm = true,
						confirmText = "Warning: Requires UI reloading.",
                        order = 1,
                        get = function(info) return NugCastDB.targetCastbar end,
                        set = function(info, v)
                            NugCastDB.targetCastbar = not NugCastDB.targetCastbar
                            ReloadUI()
                        end
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
                                    local r,g,b = unpack(NugCastDB.castColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugCastDB.castColor = {r,g,b}
                                end,
                                order = 1,
                            },
                            channelColor = {
                                name = "Channel Color",
                                type = 'color',
                                order = 2,
                                get = function(info)
                                    local r,g,b = unpack(NugCastDB.channelColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugCastDB.channelColor = {r,g,b}
                                end,
                            },
                            textColor = {
                                name = "Text Color & Alpha",
                                type = 'color',
                                hasAlpha = true,
                                order = 6,
                                get = function(info)
                                    local r,g,b,a = unpack(NugCastDB.textColor)
                                    return r,g,b,a
                                end,
                                set = function(info, r, g, b, a)
                                    NugCastDB.textColor = {r,g,b, a}
                                    NugCast:ResizeText()
                                end,
                            },
                            texture = {
                                type = "select",
                                name = "Texture",
                                order = 5,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugCastDB.barTexture end,
                                set = function(info, value)
                                    NugCastDB.barTexture = value
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
                                get = function(info) return NugCastDB.player.width end,
                                set = function(info, v)
                                    NugCastDB.player.width = tonumber(v)
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
                                get = function(info) return NugCastDB.player.height end,
                                set = function(info, v)
                                    NugCastDB.player.height = tonumber(v)
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
                                get = function(info) return NugCastDB.player.spellFontSize end,
                                set = function(info, v)
                                    NugCastDB.player.spellFontSize = tonumber(v)
                                    NugCast:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },

                            targetWidth = {
                                name = "Target Bar Width",
                                type = "range",
                                get = function(info) return NugCastDB.target.width end,
                                set = function(info, v)
                                    NugCastDB.target.width = tonumber(v)
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
                                get = function(info) return NugCastDB.target.height end,
                                set = function(info, v)
                                    NugCastDB.target.height = tonumber(v)
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
                                get = function(info) return NugCastDB.target.spellFontSize end,
                                set = function(info, v)
                                    NugCastDB.target.spellFontSize = tonumber(v)
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
                                get = function(info) return NugCastDB.spellFont end,
                                set = function(info, value)
                                    NugCastDB.spellFont = value
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
                                get = function(info) return NugCastDB.timeFont end,
                                set = function(info, value)
                                    NugCastDB.timeFont = value
                                    NugCast:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },
                            font2Size = {
                                name = "Time Font Size",
                                type = "range",
                                order = 4,
                                get = function(info) return NugCastDB.timeFontSize end,
                                set = function(info, v)
                                    NugCastDB.timeFontSize = tonumber(v)
                                    NugCast:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },
                        },
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