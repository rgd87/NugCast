Spellgarden = CreateFrame("Frame",nil,UIParent)

local Spellgarden = _G.Spellgarden
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo

local SpellgardenDB

local LSM = LibStub("LibSharedMedia-3.0")

LSM:Register("statusbar", "Aluminium", [[Interface\AddOns\Spellgarden\statusbar.tga]])

local npCastbars = {}
local npCastbarsByUnit = {}
local npCastbarsByGUID = {}
local MAX_NAMEPLATE_CASTBARS = 7
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
    nameplates = {
        width = 180,
        height = 18,
        spellFontSize = 10,
    },
    barTexture = "Aluminium",
    spellFont = "Friz Quadrata TT",
    timeFont = "Friz Quadrata TT",
    timeFontSize = 8,
    targetCastbar = true,
    textColor = {1,1,1,0.5},
    castColor = { 0.6, 0, 1 },
    channelColor = {200/255,50/255,95/255 },
    highlightColor = { 206/255, 4/256, 56/256 },
    nameplateExcludeTarget = false,
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


Spellgarden:RegisterEvent("PLAYER_LOGIN")
Spellgarden:RegisterEvent("PLAYER_LOGOUT")
Spellgarden:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

function Spellgarden:PLAYER_LOGIN()
    _G.SpellgardenDB = _G.SpellgardenDB or {}
    SpellgardenDB = _G.SpellgardenDB
    SetupDefaults(SpellgardenDB, defaults)

    local player = Spellgarden:SpawnCastBar("player", SpellgardenDB.player.width, SpellgardenDB.player.height)
    player.spellText:Hide()
    player.timeText:Hide()
    CastingBarFrame:UnregisterAllEvents()
    SpellgardenPlayer = player

    local player_anchor = self:CreateAnchor(SpellgardenDB.anchors["player"])
    player:SetPoint("TOPLEFT",player_anchor,"BOTTOMRIGHT",0,0)
    anchors["player"] = player_anchor

    if SpellgardenDB.targetCastbar then
        local target = Spellgarden:SpawnCastBar("target", SpellgardenDB.target.width, SpellgardenDB.target.height)
        target:RegisterEvent("PLAYER_TARGET_CHANGED")
        Spellgarden:AddMore(target)
        SpellgardenTarget = target

        local target_anchor = self:CreateAnchor(SpellgardenDB.anchors["target"])
        target:SetPoint("TOPLEFT",target_anchor,"BOTTOMRIGHT",0,0)
        anchors["target"] = target_anchor
    end

    -- local focus = Spellgarden:SpawnCastBar("focus",200,25)
    -- Spellgarden:AddMore(focus)
    -- if oUF_Focus then focus:SetPoint("TOPRIGHT",oUF_Focus,"BOTTOMRIGHT", 0,-5)
    -- else focus:SetPoint("CENTER",UIParent,"CENTER", 0,300) end


    if SpellgardenDB.nameplateCastbars then
        local npheader = Spellgarden:CreateNameplateCastbars()
        SpellgardenPlayerNameplateHeader = npheader
        local nameplates_anchor = self:CreateAnchor(SpellgardenDB.anchors["nameplates"])
        npheader:SetPoint("TOPLEFT", nameplates_anchor,"BOTTOMRIGHT",0,0)
        -- npheader:SetPoint("CENTER", UIParent, "CENTER",0,0)
        anchors["nameplates"] = nameplates_anchor
    end


    SLASH_SPELLGARDEN1= "/spellgarden"
    SLASH_SPELLGARDEN2= "/spg"
    SlashCmdList["SPELLGARDEN"] = Spellgarden.SlashCmd

    local f = CreateFrame('Frame', nil, InterfaceOptionsFrame)
    f:SetScript('OnShow', function(self)
        self:SetScript('OnShow', nil)

        if not Spellgarden.optionsPanel then
            Spellgarden.optionsPanel = Spellgarden:CreateGUI()
        end
    end)
end

