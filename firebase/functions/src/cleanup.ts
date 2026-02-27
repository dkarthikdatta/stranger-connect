import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();
const DEFAULT_TIMEOUT_SECONDS = 30;

export const cleanupQueue = onSchedule("every 1 minutes", async () => {
  let timeoutSeconds = DEFAULT_TIMEOUT_SECONDS;
  try {
    const doc = await db.collection("config").doc("matchmaking").get();
    timeoutSeconds = (doc.data()?.timeoutSeconds as number) ?? DEFAULT_TIMEOUT_SECONDS;
  } catch {
    // use default
  }

  const cutoff = admin.firestore.Timestamp.fromMillis(
    Date.now() - timeoutSeconds * 1000
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
