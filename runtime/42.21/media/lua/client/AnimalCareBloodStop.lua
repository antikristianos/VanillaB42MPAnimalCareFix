if not isClient() then return end
require "TimedActions/Animals/ISGatherBloodFromAnimal"
if ISGatherBloodFromAnimal._animalCareNativeStop then return end
ISGatherBloodFromAnimal._animalCareNativeStop = true

function ISGatherBloodFromAnimal:forceStop()
    -- The engine then calls stop(), including Vanilla UI cleanup and the
    -- native GeneralAction rejection. Resetting only the Lua queue skips it.
    ISBaseTimedAction.forceStop(self)
end
