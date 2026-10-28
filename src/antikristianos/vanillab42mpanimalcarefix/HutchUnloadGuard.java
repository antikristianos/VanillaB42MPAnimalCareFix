package antikristianos.vanillab42mpanimalcarefix;

import zombie.iso.objects.IsoHutch;
import zombie.network.GameClient;
import zombie.network.GameServer;

/** No animal creation, server mutation, packet, save field or whole-method replacement. */
public final class HutchUnloadGuard {
    private static boolean announced;
    private static int reports;

    private HutchUnloadGuard() { }

    public static void prepare(IsoHutch hutch) {
        if (!GameClient.client || GameServer.server || hutch == null || hutch.animalInside == null) return;
        if (!announced) {
            announced = true;
            System.out.println("[VanillaB42MPAnimalCareFix] ACTIVE client hutch unload guard");
        }
        // Vanilla's packet parser uses put(slot, null). Such placeholders are not
        // animals. Remove just these local entries before the native values loop.
        int before = hutch.animalInside.size();
        hutch.animalInside.values().removeIf(java.util.Objects::isNull);
        int removed = before - hutch.animalInside.size();
        if (removed > 0 && reports < 10) {
            reports++;
            System.out.println("[VanillaB42MPAnimalCareFix] Client hutch unload: skipped " + removed
                    + " empty slot(s) at " + hutch.savedX + "," + hutch.savedY + "," + hutch.savedZ
                    + (reports == 10 ? "; further recovery messages suppressed" : ""));
        }
    }
}