function Spellgarden:PLAYER_LOGOUT()
    RemoveDefaults(SpellgardenDB, defaults)
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

function Spellgarden.UNIT_SPELLCAST_START(self,event,unit,spell)
    if unit ~= self.unit then return end
    local name, subText, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
    self.inverted = false
    self:UpdateCastingInfo(name,texture,startTime,endTime,castID, notInterruptible)
end
Spellgarden.UNIT_SPELLCAST_DELAYED = Spellgarden.UNIT_SPELLCAST_START
function Spellgarden.UNIT_SPELLCAST_CHANNEL_START(self,event,unit,spell)
    if unit ~= self.unit then return end
    local name, subText, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitChannelInfo(unit)
    self.inverted = true
    self:UpdateCastingInfo(name,texture,startTime,endTime,castID, notInterruptible)
end
Spellgarden.UNIT_SPELLCAST_CHANNEL_UPDATE = Spellgarden.UNIT_SPELLCAST_CHANNEL_START


function Spellgarden.UNIT_SPELLCAST_STOP(self, event, unit, spell)
    if unit ~= self.unit then return end
    if self.Deactivate then
        self:Deactivate()
    end
    self:Hide()
end
function Spellgarden.UNIT_SPELLCAST_FAILED(self, event, unit, spell, _,castID)
    if unit ~= self.unit then return end
    if self.castID == castID then Spellgarden.UNIT_SPELLCAST_STOP(self, event, unit, spell) end
end
Spellgarden.UNIT_SPELLCAST_INTERRUPTED = Spellgarden.UNIT_SPELLCAST_STOP
Spellgarden.UNIT_SPELLCAST_CHANNEL_STOP = Spellgarden.UNIT_SPELLCAST_STOP


function Spellgarden.UNIT_SPELLCAST_INTERRUPTIBLE(self,event,unit)
    if unit ~= self.unit then return end
    self.shield:Hide()
end
function Spellgarden.UNIT_SPELLCAST_NOT_INTERRUPTIBLE(self,event,unit)
    if unit ~= self.unit then return end
    self.shield:Show()
end


function Spellgarden.PLAYER_TARGET_CHANGED(self,event)
    if UnitCastingInfo("target") then return Spellgarden.UNIT_SPELLCAST_START(self,event,"target") end
    if UnitChannelInfo("target") then return Spellgarden.UNIT_SPELLCAST_CHANNEL_START(self,event,"target") end
    Spellgarden.UNIT_SPELLCAST_STOP(self,event,"target")
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
        if self.unit ~= "player" and Spellgarden.badSpells[name] then
            if self.shine:IsPlaying() then self.shine:Stop() end
            self.shine:Play()
        end
        local color = coloredSpells[name] or (self.inverted and SpellgardenDB.channelColor or SpellgardenDB.castColor)
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
function Spellgarden.SpawnCastBar(self,unit,width,height)
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
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    -- f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    -- f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    f:SetScript("OnEvent", function(self, event, ...)
        return Spellgarden[event](self, event, ...)
    end)
    f.UpdateCastingInfo = UpdateCastingInfo

    return f
end

Spellgarden.AddSpark = function(self, bar)
    -- local bar = f.bar

    local spark = bar:CreateTexture(nil, "ARTWORK", nil, 4)
    spark:SetBlendMode("ADD")
    spark:SetTexture([[Interface\AddOns\Spellgarden\spark.tga]])
    spark:SetSize(bar:GetHeight()*2, bar:GetHeight())

    spark:SetPoint("CENTER", bar, "TOP",0,0)
    -- spark:SetVertexColor(unpack(colors.health))
    bar.spark = spark

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
        self.spark:SetPoint("CENTER", self, "LEFT", len, 0)
        return OriginalSetValue(self, v)
    end

    local OriginalSetStatusBarColor = bar.SetStatusBarColor
    bar.SetStatusBarColor = function(self, r,g,b,a)
        self.spark:SetVertexColor(r,g,b,a)
        return OriginalSetStatusBarColor(self, r,g,b,a)
    end
