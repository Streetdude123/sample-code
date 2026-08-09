-- SERVICES

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- MODULE IMPORTS

local GiftConfig = require(ReplicatedStorage.GiftingShared.GiftConfig)

local Store = require(ServerScriptService.GiftingServer.Modules.Store)

-- MODULE DEFINITION

-- Roblox retries ProcessReceipt until it hears PurchaseGranted, recording every PurchaseId keeps a purchase from granting twice
local ReceiptLedger = {}

-- VARIABLE TYPES

type ClaimResult = "New" | "AlreadyProcessed" | "Error"

type ReceiptRecord = {
	ClaimedAt: number,
}

-- PRIVATE FUNCTION INITIALIZATIONS

local key_for: (purchase_id: string) -> string

-- PUBLIC FUNCTIONS

-- New means this server owns the delivery, Error means Roblox should retry later
ReceiptLedger.Claim = function(purchase_id: string): ClaimResult
	local already_processed = false

	local claim_transform = function(current: any): ReceiptRecord?
		if current ~= nil then
			already_processed = true
			return nil
		end
		return { ClaimedAt = os.time() }
	end

	local succeeded = Store.Update(GiftConfig.ReceiptStoreName, key_for(purchase_id), claim_transform)

	if not succeeded then
		return "Error"
	end
	if already_processed then
		return "AlreadyProcessed"
	end
	return "New"
end

-- Must actually delete the key, a transform returning nil only cancels the write
ReceiptLedger.Release = function(purchase_id: string): ()
	Store.Remove(GiftConfig.ReceiptStoreName, key_for(purchase_id))
end

-- PRIVATE FUNCTION DEFINITIONS

key_for = function(purchase_id: string): string
	return "Receipt_" .. purchase_id
end

-- MODULE EXPORT

return ReceiptLedger
