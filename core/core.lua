--core 

local addonName,addon = ...
local AG = LibStub("AceGUI-3.1")

--TODO cleanup this global
ClientBets = addon:GetModule("ClientBets")
BookieBets = addon:GetModule("BookieBets")

--TODO not necessary
Bookie = addon

--TODO move over to bookie
addon.ClientBets = ClientBets
addon.BookieBets = BookieBets

local ClientQuitConfirmationPopup = "BOOKIE_CLIENT_CONFIRM_QUIT"
StaticPopupDialogs[ClientQuitConfirmationPopup] = {
	text = "Are you sure you want to quit?\nAny bets will for forfeited.",
	button1 = "Quit",
	button2 = "Cancel",
	OnAccept = function()
		ClientBets:QuitBet()
	end,
	timeout = 15,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local BookieCancelConfirmationPopup = "BOOKIE_BOOKIE_CONFIRM_CANCEL_BET"
StaticPopupDialogs[BookieCancelConfirmationPopup] = {
	text = "Are you sure you want to cancel this bet?",
	button1 = "Confirm",
	button2 = "Cancel",
	OnAccept = function()
		BookieBets:CancelBet()
	end,
	timeout = 15,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local FrameDefaults = {
	width = 284,
	height = 330,
	lobby = {
		widget = function() return addon:MDB_GetTabLobby() end,
		height = 200,
	},
	bookie_create = {
		widget = function() return addon:GetTabBookieCreate() end,
		height = 210,
	},
	bookie_status = {
		widget = function() return addon:GetTabBookieStatus() end,
		height = 390,
		width = 300
	},
	client_joined = {
		widget = function() return addon:GetTabClientJoined() end,
		height = 260,
	},
	client_waiting = {
		widget = function() return addon:GetTabClientWaiting() end,
		height = 240,
	},
	add_entrant = {
		height = 260
	},
}

local frame = nil 
local root = nil

local BookieFontDuelerChoice = CreateFont("BookieFontDuelerChoice")
BookieFontDuelerChoice:SetFontObject(GameFontNormalHuge2)
local BookieFontDuelerChoiceSm = CreateFont("BookieFontDuelerChoiceSm")
BookieFontDuelerChoiceSm:SetFontObject(GameFontNormalLarge)

local DuelerColors = {
	[1] = { (143/255), (154/255), (209/255) },
	[2] = { (216/255), (89/255), (38/255) },
}

local MoneyColor = { 1.0, 0.82, 0 }

local ClientStatusData = {
	[addon.clientStatus.WaitingForTrade] = {
		text = "Pay your Bookie",
		color = DuelerColors[2],
	},
	[addon.clientStatus.WaitingForResults] = {
		text = "Waiting for Results",
		color = DuelerColors[1],
	},
	[addon.clientStatus.WaitingForPayout] = {
		text = "WINNER!",
		color = DuelerColors[2],
	},
	[addon.clientStatus.ConclusionLost] = {
		text = "LOSER",
		color = DuelerColors[1],
	},
	[addon.clientStatus.ConclusionPaid] = {
		text = "PAID",
		color = DuelerColors[1],
	},
}

local BookieStatusData = {
	[addon.clientStatus.Inactive] = {
		text = "INACTIVE",
		color = DuelerColors[1],
	},
	[addon.clientStatus.WaitingForWager] = {
		text = "CHOOSING OPTION",
		color = DuelerColors[1],
	},
	[addon.clientStatus.WaitingForTrade] = {
		text = "NEEDS TO PAY",
		color = DuelerColors[2],
	},
	[addon.clientStatus.WaitingForResults] = {
		text = "BET",
		color = DuelerColors[1],
	},
	[addon.clientStatus.WaitingForPayout] = {
		text = "NEEDS",
		color = DuelerColors[2],
	},
	[addon.clientStatus.ConclusionLost] = {
		text = "LOST",
		color = DuelerColors[1],
	},
	[addon.clientStatus.ConclusionPaid] = {
		text = "PAID",
		color = DuelerColors[1],
	},
}

function Bookie:ValidBetParams(dueler1, dueler2, minbet, maxbet, rake)
	local validNames = dueler1 ~= nil and dueler2 ~= nil and dueler1 ~= "" and dueler2 ~= "" and dueler1 ~= dueler2 
 	return validNames and minbet and maxbet and rake and (tonumber(minbet) < tonumber(maxbet))
end

--TODO move to utils
function Bookie:GetRake(text)
	rake = string.gsub(text, "%%", "")
	rake = tonumber(rake)/100
	return rake
end

local function ValidWager(wager)
	return string.match(wager, '%D') == nil and tonumber(wager) > 0
end

local function ValidName(name)
	return string.match(name, '%w') ~= nil
end

function Bookie:DrawFrame(key)
	addon:Debug("Getting active widget "..key)
	local default = FrameDefaults[key]
	root:ReleaseChildren()
	root:AddChild(default.widget())
	frame:SetHeight(default.height or FrameDefaults.height)
	frame:SetWidth(default.width or FrameDefaults.width)
end

function Bookie:GUIInit()
	frame = AG:Create("Frame")
	frame:SetTitle("Bookie")
	frame:SetLayout("Fill")
	frame:SetCallback("OnClose", function(widget) AG:Release(widget) end)
	frame:SetWidth(FrameDefaults.width)
	frame:SetHeight(FrameDefaults.height)

	root = AG:Create("SimpleGroup")
	frame:AddChild(root)
	root:SetLayout("Flow")

	if addon.isBookie then
		addon:Debug("resuming active bookie bets")
		self:GUIRefresh_BookieStatus()
	else
		ClientBets:GetActiveBet()
		if not ClientBets.activeBet then
			ClientBets:GetAvailableBets()
		end

		self:GUIRefresh_Lobby()
	end
end

function Bookie:GUIRefresh_ClientJoined()
	if not frame:IsVisible() then return end
	self:DrawFrame("client_joined")
end

function Bookie:GUIRefresh_ClientWaiting()
	if not frame:IsVisible() then return end
	self:DrawFrame("client_waiting")
end

function Bookie:GUIRefresh_BookieCreate()
	if not frame:IsVisible() then return end
	self:DrawFrame("bookie_create")
end

function Bookie:GUIRefresh_BookieStatus()
	if not frame:IsVisible() then return end
	self:DrawFrame("bookie_status")
end

function Bookie:GUIRefresh_Lobby()
	if not frame:IsVisible() then return end
	self:DrawFrame("lobby")
end

function Bookie:GUI_ShowRootFrame()
	if not frame:IsVisible() then
		self:GUIInit()
		frame:Show()
	end
end

function Bookie:GUI_HideRootFrame()
	frame:Hide()
end

function Bookie:MDB_GetTabLobby()
	returnGroup = AG:Create("SimpleGroup")
	returnGroup:SetFullWidth(true)
	returnGroup:SetFullHeight(true)

	body = AG:Create("SimpleGroup")
	body:SetLayout("List")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	returnGroup:AddChild(body)

	local bookiePanel = AG:Create("SimpleGroup")
	bookiePanel:SetFullWidth(true)
	bookiePanel:SetLayout("Flow")
	body:AddChild(bookiePanel)

	bookieButton = AG:Create("Button")
	bookiePanel:AddChild(bookieButton)
	bookieButton:SetText("Create New Bookie Session")
	bookieButton:SetFullWidth(true)
	bookieButton:SetCallback("OnClick", 
		function() 
			addon:GUIRefresh_BookieCreate()
		end )

	horzLine = AG:Create("Heading")
	horzLine:SetRelativeWidth(1)
	body:AddChild(horzLine)

	--scrollable table of available bets
	clientJoinPanel = AG:Create("SimpleGroup")
	clientJoinPanel:SetLayout("Flow")
	clientJoinPanel:SetFullWidth(true)
	body:AddChild(clientJoinPanel)

	local scrollContainer = AG:Create("SimpleGroup")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetHeight(100)
	scrollContainer:SetLayout("Fill")
	clientJoinPanel:AddChild(scrollContainer)

	local scroll = AG:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scrollContainer:AddChild(scroll)

	for idx=1, #ClientBets.availableBets do
		bet = ClientBets.availableBets[idx]

		fillCount = 1
		--if addon.debug then fillCount = 20 end

		for i=1, fillCount do 
			entry = AG:Create("SimpleGroup")
			entry:SetFullWidth(true)
			entry:SetLayout("Flow")
			scroll:AddChild(entry)

			namePanel = AG:Create("SimpleGroup")
			namePanel:SetRelativeWidth(0.7)
			namePanel:SetLayout("Flow")
			entry:AddChild(namePanel)

			buttonPanel = AG:Create("SimpleGroup")
			buttonPanel:SetRelativeWidth(0.3)
			buttonPanel:SetLayout("Flow")
			entry:AddChild(buttonPanel)

			local entryLabel = AG:Create("Label")
			entryLabel:SetText(bet.duelers[1].." VS ".. bet.duelers[2])
			namePanel:AddChild(entryLabel)
			local bookieLabel = AG:Create("Label")
			bookieLabel:SetText("Bookie: "..bet.bookie)
			namePanel:AddChild(bookieLabel)

			local joinButton = AG:Create("Button")
			joinButton:SetText("Join")
			joinButton:SetFullWidth(true)
			joinButton:SetFullHeight(true)
			joinButton:SetCallback("OnClick", function() ClientBets:JoinBet(idx) end) 
			buttonPanel:AddChild(joinButton)
		end
	end

	if #ClientBets.availableBets == 0 then
		noneLabel = AG:Create("Label")
		noneLabel:SetText("Waiting for a bookie...")
		scroll:AddChild(noneLabel)
	end

	return returnGroup
end

function Bookie:GetTabBookieCreate()
	local returnGroup = AG:Create("SimpleGroup")
	returnGroup:SetFullWidth(true)
	returnGroup:SetFullHeight(true)

	local header = AG:Create("SimpleGroup")
	header:SetFullWidth(true)
	header:SetLayout("Flow")
	returnGroup:AddChild(header)
	local body = AG:Create("SimpleGroup")
	body:SetFullWidth(true)
	body:SetLayout("List")
	returnGroup:AddChild(body)

	local headerLabel = AG:Create("Label")
	headerLabel:SetText("Creating a New Bookie Session")
	header:AddChild(headerLabel)

	local dueler1Name, dueler2Name, rake
	local minbet = 0
	local maxbet = math.huge
	local startButton

	if addon.debug then dueler1Name, dueler2Name = "Lootch", "Deulbookie" end

	local duelerContainer = AG:Create("SimpleGroup")
	duelerContainer:SetFullWidth(true)
	duelerContainer:SetLayout("Flow")
	body:AddChild(duelerContainer)

	local dueler1Editbox = AG:Create("EditBox")
	dueler1Editbox:SetLabel("Choice #1")
	dueler1Editbox:SetText(dueler1Name)
	dueler1Editbox:SetRelativeWidth(0.5)
	dueler1Editbox:SetMaxLetters(12)
	dueler1Editbox:DisableButton(true)
	dueler1Editbox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			dueler1Name = text 
			createBetStartButton:SetDisabled(not self:ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	duelerContainer:AddChild(dueler1Editbox)

	local dueler2Editbox = AG:Create("EditBox")
	dueler2Editbox:SetLabel("Choice #2")
	dueler2Editbox:SetText(dueler2Name)
	dueler2Editbox:SetRelativeWidth(0.5)
	dueler2Editbox:SetMaxLetters(12)
	dueler2Editbox:DisableButton(true)
	dueler2Editbox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			dueler2Name = text 
			createBetStartButton:SetDisabled(not self:ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	duelerContainer:AddChild(dueler2Editbox)

	--TODO removing min/max bet for now. The data format is still there if we want to allow a bookie to set this
	--[[
	betsContainer = AG:Create("SimpleGroup")
	betsContainer:SetFullWidth(true)
	betsContainer:SetLayout("Flow")
	body:AddChild(betsContainer)

	minbetEditbox = AG:Create("EditBox")
	minbetEditbox:SetLabel("Minimum Bet (gold)")
	minbetEditbox:SetText(minbet)
	minbetEditbox:SetRelativeWidth(0.5)
	minbetEditbox:SetMaxLetters(4)
	minbetEditbox:DisableButton(true)
	minbetEditbox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			minbet = text 
			createBetStartButton:SetDisabled(not self:ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	betsContainer:AddChild(minbetEditbox)

	maxbetEditbox = AG:Create("EditBox")
	maxbetEditbox:SetLabel("Maximum Bet (gold)")
	maxbetEditbox:SetText(maxbet)
	maxbetEditbox:SetRelativeWidth(0.5)
	maxbetEditbox:SetMaxLetters(4)
	maxbetEditbox:DisableButton(true)
	maxbetEditbox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			maxbet = text 
			createBetStartButton:SetDisabled(not self:ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	betsContainer:AddChild(maxbetEditbox)
	--]]
	
	local rakeContainer = AG:Create("SimpleGroup")
	rakeContainer:SetFullWidth(true)
	rakeContainer:SetLayout("Flow")
	body:AddChild(rakeContainer)

	local rakeOptions = {
		rake0 = "0%",
		rake5 = "5%",
		rake10 = "10%",
		rake20 = "25%",
	}

	local rakeOptionOrder = { "rake0", "rake5", "rake10", "rake20" }
	rake = self:GetRake(rakeOptions.rake0)

	rakeDropdown = AG:Create("Dropdown")
	rakeDropdown:SetLabel("Percentage of gold taken from prize pool:")
	rakeDropdown:SetFullWidth(true)
	rakeDropdown:SetList(rakeOptions, rakeOptionOrder)
	rakeDropdown:SetValue("rake0")
	rakeDropdown:SetCallback("OnValueChanged", 
		function(widget, event, key) 
			rake = self:GetRake(rakeOptions[key])
			createBetStartButton:SetDisabled(not self:ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	rakeContainer:AddChild(rakeDropdown)

	horzLine = AG:Create("Heading")
	body:AddChild(horzLine)
	horzLine:SetRelativeWidth(1)

	footer = AG:Create("SimpleGroup")
	footer:SetFullWidth(true)
	footer:SetLayout("Flow")
	body:AddChild(footer)

	createBetStartButton = AG:Create("Button")
	footer:AddChild(createBetStartButton)
	createBetStartButton:SetText("Start")
	createBetStartButton:SetRelativeWidth(0.6)
	createBetStartButton:SetDisabled(not self:ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
	createBetStartButton:SetCallback("OnClick", 
		function() 
			addon:ChatMsg(
				string.format("Bookie: %s vs %s - Now open for bets", 
					string.upper(dueler1Name), 
					string.upper(dueler2Name)), 
				"SAY")
			BookieBets:CreateBet(dueler1Name, dueler2Name, minbet, maxbet, rake) 
			self:GUIRefresh_BookieStatus()
		end )

	local cancelBetButton = AG:Create("Button")
	footer:AddChild(cancelBetButton)
	cancelBetButton:SetText("Cancel")
	cancelBetButton:SetRelativeWidth(0.4)
	cancelBetButton:SetCallback("OnClick", function() self:GUIRefresh_Lobby() end )

	return returnGroup
end

function Bookie:GetControlButtons(status)
	addon:Debug("Get control buttons: "..status)
	controlBetsPanel = AG:Create("SimpleGroup")
	controlBetsPanel:SetLayout("Flow")

	if status == addon.betStatus.Open then
		
		local lastcallButton = AG:Create("Button")
		controlBetsPanel:AddChild(lastcallButton)
		lastcallButton:SetRelativeWidth(0.4)
		lastcallButton:SetText("Last Call")
		lastcallButton:SetCallback("OnClick", function() addon:ChatMsg("Bookie: Last call to place bets.", "SAY") end)

		local closeBetsButton = AG:Create("Button")
		controlBetsPanel:AddChild(closeBetsButton)
		closeBetsButton:SetRelativeWidth(0.6)
		closeBetsButton:SetDisabled(BookieBets:GetEntrantsCount() == 0)
		closeBetsButton:SetText("Close Bets")
		closeBetsButton:SetCallback("OnClick", 
			function() 
				BookieBets:CloseBets() 
			end)

	elseif status == addon.betStatus.BetsClosed then
		local finalLabel = AG:Create("Label")
		finalLabel:SetText("Choose Winner:")
		controlBetsPanel:AddChild(finalLabel)
		finalLabel:SetFullWidth(true)

		dueler1Button = AG:Create("Button")
		dueler1Button:SetText(BookieBets.bet.duelers[1])
		dueler1Button:SetRelativeWidth(0.5)
		dueler1Button:SetCallback("OnClick", function() BookieBets:FinalizeDuelWinner(1) end)
		controlBetsPanel:AddChild(dueler1Button)
		
		dueler2Button = AG:Create("Button")
		dueler2Button:SetRelativeWidth(0.5)
		dueler2Button:SetText(BookieBets.bet.duelers[2])
		dueler2Button:SetCallback("OnClick", function() BookieBets:FinalizeDuelWinner(2) end)
		controlBetsPanel:AddChild(dueler2Button)

	elseif status == addon.betStatus.Complete or status == addon.betStatus.PendingPayout then
		returnButton = AG:Create("Button")
		controlBetsPanel:AddChild(returnButton)
		returnButton:SetFullWidth(true)
		returnButton:SetText("Return to Lobby")
		returnButton:SetCallback("OnClick", function() BookieBets:EndCurrentBet() end )

		--check if all entrants are paid
		entrantsPaid = BookieBets:AllEntrantsPaid()
		returnButton:SetDisabled(not entrantsPaid)
	end
	
	return controlBetsPanel
end

local function CreateAddEntrantFrame()
	addon:Debug("Adding entrant")

	if not addon.isBookie then addon:Debug("Error: not a bookie, cannot add player") return end
	if not BookieBets.bet then addon:Debug("Error: no active bet to add player") return end

	local bet = BookieBets.bet

	local frame = AG:Create("Frame")
	frame:SetWidth(FrameDefaults.width)
	frame:SetHeight(FrameDefaults.add_entrant.height)
	frame:SetTitle("Add New Entrant")

	local body = AG:Create("SimpleGroup")
	frame:AddChild(body)
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	body:SetLayout("List")

	local entrantName = ""
	local nameEditBox = AG:Create("EditBox")
	body:AddChild(nameEditBox)
	nameEditBox:SetFullWidth(true)
	nameEditBox:SetLabel("Entrant Name")
	nameEditBox:SetText(entrantName)
	nameEditBox:SetMaxLetters(10)
	nameEditBox:DisableButton(true)

	--TODO three edit boxes for gold, silver, copper
	local wager = 1
	wagerEditBox = AG:Create("EditBox")
	body:AddChild(wagerEditBox)
	wagerEditBox:SetLabel("Bet Amount (gold)")
	wagerEditBox:SetText(wager)
	wagerEditBox:SetRelativeWidth(1)
	wagerEditBox:SetMaxLetters(5)
	wagerEditBox:DisableButton(true)

	--dropdown for two choices
	local choice = 1
	choiceDropdown = AG:Create("Dropdown")
	body:AddChild(choiceDropdown)
	choiceDropdown:SetLabel("Select Choice")
	choiceDropdown:SetFullWidth(true)
	choiceDropdown:SetList(bet.duelers)
	choiceDropdown:SetValue(choice)
	choiceDropdown:SetCallback("OnValueChanged", 
		function(widget, event, key) 
			addon:Debug("dropdown choice: "..key)
			choice = key
		end)

	local submitButton = AG:Create("Button")
	body:AddChild(submitButton)
	submitButton:SetText("Submit")
	submitButton:SetFullWidth(true)
	submitButton:SetDisabled(not (ValidWager(wager) and ValidName(entrantName)) )
	submitButton:SetCallback("OnClick", function() 
		BookieBets:ReceiveClientJoinManual(entrantName, tonumber(wager)*10000, choice) --TODO temp 10000x until 3 editboxes in place
		frame:Hide()
	end)

	nameEditBox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			entrantName = text 
			submitButton:SetDisabled(not (ValidWager(wager) and ValidName(entrantName)) )
		end)

	wagerEditBox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			wager = text
			submitButton:SetDisabled(not (ValidWager(wager) and ValidName(entrantName)) )
		end)

end

function Bookie:GetTabBookieStatus()
	local bet = BookieBets.bet

	returnGroup = AG:Create("SimpleGroup")
	local body = AG:Create("SimpleGroup")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	body:SetLayout("List")
	returnGroup:AddChild(body)

	local cancelButton = AG:Create("Button")
	body:AddChild(cancelButton)
	cancelButton:SetFullWidth(true)
	cancelButton:SetText("Cancel Bet")
	cancelButton:SetCallback("OnClick", function() 
		StaticPopup_Show(BookieCancelConfirmationPopup)
	end)

	local horzline4 = AG:Create("Heading")
	horzline4:SetRelativeWidth(1)
	body:AddChild(horzline4)

	--dueler1, dueler2, wager
	local titleContainer = AG:Create("SimpleGroup")
	body:AddChild(titleContainer)
	titleContainer:SetFullWidth(true)
	titleContainer:SetLayout("Flow")

	local titleGroup = AG:Create("SimpleGroup")
	titleContainer:AddChild(titleGroup)
	titleGroup:SetLayout("Flow")
	titleGroup:SetFullWidth(true)

	local dueler1Label = AG:Create("Label")
	titleGroup:AddChild(dueler1Label)
	dueler1Label:SetText(bet.duelers[1])
	dueler1Label:SetJustifyH("RIGHT")
	dueler1Label:SetFontObject(BookieFontDuelerChoiceSm)
	dueler1Label:SetColor(unpack(DuelerColors[1]))
	dueler1Label:SetRelativeWidth(0.43)

	local vslabel = AG:Create("Label")
	titleGroup:AddChild(vslabel)
	vslabel:SetText("vs")
	vslabel:SetJustifyH("CENTER")
	vslabel:SetFontObject(BookieFontDuelerChoiceSm)
	vslabel:SetRelativeWidth(0.14)

	local dueler2Label = AG:Create("Label")
	titleGroup:AddChild(dueler2Label)
	dueler2Label:SetText(bet.duelers[2])
	dueler2Label:SetJustifyH("LEFT")
	dueler2Label:SetFontObject(BookieFontDuelerChoiceSm)
	dueler2Label:SetColor(unpack(DuelerColors[2]))
	dueler2Label:SetRelativeWidth(0.43)

	local horzline5 = AG:Create("Heading")
	horzline5:SetRelativeWidth(1)
	body:AddChild(horzline5)

	headerPanel = AG:Create("SimpleGroup")
	headerPanel:SetLayout("Flow")
	headerPanel:SetFullWidth(true)
	body:AddChild(headerPanel)

	headerPanelLeft = AG:Create("SimpleGroup")
	headerPanel:AddChild(headerPanelLeft)
	headerPanelLeft:SetRelativeWidth(0.35)
	headerPanelLeft:SetLayout("List")

	prizepoolLabel = AG:Create("Label")
	headerPanelLeft:AddChild(prizepoolLabel)
	prizepoolLabel:SetText("PURSE")

	local prizepoolMoneyLabel = AG:Create("Label")
	headerPanelLeft:AddChild(prizepoolMoneyLabel)
	prizepoolMoneyLabel:SetText(addon:FormatMoney(BookieBets:GetPrizePoolRaked()))
	prizepoolMoneyLabel:SetColor(unpack(MoneyColor))

	local headerPanelRight = AG:Create("SimpleGroup")
	headerPanel:AddChild(headerPanelRight)
	headerPanelRight:SetRelativeWidth(0.35)
	headerPanelRight:SetLayout("List")

	local rakeLabel = AG:Create("Label")
	headerPanelRight:AddChild(rakeLabel)
	rakeLabel:SetText("RAKE")

	local rakedMoney = BookieBets:GetRakeTotal()
	rakeMoneyLabel = AG:Create("Label")
	headerPanelRight:AddChild(rakeMoneyLabel)
	rakeMoneyLabel:SetText(addon:FormatMoney(rakedMoney))
	rakeMoneyLabel:SetColor(unpack(MoneyColor))

	local headerPanelCenter = AG:Create("SimpleGroup")
	headerPanel:AddChild(headerPanelCenter)
	headerPanelCenter:SetRelativeWidth(0.3)
	headerPanelCenter:SetLayout("List")

	local odds = BookieBets:CalculateOdds()

	oddsLabel = AG:Create("Label")
	headerPanelCenter:AddChild(oddsLabel)
	oddsLabel:SetText("ODDS")

	local oddsContainer = AG:Create("SimpleGroup")
	headerPanelCenter:AddChild(oddsContainer)
	oddsContainer:SetLayout("Flow")
	oddsContainer:SetRelativeWidth(1)

	local dueler1OddsLabel = AG:Create("Label")
	oddsContainer:AddChild(dueler1OddsLabel)

	
	dueler1OddsLabel:SetColor(unpack(DuelerColors[1]))
	dueler1OddsLabel:SetRelativeWidth(0.35)
	dueler1OddsLabel:SetJustifyH("RIGHT")

	local colonLabel = AG:Create("Label")
	oddsContainer:AddChild(colonLabel)
	colonLabel:SetText(" : ")
	colonLabel:SetRelativeWidth(0.12)

	local dueler2OddsLabel = AG:Create("Label")
	oddsContainer:AddChild(dueler2OddsLabel)
	dueler2OddsLabel:SetColor(unpack(DuelerColors[2]))
	dueler2OddsLabel:SetRelativeWidth(0.35)

	if tonumber(odds[1]) > 10 then
		dueler1OddsLabel:SetText(string.format("%.0f",odds[1]))
	else
		dueler1OddsLabel:SetText(string.format("%.1f",odds[1]))
	end

	if tonumber(odds[2]) > 10 then
		dueler2OddsLabel:SetText(string.format("%.0f",odds[2]))
	else
		dueler2OddsLabel:SetText(string.format("%.1f",odds[2]))
	end

	local horzline3 = AG:Create("Heading")
	horzline3:SetRelativeWidth(1)
	body:AddChild(horzline3)

	bottomPanel = AG:Create("SimpleGroup")
	body:AddChild(bottomPanel)
	bottomPanel:SetFullWidth(true)
	bottomPanel:SetLayout("Flow")

	local entrantsContainer = AG:Create("SimpleGroup")
	bottomPanel:AddChild(entrantsContainer)
	entrantsContainer:SetFullWidth(true)
	entrantsContainer:SetLayout("Flow")

	local leftLabel = AG:Create("Label")
	entrantsContainer:AddChild(leftLabel)
	leftLabel:SetText("ENTRANTS")
	leftLabel:SetRelativeWidth(0.8)

	local addButton = AG:Create("Button")
	entrantsContainer:AddChild(addButton)
	addButton:SetText("+")
	addButton:SetRelativeWidth(0.2)
	addButton:SetDisabled(bet.status ~= addon.betStatus.Open)
	addButton:SetCallback("OnClick", function() CreateAddEntrantFrame() end)

	horzlineLeft = AG:Create("Heading")
	horzlineLeft:SetRelativeWidth(1)
	bottomPanel:AddChild(horzlineLeft)

	--scrollable table of current entrants
	local scrollContainer = AG:Create("SimpleGroup")
	scrollContainer:SetLayout("Fill")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetHeight(100)
	bottomPanel:AddChild(scrollContainer)
	local scroll = AG:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scrollContainer:AddChild(scroll)

	--List entrants who have submitted 
	for name, data in pairs(BookieBets.bet.entrants) do
		--TODO purge entrants if they are clientStatus.ConclusionLost
		fillCount = 1
		--if addon.debug then fillCount = 20 end

		for i=1, fillCount do
			local entry = AG:Create("SimpleGroup")
			scroll:AddChild(entry)
			entry:SetFullWidth(true)
			entry:SetLayout("Flow")
			
			local entryName = AG:Create("Label")
			entryName:SetText(name)
			entryName:SetRelativeWidth(0.31)
			entry:AddChild(entryName)

			local status = data.status
			local entryStatus = AG:Create("Label")
			entry:AddChild(entryStatus)
			entryStatus:SetText(BookieStatusData[status].text)
			entryStatus:SetColor(unpack(BookieStatusData[status].color))
			entryStatus:SetRelativeWidth(0.375)
			entryStatus:SetJustifyH("CENTER")

			local entryWager = AG:Create("Label")
			entry:AddChild(entryWager)
			entryWager:SetRelativeWidth(0.10)
			entryWager:SetColor(unpack(MoneyColor))
			entryWager:SetJustifyH("CENTER")

			local removeButton = AG:Create("Button")
			entry:AddChild(removeButton)
			removeButton:SetRelativeWidth(0.165)
			removeButton:SetText("X")
			removeButton:SetDisabled(bet.status == addon.betStatus.BetsClosed)
			removeButton.entrant = name

			--TODO just declare this here for now
			local BookieRemoveEntrantConfirmationPopup = "BOOKIE_BOOKIE_CONFIRM_REMOVE_ENTRANT"
			StaticPopupDialogs[BookieRemoveEntrantConfirmationPopup] = {
				text = "Are you sure you want to remove this wager?",
				button1 = "Confirm",
				button2 = "Cancel",
				OnAccept = function()
					BookieBets:RemoveEntrant(removeButton.entrant) 
					addon:GUIRefresh_BookieStatus()
				end,
				timeout = 15,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}

			removeButton:SetCallback("OnClick", function() 
				StaticPopup_Show(BookieRemoveEntrantConfirmationPopup)
			end)

			moneyText = ""
			if data.wager and data.wager > 0 then 
				moneyText = addon:FormatMoney(data.wager)
				if data.status == addon.clientStatus.ConclusionPaid then
					moneyText = addon:FormatMoney(data.payoutReceived)
				elseif data.status > addon.clientStatus.WaitingForResults then
					moneyText = addon:FormatMoney(data.payout - data.payoutReceived)
				end
			end
			entryWager:SetText(moneyText)

			--resize for payout status
			if status >= addon.clientStatus.WaitingForResults then
				entryStatus:SetRelativeWidth(0.17)
				entryWager:SetRelativeWidth(0.32)
				removeButton:SetRelativeWidth(0.15)
			end
		end
	end

	horzSpacer = AG:Create("Heading")
	horzSpacer:SetRelativeWidth(1)
	body:AddChild(horzSpacer)

	controlPanel = AG:Create("SimpleGroup")
	body:AddChild(controlPanel)
	controlPanel:SetFullWidth(true)
	controlPanel:SetLayout("Flow")

	controlButtons = self:GetControlButtons(BookieBets.bet.status)
	controlPanel:AddChild(controlButtons)

	return returnGroup
end

function Bookie:GetTabClientJoined()
	addon:Debug("Create clientjoined tab")
	local returnGroup = AG:Create("SimpleGroup")

	local bet = ClientBets.activeBet

	--populate tab with bet data
	local body = AG:Create("SimpleGroup")
	body:SetLayout("List")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	returnGroup:AddChild(body)

	local cancelButton = AG:Create("Button")
	body:AddChild(cancelButton)
	cancelButton:SetText("Quit Session")
	cancelButton:SetFullWidth(true)
	cancelButton:SetCallback("OnClick", function() StaticPopup_Show(ClientQuitConfirmationPopup) end) 

	local horzline = AG:Create("Heading")
	horzline:SetRelativeWidth(1)
	body:AddChild(horzline)

	local duelerChoiceLabel = AG:Create("Label")
	duelerChoiceLabel:SetText("Select Your Choice")
	body:AddChild(duelerChoiceLabel)
	duelerChoiceLabel:SetJustifyH("CENTER")
	duelerChoiceLabel:SetFontObject(GameFontNormalLarge2)

	local duelerPanel = AG:Create("SimpleGroup")
	duelerPanel:SetLayout("Flow")
	duelerPanel:SetFullWidth(true)
	body:AddChild(duelerPanel)


	local dueler1Button = AG:Create("Button")
	dueler1Button:SetText(bet.duelers[1])
	dueler1Button:SetRelativeWidth(1)
	dueler1Button:SetHeight(50)
	duelerPanel:AddChild(dueler1Button)

	local dueler2Button = AG:Create("Button")
	dueler2Button:SetText(bet.duelers[2])
	dueler2Button:SetRelativeWidth(1)
	dueler2Button:SetHeight(50)
	duelerPanel:AddChild(dueler2Button)

	dueler1Button:SetCallback("OnClick", 
		function(button) 
			ClientBets:SubmitWager(1)
		end)

	dueler2Button:SetCallback("OnClick", 
		function(button) 
			ClientBets:SubmitWager(2)
		end)

	return returnGroup
end

function Bookie:GetTabClientWaiting()
	if not ClientBets.activeBet then addon:Debug("GUI Error! No active client bet.") return end

	local bet = ClientBets.activeBet
	local status = bet.entrants[addon.playerName].status

	if status == addon.clientStatus.WaitingForWager then
		return GetTabClientJoined()
	end

	local returnGroup = AG:Create("SimpleGroup")

	local body = AG:Create("SimpleGroup")
	body:SetLayout("List")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	returnGroup:AddChild(body)

	--dueler1, dueler2, wager
	local titleContainer = AG:Create("SimpleGroup")
	body:AddChild(titleContainer)
	titleContainer:SetFullWidth(true)
	titleContainer:SetLayout("Flow")

	local titleGroup = AG:Create("SimpleGroup")
	titleContainer:AddChild(titleGroup)
	titleGroup:SetLayout("Flow")
	titleGroup:SetFullWidth(true)

	local dueler1Label = AG:Create("Label")
	titleGroup:AddChild(dueler1Label)
	dueler1Label:SetText(bet.duelers[1])
	dueler1Label:SetJustifyH("RIGHT")
	dueler1Label:SetFontObject(BookieFontDuelerChoiceSm)
	dueler1Label:SetColor(unpack(DuelerColors[1]))
	dueler1Label:SetRelativeWidth(0.43)

	local vslabel = AG:Create("Label")
	titleGroup:AddChild(vslabel)
	vslabel:SetText("vs")
	vslabel:SetJustifyH("CENTER")
	vslabel:SetFontObject(BookieFontDuelerChoiceSm)
	vslabel:SetRelativeWidth(0.14)

	local dueler2Label = AG:Create("Label")
	titleGroup:AddChild(dueler2Label)
	dueler2Label:SetText(bet.duelers[2])
	dueler2Label:SetJustifyH("LEFT")
	dueler2Label:SetFontObject(BookieFontDuelerChoiceSm)
	dueler2Label:SetColor(unpack(DuelerColors[2]))
	dueler2Label:SetRelativeWidth(0.43)

	local horzLine1 = AG:Create("Heading")
	horzLine1:SetRelativeWidth(1)
	body:AddChild(horzLine1)

	--Bet info
	local betContainer = AG:Create("SimpleGroup")
	betContainer:SetLayout("List")
	betContainer:SetFullWidth(true)
	body:AddChild(betContainer)

	local choiceContainer = AG:Create("SimpleGroup")
	choiceContainer:SetFullWidth(true)
	betContainer:AddChild(choiceContainer)
	choiceContainer:SetLayout("Flow")
	local choiceLabel = AG:Create("Label")
	choiceLabel:SetRelativeWidth(0.28)
	choiceLabel:SetText("CHOICE: ")
	choiceContainer:AddChild(choiceLabel)

	local duelerChoiceLabel = AG:Create("Label")
	duelerChoiceLabel:SetText(ClientBets:GetChoiceText())
	local choiceIndex = ClientBets:GetChoiceIndex()
	duelerChoiceLabel:SetColor(unpack(DuelerColors[choiceIndex]))
	duelerChoiceLabel:SetRelativeWidth(0.72)
	choiceContainer:AddChild(duelerChoiceLabel)

	--bookie
	local bookieLabel = AG:Create("Label")
	bookieLabel:SetText("BOOKIE: "..ClientBets:GetBookie())
	betContainer:AddChild(bookieLabel)

	local horzLine2 = AG:Create("Heading")
	horzLine2:SetRelativeWidth(1)
	body:AddChild(horzLine2)

	--wagers and payouts	
	local payoutsContainer = AG:Create("SimpleGroup")
	payoutsContainer:SetLayout("Flow")
	payoutsContainer:SetFullWidth(true)
	body:AddChild(payoutsContainer)

	local wagerContainer = AG:Create("SimpleGroup")
	payoutsContainer:AddChild(wagerContainer)
	wagerContainer:SetLayout("List")
	wagerContainer:SetRelativeWidth(0.5)
	
	local wagerLabel = AG:Create("Label")
	wagerLabel:SetText("WAGER")
	wagerContainer:AddChild(wagerLabel)
	local wagerMoneyLabel = AG:Create("Label")
	wagerMoneyLabel:SetText(addon:FormatMoney(ClientBets:GetActiveWager()))
	wagerContainer:AddChild(wagerMoneyLabel)

	local payoutContainer = AG:Create("SimpleGroup")
	payoutsContainer:AddChild(payoutContainer)
	payoutContainer:SetLayout("List")
	payoutContainer:SetRelativeWidth(0.5)

	local payoutLabel = AG:Create("Label")
	payoutContainer:AddChild(payoutLabel)
	payoutLabel:SetText("PAYOUT")
	local payoutMoneyLabel = AG:Create("Label")
	payoutMoneyLabel:SetText(addon:FormatMoney(ClientBets:GetPayout()))
	payoutContainer:AddChild(payoutMoneyLabel)

	local horzLine2 = AG:Create("Heading")
	horzLine2:SetRelativeWidth(1)
	body:AddChild(horzLine2)

	--status text
	local statusContainer = AG:Create("SimpleGroup")
	statusContainer:SetLayout("List")
	statusContainer:SetFullWidth(true)
	body:AddChild(statusContainer)

	local statusLabelContainer = AG:Create("SimpleGroup")
	statusContainer:AddChild(statusLabelContainer)
	statusLabelContainer:SetLayout("Flow")
	statusLabelContainer:SetFullWidth(true)

	local statusLabel = AG:Create("Label")
	statusLabelContainer:AddChild(statusLabel)
	statusLabel:SetRelativeWidth(0.35)
	statusLabel:SetText("STATUS:")

	local statusLabel2 = AG:Create("Label")
	statusLabelContainer:AddChild(statusLabel2)
	statusLabel2:SetRelativeWidth(0.65)

	statusLabel2:SetText(ClientStatusData[status].text)
	statusLabel2:SetColor(unpack(ClientStatusData[status].color))

	local horzLine3 = AG:Create("Heading")
	horzLine3:SetRelativeWidth(1)
	body:AddChild(horzLine3)

	--cancel button
	local footer = AG:Create("SimpleGroup")
	footer:SetLayout("Flow")
	footer:SetFullWidth(true)
	body:AddChild(footer)

	local buttonText = "Return to Lobby"
	local buttonDisable = false

	if status == addon.clientStatus.WaitingForPayout then
		buttonDisable = true
		buttonText = "Waiting for Payout"
	end

	local cancelButton = AG:Create("Button")
	footer:AddChild(cancelButton)
	cancelButton:SetDisabled(buttonDisable)
	cancelButton:SetText(buttonText)
	cancelButton:SetFullWidth(true)
	
	if status <= addon.clientStatus.WaitingForPayout then
		cancelButton:SetCallback("OnClick", function() StaticPopup_Show(ClientQuitConfirmationPopup) end) 
	else
		cancelButton:SetCallback("OnClick", function() ClientBets:QuitBet() end)
	end

	return returnGroup
end

