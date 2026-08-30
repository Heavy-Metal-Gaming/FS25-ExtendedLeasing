--
-- LeasingExtension.lua
-- Main mod entry for the Leasing Extension mod.
--

LeasingExtension = {}
LeasingExtension.modName = g_currentModName or "LeasingExtension"
LeasingExtension.modDir = g_currentModDirectory or ""
LeasingExtension.isLoaded = false
LeasingExtension.settingsInjected = false

LeasingExtension.defaults = {
    maxLeaseValueMode = "valueBased",
    maxLeaseValueScope = "perItem",
    maxLeaseValuePercent = 10,
    maxLeaseStaticValue = 250000,
    maxLeasedItems = 0,
    debugLogging = true,
}

LeasingExtension.settings = {}
for key, value in pairs(LeasingExtension.defaults) do
    LeasingExtension.settings[key] = value
end

LeasingExtension.menuItems = {
    "maxLeaseValueMode",
    "maxLeaseValueScope",
    "maxLeaseValuePercent",
    "maxLeaseStaticValue",
    "maxLeasedItems",
}

LeasingExtension.SETTINGS = {}
LeasingExtension.CONTROLS = {}

function LeasingExtension:log(message, ...)
    if not self.settings.debugLogging then
        return
    end

    if message ~= nil then
        if ... then
            Logging.info("LeasingExtension: " .. string.format(message, ...))
        else
            Logging.info("LeasingExtension: " .. tostring(message))
        end
    end
end

function LeasingExtension:getSettingsFilePath()
    return Utils.getFilename("modSettings/LeasingExtension.xml", getUserProfileAppPath())
end

function LeasingExtension:initSettingsDefs()
    LeasingExtension.SETTINGS.maxLeaseValueMode = {
        default = 1,
        values = {"valueBased", "static"},
        strings = {
            g_i18n:getText("leasingExtension_mode_valueBased"),
            g_i18n:getText("leasingExtension_mode_static"),
        },
    }

    LeasingExtension.SETTINGS.maxLeaseValueScope = {
        default = 1,
        values = {"perItem", "total"},
        strings = {
            g_i18n:getText("leasingExtension_scope_perItem"),
            g_i18n:getText("leasingExtension_scope_total"),
        },
    }

    LeasingExtension.SETTINGS.maxLeaseValuePercent = {
        default = 10,
        values = {},
        strings = {},
    }
    for i = 1, 300 do
        table.insert(LeasingExtension.SETTINGS.maxLeaseValuePercent.values, i)
        table.insert(LeasingExtension.SETTINGS.maxLeaseValuePercent.strings, tostring(i) .. "%")
    end

    LeasingExtension.SETTINGS.maxLeaseStaticValue = {
        default = 250000,
        min = 0,
        max = 1000000000,
        step = 1000,
    }

    LeasingExtension.SETTINGS.maxLeasedItems = {
        default = 1,
        values = {},
        strings = {},
    }
    table.insert(LeasingExtension.SETTINGS.maxLeasedItems.values, 0)
    table.insert(LeasingExtension.SETTINGS.maxLeasedItems.strings, g_i18n:getText("leasingExtension_infinite"))
    for i = 1, 100 do
        table.insert(LeasingExtension.SETTINGS.maxLeasedItems.values, i)
        table.insert(LeasingExtension.SETTINGS.maxLeasedItems.strings, tostring(i))
    end
end

function LeasingExtension.getSettingValue(id)
    if id == "maxLeaseValueMode" then
        return LeasingExtension.settings.maxLeaseValueMode
    elseif id == "maxLeaseValueScope" then
        return LeasingExtension.settings.maxLeaseValueScope
    elseif id == "maxLeaseValuePercent" then
        return LeasingExtension.settings.maxLeaseValuePercent
    elseif id == "maxLeaseStaticValue" then
        return LeasingExtension.settings.maxLeaseStaticValue
    elseif id == "maxLeasedItems" then
        return LeasingExtension.settings.maxLeasedItems
    end
end

function LeasingExtension.setSettingValue(id, value)
    if id == "maxLeaseValueMode" then
        LeasingExtension.settings.maxLeaseValueMode = value
    elseif id == "maxLeaseValueScope" then
        LeasingExtension.settings.maxLeaseValueScope = value
    elseif id == "maxLeaseValuePercent" then
        LeasingExtension.settings.maxLeaseValuePercent = value
    elseif id == "maxLeaseStaticValue" then
        LeasingExtension.settings.maxLeaseStaticValue = value
    elseif id == "maxLeasedItems" then
        LeasingExtension.settings.maxLeasedItems = value
    end
