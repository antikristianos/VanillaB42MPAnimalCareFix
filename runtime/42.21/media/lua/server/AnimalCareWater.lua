-- Validate before the native water/XP tick; preserve its quantities and timing.
if not isServer() then return end
require "TimedActions/Animals/ISGiveWaterToAnimal"
if ISGiveWaterToAnimal._animalCareWaterGuard then return end
ISGiveWaterToAnimal._animalCareWaterGuard = true

local originalStart = ISGiveWaterToAnimal.serverStart
local originalEvent = ISGiveWaterToAnimal.animEvent
local originalComplete = ISGiveWaterToAnimal.complete
local originalStop = ISGiveWaterToAnimal.serverStop

local function canWater(self)
    local p, animal, item = self.character, self.animal, self.item
    return p and not p:isDead() and p:isExistInTheWorld()
        and animal and not animal:isDead() and item
        and p:getInventory():contains(item) and item:getFluidContainer()
        and not item:getFluidContainer():isEmpty()
        and animal:getStats():get(CharacterStat.THIRST) > 0
end

local function finish(self)
    if self._animalCareWaterClosed then return end
    self._animalCareWaterClosed = true
    self.netAction:forceComplete()
end

function ISGiveWaterToAnimal:serverStart()
    if self._animalCareWaterStarted or self._animalCareWaterClosed then return end
    if not canWater(self) then finish(self); return end
    self._animalCareWaterStarted = true
    return originalStart(self)
end

function ISGiveWaterToAnimal:animEvent(event, parameter)
    if self._animalCareWaterClosed or not self._animalCareWaterStarted then return end
    if event ~= "update" then return originalEvent(self, event, parameter) end
    if not canWater(self) then finish(self); return end
    originalEvent(self, event, parameter)
    -- Vanilla already requested completion after consuming the final portion.
    if not canWater(self) then self._animalCareWaterClosed = true end
end

function ISGiveWaterToAnimal:serverStop()
    if self._animalCareWaterStopped then return end
    self._animalCareWaterClosed = true
    self._animalCareWaterStopped = true
    if originalStop then return originalStop(self) end
end

function ISGiveWaterToAnimal:complete()
    if self._animalCareWaterCompleted then return true end
    self._animalCareWaterClosed = true
    self._animalCareWaterCompleted = true
    if self._animalCareWaterStopped or not self.animal then return true end
    return originalComplete(self)
end

print("[VanillaB42MPAnimalCareFix] Server watering lifecycle guard active")
