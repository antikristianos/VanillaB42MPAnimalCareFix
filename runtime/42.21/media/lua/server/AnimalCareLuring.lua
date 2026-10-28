-- Native luring and XP stay server-owned; close the action before cleanup
-- clears luredBy and makes another successful XP award possible.
if not isServer() or isClient() then return end
require "TimedActions/Animals/ISLureAnimal"
require "HutchEggCollectionMPFix"
if ISLureAnimal._vanillaAnimalCareLureFix then return end
ISLureAnimal._vanillaAnimalCareLureFix = true

local diagnostics = VanillaB42MPAnimalCareFix.XPDiagnostics
local active = setmetatable({}, { __mode = "k" })
local serial = 0
local originalStart = ISLureAnimal.serverStart
local originalEvent = ISLureAnimal.animEvent
local originalStop = ISLureAnimal.serverStop
local originalComplete = ISLureAnimal.complete

local function valid(self)
    local player = self.character
    return player and not player:isDead() and player:isExistInTheWorld()
        and self.item ~= nil and player:getPrimaryHandItem() == self.item
end

local function close(self, reason, feed, requestComplete)
    if self._animalCareClosed then return self._animalCareResult ~= false end
    self._animalCareClosed = true
    local player = self.character
    local ownsAction = player and active[player] == self
    if ownsAction then active[player] = nil end
    local ok, result = true, true
    if ownsAction then
        if reason == "arrived" then
            -- Preserve both native arrival and completion hooks, once each.
            -- The closed guard is already set before either releases luredBy.
            ok, result = pcall(function()
                originalEvent(self, "update", nil)
                return originalComplete(self)
            end)
        elseif feed then ok, result = pcall(originalComplete, self)
        else ok, result = pcall(originalStop, self) end
    end
    self._animalCareResult = ok and (not feed or result ~= false)
    if player then diagnostics.flush(player) end
    print("[VanillaB42MPAnimalCareFix] Lure closed player="
        .. (player and tostring(player:getOnlineID()) or "none")
        .. " action=" .. (self._animalCareSerial or 0) .. " reason=" .. reason)
    if requestComplete and self.netAction and (reason ~= "arrived" or not ok) then
        self.netAction:forceComplete()
    end
    if not ok then error(result) end
    return self._animalCareResult
end

function ISLureAnimal:serverStart()
    if self._animalCareClosed or self._animalCareStarted then return end
    if not valid(self) then close(self, "invalid-start", false, true); return end
    local previous = active[self.character]
    if previous and previous ~= self then close(previous, "superseded", false, true) end
    serial = serial + 1
    self._animalCareSerial = serial
    self._animalCareStarted = true
    active[self.character] = self
    local ok, failure = pcall(originalStart, self)
    if not ok then close(self, "start-error", false, true); error(failure) end
    print("[VanillaB42MPAnimalCareFix] Lure started player="
        .. self.character:getOnlineID() .. " action=" .. serial)
end

function ISLureAnimal:animEvent(event, parameter)
    if event ~= "update" then return originalEvent(self, event, parameter) end
    if self._animalCareClosed then return end
    if not self._animalCareStarted or active[self.character] ~= self then
        close(self, "inactive", false, true); return
    end
    if not valid(self) then close(self, "invalid-player-or-bait", false, true); return end

    local animals = self.character:getLuredAnimals()
    if animals:size() == 0 and self._animalCareHadAnimals then
        -- The successful binding disappeared (e.g. cancellation). Never
        -- restart it from an old animation timer and earn that XP again.
        close(self, "lost-binding", false, true); return
    end
    for i = 0, animals:size() - 1 do
        if animals:get(i):DistTo(self.character) <= 2 then
            close(self, "arrived", true, true); return
        end
    end
    if animals:size() > 0 then self._animalCareHadAnimals = true end
    local ok, failure = pcall(diagnostics.withLure, self.character, function()
        self.character:lureAnimal(self.item)
    end)
    if not ok then close(self, "lure-error", false, true); error(failure) end
    if animals:size() > 0 then self._animalCareHadAnimals = true end
end

function ISLureAnimal:serverStop()
    return close(self, "cancelled", false, false)
end

function ISLureAnimal:complete()
    if self._animalCareClosed then return self._animalCareResult ~= false end
    return close(self, "completed", valid(self), false)
end

print("[VanillaB42MPAnimalCareFix] Server luring repair active.")