end

Spellgarden.AddMore = function(self, f)
    f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
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

    local sag = at:CreateAnimationGroup()
    local sa1 = sag:CreateAnimation("Alpha")
    sa1:SetToAlpha(1)
    sa1:SetDuration(0.3)
    sa1:SetOrder(1)
    local sa2 = sag:CreateAnimation("Alpha")
    sa2:SetToAlpha(0)
    sa2:SetDuration(0.5)
    sa2:SetSmoothing("OUT")
    sa2:SetOrder(2)

    f.shine = sag
end

local ResizeFunc = function(self, width, height)
    local texture = LSM:Fetch("statusbar", SpellgardenDB.barTexture)
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
    self.timeText:SetFont(LSM:Fetch("font", SpellgardenDB.timeFont), SpellgardenDB.timeFontSize)
    self.timeText:SetTextColor(unpack(SpellgardenDB.textColor))

    self.spellText:SetFont(LSM:Fetch("font", SpellgardenDB.spellFont), spellFontSize)
    self.spellText:SetTextColor(unpack(SpellgardenDB.textColor))
end

Spellgarden.FillFrame = function(self, f,width,height, unit, spark)
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

    local texture = LSM:Fetch("statusbar", SpellgardenDB.barTexture)

    f.bar = CreateFrame("StatusBar",nil,f)
    f.bar:SetFrameStrata("MEDIUM")
    f.bar:SetStatusBarTexture(texture)
    f.bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
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
    f.timeText:SetFont(LSM:Fetch("font", SpellgardenDB.timeFont), SpellgardenDB.timeFontSize)
    -- f.timeText:SetFont("Fonts\\FRIZQT___CYR.TTF",8)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetVertexColor(1,1,1)
    f.timeText:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",-6,0)
    f.timeText:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT",0,0)
    f.timeText:SetTextColor(unpack(SpellgardenDB.textColor))

    local spellFontSize = SpellgardenDB[unit].spellFontSize

    f.spellText = f.bar:CreateFontString();
    f.spellText:SetFont(LSM:Fetch("font", SpellgardenDB.spellFont), spellFontSize)
    f.spellText:SetWidth(width/4*3 -12)
    f.spellText:SetHeight(height/2+1)
    f.spellText:SetJustifyH("CENTER")
    f.spellText:SetTextColor(unpack(SpellgardenDB.textColor))
    f.spellText:SetPoint("LEFT", f.bar, "LEFT",6,0)
    -- f.spellText:SetAlpha(0.5)


    f:SetScript("OnUpdate",TimerOnUpdate)

    return f
end


Spellgarden.MakeDoubleCastbar = function(self, f,width,height)
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }

    f:SetWidth(width)
    f:SetHeight(height)

    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0, 0, 0, 0.7)

    local texture = LSM:Fetch("statusbar", SpellgardenDB.barTexture)

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
        if not bar.isActive then
            return  bar
        end
    end
end
Spellgarden.FindFreeCastbar = FindFreeCastbar


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

function Spellgarden:ArrangeNameplateTimers()

end

function Spellgarden:CreateNameplateCastbars()
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
                    if SpellgardenDB.nameplateExcludeTarget then
                        bar:Hide()
                    else
                        table.insert(ordered_bars, bar)
                        bar.bar:SetColor(unpack(SpellgardenDB.highlightColor))
                    end
                else
                    table.insert(ordered_bars, bar)
                    bar:Show()
                    if not SpellgardenDB.nameplateExcludeTarget then    
                        local color = (bar.inverted and SpellgardenDB.channelColor or SpellgardenDB.castColor)
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
                    Spellgarden[event](castbar, event, unit, ...)
                end
            elseif UnitChannelInfo(unit) then
                event = "UNIT_SPELLCAST_CHANNEL_START"
                local castbar = FindFreeCastbar()
                if castbar then
                    castbar.unit = unit
                    npCastbarsByUnit[unit] = castbar
                    Spellgarden[event](castbar, event, unit, ...)
                end
            end
        elseif (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") and not npCastbarsByUnit[unit] then
            if not UnitIsEnemy("player", unit) then return end
            local castbar = FindFreeCastbar()
            if castbar then
                castbar.unit = unit
                npCastbarsByUnit[unit] = castbar
                Spellgarden[event](castbar, event, unit, ...)
            end
        else
            local castbar = npCastbarsByUnit[unit]
            if castbar then
                Spellgarden[event](castbar, event, unit, ...)
            end
        end

        npCastbarsHeader:Arrange()
    end)

    for i=1, MAX_NAMEPLATE_CASTBARS do 
        local f = CreateFrame("Frame", nil, npCastbarsHeader)
        self:FillFrame(f, SpellgardenDB.nameplates.width, SpellgardenDB.nameplates.height, "nameplates")
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













