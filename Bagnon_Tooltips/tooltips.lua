--[[
	Bagnon Tooltips
		Does ownership tooltips based on Bagnon_Forever data
--]]

local currentPlayer = UnitName('player')
local SILVER = '|cffc7c7cf%s|r'
local TEAL = '|cff00ff9a%s|r'

-- Locales
local L_TOTAL = "Total"
local L_GUILD_BANK = "Guild Bank"

local locale = GetLocale()
if locale == "zhCN" then
	L_TOTAL = "总计"
	L_GUILD_BANK = "公会银行"
elseif locale == "zhTW" then
	L_TOTAL = "總計"
	L_GUILD_BANK = "公會銀行"
elseif locale == "ruRU" then
	L_TOTAL = "Всего"
	L_GUILD_BANK = "Гильдейский банк"
elseif locale == "deDE" then
	L_TOTAL = "Gesamt"
	L_GUILD_BANK = "Gildenbank"
end

-- Forward declarations
local BagnonTooltipsScrollChild
local optionsPanel = CreateFrame("Frame", "BagnonTooltipsOptionsPanel", UIParent)
optionsPanel.name = "Bagnon Tooltips"

local textSettingsPanel = CreateFrame("Frame", "BagnonTooltipsTextSettingsPanel", UIParent)
textSettingsPanel.name = "Text Settings"
textSettingsPanel.parent = "Bagnon Tooltips"

-- Default Settings & Init
local function InitDB()
	if not BagnonTooltipsDB then
		BagnonTooltipsDB = {}
	end
	if BagnonTooltipsDB.shortNumbers == nil then
		BagnonTooltipsDB.shortNumbers = true
	end
	if BagnonTooltipsDB.condense == nil then
		BagnonTooltipsDB.condense = true
	end
	if BagnonTooltipsDB.guildBank == nil then
		BagnonTooltipsDB.guildBank = true
	end
	if not BagnonTooltipsDB.blacklist then
		BagnonTooltipsDB.blacklist = {}
	end
	if BagnonTooltipsDB.fontSize == nil then
		BagnonTooltipsDB.fontSize = 12
	end
	if BagnonTooltipsDB.fontPath == nil then
		BagnonTooltipsDB.fontPath = "Default"
	end
	if BagnonTooltipsDB.playerColor == nil then
		BagnonTooltipsDB.playerColor = "00ff9a"
	end
	if BagnonTooltipsDB.detailColor == nil then
		BagnonTooltipsDB.detailColor = "c7c7cf"
	end
end

-- Color helpers
local function GetPlayerColor()
	return (BagnonTooltipsDB and BagnonTooltipsDB.playerColor) or "00ff9a"
end

local function GetDetailColor()
	return (BagnonTooltipsDB and BagnonTooltipsDB.detailColor) or "c7c7cf"
end

local function formatPlayerColor(text)
	return string.format("|cff%s%s|r", GetPlayerColor(), text)
end

local function formatDetailColor(text)
	return string.format("|cff%s%s|r", GetDetailColor(), text)
end

local function RGBToHex(r, g, b)
	return string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function HexToRGB(hex)
	if not hex or #hex ~= 6 then return 1, 1, 1 end
	local r = tonumber(hex:sub(1, 2), 16) or 255
	local g = tonumber(hex:sub(3, 4), 16) or 255
	local b = tonumber(hex:sub(5, 6), 16) or 255
	return r / 255, g / 255, b / 255
end

local function OpenColorPicker(currentHex, callback)
	local r, g, b = HexToRGB(currentHex)

	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame.hasOpacity = false

	ColorPickerFrame.func = function()
		local newR, newG, newB = ColorPickerFrame:GetColorRGB()
		local newHex = RGBToHex(newR, newG, newB)
		callback(newHex)
	end

	ColorPickerFrame.cancelFunc = function()
		callback(currentHex)
	end

	ColorPickerFrame:Show()
end

-- Formatting functions
local function FormatNumber(count)
	if not BagnonTooltipsDB or not BagnonTooltipsDB.shortNumbers then
		return tostring(count)
	end
	if count >= 1000000 then
		-- millions: 3 decimal places
		return string.format("%.3fm", count / 1000000)
	elseif count >= 1000 then
		-- thousands: 1 decimal place
		return string.format("%.1fk", count / 1000)
	else
		return tostring(count)
	end
end