end

function LeasingExtension.getStateIndex(id)
    local currentValue = LeasingExtension.getSettingValue(id)
    local def = LeasingExtension.SETTINGS[id]
    if def == nil then
        return 1
    end

    for i, v in ipairs(def.values) do
        if type(v) == "table" and type(currentValue) == "table" then
            if math.abs(v[1] - currentValue[1]) < 0.01 and math.abs(v[2] - currentValue[2]) < 0.01 and math.abs(v[3] - currentValue[3]) < 0.01 then
                return i
            end
        elseif v == currentValue then
            return i
        elseif type(v) == "number" and type(currentValue) == "number" then
            if math.abs(v - currentValue) < 0.001 then
                return i
            end
        end
    end

    return def.default or 1
end

function LeasingExtension:saveSettings()
    local filePath = self.getSettingsFilePath()
    local key = "LeasingExtension"
    local xmlFile = createXMLFile("settings", filePath, key)
    if xmlFile == nil or xmlFile == 0 then
        Logging.warning("LeasingExtension: Could not create settings file '%s'", filePath)
        return
    end

    setXMLString(xmlFile, key .. ".maxLeaseValueMode#value", self.settings.maxLeaseValueMode)
    setXMLString(xmlFile, key .. ".maxLeaseValueScope#value", self.settings.maxLeaseValueScope)
    setXMLInt(xmlFile, key .. ".maxLeaseValuePercent#value", self.settings.maxLeaseValuePercent)
    setXMLFloat(xmlFile, key .. ".maxLeaseStaticValue#value", self.settings.maxLeaseStaticValue)
    setXMLInt(xmlFile, key .. ".maxLeasedItems#value", self.settings.maxLeasedItems)
    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function LeasingExtension:loadSettings()
    local filePath = self.getSettingsFilePath()
    if not fileExists(filePath) then
        self:saveSettings()
        return
    end

    local xmlFile = loadXMLFile("LeasingExtensionSettings", filePath)
    if xmlFile == nil or xmlFile == 0 then
        return
    end

    local key = "LeasingExtension"

    if hasXMLProperty(xmlFile, key .. ".maxLeaseValueMode#value") then
        self.settings.maxLeaseValueMode = getXMLString(xmlFile, key .. ".maxLeaseValueMode#value") or self.defaults.maxLeaseValueMode
    end
    if hasXMLProperty(xmlFile, key .. ".maxLeaseValueScope#value") then
        self.settings.maxLeaseValueScope = getXMLString(xmlFile, key .. ".maxLeaseValueScope#value") or self.defaults.maxLeaseValueScope
    end
    if hasXMLProperty(xmlFile, key .. ".maxLeaseValuePercent#value") then
        self.settings.maxLeaseValuePercent = getXMLInt(xmlFile, key .. ".maxLeaseValuePercent#value") or self.defaults.maxLeaseValuePercent
    end
    if hasXMLProperty(xmlFile, key .. ".maxLeaseStaticValue#value") then
        self.settings.maxLeaseStaticValue = getXMLFloat(xmlFile, key .. ".maxLeaseStaticValue#value") or self.defaults.maxLeaseStaticValue
    end
    if hasXMLProperty(xmlFile, key .. ".maxLeasedItems#value") then
        self.settings.maxLeasedItems = getXMLInt(xmlFile, key .. ".maxLeasedItems#value") or self.defaults.maxLeasedItems
    end

    delete(xmlFile)
end

function LeasingExtension:getMaxPurchasePriceLimit(farm)
    if self.settings.maxLeaseValueMode == "static" then
        local staticValue = tonumber(self.settings.maxLeaseStaticValue) or self.defaults.maxLeaseStaticValue
        if staticValue <= 0 then
            return nil
        end
        return staticValue
    end

    local farmValue = 0
    if farm ~= nil then
        if farm.getFarmValue ~= nil then
            farmValue = farm:getFarmValue() or 0
        elseif farm.totalValue ~= nil then
            farmValue = farm.totalValue or 0
        elseif farm.moneyValue ~= nil then
            farmValue = farm.moneyValue or 0
        end
    end

    local pct = math.max(0.01, math.min(3, (self.settings.maxLeaseValuePercent or 10) / 100))
    return farmValue * pct