function Spellgarden:CreateAnchor(db_tbl)
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
Spellgarden.Commands = {
    ["unlock"] = function()
        for unit, anchor in pairs(anchors) do
            anchor:Show()
        end
        local now = GetTime() * 1000
        SpellgardenPlayer:UpdateCastingInfo("Player","Interface\\Icons\\inv_misc_questionmark",now - 150000, now + 150000, 1, true)
        SpellgardenTarget:UpdateCastingInfo("Target","Interface\\Icons\\inv_misc_questionmark",now - 150000, now + 150000, 1, true)
        for i=1, 3 do
            local castbar = Spellgarden.FindFreeCastbar()
            castbar.unit = "nameplate"..i
            castbar:UpdateCastingInfo("Nameplate"..i,"Interface\\Icons\\inv_misc_questionmark",now - 15000, now + 15000, 1, true)
        end
        SpellgardenPlayerNameplateHeader:Arrange()
    end,
    ["lock"] = function()
        for unit, anchor in pairs(anchors) do
            anchor:Hide()
        end
        SpellgardenPlayer:Hide()
        SpellgardenTarget:Hide()
        for _, castbar in ipairs(npCastbars) do
            castbar:Deactivate()
            castbar:Hide()
        end
        SpellgardenPlayerNameplateHeader:Arrange()
    end,
    ["nameplatebars"] = function()
        SpellgardenDB.nameplateCastbars = not SpellgardenDB.nameplateCastbars
        print("Nameplate castbars turned "..(SpellgardenDB.nameplateCastbars and "on" or "off")..". Will take effect after /reload")
    end,

    ["excludetarget"] = function()
        SpellgardenDB.nameplateExcludeTarget = not SpellgardenDB.nameplateExcludeTarget
    end,

    ["targetcastbar"] = function()
        SpellgardenDB.targetCastbar = not SpellgardenDB.targetCastbar
        print("Target castbar turned "..(SpellgardenDB.targetCastbar and "on" or "off")..". Will take effect after /reload")
    end,

    ["set"] = function(v)
        local p = ParseOpts(v)
        local unit = p["unit"]
        if unit then
            if p.width then SpellgardenDB[unit].width = p.width end
            if p.height then SpellgardenDB[unit].height = p.height end

            if unit == "player" then
                SpellgardenPlayer:Resize(SpellgardenDB.player.width, SpellgardenDB.player.height)
            elseif unit == "target" then
                SpellgardenTarget:Resize(SpellgardenDB.target.width, SpellgardenDB.target.height)
            elseif unit == "nameplates" then
                for i, timer in ipairs(npCastbars) do
                    timer:Resize(SpellgardenDB.nameplates.width, SpellgardenDB.nameplates.height)
                end
            end
        end
    end,
}

function Spellgarden.SlashCmd(msg)
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
    if Spellgarden.Commands[k] then
        Spellgarden.Commands[k](v)
    end

end




function Spellgarden:Resize()

    SpellgardenPlayer:Resize(SpellgardenDB.player.width, SpellgardenDB.player.height)
    if SpellgardenTarget then
        SpellgardenTarget:Resize(SpellgardenDB.target.width, SpellgardenDB.target.height)
    end
    for i, timer in ipairs(npCastbars) do
        timer:Resize(SpellgardenDB.nameplates.width, SpellgardenDB.nameplates.height)
    end