local function FormatMoney(money)
	local gold = math.floor(money / 10000)
	local silver = math.floor((money % 10000) / 100)
	local copper = money % 100

	local result = ""
	if gold > 0 then
		result = result .. gold .. "|cffffd700g|r "
	end
	if silver > 0 or gold > 0 then
		result = result .. silver .. "|cffc7c7cfs|r "
	end
	result = result .. copper .. "|cffeda55fc|r"
	return result
end

local function GetNumBagsString(count)
	local fmt = (BAGNON_NUM_BAGS or 'Bags: %d'):gsub("%%d", "%%s")
	return fmt:format(FormatNumber(count))
end

local function GetNumBankString(count)
	local fmt = (BAGNON_NUM_BANK or 'Bank: %d'):gsub("%%d", "%%s")
	return fmt:format(FormatNumber(count))
end

local function CountsToInfoString(invCount, bankCount, equipCount)
	local info
	local total = invCount + bankCount + equipCount

	if invCount > 0 then
		info = GetNumBagsString(invCount)
	end

	if bankCount > 0 then
		local countStr = GetNumBankString(bankCount)
		if info then
			info = strjoin(', ', info, countStr)
		else
			info = countStr
		end
	end

	if equipCount > 0 then
		if info then
			info = strjoin(', ', info, BAGNON_EQUIPPED or 'Equipped')
		else
			info = BAGNON_EQUIPPED or 'Equipped'
		end
	end

	if info then
		if total and not(total == invCount or total == bankCount or total == equipCount) then
			local totalStr = formatPlayerColor(FormatNumber(total))
			return totalStr .. formatDetailColor(string.format(' (%s)', info))
		end
		return formatPlayerColor(FormatNumber(total))
	end
end

local function GetPlayerCounts(player, link)
	local invCount = BagnonDB:GetItemCount(link, KEYRING_CONTAINER, player) or 0
	for bag = 0, NUM_BAG_SLOTS do
		invCount = invCount + (BagnonDB:GetItemCount(link, bag, player) or 0)
	end

	local bankCount = BagnonDB:GetItemCount(link, BANK_CONTAINER, player) or 0
	for i = 1, NUM_BANKBAGSLOTS do
		bankCount = bankCount + (BagnonDB:GetItemCount(link, NUM_BAG_SLOTS + i, player) or 0)
	end

	local equipCount = BagnonDB:GetItemCount(link, 'e', player) or 0

	return invCount, bankCount, equipCount
end

local function IsBlacklisted(itemLink)
	if not BagnonTooltipsDB or not BagnonTooltipsDB.blacklist then return false end
	if not itemLink then return false end
	local itemName, _, _, _, _, _, _, _, _, _, _ = GetItemInfo(itemLink)

	-- Extract item ID from link
	local itemID = tonumber(itemLink:match("item:(%d+)"))

	-- Check ID in blacklist
	if itemID then
		if BagnonTooltipsDB.blacklist[itemID] or BagnonTooltipsDB.blacklist[tostring(itemID)] then
			return true
		end
	end

	-- Check Name in blacklist (case-insensitive)
	if itemName then
		local lowerName = string.lower(itemName)
		if BagnonTooltipsDB.blacklist[lowerName] then
			return true
		end
	end

	return false
end

