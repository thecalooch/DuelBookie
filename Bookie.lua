local AddonName,addon = ...
_G.Bookie = LibStub('AceAddon-3.0'):NewAddon(addon, AddonName, "AceComm-3.0", "AceSerializer-3.0")

if BookieSave == nil then BookieSave = {} end
BookieSave.Bookie = Bookie

Bookie.playerName = nil
Bookie.debug = false
Bookie.autoAcceptTrades = false
Bookie.isBookie = false

local syncTargets = {}

Bookie.clientStatus = {
	Inactive = 1,
	WaitingForWager = 2,
	WaitingForTrade = 3,
	WaitingForResults = 4,
	WaitingForPayout = 5,
	ConclusionLost = 6,
	ConclusionPaid = 7,
}

--TODO remove, handling this in core gui
Bookie.clientStatusShort = {
	"DONE",
	"CHOOSING OPTION",
	"NEEDS TO PAY",
	"WAGERED",
	"NEEDS",
	"LOST",
	"WAS PAID",
}

Bookie.betStatus = {
	Open = 0,
	BetsClosed = 1,
	PendingPayout = 2,
	Complete = 3,
	Cancelled = 4,
}

function Bookie:LoadSavedVariables()
	addon:Debug("loading saved vars")
	addon.isBookie = BookieSave.Bookie.isBookie or false

	if addon.isBookie then
		BookieBets.bet = BookieSave.Bookie.BookieBets.bet
		BookieBets:UpdateClients()
	end 
end

function Bookie:OnInitialize()
	addon:Debug("Bookie initialize")
	addon:LoadSavedVariables()

	self.playerName = UnitName("player")
	self:RegisterComm("Bookie")
	self:GUIInit()

	if addon.debug then 
		addon:GUI_ShowRootFrame() 
	else
		addon:GUI_HideRootFrame()
	end
end

event_handlers = {
	TRADE_SHOW = {
		handler = function(...) 
			addon:Debug("TRADE_SHOW")
			if addon.isBookie then
				addon.BookieBets:InitiateTrade()
			else
				addon.ClientBets:InitiateTrade()
			end
		end,
	},
	TRADE_ACCEPT_UPDATE = {
		handler = function(...) 
			addon:Debug("TRADE_ACCEPT_UPDATE")
			local args = { ... }
			if addon.isBookie and addon.autoAcceptTrades and args[2] == 1 then
				AcceptTrade()
			end

			if args[1] == 1 then
				addon:Debug("one player accept")
				if addon.isBookie then
					addon.BookieBets:SetTradeAmount()	
				else
					addon.ClientBets:SetTradeAmount()	
				end
			end
		end,
	},
	TRADE_REQUEST_CANCEL = {
		handler = function(...) 
			addon:Debug("TRADE_REQUEST_CANCEL")
		end,
	},
	PLAYER_TRADE_MONEY = {
		handler = function(...) 
			addon:Debug("PLAYER_TRADE_MONEY")
			if addon.isBookie then
				addon.BookieBets:HandleTrade()	
			else
				addon.ClientBets:HandleTrade()	
			end
		end,
	},
	TRADE_CLOSED = {
		handler = function(...) 
			addon:Debug("TRADE_CLOSED")
			if addon.isBookie then
				addon.BookieBets:FinalizeTrade()	
			else
				addon.ClientBets:FinalizeTrade()	
			end
		end,
	},
	GROUP_JOINED = {
		handler = function(...) 
			addon:Debug("Joined group")
			if not addon.isBookie and not addon.ClientBets.activeBet then
				addon.ClientBets:GetAvailableBets()	
			elseif addon.isBookie and addon.BookieBets.bet then
				local clients = Bookie:GetSyncTargetOptions()
				for name,_ in pairs(clients) do
					BookieBets:SendAvailableBet({name})
				end
			end
		end,
	},
}

function Bookie_OnLoad(self)
	for event,_ in pairs(event_handlers) do
		self:RegisterEvent(event)
	end
end

function Bookie_OnEvent(self, event, ...)
	local eventHandler = event_handlers[event]
	if eventHandler then
		eventHandler.handler(...)
	end
end

local comm_msgs = {
	new_bet = {
		callback = function(data) ClientBets:GetAvailableBets() end
	}, 
	get_available_bets = {
		callback = function(data) BookieBets:SendAvailableBet(data) end
	},
	get_active_bet = {
		callback = function(data) BookieBets:SendActiveBet(data) end
	},
	send_available_bet = {
		callback = function(data) ClientBets:ReceiveAvailableBet(data) end
	},
	join_bet = {
		callback = function(data) BookieBets:ReceiveClientJoin(data) end
	},
	quit_bet = {
		callback = function(data) BookieBets:ReceiveClientQuit(data) end
	},
	send_choice = {
		callback = function(data) BookieBets:ReceiveChoice(data) end
	},
	update_client_status = {
		callback = function(data) ClientBets:ReceiveUpdate(data) end
	}, 
	send_client_trade = {
		callback = function(data) BookieBets:ReceieveClientTrade(data) end
	},
	send_client_payout_confirm = {
		callback = function(data) BookieBets:ReceieveClientPayoutConfirm(data) end
	},
	cancel_bet = {
		callback = function(data) ClientBets:ReceiveCancelledBet(data) end
	},
	broadcast_bet_close = {
		callback = function(data) ClientBets:ReceiveBetClosed(data) end
	},
}

