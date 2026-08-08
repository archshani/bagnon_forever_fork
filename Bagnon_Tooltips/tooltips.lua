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

-- Color Scheme Presets
local SCHEMES = {
	Default = { player = "00ff9a", detail = "c7c7cf" },
	Classic = { player = "00ff00", detail = "888888" },
	Ocean = { player = "00c0ff", detail = "ffffff" },
	Volcano = { player = "ff8000", detail = "ffff00" },
	Royal = { player = "a335ee", detail = "ff69b4" },
	Monochrome = { player = "ffffff", detail = "c7c7cf" }
}

-- Forward declarations
local BagnonTooltipsScrollChild
local optionsPanel = CreateFrame("Frame", "BagnonTooltipsOptionsPanel", UIParent)
optionsPanel.name = "Bagnon Tooltips"

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
	if BagnonTooltipsDB.colorScheme == nil then
		BagnonTooltipsDB.colorScheme = "Default"
	end
end

-- Custom color helpers
local function GetPlayerColor()
	local scheme = (BagnonTooltipsDB and BagnonTooltipsDB.colorScheme) or "Default"
	local colors = SCHEMES[scheme] or SCHEMES.Default
	return colors.player
end

local function GetDetailColor()
	local scheme = (BagnonTooltipsDB and BagnonTooltipsDB.colorScheme) or "Default"
	local colors = SCHEMES[scheme] or SCHEMES.Default
	return colors.detail
end

local function formatPlayerColor(text)
	return string.format("|cff%s%s|r", GetPlayerColor(), text)
end

local function formatDetailColor(text)
	return string.format("|cff%s%s|r", GetDetailColor(), text)
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

local listButtons = {}

function optionsPanel:RefreshList()
	-- Hide all existing buttons
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

			-- Delete Button
			local del = CreateFrame("Button", nil, btn)
			del:SetSize(16, 16)
			del:SetPoint("RIGHT", -8, 0)

			local ntex = del:CreateTexture()
			ntex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
			ntex:SetAllPoints()
			del:SetNormalTexture(ntex)

			local ptex = del:CreateTexture()
			ptex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
			ptex:SetAllPoints()
			del:SetPushedTexture(ptex)

			local htex = del:CreateTexture()
			htex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
			htex:SetAllPoints()
			del:SetHighlightTexture(htex)

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
		-- Open options panel
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

local colorSchemeItems = {
	{ text = "Teal & Silver (Default)", value = "Default" },
	{ text = "Green & Grey (Classic)", value = "Classic" },
	{ text = "Blue & White (Ocean)", value = "Ocean" },
	{ text = "Orange & Yellow (Volcano)", value = "Volcano" },
	{ text = "Purple & Pink (Royal)", value = "Royal" },
	{ text = "White & Silver (Monochrome)", value = "Monochrome" }
}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "Bagnon_Tooltips" then
		InitDB()

		-- Setup Options Panel GUI
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

		-- Column 2 (Right Column, X = 300)
		-- Font Size Textbox (EditBox)
		local lblSize = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		lblSize:SetText("Font Size (6-36):")
		lblSize:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 300, -24)

		local sizeInput = CreateFrame("EditBox", "BagnonTooltipsFontSizeInput", optionsPanel, "InputBoxTemplate")
		sizeInput:SetSize(50, 26)
		sizeInput:SetPoint("TOPLEFT", lblSize, "BOTTOMLEFT", 4, -8)
		sizeInput:SetNumeric(true)
		sizeInput:SetMaxLetters(2)
		sizeInput:SetAutoFocus(false)

		sizeInput:SetScript("OnShow", function(self)
			self:SetText(tostring((BagnonTooltipsDB and BagnonTooltipsDB.fontSize) or 12))
		end)

		sizeInput:SetScript("OnTextChanged", function(self)
			local text = self:GetText()
			local val = tonumber(text)
			if val then
				if val < 6 then val = 6 end
				if val > 36 then val = 36 end
				if BagnonTooltipsDB then
					BagnonTooltipsDB.fontSize = val
				end
			end
		end)

		sizeInput:SetScript("OnEditFocusLost", function(self)
			self:SetText(tostring((BagnonTooltipsDB and BagnonTooltipsDB.fontSize) or 12))
		end)

		-- Font Type Dropdown
		local ddFont, lblFont = CreateDropdown(optionsPanel, "Font Type", "fontPath", fontItems, 120)
		lblFont:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 300, -84)
		ddFont:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 285, -100)

		-- Color Scheme Dropdown (Combined Player + Detail Colors)
		local ddScheme, lblScheme = CreateDropdown(optionsPanel, "Color Scheme", "colorScheme", colorSchemeItems, 160)
		lblScheme:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 300, -154)
		ddScheme:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 285, -170)

		optionsPanel:SetScript("OnShow", function(self)
			self:RefreshList()
		end)

		InterfaceOptions_AddCategory(optionsPanel)

		-- Register Slash Commands
		SlashCmdList["BAGNONTOOLTIPS"] = HandleBlacklistCmd
		SLASH_BAGNONTOOLTIPS1 = "/bagnonbl"
		SLASH_BAGNONTOOLTIPS2 = "/bgbl"
		SLASH_BAGNONTOOLTIPS3 = "/bgnbl"
	end
end)