local function AddOwners(frame, link)
	if not BagnonTooltipsDB then
		return
	end
	if IsBlacklisted(link) then
		return
	end

	local totalCount = 0
	local playersData = {}

	-- Get player counts
	for player in BagnonDB:GetPlayers() do
		local invCount, bankCount, equipCount = GetPlayerCounts(player, link)
		local charTotal = invCount + bankCount + equipCount
		if charTotal > 0 then
			totalCount = totalCount + charTotal
			playersData[player] = CountsToInfoString(invCount, bankCount, equipCount)
		end
	end

	-- Get Guild Bank count
	local guildTotal = 0
	if BagnonTooltipsDB.guildBank and BagnonDB.GetGuildItemCount then
		guildTotal = BagnonDB:GetGuildItemCount(link) or 0
		totalCount = totalCount + guildTotal
	end

	if totalCount == 0 then
		return
	end

	local isCondensed = BagnonTooltipsDB.condense and not IsShiftKeyDown()

	local numLinesBefore = frame:NumLines()

	if isCondensed then
		-- Option A: single aggregated line across the account
		frame:AddDoubleLine(formatPlayerColor(L_TOTAL), formatPlayerColor(FormatNumber(totalCount)))
	else
		-- Expanded: show each character separately, guild bank, and total at the bottom
		local sortedPlayers = {}
		for player in pairs(playersData) do
			table.insert(sortedPlayers, player)
		end
		table.sort(sortedPlayers, function(a, b)
			if a == currentPlayer then return true end
			if b == currentPlayer then return false end
			return a < b
		end)

		for _, player in ipairs(sortedPlayers) do
			local infoString = playersData[player]
			if infoString and infoString ~= '' then
				frame:AddDoubleLine(formatPlayerColor(player), infoString)
			end
		end

		if guildTotal > 0 then
			frame:AddDoubleLine(formatPlayerColor(L_GUILD_BANK), formatPlayerColor(FormatNumber(guildTotal)))
		end

		-- Total line at the bottom
		frame:AddDoubleLine(formatPlayerColor(L_TOTAL), formatPlayerColor(FormatNumber(totalCount)))
	end

	-- Apply custom font & font size to our added lines
	local numLinesAfter = frame:NumLines()
	for i = numLinesBefore + 1, numLinesAfter do
		local leftTextStr = _G[frame:GetName() .. "TextLeft" .. i]
		local rightTextStr = _G[frame:GetName() .. "TextRight" .. i]

		if leftTextStr then
			local currentFont, currentSize, currentFlags = leftTextStr:GetFont()
			local size = BagnonTooltipsDB.fontSize or currentSize
			local fontPath = (BagnonTooltipsDB.fontPath and BagnonTooltipsDB.fontPath ~= "Default") and BagnonTooltipsDB.fontPath or currentFont
			leftTextStr:SetFont(fontPath, size, currentFlags)
		end

		if rightTextStr then
			local currentFont, currentSize, currentFlags = rightTextStr:GetFont()
			local size = BagnonTooltipsDB.fontSize or currentSize
			local fontPath = (BagnonTooltipsDB.fontPath and BagnonTooltipsDB.fontPath ~= "Default") and BagnonTooltipsDB.fontPath or currentFont
			rightTextStr:SetFont(fontPath, size, currentFlags)
		end
	end

	frame:Show()
end

local function HookTip(tooltip)
	tooltip:HookScript('OnTooltipSetItem', function(self, ...)
		local itemLink = select(2, self:GetItem())
		if itemLink and GetItemInfo(itemLink) then --fix for blizzard doing craziness when doing getiteminfo
			AddOwners(self, itemLink)
		end
	end)
end

HookTip(GameTooltip)
HookTip(ItemRefTooltip)

-- Checkbox creation helper
local function CreateCheckbox(parent, label, settingKey, description)
	local check = CreateFrame("CheckButton", parent:GetName() .. "_" .. settingKey, parent, "InterfaceOptionsCheckButtonTemplate")

	_G[check:GetName() .. "Text"]:SetText(label)

	if description then
		check.tooltipText = description
	end

	check:SetScript("OnShow", function(self)
		self:SetChecked(BagnonTooltipsDB and BagnonTooltipsDB[settingKey])
	end)

	check:SetScript("OnClick", function(self)
		if BagnonTooltipsDB then
			BagnonTooltipsDB[settingKey] = not not self:GetChecked()
		end
	end)

	return check
end