local function AddNameToList(list, name)
   addon:Debug("Sync:addNameToList(): "..name)
   list[name] = tostring(name)
end

function Bookie:GetSyncGroupOptions()
   local name, isOnline, class, _
   local ret = {}
   -- target
   --if UnitIsFriend("player", "target") and UnitIsPlayer("target") then
   --   addNameToList(ret, addon:UnitName("target"), select(2, UnitClass("target")))
   --end
   -- group
   for i = 1, GetNumGroupMembers() do
	   name, _, _, _, _, _, _, isOnline = GetRaidRosterInfo(i)
      if isOnline then AddNameToList(ret, name) end
   end
   -- friends
   for i = 1, C_FriendList.GetNumOnlineFriends() do
      name, _, class, _, isOnline = C_FriendList.GetFriendInfoByIndex(i)
      if isOnline then AddNameToList(ret, name) end
   end
   -- guildmembers
   --for i = 1, GetNumGuildMembers() do
   --   name, _, _, _, _, _, _, _, isOnline,_,class = GetGuildRosterInfo(i)
   --   if isOnline then AddNameToList(ret, name) end
   --end
   -- Remove ourselves
   if not addon.debug then ret[addon.playerName] = nil end
   -- Check if it's empty
   local isEmpty = true
   for k in pairs(ret) do isEmpty = false; break end
   ret[1] = isEmpty and "--No recipients available--" or nil
   --table.sort(ret, function(a,b) return a > b end)
   return ret
end

--- Send a Bookie Comm Message using AceComm-3.0
-- See Bookie:OnCommReceived() on how to receive these messages.
-- @param target The receiver of the message. Can be "group", "guild" or "playerName".
-- @param command The command to send.
-- @param ... Any number of arguments to send along. Will be packaged as a table.
function Bookie:SendCommand(command, data)
	if not (IsInGuild() or IsInRaid() or IsInGroup()) then addon:Debug("No comm methods are available."); return end

	local toSend = self:Serialize(command, data)

	if IsInGuild() then
		addon:Debug("Sending GUILD comm: "..command)
		self:SendCommMessage("Bookie", toSend, "GUILD")
	end

	if IsInRaid() then 
		addon:Debug("Sending RAID comm: "..command)
		self:SendCommMessage("Bookie", toSend, "RAID")
	elseif IsInGroup() then 
		addon:Debug("Sending PARTY comm: "..command)
		self:SendCommMessage("Bookie", toSend, "PARTY")
	end
end

--- Receives Bookie commands.
-- Params are delivered by AceComm-3.0, but we need to extract our data created with the
-- Bookie:SendCommand function.
-- @usage
-- --To extract the original data using AceSerializer-3.0:
-- local success, command, data = self:Deserialize(serializedMsg)
-- --'data' is a table containing the varargs delivered to Bookie:SendCommand().
function Bookie:OnCommReceived(prefix, serializedMsg, distri, sender)
	if prefix ~= "Bookie" then addon:Debug("Error: Invalid comm prefix.") return end

	-- data is always a table to be unpacked
	local test, command, data = self:Deserialize(serializedMsg)

	if not test then self:Debug("Error with com received!"); return end
	if not comm_msgs[command] then self:Debug("Invalid command message"); return end

	comm_msgs[command].callback(data)
end

function Bookie:Debug(msg, ...)
	if self.debug then print(msg) end
end

function Bookie:FormatMoney(money)
	if not string.match(money, "%d") then return money end
	if money == 0 then return "0g" end

    local ret = ""
    local gold = floor(money/10000)
    local silver = floor((money - (gold * 10000)) / 100)
    local copper = floor(mod(money, 100))
    if gold > 0 then
        ret = gold .. "g "
    end
    if silver > 0 or copper > 0 then
        ret = ret .. silver .. "s "
    end
    if copper > 0 then
    	ret = ret .. copper .. "c"
    end
    return ret
end

function Bookie:GetClientStatusText(status)
	for k,v in pairs(self.clientStatus) do
		if v == status then return k end
	end
end

function Bookie:GetClientStatusTextShort(status)
	return self.clientStatusShort[status]
end

function Bookie:GetBetStatusText(status)
	for k,v in pairs(self.betStatus) do
		if v == status then return k end
	end
end

function MDB_ShowRootFrame()
	addon:GUI_ShowRootFrame()
end

function MDB_HideRootFrame()
	addon:GUI_HideRootFrame()
end


local slash_cmds = {
	show = {
		cmd = "show",
		func = MDB_ShowRootFrame,
		description = "Shows the main window."
	},
	hide = {
		cmd = "hide",
		func = MDB_HideRootFrame,
		description = "Hides the main window."
	},
}

function MDB_SlashCmd(msg)
	if not msg or msg == "" then
		msg = "show"
	end

	args = {} 
	idx = 0
	for arg in string.gmatch(msg, "([^".." ".."]+)") do
		args[idx] = arg
		idx = idx + 1
	end

	if slash_cmds[args[0]] ~= nil then
		slash_cmds[args[0]].func(args)
	end
end

SLASH_MDB1 = "/mdb"
SLASH_MDB2 = "/bookie"
SlashCmdList["MDB"] = MDB_SlashCmd