end
function Spellgarden:ResizeText()
    SpellgardenPlayer:ResizeText(SpellgardenDB.player.spellFontSize)
    if SpellgardenTarget then
        SpellgardenTarget:ResizeText(SpellgardenDB.target.spellFontSize)
    end
    for i, timer in ipairs(npCastbars) do
        timer:ResizeText(SpellgardenDB.nameplates.spellFontSize)
    end
end


function Spellgarden:CreateGUI()
    local opt = {
        type = 'group',
        name = "Spellgarden Settings",
        order = 1,
        args = {
            unlock = {
                name = "Unlock",
                type = "execute",
                desc = "Unlock anchor for dragging",
                func = function() Spellgarden.Commands.unlock() end,
                order = 1,
            },
            lock = {
                name = "Lock",
                type = "execute",
                desc = "Lock anchor",
                func = function() Spellgarden.Commands.lock() end,
                order = 2,
            },
            resetToDefault = {
                name = "Restore Defaults",
                type = 'execute',
                func = function()
                    _G.SpellgardenDB = {}
                    SetupDefaults(_G.SpellgardenDB, defaults)
                    SpellgardenDB = _G.SpellgardenDB
                    Spellgarden:Resize()
                    Spellgarden:ResizeText()
                end,
                order = 3,
            },
            toggleGroup = {
                        
                type = "group",
                guiInline = true,
                name = " ",
                order = 4,
                args = {
                    excludeTarget = {
                        name = "Exclude Target",
                        type = "toggle",
                        order = 4,
                        get = function(info) return SpellgardenDB.nameplateExcludeTarget end,
                        set = function(info, v) Spellgarden.Commands.excludetarget() end
                    },
                    npCastbars = {
                        name = "Nameplate Castbars",
                        type = "toggle",
                        confirm = true,
						confirmText = "Warning: Requires UI reloading.",
                        order = 5,
                        get = function(info) return SpellgardenDB.nameplateCastbars end,
                        set = function(info, v)
                            SpellgardenDB.nameplateCastbars = not SpellgardenDB.nameplateCastbars
                            ReloadUI()
                        end
                    },
                    targetCastbar = {
                        name = "Target Castbar",
                        type = "toggle",
                        confirm = true,
						confirmText = "Warning: Requires UI reloading.",
                        order = 6,
                        get = function(info) return SpellgardenDB.targetCastbar end,
                        set = function(info, v)
                            SpellgardenDB.targetCastbar = not SpellgardenDB.targetCastbar
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
                                    local r,g,b = unpack(SpellgardenDB.castColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    SpellgardenDB.castColor = {r,g,b}
                                end,
                                order = 1,
                            },
                            channelColor = {
                                name = "Channel Color",
                                type = 'color',
                                order = 2,
                                get = function(info)
                                    local r,g,b = unpack(SpellgardenDB.channelColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    SpellgardenDB.channelColor = {r,g,b}
                                end,
                            },
                            highlightColor = {
                                name = "Highlight Color",
                                type = 'color',
                                order = 3,
                                get = function(info)
                                    local r,g,b = unpack(SpellgardenDB.highlightColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    SpellgardenDB.highlightColor = {r,g,b}
                                end,
                            },
                            textColor = {
                                name = "Text Color & Alpha",
                                type = 'color',
                                hasAlpha = true,
                                order = 6,
                                get = function(info)
                                    local r,g,b,a = unpack(SpellgardenDB.textColor)
                                    return r,g,b,a
                                end,
                                set = function(info, r, g, b, a)
                                    SpellgardenDB.textColor = {r,g,b, a}
                                    Spellgarden:ResizeText()
                                end,
                            },
                            texture = {
                                type = "select",
                                name = "Texture",
                                order = 5,
                                desc = "Set the statusbar texture.",
                                get = function(info) return SpellgardenDB.barTexture end,
                                set = function(info, value)
                                    SpellgardenDB.barTexture = value
                                    Spellgarden:Resize()
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
                                get = function(info) return SpellgardenDB.player.width end,
                                set = function(info, v)
                                    SpellgardenDB.player.width = tonumber(v)
                                    Spellgarden:Resize()
                                end,
                                min = 30,
                                max = 1000,
                                step = 1,
                                order = 1,
                            },
                            playerHeight = {
                                name = "Player Bar Height",
                                type = "range",
                                get = function(info) return SpellgardenDB.player.height end,
                                set = function(info, v)
                                    SpellgardenDB.player.height = tonumber(v)
                                    Spellgarden:Resize()
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
                                get = function(info) return SpellgardenDB.player.spellFontSize end,
                                set = function(info, v)
                                    SpellgardenDB.player.spellFontSize = tonumber(v)
                                    Spellgarden:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },

                            targetWidth = {
                                name = "Target Bar Width",
                                type = "range",
                                get = function(info) return SpellgardenDB.target.width end,
                                set = function(info, v)
                                    SpellgardenDB.target.width = tonumber(v)
                                    Spellgarden:Resize()
                                end,
                                min = 30,
                                max = 1000,
                                step = 1,
                                order = 4,
                            },
                            targetHeight = {
                                name = "Target Bar Height",
                                type = "range",
                                get = function(info) return SpellgardenDB.target.height end,
                                set = function(info, v)
                                    SpellgardenDB.target.height = tonumber(v)
                                    Spellgarden:Resize()
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
                                get = function(info) return SpellgardenDB.target.spellFontSize end,
                                set = function(info, v)
                                    SpellgardenDB.target.spellFontSize = tonumber(v)
                                    Spellgarden:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },

                            nameplatesWidth = {
                                name = "Nameplates Bar Width",
                                type = "range",
                                get = function(info) return SpellgardenDB.nameplates.width end,
                                set = function(info, v)
                                    SpellgardenDB.nameplates.width = tonumber(v)
                                    Spellgarden:Resize()
                                end,
                                min = 30,
                                max = 300,
                                step = 1,
                                order = 7,
                            },
                            nameplatesHeight = {
                                name = "Nameplates Bar Height",
                                type = "range",
                                get = function(info) return SpellgardenDB.nameplates.height end,
                                set = function(info, v)
                                    SpellgardenDB.nameplates.height = tonumber(v)
                                    Spellgarden:Resize()
                                end,
                                min = 10,
                                max = 60,
                                step = 1,
                                order = 8,
                            },
                            nameplateFontSize = {
                                name = "Enemies Font Size",
                                type = "range",
                                order = 9,
                                get = function(info) return SpellgardenDB.nameplates.spellFontSize end,
                                set = function(info, v)
                                    SpellgardenDB.nameplates.spellFontSize = tonumber(v)
                                    Spellgarden:ResizeText()
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
                                get = function(info) return SpellgardenDB.spellFont end,
                                set = function(info, value)
                                    SpellgardenDB.spellFont = value
                                    Spellgarden:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },
                            
                            font2 = {
                                type = "select",
                                name = "Time Font",
                                order = 3,
                                desc = "Set the statusbar texture.",
                                get = function(info) return SpellgardenDB.timeFont end,
                                set = function(info, value)
                                    SpellgardenDB.timeFont = value
                                    Spellgarden:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },
                            font2Size = {
                                name = "Time Font Size",
                                type = "range",
                                order = 4,
                                get = function(info) return SpellgardenDB.timeFontSize end,
                                set = function(info, v)
                                    SpellgardenDB.timeFontSize = tonumber(v)
                                    Spellgarden:ResizeText()
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
    AceConfigRegistry:RegisterOptionsTable("SpellgardenOptions", opt)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local panelFrame = AceConfigDialog:AddToBlizOptions("SpellgardenOptions", "Spellgarden")

    return panelFrame
end