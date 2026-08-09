-- SERVICES

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MODULE IMPORTS

local GiftConfig = require(ReplicatedStorage.GiftingShared.GiftConfig)

-- MODULE DEFINITION

local Gift = {}

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

type GiftParameters = {
	Id: string?,
	ProductId: number,
	SenderUserId: number,
	SenderName: string,
	RecipientUserId: number,
	RecipientName: string,
	Note: string?,
	CreatedAt: number?,
	ExpiresAt: number?,
	Returned: boolean?,
}

-- The only shape allowed across the network, ids the client has no business seeing are stripped
type GiftPayload = {
	Id: string,
	ProductName: string,
	SenderName: string,
	Note: string,
	SecondsLeft: number,
	Returned: boolean,
	Coins: number,
	ItemName: string?,
}

-- PUBLIC FUNCTIONS

Gift.New = function(parameters: GiftParameters): GiftData
	local created_at = parameters.CreatedAt or os.time()

	local gift_data: GiftData = {
		Id = parameters.Id or HttpService:GenerateGUID(false),
		ProductId = parameters.ProductId,
		SenderUserId = parameters.SenderUserId,
		SenderName = parameters.SenderName,
		RecipientUserId = parameters.RecipientUserId,
		RecipientName = parameters.RecipientName,
		Note = parameters.Note or "",
		CreatedAt = created_at,
		ExpiresAt = parameters.ExpiresAt or (created_at + GiftConfig.GiftExpirySeconds),
		Returned = parameters.Returned or false,
	}

	return gift_data
end

Gift.IsExpired = function(gift_data: GiftData): boolean
	return os.time() >= gift_data.ExpiresAt
end

Gift.ToPayload = function(gift_data: GiftData): GiftPayload
	local product = GiftConfig.GetProduct(gift_data.ProductId)

	return {
		Id = gift_data.Id,
		ProductName = product and product.Name or "Unknown product",
		SenderName = gift_data.SenderName,
		Note = gift_data.Note,
		SecondsLeft = math.max(0, gift_data.ExpiresAt - os.time()),
		Returned = gift_data.Returned,
		Coins = product and product.Coins or 0,
		ItemName = product and product.ItemName or nil,
	}
end

-- Returned gifts never expire again, otherwise they would bounce forever
Gift.AsReturnedGift = function(gift_data: GiftData): GiftData
	return Gift.New({
		ProductId = gift_data.ProductId,
		SenderUserId = gift_data.SenderUserId,
		SenderName = gift_data.SenderName,
		RecipientUserId = gift_data.SenderUserId,
		RecipientName = gift_data.RecipientName,
		Note = gift_data.Note,
		CreatedAt = os.time(),
		ExpiresAt = math.huge,
		Returned = true,
	})
end

-- MODULE EXPORT

return Gift