-- Dropdown creation helper
local function CreateDropdown(parent, label, settingKey, items, width)
	local labelString = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	labelString:SetText(label)

	local dropdown = CreateFrame("Frame", parent:GetName() .. "_" .. settingKey, parent, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(dropdown, width or 120)

	local function Dropdown_OnClick(self)
		UIDropDownMenu_SetSelectedValue(dropdown, self.value)
		if BagnonTooltipsDB then
			BagnonTooltipsDB[settingKey] = self.value
		end
	end

	local function Dropdown_Initialize(self)
		local selectedValue = (BagnonTooltipsDB and BagnonTooltipsDB[settingKey]) or items[1].value
		for _, item in ipairs(items) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = item.text
			info.value = item.value
			info.func = Dropdown_OnClick
			info.checked = (item.value == selectedValue)
			UIDropDownMenu_AddButton(info)
		end
	end

	dropdown:SetScript("OnShow", function(self)
		UIDropDownMenu_Initialize(self, Dropdown_Initialize)
		local selectedValue = (BagnonTooltipsDB and BagnonTooltipsDB[settingKey]) or items[1].value
		UIDropDownMenu_SetSelectedValue(self, selectedValue)
	end)

	return dropdown, labelString
end

-- Bidirectional Color Picker helper
local function CreateColorPickerControl(parent, label, settingKey)
	local container = CreateFrame("Frame", parent:GetName() .. "_" .. settingKey, parent)
	container:SetSize(260, 36)

	-- Label
	local labelString = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	labelString:SetText(label)
	labelString:SetSize(120, 20)
	labelString:SetJustifyH("LEFT")
	labelString:SetPoint("LEFT", 0, 0)

	-- Color Button
	local colorBtn = CreateFrame("Button", container:GetName() .. "_Btn", container)
	colorBtn:SetSize(20, 20)
	colorBtn:SetPoint("LEFT", labelString, "RIGHT", 12, 0)

	local bgTex = colorBtn:CreateTexture(nil, "BACKGROUND")
	bgTex:SetAllPoints()
	bgTex:SetTexture(1, 1, 1)
	colorBtn.bgTex = bgTex

	local border = colorBtn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	border:SetSize(22, 22)
	border:SetPoint("CENTER", 0, 0)
	border:SetVertexColor(0.5, 0.5, 0.5, 0.5)

	-- Hex Input Box
	local hexBox = CreateFrame("EditBox", container:GetName() .. "_Hex", container, "InputBoxTemplate")
	hexBox:SetSize(60, 24)
	hexBox:SetPoint("LEFT", colorBtn, "RIGHT", 16, 0)
	hexBox:SetMaxLetters(6)
	hexBox:SetAutoFocus(false)

	local function UpdateControlUI(hexVal)
		hexBox:SetText(hexVal)
		local r, g, b = HexToRGB(hexVal)
		bgTex:SetVertexColor(r, g, b)
	end

	colorBtn:SetScript("OnClick", function()
		local currentHex = (BagnonTooltipsDB and BagnonTooltipsDB[settingKey]) or "ffffff"
		OpenColorPicker(currentHex, function(newHex)
			if BagnonTooltipsDB then
				BagnonTooltipsDB[settingKey] = newHex
				UpdateControlUI(newHex)
			end
		end)
	end)

	hexBox:SetScript("OnTextChanged", function(self)
		local text = self:GetText():lower()
		if text:match("^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") then
			if BagnonTooltipsDB then
				BagnonTooltipsDB[settingKey] = text
				local r, g, b = HexToRGB(text)
				bgTex:SetVertexColor(r, g, b)
			end
		end
	end)

	hexBox:SetScript("OnEditFocusLost", function(self)
		local currentHex = (BagnonTooltipsDB and BagnonTooltipsDB[settingKey]) or "ffffff"
		self:SetText(currentHex)
	end)

	container:SetScript("OnShow", function()
		local currentHex = (BagnonTooltipsDB and BagnonTooltipsDB[settingKey]) or "ffffff"
		UpdateControlUI(currentHex)
	end)

	return container
end

local listButtons = {}

function optionsPanel:RefreshList()
	for _, btn in ipairs(listButtons) do
		btn:Hide()
	end

	if not BagnonTooltipsDB or not BagnonTooltipsDB.blacklist then return end

	-- Get sorted list of blacklisted keys
	local keys = {}
	for k, v in pairs(BagnonTooltipsDB.blacklist) do
		if v then
			table.insert(keys, k)
		end
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	local yOffset = 0
	for i, key in ipairs(keys) do
		local btn = listButtons[i]
		if not btn then
			btn = CreateFrame("Frame", "BagnonTooltipsBlacklistEntry" .. i, BagnonTooltipsScrollChild)
			btn:SetSize(240, 24)

			-- Text
			local text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			text:SetPoint("LEFT", 8, 0)
			text:SetPoint("RIGHT", -32, 0)
			text:SetJustifyH("LEFT")
			btn.text = text

			-- Delete Button with standard texture path
			local del = CreateFrame("Button", nil, btn)
			del:SetSize(16, 16)
			del:SetPoint("RIGHT", -8, 0)
			del:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
			del:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
			del:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")

			del:SetScript("OnClick", function()
				if BagnonTooltipsDB and BagnonTooltipsDB.blacklist then
					BagnonTooltipsDB.blacklist[btn.key] = nil
					print(string.format("|cff00ff9aBagnon Tooltips:|r Removed '%s' from the blacklist.", tostring(btn.key)))
					optionsPanel:RefreshList()
				end
			end)

			listButtons[i] = btn
		end

		btn.key = key
		btn.text:SetText(tostring(key))
		btn:SetPoint("TOPLEFT", 0, -yOffset)
		btn:Show()

		yOffset = yOffset + 24
	end

	if BagnonTooltipsScrollChild then
		BagnonTooltipsScrollChild:SetHeight(math.max(1, yOffset))
	end
end

local function HandleBlacklistCmd(msg)
	msg = msg and msg:trim()
	if not msg or msg == "" then
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
		return
	end

	if not BagnonTooltipsDB then return end

	local cmd, target = msg:match("^(%S+)%s*(.*)$")
	if cmd then
		cmd = cmd:lower()
	end

	if cmd == "list" then
		print("|cff00ff9aBagnon Tooltips Blacklist:|r")
		local count = 0
		for k, v in pairs(BagnonTooltipsDB.blacklist) do
			if v then
				print(" - " .. tostring(k))
				count = count + 1
			end
		end
		if count == 0 then
			print(" (Empty)")
		end
		return
	end

	local action, itemIdentifier
	if cmd == "add" then
		action = "add"
		itemIdentifier = target:trim()
	elseif cmd == "remove" or cmd == "rem" or cmd == "del" then
		action = "remove"
		itemIdentifier = target:trim()
	else
		action = "toggle"
		itemIdentifier = msg
	end

	if not itemIdentifier or itemIdentifier == "" then
		print("Usage: /bgbl [add|remove|list] [itemLink or itemID]")
		return
	end

	-- Extract Item ID or Name from itemLink or use as-is
	local itemID = tonumber(itemIdentifier) or tonumber(itemIdentifier:match("item:(%d+)"))
	local itemName
	if not itemID then
		itemName = itemIdentifier:match("%[(.-)%]") or itemIdentifier
	else
		itemName = GetItemInfo(itemID)
	end

	local key = itemID or (itemName and itemName:lower()) or itemIdentifier:lower()

	if action == "add" then
		BagnonTooltipsDB.blacklist[key] = true
		print(string.format("|cff00ff9aBagnon Tooltips:|r Added '%s' to the blacklist.", tostring(key)))
	elseif action == "remove" then
		BagnonTooltipsDB.blacklist[key] = nil
		print(string.format("|cff00ff9aBagnon Tooltips:|r Removed '%s' from the blacklist.", tostring(key)))
	else -- toggle
		if BagnonTooltipsDB.blacklist[key] then
			BagnonTooltipsDB.blacklist[key] = nil
			print(string.format("|cff00ff9aBagnon Tooltips:|r Removed '%s' from the blacklist.", tostring(key)))
		else
			BagnonTooltipsDB.blacklist[key] = true
			print(string.format("|cff00ff9aBagnon Tooltips:|r Added '%s' to the blacklist.", tostring(key)))
		end
	end

	if optionsPanel and optionsPanel.RefreshList then
		optionsPanel:RefreshList()
	end
end

local fontItems = {
	{ text = "Default", value = "Default" },
	{ text = "Friz Quadrata", value = "Fonts\\FRIZQT__.TTF" },
	{ text = "Arial Narrow", value = "Fonts\\ARIALN.TTF" },
	{ text = "Morpheus", value = "Fonts\\MORPHEUS.TTF" },
	{ text = "Skurri", value = "Fonts\\skurri.ttf" }
}

-- Currency tracking and dynamic Money frame hooking
local function AppendCurrencyTooltip(tooltip, currencyName)
	if not BagnonTooltipsDB or not currencyName then return end
	if IsBlacklisted(currencyName) then return end

	local total = 0
	local playersData = {}

	for player in BagnonDB:GetPlayers() do
		local count = BagnonDB.GetCurrencyCount and BagnonDB:GetCurrencyCount(player, currencyName) or 0
		if count > 0 then
			total = total + count
			playersData[player] = count
		end
	end

	if total == 0 then return end

	tooltip:AddLine(" ")
	tooltip:AddLine(formatPlayerColor(currencyName .. " " .. L_TOTAL .. ": " .. FormatNumber(total)))

	local sortedPlayers = {}
	for player in pairs(playersData) do
		table.insert(sortedPlayers, player)
	end
	table.sort(sortedPlayers, function(a, b)
		if a == currentPlayer then return true end
		if b == currentPlayer then return false end
		return a < b
	end)

	for _, player in ipairs(sortedPlayers) do
		tooltip:AddDoubleLine(formatPlayerColor(player), formatDetailColor(FormatNumber(playersData[player])))
	end

	tooltip:Show()
end

if GameTooltip.SetCurrencyToken then
	hooksecurefunc(GameTooltip, "SetCurrencyToken", function(self, index)
		if GetCurrencyListInfo then
			local name = GetCurrencyListInfo(index)
			if name then
				AppendCurrencyTooltip(self, name)
			end
		end
	end)
end

if GameTooltip.SetBackpackToken then
	hooksecurefunc(GameTooltip, "SetBackpackToken", function(self, index)
		if GetBackpackCurrencyInfo then
			local name = GetBackpackCurrencyInfo(index)
			if name then
				AppendCurrencyTooltip(self, name)
			end
		end
	end)
end

hooksecurefunc(GameTooltip, "Show", function(self)
	if self.bagnonGoldShown then return end

	local focus = GetMouseFocus()
	if focus and focus:GetName() and (focus:GetName():find("MoneyFrame") or focus:GetName():find("Money")) then
		self.bagnonGoldShown = true

		local total = 0
		local playersData = {}
		for player in BagnonDB:GetPlayers() do
			local money = BagnonDB:GetMoney(player) or 0
			if money > 0 then
				total = total + money
				playersData[player] = money
			end
		end

		if total > 0 then
			self:AddLine(" ")
			self:AddLine(formatPlayerColor("Account Balance: " .. FormatMoney(total)))

			local sortedPlayers = {}
			for player in pairs(playersData) do
				table.insert(sortedPlayers, player)
			end
			table.sort(sortedPlayers, function(a, b)
				if a == currentPlayer then return true end
				if b == currentPlayer then return false end
				return a < b
			end)

			for _, player in ipairs(sortedPlayers) do
				self:AddDoubleLine(formatPlayerColor(player), FormatMoney(playersData[player]))
			end
		end
	end
end)

hooksecurefunc(GameTooltip, "Hide", function(self)
	self.bagnonGoldShown = nil
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "Bagnon_Tooltips" then
		InitDB()

		-- Setup Main Options Panel
		optionsPanel.name = "Bagnon Tooltips"

		local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", 16, -16)
		title:SetText("Bagnon Tooltips Settings")

		-- Column 1 (Left Column)
		local cbShort = CreateCheckbox(optionsPanel, "Enable Short Number Formatting", "shortNumbers", "Format numbers like 23.4k and 1.234m.")
		cbShort:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)

		local cbCondense = CreateCheckbox(optionsPanel, "Condense Tooltip by Default", "condense", "Hold Shift to show character breakdown, otherwise shows total count.")
		cbCondense:SetPoint("TOPLEFT", cbShort, "BOTTOMLEFT", 0, -8)

		local cbGuild = CreateCheckbox(optionsPanel, "Enable Guild Bank Tracking", "guildBank", "Include Guild Bank contents in tooltips.")
		cbGuild:SetPoint("TOPLEFT", cbCondense, "BOTTOMLEFT", 0, -8)

		local blTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		blTitle:SetPoint("TOPLEFT", cbGuild, "BOTTOMLEFT", 0, -20)
		blTitle:SetText("Blacklisted Items (Names or IDs):")

		local editBox = CreateFrame("EditBox", "BagnonTooltipsBlacklistInput", optionsPanel, "InputBoxTemplate")
		editBox:SetSize(160, 26)
		editBox:SetPoint("TOPLEFT", blTitle, "BOTTOMLEFT", 4, -8)
		editBox:SetAutoFocus(false)

		local addButton = CreateFrame("Button", "BagnonTooltipsBlacklistAddBtn", optionsPanel, "UIPanelButtonTemplate")
		addButton:SetSize(60, 22)
		addButton:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
		addButton:SetText("Add")

		addButton:SetScript("OnClick", function(self)
			local text = editBox:GetText()
			if text and text:trim() ~= "" then
				HandleBlacklistCmd("add " .. text:trim())
				editBox:SetText("")
				editBox:ClearFocus()
			end
		end)

		editBox:SetScript("OnEnterPressed", function(self)
			addButton:Click()
		end)

		local listBg = CreateFrame("Frame", "BagnonTooltipsBlacklistBg", optionsPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
		listBg:SetSize(250, 160)
		listBg:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", -4, -12)
		listBg:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 3, right = 3, top = 3, bottom = 3 }
		})
		listBg:SetBackdropColor(0, 0, 0, 0.5)
		listBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1.0)

		local scrollFrame = CreateFrame("ScrollFrame", "BagnonTooltipsScrollFrame", listBg, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 8, -8)
		scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

		BagnonTooltipsScrollChild = CreateFrame("Frame", "BagnonTooltipsScrollChild", scrollFrame)
		BagnonTooltipsScrollChild:SetSize(210, 1)
		scrollFrame:SetScrollChild(BagnonTooltipsScrollChild)

		optionsPanel:SetScript("OnShow", function(self)
			self:RefreshList()
		end)

		InterfaceOptions_AddCategory(optionsPanel)

		-- Setup Sub-category Options Panel (Text Settings)
		local subTitle = textSettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		subTitle:SetPoint("TOPLEFT", 16, -16)
		subTitle:SetText("Bagnon Tooltips - Text Settings")

		-- Font Size Textbox (EditBox)
		local lblSize = textSettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		lblSize:SetText("Font Size (6-36):")
		lblSize:SetPoint("TOPLEFT", subTitle, "BOTTOMLEFT", 4, -20)

		local sizeInput = CreateFrame("EditBox", "BagnonTooltipsFontSizeInput", textSettingsPanel, "InputBoxTemplate")
		sizeInput:SetSize(60, 26)
		sizeInput:SetPoint("TOPLEFT", lblSize, "BOTTOMLEFT", 4, -8)
		sizeInput:SetNumeric(true)
		sizeInput:SetMaxLetters(2)
		sizeInput:SetAutoFocus(false)

		-- Indicator of current Font Size
		local currentSizeLabel = textSettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		currentSizeLabel:SetPoint("LEFT", sizeInput, "RIGHT", 16, 0)

		local function UpdateSizeLabel()
			local sz = (BagnonTooltipsDB and BagnonTooltipsDB.fontSize) or 12
			currentSizeLabel:SetText("Current Size: " .. sz)
		end

		sizeInput:SetScript("OnShow", function(self)
			self:SetText(tostring((BagnonTooltipsDB and BagnonTooltipsDB.fontSize) or 12))
			UpdateSizeLabel()
		end)

		sizeInput:SetScript("OnTextChanged", function(self)
			local text = self:GetText()
			local val = tonumber(text)
			if val then
				if val < 6 then val = 6 end
				if val > 36 then val = 36 end
				if BagnonTooltipsDB then
					BagnonTooltipsDB.fontSize = val
					UpdateSizeLabel()
				end
			end
		end)

		sizeInput:SetScript("OnEditFocusLost", function(self)
			local sz = (BagnonTooltipsDB and BagnonTooltipsDB.fontSize) or 12
			self:SetText(tostring(sz))
			UpdateSizeLabel()
		end)

		-- Font Type Dropdown
		local ddFont, lblFont = CreateDropdown(textSettingsPanel, "Font Type:", "fontPath", fontItems, 120)
		lblFont:SetPoint("TOPLEFT", sizeInput, "BOTTOMLEFT", -4, -20)
		ddFont:SetPoint("TOPLEFT", sizeInput, "BOTTOMLEFT", -19, -36)

		-- Bidirectional Color Pickers (Player Name Color and Count Detail Color)
		local playerColorPicker = CreateColorPickerControl(textSettingsPanel, "Player Name Color:", "playerColor")
		playerColorPicker:SetPoint("TOPLEFT", ddFont, "BOTTOMLEFT", 19, -20)

		local detailColorPicker = CreateColorPickerControl(textSettingsPanel, "Count Detail Color:", "detailColor")
		detailColorPicker:SetPoint("TOPLEFT", playerColorPicker, "BOTTOMLEFT", 0, -10)

		InterfaceOptions_AddCategory(textSettingsPanel)

		-- Register Slash Commands
		SlashCmdList["BAGNONTOOLTIPS"] = HandleBlacklistCmd
		SLASH_BAGNONTOOLTIPS1 = "/bagnonbl"
		SLASH_BAGNONTOOLTIPS2 = "/bgbl"
		SLASH_BAGNONTOOLTIPS3 = "/bgnbl"
	end
end)
