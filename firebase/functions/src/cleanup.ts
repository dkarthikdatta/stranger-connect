import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Scheduled function: runs every minute to clean up stale queue entries.
 * Deletes entries older than 30 seconds that are still in "waiting" status.
 */
export const cleanupQueue = onSchedule("every 1 minutes", async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 30 * 1000
    );

    const staleEntries = await db
      .collection("matchmaking_queue")
      .where("status", "==", "waiting")
      .where("timestamp", "<", cutoff)
      .get();

    if (staleEntries.empty) return;

    const batch = db.batch();
    for (const doc of staleEntries.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();

    console.log(`Cleaned up ${staleEntries.size} stale queue entries`);
  });