end

function LeasingExtension:getMaxLeasedItemsLimit()
    local value = tonumber(self.settings.maxLeasedItems) or 0
    if value < 0 then
        return 0
    end
    return value
end

function LeasingExtension:getPurchasePriceValue(leaseData)
    if leaseData == nil then
        return nil
    end

    -- Try multiple possible field names for purchase price
    local candidates = {
        leaseData.purchasePrice,
        leaseData.price,
        leaseData.itemPrice,
        leaseData.item and leaseData.item.purchasePrice,
        leaseData.item and leaseData.item.price,
    }

    for _, value in ipairs(candidates) do
        local numericValue = tonumber(value)
        if numericValue ~= nil and numericValue > 0 then
            return numericValue
        end
    end

    return nil
end

function LeasingExtension:getFarmLeasedPurchaseTotal(farm)
    if farm == nil then
        return 0
    end

    local total = 0
    local sources = {}

    if type(farm.leasedItems) == "table" then
        table.insert(sources, farm.leasedItems)
    end
    if type(farm.rentedItems) == "table" then
        table.insert(sources, farm.rentedItems)
    end

    for _, source in ipairs(sources) do
        if type(source) == "table" then
            for _, entry in pairs(source) do
                local purchasePrice = self:getPurchasePriceValue(entry)
                if purchasePrice ~= nil then
                    total = total + purchasePrice
                end
            end
        end
    end

    return total
end

function LeasingExtension:applyLeaseLimit(leaseData, farm)
    if leaseData == nil then
        return leaseData
    end

    local maxItems = self:getMaxLeasedItemsLimit()
    if maxItems > 0 and leaseData.itemCount ~= nil and leaseData.itemCount > maxItems then
        leaseData.itemCount = maxItems
    end

    local maxPurchasePrice = self:getMaxPurchasePriceLimit(farm)
    local purchasePrice = self:getPurchasePriceValue(leaseData)

    if maxPurchasePrice == nil or purchasePrice == nil then
        return leaseData
    end

    if self.settings.maxLeaseValueScope == "total" then
        local totalLeasedPurchaseValue = self:getFarmLeasedPurchaseTotal(farm)
        if purchasePrice ~= nil then
            totalLeasedPurchaseValue = totalLeasedPurchaseValue + purchasePrice
        end

        if maxPurchasePrice ~= nil and totalLeasedPurchaseValue > maxPurchasePrice then
            local excess = totalLeasedPurchaseValue - maxPurchasePrice
            local adjustedPrice = math.max(0, (purchasePrice or 0) - excess)

            if leaseData.purchasePrice ~= nil then
                leaseData.purchasePrice = adjustedPrice
            end
            if leaseData.price ~= nil then
                leaseData.price = adjustedPrice
            end
            if leaseData.itemPrice ~= nil then
                leaseData.itemPrice = adjustedPrice
            end
            if leaseData.item ~= nil and type(leaseData.item) == "table" then
                if leaseData.item.purchasePrice ~= nil then
                    leaseData.item.purchasePrice = adjustedPrice
                end
                if leaseData.item.price ~= nil then
                    leaseData.item.price = adjustedPrice
                end
            end
        end
    else
        -- Per-item cap
        if purchasePrice ~= nil and purchasePrice > maxPurchasePrice then
            local adjustedPrice = maxPurchasePrice

            if leaseData.purchasePrice ~= nil then
                leaseData.purchasePrice = adjustedPrice
            end
            if leaseData.price ~= nil then
                leaseData.price = adjustedPrice
            end
            if leaseData.itemPrice ~= nil then
                leaseData.itemPrice = adjustedPrice
            end
            if leaseData.item ~= nil and type(leaseData.item) == "table" then
                if leaseData.item.purchasePrice ~= nil then
                    leaseData.item.purchasePrice = adjustedPrice
                end
                if leaseData.item.price ~= nil then
                    leaseData.item.price = adjustedPrice
                end
            end
        end
    end

    return leaseData
end

