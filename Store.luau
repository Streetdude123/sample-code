--!strict
--[[
	@module Store (excerpt)
	@description Excerpt from the DataStore access layer of a gifting system.
	One retry loop drives Get, Update, and Remove because every operation
	reads only StoreName and Key from the request; Transform exists solely
	for Update and is guarded at runtime. Full module includes a Studio
	in-memory fallback and deep-copy isolation of read results.
]]--

-- ============================ VARIABLE TYPES ================================

type StoreTransform = (any) -> any

type MemoryBucket = { [string]: any }

type MemoryTable = { [string]: MemoryBucket }

-- Transform is populated only for update requests; every operation reads
-- StoreName and Key, which is what lets one retry loop drive all three.
type StoreRequest = {
	StoreName: string,
	Key: string,
	Transform: StoreTransform?,
}

type StoreOperation = (StoreRequest) -> any

-- ========================== PRIVATE VARIABLES ===============================

local RETRY_ATTEMPT_COUNT: number = 3
local RETRY_BACKOFF_SECONDS: number = 0.5

local MISSING_TRANSFORM_MESSAGE: string = "Store.Update requires a transform function"

-- ================== PRIVATE FUNCTION INITIALIZATIONS ========================

local retry_store_operation: (operation: StoreOperation, request: StoreRequest) -> (boolean, any)

local run_get_async: StoreOperation
local run_update_async: StoreOperation
local run_remove_async: StoreOperation

-- ==================== PRIVATE FUNCTION DEFINITIONS ==========================

--[[
	Yields after the final attempt as well, so a caller looping on a hard
	failure cannot hammer the endpoint.
]]--
retry_store_operation = function(operation: StoreOperation, request: StoreRequest): (boolean, any)
	local last_error: any = nil

	for attempt = 1, RETRY_ATTEMPT_COUNT do
		local succeeded, result = pcall(operation, request)
		if succeeded then
			return true, result
		end

		last_error = result
		local backoff_seconds = attempt * RETRY_BACKOFF_SECONDS
		task.wait(backoff_seconds)
	end

	return false, last_error
end

--[[
	GetDataStore itself throws in an unpublished place, so it has to sit inside
	the retried body instead of being resolved once by the caller.
]]--
run_get_async = function(request: StoreRequest): any
	local data_store = DataStoreService:GetDataStore(request.StoreName)
	return data_store:GetAsync(request.Key)
end

run_update_async = function(request: StoreRequest): any
	local transform = request.Transform
	if not transform then
		error(MISSING_TRANSFORM_MESSAGE)
	end

	local data_store = DataStoreService:GetDataStore(request.StoreName)
	return data_store:UpdateAsync(request.Key, transform)
end

run_remove_async = function(request: StoreRequest): any
	local data_store = DataStoreService:GetDataStore(request.StoreName)
	return data_store:RemoveAsync(request.Key)
end
