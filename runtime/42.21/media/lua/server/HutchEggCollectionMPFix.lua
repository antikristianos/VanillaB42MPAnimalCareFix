-- Only the server owns collection and XP. SP/client paths stay Vanilla.
if not isServer() or isClient() then return end

require "TimedActions/Animals/ISHutchGrabEgg"
if ISHutchGrabEgg._hutchEggCollectionMPFix then return end
ISHutchGrabEgg._hutchEggCollectionMPFix = true

local prefix = "[VanillaB42MPAnimalCareFix] "
local xpRows = setmetatable({}, { __mode = "k" })
local awardingPlayer = nil
local luringPlayer = nil

local function playerID(player)
    return player and tostring(player:getOnlineID()) or "none"
end

local function flushXP(player, row)
    if not row or row.events == 0 then return end
    print(prefix .. "AnimalCare player=" .. playerID(player)
        .. " events=" .. row.events .. " eggEvents=" .. row.eggs
        .. " otherEvents=" .. row.other .. " actualXP=" .. row.amount
        .. " totalXP=" .. player:getXp():getXP(Perks.Husbandry)
        .. " lureEvents=" .. row.lures)
    row.events, row.eggs, row.other, row.amount, row.lures = 0, 0, 0, 0, 0
    row.nextLog = getTimestampMs() + 10000
end

-- AddXP reports the adjusted amount, after Vanilla multipliers/caps.
-- Other sources are observed, never relabelled as luring or modified.
Events.AddXP.Add(function(player, perk, amount)
    if perk ~= Perks.Husbandry or not player or amount <= 0 then return end
    local row = xpRows[player]
    if not row then
        row = { events = 0, eggs = 0, lures = 0, other = 0, amount = 0, nextLog = 0 }
        xpRows[player] = row
    end
    row.events = row.events + 1
    row.amount = row.amount + amount
    if awardingPlayer == player then row.eggs = row.eggs + 1
    elseif luringPlayer == player then row.lures = row.lures + 1
    else row.other = row.other + 1 end
    if getTimestampMs() >= row.nextLog then flushXP(player, row) end
end)

VanillaB42MPAnimalCareFix = VanillaB42MPAnimalCareFix or {}
VanillaB42MPAnimalCareFix.XPDiagnostics = {
    flush = function(player) flushXP(player, xpRows[player]) end,
    withLure = function(player, callback)
        local previous = luringPlayer
        luringPlayer = player
        local ok, failure = pcall(callback)
        luringPlayer = previous
        if not ok then error(failure) end
    end,
}
local function finish(self, reason, requestComplete)
    if self._eggFixClosed then return end
    self._eggFixClosed = true
    flushXP(self.character, xpRows[self.character])
    print(prefix .. "Collection closed player=" .. playerID(self.character)
        .. " collected=" .. (self._eggFixCollected or 0) .. " reason=" .. reason)
    if requestComplete and self.netAction then self.netAction:forceComplete() end
end

local function valid(self)
    local player, hutch, nest = self.character, self.hutch, self.nestbox
    if not player or player:isDead() or not player:isExistInTheWorld()
        or not player:getInventory() then return false end
    if not hutch or not hutch:getSquare() or hutch:getObjectIndex() < 0 then return false end
    return nest ~= nil and hutch:getNestBox(nest:getIndex()) == nest
end

local originalStart = ISHutchGrabEgg.serverStart
function ISHutchGrabEgg:serverStart()
    -- Never reopen a completed action, even if a duplicate start arrives.
    if self._eggFixClosed or self._eggFixRemaining ~= nil then return end
    if not valid(self) then finish(self, "invalid-start", true); return end
    self._eggFixRemaining = self.nestbox:getEggsNb()
    self._eggFixCollected = 0
    if self._eggFixRemaining <= 0 then finish(self, "empty-start", true); return end
    originalStart(self)
end

local originalEvent = ISHutchGrabEgg.animEvent
function ISHutchGrabEgg:animEvent(event, parameter)
    if event ~= "update" then return originalEvent(self, event, parameter) end
    if self._eggFixClosed then return end
    if not valid(self) then finish(self, "invalid-target", true); return end
    -- Reject callbacks that do not belong to a started collection.
    if self._eggFixRemaining == nil then finish(self, "not-started", true); return end
    if self._eggFixRemaining <= 0 or self.nestbox:getEggsNb() <= 0 then
        finish(self, "exhausted", true)
        return
    end

    local egg = self.nestbox:removeEgg(0)
    if not egg then finish(self, "missing-egg", true); return end
    local inventory = self.character:getInventory()
    inventory:AddItem(egg)
    if not inventory:contains(egg) then
        self.nestbox:addEgg(egg)
        self.hutch:sync()
        finish(self, "inventory-rejected", true)
        return
    end
    self._eggFixRemaining = self._eggFixRemaining - 1
    self._eggFixCollected = self._eggFixCollected + 1
    self.hutch:sync()
    sendAddItemToContainer(inventory, egg)

    local previous = awardingPlayer
    awardingPlayer = self.character
    local ok, failure = pcall(addXp, self.character, Perks.Husbandry, 1)
    awardingPlayer = previous
    if not ok then
        finish(self, "xp-error", true)
        error(failure)
    end
    if self._eggFixRemaining <= 0 or self.nestbox:getEggsNb() <= 0 then
        finish(self, "exhausted", true)
    end
end

local originalStop = ISHutchGrabEgg.serverStop
function ISHutchGrabEgg:serverStop()
    finish(self, "cancelled", false)
    if originalStop then return originalStop(self) end
end

local originalComplete = ISHutchGrabEgg.complete
function ISHutchGrabEgg:complete()
    finish(self, "completed", false)
    return originalComplete(self)
end

print(prefix .. "Server egg repair active; AnimalCare diagnostics use player IDs and 10s event summaries.")