function LeasingExtension:installLeaseHooks()
    -- Hook BuyVehicleData:updatePrice() to intercept and apply lease caps
    -- This is called whenever a lease price needs to be calculated
    if BuyVehicleData ~= nil and type(BuyVehicleData.updatePrice) == "function" then
        local originalUpdatePrice = BuyVehicleData.updatePrice
        BuyVehicleData.updatePrice = function(self, ...)
            -- Call original to calculate base price
            originalUpdatePrice(self, ...)
            
            -- Apply lease extension limits if this is a lease
            if self.leaseVehicle and self.price ~= nil then
                local farm = g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.farm or nil
                local adjustedPrice = LeasingExtension:applyLeasePriceCap(self.price, farm)
                if adjustedPrice ~= nil then
                    self.price = adjustedPrice
                end
            end
        end
        self:log("Lease price hook installed successfully on BuyVehicleData:updatePrice()")
    else
        self:log("Warning: Could not hook BuyVehicleData:updatePrice() - leasing limits will not be enforced")
    end
end

---Apply lease price cap based on settings
function LeasingExtension:applyLeasePriceCap(leasePrice, farm)
    if leasePrice == nil or leasePrice <= 0 then
        return nil
    end
    
    local maxPurchasePrice = self:getMaxPurchasePriceLimit(farm)
    if maxPurchasePrice == nil then
        return nil
    end
    
    if self.settings.maxLeaseValueScope == "total" then
        local totalLeasedPurchaseValue = self:getFarmLeasedPurchaseTotal(farm)
        if (totalLeasedPurchaseValue or 0) + leasePrice > maxPurchasePrice then
            -- Cap the price so total doesn't exceed limit
            return math.max(0, maxPurchasePrice - (totalLeasedPurchaseValue or 0))
        end
    else
        -- Per-item cap
        if leasePrice > maxPurchasePrice then
            return maxPurchasePrice
        end
    end
    
    return nil  -- No adjustment needed
end

LeasingExtensionMenuCallbacks = {}
LeasingExtensionMenuCallbacks.name = ""

function LeasingExtensionMenuCallbacks.onMenuOptionChanged(self, state, menuOption)
    local id = menuOption.id
    local def = LeasingExtension.SETTINGS[id]
    if def == nil then
        return
    end

    local value = def.values[state]
    if value ~= nil then
        LeasingExtension.setSettingValue(id, value)
    end

    LeasingExtension:saveSettings()
    LeasingExtension:updateMenuState()
end

function LeasingExtensionMenuCallbacks.onNumericValueChanged(self, inputElement)
    if inputElement == nil then
        return
    end

    local id = inputElement.id
    if id == nil then
        return
    end

    local value = tonumber(inputElement:getValue() or inputElement:getText() or 0)
    if value == nil then
        return
    end

    LeasingExtension.setSettingValue(id, value)
    LeasingExtension:saveSettings()
    LeasingExtension:updateMenuState()
end

local function updateFocusIds(element)
    if not element then
        return
    end
    element.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(element.elements) do
        updateFocusIds(child)
    end
end

function LeasingExtension:updateMenuState()
    local valueMode = self.settings.maxLeaseValueMode
    local modeIsValueBased = valueMode == "valueBased"

    for _, id in ipairs(self.menuItems) do
        local control = self.CONTROLS[id]
        if control ~= nil then
            if id == "maxLeaseValuePercent" then
                control:setDisabled(not modeIsValueBased)
            elseif id == "maxLeaseStaticValue" then
                control:setDisabled(modeIsValueBased)
                if control.setText ~= nil then
                    control:setText(tostring(self.settings.maxLeaseStaticValue))
                elseif control.setValue ~= nil then
                    control:setValue(self.settings.maxLeaseStaticValue)
                end
            else
                control:setDisabled(false)
            end

            if control.setState ~= nil then
                control:setState(self.getStateIndex(id))
            end
        end
    end
end

function LeasingExtension:installLeaseButtonHooks()
    -- Attempt to hook into lease button handlers if they exist at runtime
    local targetNames = {"VehicleShopDialog", "VehicleMenu", "LeasingMenu"}

    for _, name in ipairs(targetNames) do
        local target = _G[name]
        if type(target) == "table" then
            local methodNames = {"onClickLease", "onLeaseClicked", "onLeaseButtonClicked"}
            for _, methodName in ipairs(methodNames) do
                if type(target[methodName]) == "function" and not target[methodName].LeasingExtensionWrapped then
                    local original = target[methodName]
                    target[methodName] = function(selfArg, ...)
                        if type(selfArg.showLeasingMenu) == "function" then
                            selfArg:showLeasingMenu()
                        elseif type(selfArg.openLeasingMenu) == "function" then
                            selfArg:openLeasingMenu()
                        end
                        return original(selfArg, ...)
                    end
                    target[methodName].LeasingExtensionWrapped = true
                    LeasingExtension:log("Lease button hook installed for %s.%s", name, methodName)
                end
            end
        end
    end
