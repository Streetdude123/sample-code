-- SERVICES

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- MODULE IMPORTS

local GiftConfig = require(ReplicatedStorage.GiftingShared.GiftConfig)

local Store = require(ServerScriptService.GiftingServer.Modules.Store)

-- MODULE DEFINITION

-- Every write is an UpdateAsync, so two servers touching one inbox cannot duplicate or lose a gift
local InboxStore = {}

-- VARIABLE TYPES

type GiftData = {
	Id: string,
	ProductId: number,
	SenderUserId: number,
	SenderName: string,
	RecipientUserId: number,
	RecipientName: string,
	Note: string,
	CreatedAt: number,
	ExpiresAt: number,
	Returned: boolean,
}

type InboxRecord = {
	Gifts: { GiftData },
}

-- PRIVATE FUNCTION INITIALIZATIONS

local key_for: (user_id: number) -> string
local gifts_of: (current: any) -> { GiftData }

-- PUBLIC FUNCTIONS

InboxStore.GetGifts = function(user_id: number): { GiftData }?
	local succeeded, result = Store.Get(GiftConfig.InboxStoreName, key_for(user_id))
	if not succeeded then
		return nil
	end
	return gifts_of(result)
end

-- A duplicate add reports success because the gift is already there
InboxStore.AddGift = function(user_id: number, gift_data: GiftData): (boolean, string?)
	local failure: string? = nil

	local add_transform = function(current: any): InboxRecord?
		local gifts = gifts_of(current)

		if #gifts >= GiftConfig.MaxInboxSize then
			failure = "InboxFull"
			return nil
		end

		-- Guards against a retried write adding the same gift twice
		for _, existing_gift in ipairs(gifts) do
			if existing_gift.Id == gift_data.Id then
				failure = "Duplicate"
				return nil
			end
		end

		table.insert(gifts, gift_data)
		return { Gifts = gifts }
	end

	local succeeded, update_error = Store.Update(GiftConfig.InboxStoreName, key_for(user_id), add_transform)

	if failure == "Duplicate" then
		return true, nil
	end
	if failure then
		return false, failure
	end
	if not succeeded then
		return false, tostring(update_error)
	end
	return true, nil
end

-- The removal is the claim, whoever removes the gift first wins and double clicks get nil
InboxStore.RemoveGift = function(user_id: number, gift_id: string): (boolean, any)
	local removed_gift: GiftData? = nil

	local remove_transform = function(current: any): InboxRecord?
		local gifts = gifts_of(current)
		for index, gift in ipairs(gifts) do
			if gift.Id == gift_id then
				removed_gift = gift
				table.remove(gifts, index)
				return { Gifts = gifts }
			end
		end
		return nil
	end

	local succeeded, update_error = Store.Update(GiftConfig.InboxStoreName, key_for(user_id), remove_transform)

	if not succeeded then
		return false, tostring(update_error)
	end
	return true, removed_gift
end

-- One write sweeps everything expired, so two servers cannot both return the same gift
InboxStore.RemoveExpired = function(user_id: number): (boolean, any)
	local expired_gifts: { GiftData } = {}

	local sweep_transform = function(current: any): InboxRecord?
		local gifts = gifts_of(current)
		local now = os.time()
		local kept_gifts: { GiftData } = {}
		local changed = false

		for _, gift in ipairs(gifts) do
			if not gift.Returned and gift.ExpiresAt and now >= gift.ExpiresAt then
				table.insert(expired_gifts, gift)
				changed = true
			else
				table.insert(kept_gifts, gift)
			end
		end

		if not changed then
			return nil
		end
		return { Gifts = kept_gifts }
	end

	local succeeded, update_error = Store.Update(GiftConfig.InboxStoreName, key_for(user_id), sweep_transform)

	if not succeeded then
		return false, tostring(update_error)
	end
	return true, expired_gifts
end

-- PRIVATE FUNCTION DEFINITIONS

key_for = function(user_id: number): string
	return "Inbox_" .. user_id
end

-- DataStore values arrive untyped, this is the one place that shape gets checked
gifts_of = function(current: any): { GiftData }
	if current and type(current.Gifts) == "table" then
		return current.Gifts
	end
	return {}
end

-- MODULE EXPORT

return InboxStore
