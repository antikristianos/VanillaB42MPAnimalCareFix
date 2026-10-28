package antikristianos.vanillab42mpanimalcarefix;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.iso.objects.IsoHutch;

/** Keep the complete native cleanup; prepare only the MP client's local occupants. */
@Patch(className = "zombie.iso.objects.IsoHutch", methodName = "removeFromWorld",
        warmUp = true, strictMatch = true)
public final class PatchHutchUnload {
    private PatchHutchUnload() { }

    @Patch.OnEnter
    public static void enter(@Patch.This IsoHutch hutch) {
        HutchUnloadGuard.prepare(hutch);
    }
}