end

function LeasingExtension.injectMenu()
    if self.settingsInjected then
        return
    end

    local inGameMenu = g_gui.screenControllers[InGameMenu]
    if inGameMenu == nil then
        Logging.warning("LeasingExtension: Could not find InGameMenu controller")
        return
    end

    local settingsPage = inGameMenu.pageSettings
    if settingsPage == nil then
        Logging.warning("LeasingExtension: Could not find settings page")
        return
    end

    LeasingExtensionMenuCallbacks.name = settingsPage.name

    local function addBinaryMenuOption(id)
        local callback = "onMenuOptionChanged"
        local options = LeasingExtension.SETTINGS[id].strings

        local originalBox = settingsPage.checkWoodHarvesterAutoCutBox
        if originalBox == nil then
            for _, elem in ipairs(settingsPage.generalSettingsLayout.elements) do
                if elem.elements ~= nil and #elem.elements > 0 then
                    local firstChild = elem.elements[1]
                    if firstChild ~= nil and firstChild:isa(BinaryOptionElement) then
                        originalBox = elem
                        break
                    end
                end
            end
        end
        if originalBox == nil then
            return nil
        end

        local menuOptionBox = originalBox:clone(settingsPage.generalSettingsLayout)
        menuOptionBox.id = id .. "box"

        local menuBinaryOption = menuOptionBox.elements[1]
        menuBinaryOption.id = id
        menuBinaryOption.target = LeasingExtensionMenuCallbacks
        menuBinaryOption:setCallback("onClickCallback", callback)
        menuBinaryOption:setDisabled(false)

        local label = menuOptionBox.elements[2]
        if label ~= nil and label.setText ~= nil then
            label:setText(g_i18n:getText("leasingExtension_setting_" .. id))
        end

        menuBinaryOption:setTexts({unpack(options)})
        menuBinaryOption:setState(LeasingExtension.getStateIndex(id))

        LeasingExtension.CONTROLS[id] = menuBinaryOption
        updateFocusIds(menuOptionBox)
        table.insert(settingsPage.controlsList, menuOptionBox)
        return menuOptionBox
    end

    local function addMultiMenuOption(id)
        local callback = "onMenuOptionChanged"
        local options = LeasingExtension.SETTINGS[id].strings

        local originalBox = settingsPage.multiVolumeVoiceBox
        if originalBox == nil then
            for _, elem in ipairs(settingsPage.generalSettingsLayout.elements) do
                if elem.elements ~= nil and #elem.elements > 0 then
                    local firstChild = elem.elements[1]
                    if firstChild ~= nil and firstChild:isa(MultiTextOptionElement) then
                        originalBox = elem
                        break
                    end
                end
            end
        end
        if originalBox == nil then
            return nil
        end

        local menuOptionBox = originalBox:clone(settingsPage.generalSettingsLayout)
        menuOptionBox.id = id .. "box"

        local menuMultiOption = menuOptionBox.elements[1]
        menuMultiOption.id = id
        menuMultiOption.target = LeasingExtensionMenuCallbacks
        menuMultiOption:setCallback("onClickCallback", callback)
        menuMultiOption:setDisabled(false)

        local label = menuOptionBox.elements[2]
        if label ~= nil and label.setText ~= nil then
            label:setText(g_i18n:getText("leasingExtension_setting_" .. id))
        end

        menuMultiOption:setTexts({unpack(options)})
        menuMultiOption:setState(LeasingExtension.getStateIndex(id))

        LeasingExtension.CONTROLS[id] = menuMultiOption
        updateFocusIds(menuOptionBox)
        table.insert(settingsPage.controlsList, menuOptionBox)
        return menuOptionBox
    end

    local function addNumericMenuOption(id)
        local originalBox = settingsPage.platenNumberBox
        if originalBox == nil then
            for _, elem in ipairs(settingsPage.generalSettingsLayout.elements) do
                if elem.elements ~= nil and #elem.elements > 0 then
                    local firstChild = elem.elements[1]
                    if firstChild ~= nil and (firstChild:isa(TextInputElement) or firstChild:isa(NumberInputElement) or firstChild:isa(IntegerInputElement)) then
                        originalBox = elem
                        break
                    end
                end
            end
        end
        if originalBox == nil then
            return nil
        end

        local menuOptionBox = originalBox:clone(settingsPage.generalSettingsLayout)
        menuOptionBox.id = id .. "box"

        local inputElement = menuOptionBox.elements[1]
        inputElement.id = id
        inputElement.target = LeasingExtensionMenuCallbacks
        inputElement:setDisabled(false)

        if inputElement.setText ~= nil then
            inputElement:setText(tostring(LeasingExtension.getSettingValue(id)))
        elseif inputElement.setValue ~= nil then
            inputElement:setValue(LeasingExtension.getSettingValue(id))
        end

        if inputElement.setMin ~= nil then
            inputElement:setMin(LeasingExtension.SETTINGS[id].min or 0)
        end
        if inputElement.setMax ~= nil then
            inputElement:setMax(LeasingExtension.SETTINGS[id].max or 1000000000)
        end
        if inputElement.setCallback ~= nil then
            inputElement:setCallback("onTextChanged", "onNumericValueChanged")
            inputElement:setCallback("onFocusLost", "onNumericValueChanged")
        end

        local label = menuOptionBox.elements[2]
        if label ~= nil and label.setText ~= nil then
            label:setText(g_i18n:getText("leasingExtension_setting_" .. id))
        end

        LeasingExtension.CONTROLS[id] = inputElement
        updateFocusIds(menuOptionBox)
        table.insert(settingsPage.controlsList, menuOptionBox)
        return menuOptionBox
    end

    local sectionTitle = nil
    for _, elem in ipairs(settingsPage.generalSettingsLayout.elements) do
        if elem.name == "sectionHeader" then
            sectionTitle = elem:clone(settingsPage.generalSettingsLayout)
            break
        end
    end

    if sectionTitle then
        sectionTitle:setText(g_i18n:getText("leasingExtension_settingsTitle"))
    else
        sectionTitle = TextElement.new()
        sectionTitle:applyProfile("fs25_settingsSectionHeader", true)
        sectionTitle:setText(g_i18n:getText("leasingExtension_settingsTitle"))
        sectionTitle.name = "sectionHeader"
        settingsPage.generalSettingsLayout:addElement(sectionTitle)
    end

    sectionTitle.focusId = FocusManager:serveAutoFocusId()
    table.insert(settingsPage.controlsList, sectionTitle)

    for _, id in ipairs(LeasingExtension.menuItems) do
        local def = LeasingExtension.SETTINGS[id]
        if def ~= nil then
            if id == "maxLeaseStaticValue" then
                addNumericMenuOption(id)
            elseif #def.values == 2 then
                addBinaryMenuOption(id)
            else
                addMultiMenuOption(id)
            end
        end
    end

    settingsPage.generalSettingsLayout:invalidateLayout()
    LeasingExtension:updateMenuState()
    LeasingExtension.settingsInjected = true

    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
        LeasingExtension:updateMenuState()
    end)

    FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
        if gui == "ingameMenuSettings" then
            for _, control in pairs(LeasingExtension.CONTROLS) do
                if not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
                    if not FocusManager:loadElementFromCustomValues(control, nil, nil, false, false) then
                        Logging.warning("LeasingExtension: Could not register control %s with focus manager", control.id or tostring(control.focusId))
                    end
                end
            end
        end
    end)

    Logging.info("LeasingExtension: Settings injected into Game Settings menu")
end

function LeasingExtension:loadMap(mission)
    self.isLoaded = true
    self:initSettingsDefs()
    self:loadSettings()
    self:installLeaseHooks()
    self:installLeaseButtonHooks()
    self:injectMenu()
    self:log("loadMap() called")
    addModEventListener(LeasingExtension)
end

function LeasingExtension:deleteMap()
    self.isLoaded = false
    self:log("deleteMap() called")
end

function LeasingExtension:update(dt)
    if not self.isLoaded then
        return
    end
end

addModEventListener(LeasingExtension)
