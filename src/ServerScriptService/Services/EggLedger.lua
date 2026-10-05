-- EggLedger
-- The authoritative record of every egg: who carries it, who helps, and whether it was consumed.
-- Pure Luau (no Roblox APIs), so tests/run.luau can prove the rules outside Studio.
--
-- States:  Nest -> Carried -> (Dropped -> Carried ...) -> Consumed
--          Dropped -> Nest  (nobody picked it up in time)
-- Rules:
--   * a claim succeeds only from Nest or Dropped, after the pickup lock, for a player who is not
--     already carrying or helping: two simultaneous claims -> exactly one winner;
--   * TryConsume succeeds once per egg and removes it, so a reward can be granted only once;
--   * dropping releases every helper; a consumed egg can never be claimed, dropped or consumed again.
-- Server Lua runs one handler at a time and nothing here yields, so each check-and-set is atomic.

local EggLedger = {}
EggLedger.__index = EggLedger

function EggLedger.new()
	local self = setmetatable({}, EggLedger)
	self._eggs = {} -- [eggId] = egg
	self._carrying = {} -- [userId] = eggId
	self._helping = {} -- [userId] = eggId
	self._nextId = 0
	return self
end

-- fields: extra data stored on the egg (slot, rolled pet, ...). Core fields cannot be overridden.
function EggLedger:Create(kind, fields)
	self._nextId += 1
	local egg = {}
	if fields then
		for key, value in fields do
			egg[key] = value
		end
	end
	egg.Id = self._nextId
	egg.Kind = kind
	egg.State = "Nest"
	egg.CarrierId = nil
	egg.Helpers = {} -- [userId] = time the helper joined
	egg.HelperCount = 0
	egg.LockedUntil = 0
	egg.ClaimedAt = 0
	egg.DroppedAt = 0
	egg.Consumed = false
	self._eggs[egg.Id] = egg
	return egg
end

function EggLedger:Get(id)
	if type(id) ~= "number" then
		return nil
	end
	return self._eggs[id]
end

function EggLedger:CarriedBy(userId)
	local id = self._carrying[userId]
	return if id then self._eggs[id] else nil
end

function EggLedger:HelpingWith(userId)
	local id = self._helping[userId]
	return if id then self._eggs[id] else nil
end

function EggLedger:IsBusy(userId)
	return self._carrying[userId] ~= nil or self._helping[userId] ~= nil
end

-- A list copy of every live egg (safe to change states while looping over it).
function EggLedger:All()
	local list = {}
	for _, egg in self._eggs do
		table.insert(list, egg)
	end
	return list
end

function EggLedger:Count()
	local count = 0
	for _ in self._eggs do
		count += 1
	end
	return count
end

-- Returns true, or false and a reason: "gone" | "taken" | "unavailable" | "locked" | "busy".
function EggLedger:TryClaim(id, userId, now)
	local egg = self:Get(id)
	if not egg or egg.Consumed then
		return false, "gone"
	end
	if egg.State == "Carried" then
		return false, "taken"
	end
	if egg.State ~= "Nest" and egg.State ~= "Dropped" then
		return false, "unavailable"
	end
	if now < egg.LockedUntil then
		return false, "locked"
	end
	if self:IsBusy(userId) then
		return false, "busy"
	end

	egg.State = "Carried"
	egg.CarrierId = userId
	egg.ClaimedAt = now
	egg.Helpers = {}
	egg.HelperCount = 0
	self._carrying[userId] = id
	return true
end

-- Returns true, or false and a reason: "not_carried" | "own_egg" | "busy" | "full".
function EggLedger:TryAddHelper(id, userId, now, maxHelpers)
	local egg = self:Get(id)
	if not egg or egg.Consumed or egg.State ~= "Carried" then
		return false, "not_carried"
	end
	if egg.CarrierId == userId then
		return false, "own_egg"
	end
	if self:IsBusy(userId) then
		return false, "busy"
	end
	if egg.HelperCount >= maxHelpers then
		return false, "full"
	end

	egg.Helpers[userId] = now
	egg.HelperCount += 1
	self._helping[userId] = id
	return true
end

-- Stops a player helping. Returns the egg they were helping with, or nil.
function EggLedger:RemoveHelper(userId)
	local id = self._helping[userId]
	if not id then
		return nil
	end
	self._helping[userId] = nil
	local egg = self._eggs[id]
	if egg and egg.Helpers[userId] then
		egg.Helpers[userId] = nil
		egg.HelperCount -= 1
	end
	return egg
end

local function releaseHelpers(self, egg)
	local released = {}
	for helperId in egg.Helpers do
		self._helping[helperId] = nil
		table.insert(released, helperId)
	end
	egg.Helpers = {}
	egg.HelperCount = 0
	return released
end

-- Carried -> Dropped. Returns ok, { released helper ids }, previous carrier id.
function EggLedger:TryDrop(id, now, lockSeconds)
	local egg = self:Get(id)
	if not egg or egg.Consumed or egg.State ~= "Carried" then
		return false, {}, nil
	end
	local carrierId = egg.CarrierId
	if carrierId ~= nil then
		self._carrying[carrierId] = nil
	end
	egg.CarrierId = nil
	egg.State = "Dropped"
	egg.DroppedAt = now
	egg.LockedUntil = now + lockSeconds
	return true, releaseHelpers(self, egg), carrierId
end

-- Dropped -> Nest (it rolled home). Returns true if it moved.
function EggLedger:TryReturnToNest(id)
	local egg = self:Get(id)
	if not egg or egg.Consumed or egg.State ~= "Dropped" then
		return false
	end
	egg.State = "Nest"
	egg.LockedUntil = 0
	return true
end

-- Carried -> Consumed, only by its carrier and only once. Removes the egg.
-- Returns ok, helpers snapshot ([userId] = joinedAt) taken before the helpers are released.
function EggLedger:TryConsume(id, userId)
	local egg = self:Get(id)
	if not egg or egg.Consumed or egg.State ~= "Carried" or egg.CarrierId ~= userId then
		return false, nil
	end
	egg.Consumed = true
	egg.State = "Consumed"
	self._carrying[userId] = nil
	local helpers = table.clone(egg.Helpers)
	releaseHelpers(self, egg)
	self._eggs[id] = nil
	return true, helpers
end

-- Removes an egg that is not being carried (e.g. a despawn). Returns true if removed.
function EggLedger:Remove(id)
	local egg = self:Get(id)
	if not egg or egg.State == "Carried" then
		return false
	end
	egg.Consumed = true
	egg.State = "Consumed"
	self._eggs[id] = nil
	return true
end

return EggLedger
