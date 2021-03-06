--ClientBets.lua
--Author: Looch
--Desciption: Client listener for recieving bets from broadcasting Bookies.

local _,addon = ...
local ClientBets = addon:NewModule("ClientBets")

ClientBets.availableBets = {}
ClientBets.activeBet = nil

local UpdateCallbacks = {
	[addon.clientStatus.Inactive] = {
		func = function() 
				ClientBets.activeBet = nil
				addon:GUIRefresh_Lobby() 
			end,
		debug = "Client purged. Returning to Lobby",
	},
	[addon.clientStatus.WaitingForWager] = {
		func = function() addon:GUIRefresh_ClientJoined() end,
		debug = "Successfully joined bookie session.",
	},
	[addon.clientStatus.WaitingForTrade] = {
		func = function() addon:GUIRefresh_ClientWaiting() end,
		debug = "Bookie received your wager, waiting for your trade.",
	},
	[addon.clientStatus.WaitingForResults] = {
		func = function() addon:GUIRefresh_ClientWaiting() end,
		debug = "Bookie received your bet, waiting for results.",
	},
	[addon.clientStatus.WaitingForPayout] = {
		func = function() addon:GUIRefresh_ClientWaiting() end,
		debug = "Bookie decided winer, waiting for payouts.",
	},
	[addon.clientStatus.ConclusionPaid] = {
		func = function() addon:GUIRefresh_ClientWaiting() end,
		debug = "Received payouts.",
	},
	[addon.clientStatus.ConclusionLost] = {
		func = function() addon:GUIRefresh_ClientWaiting() end,
		debug = "Client LOST this bet.",
	},
}

function ClientBets:ReceiveUpdate(data)
	if addon.isBookie then return end

	local bookie, client, bet = unpack(data)

	if not client then return end
	if client ~= addon.playerName then addon:Debug(string.format("invalid client name update: %s from %s",client, bookie)) return end
	if not bet then return end
	if not bet.entrants[client] then addon:Debug("Error! Client does not exist in bookie's active bet"); return end

	self.activeBet = bet

	local callback = UpdateCallbacks[bet.entrants[addon.playerName].status]
	if callback then
		callback.func()
		addon.Debug(callback.debug)
	else
		addon:Debug("Update received: Invalid client status.")
	end
end

function ClientBets:ReceiveAvailableBet(data)
	if addon.isBookie then return end

	local bookie, clientName, dueler1, dueler2= unpack(data)

	if clientName ~= addon.playerName then return end
	addon:Debug("Received available bet from: "..bookie)

	local bet = {
		bookie = bookie,
		duelers = { dueler1, dueler2 },
	}

	table.insert(self.availableBets, bet)

	if not self.activeBet then
		addon:GUIRefresh_Lobby()
	end
end

function ClientBets:GetActiveBet()
	if addon.isBookie then return end
	addon:SendCommand("get_active_bet", { addon.playerName })
end

function ClientBets:GetAvailableBets()
	if addon.isBookie then return end

	--Clear our current available bets, get a fresh update from all possible bookies
	self.availableBets = {}
	addon:SendCommand("get_available_bets", { addon.playerName })
end

function ClientBets:ReceiveBetClosed(data)
	if addon.isBookie then return end
	if self.activeBet then addon:Debug("Client bet is active, skipping purge"); return end

	self:GetAvailableBets()
	addon:GUIRefresh_Lobby()
end

function ClientBets:JoinBet(index)
	if addon.isBookie then return end

	bet = self.availableBets[index]
	if not bet then return end

	addon:SendCommand("join_bet", { bet.bookie, addon.playerName })
	addon:GUIRefresh_Lobby()
end

function ClientBets:QuitBet()
	if addon.isBookie then return end

	--TODO break this up into a seperate call, the bookie alert is redundant if the bookie cancelled a bet
	--	This function needs a cleanup + bookie alert
	addon:SendCommand("quit_bet", { self.activeBet.bookie, addon.playerName })

	self.activeBet = nil
	self.availableBets = nil
	self:GetAvailableBets()
	addon:GUIRefresh_Lobby()
end

--@param wager = gold amount
--@param int choice = { 1, 2 } -> Represents dueler1 or dueler2 
function ClientBets:SubmitWager(choice)
	if addon.isBookie then return end
	if not self.activeBet then addon:Debug("ERROR! Client does not have an active bet"); return end

	addon:Debug("Client sending wager submission")
	addon:SendCommand("send_choice", { self.activeBet.bookie, addon.playerName, choice })
end

function ClientBets:InitiateTrade(target)
	if addon.isBookie then return end
	if not self.activeBet then return end
	if not target or target ~= self.activeBet.bookie then addon:Debug("Not targeting your active bookie!"); return end
	
	addon:Debug("Trade opened with your bookie: "..target)
	addon:SendCommand("client_init_trade", {target, addon.playerName} )
end

function ClientBets:ReceiveCancelledBet(data)
	if addon.isBookie then return end
	if not self.activeBet then return end

	local bookie = unpack(data)

	if bookie ~= self.activeBet.bookie then return end

	addon:Debug("Bookie cancelled our bet. Returning to lobby.")
	self:QuitBet()
end

function ClientBets:ReceiveRemovedFromBet(data)
	if addon.isBookie then return end
	if not self.activeBet then return end

	bookie, client = unpack(data)

	if client ~= addon.playerName then return end
	if bookie ~= self.activeBet.bookie then return end

	addon:Debug("Bookie removed your bet. Returning to lobby.")
	self:QuitBet()
end

function ClientBets:GetBookie()
	if not self.activeBet.bookie then return "TBD" end
	return self.activeBet.bookie
end

function ClientBets:GetActiveWager()
	if not self.activeBet.entrants[addon.playerName].wager then return "TBD" end
	return self.activeBet.entrants[addon.playerName].wager
end

function ClientBets:GetChoiceIndex()
	if not self.activeBet.entrants[addon.playerName].choice then return "TBD" end
	return self.activeBet.entrants[addon.playerName].choice
end

function ClientBets:GetChoiceText()
	if not self.activeBet.entrants[addon.playerName].choice then return "TBD" end
	local choice = self.activeBet.entrants[addon.playerName].choice
	return self.activeBet.duelers[choice]
end

function ClientBets:GetPayout()
	if not self.activeBet.entrants[addon.playerName].payout then return "TBD" end
	return self.activeBet.entrants[addon.playerName].payout
end

