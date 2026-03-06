import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const DEFAULT_MATCH_WINDOW_SECONDS = 5;

async function getMatchWindowSeconds(): Promise<number> {
  try {
    const doc = await db.collection("config").doc("matchmaking").get();
    return (doc.data()?.matchWindowSeconds as number) ?? DEFAULT_MATCH_WINDOW_SECONDS;
  } catch {
    return DEFAULT_MATCH_WINDOW_SECONDS;
  }
}

export const joinQueue = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated"
    );
  }

  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "User profile not found"
    );
  }

  const userData = userDoc.data()!;
  const matchWindowSeconds = await getMatchWindowSeconds();
  const now = admin.firestore.Timestamp.now();
  const windowStart = admin.firestore.Timestamp.fromMillis(
    now.toMillis() - matchWindowSeconds * 1000
  );

  return db.runTransaction(async (transaction) => {
    // 🔴 IMPORTANT: remove any old waiting entries of this user first
    const existingEntry = await transaction.get(
      db
        .collection("matchmaking_queue")
        .where("userId", "==", uid)
        .where("status", "==", "waiting")
    );

    for (const doc of existingEntry.docs) {
      transaction.delete(doc.ref);
    }

    // Find other users shaking within window
    const queueQuery = await transaction.get(
      db
        .collection("matchmaking_queue")
        .where("status", "==", "waiting")
        .where("timestamp", ">=", windowStart)
        .limit(10)
    );

    const match = queueQuery.docs.find(
      (doc) => doc.data().userId !== uid
    );

    if (match) {
      const matchData = match.data();

      const chatRoomRef = db.collection("chat_rooms").doc();

      transaction.set(chatRoomRef, {
        participants: [uid, matchData.userId],
        participantProfiles: {
          [uid]: {
            displayName: userData.displayName,
            profilePicUrl: userData.profilePicUrl || null,
          },
          [matchData.userId]: {
            displayName: matchData.displayName,
            profilePicUrl: matchData.profilePicUrl || null,
          },
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: null,
        lastMessageAt: null,
        active: true,
      });

      const matchInfo = {
        chatRoomId: chatRoomRef.id,
        matchedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Update both users
      transaction.update(db.collection("users").doc(uid), {
        currentMatch: matchInfo,
      });

      transaction.update(db.collection("users").doc(matchData.userId), {
        currentMatch: matchInfo,
      });

      // 🔥 CRITICAL FIX: DELETE matched queue entry
      transaction.delete(match.ref);

      return { status: "matched", chatRoomId: chatRoomRef.id };
    }

    // If no match found → add to queue
    const queueRef = db.collection("matchmaking_queue").doc();
    transaction.set(queueRef, {
      userId: uid,
      displayName: userData.displayName,
      profilePicUrl: userData.profilePicUrl || null,
      timestamp: now, // 🔥 use explicit timestamp, not serverTimestamp here
      status: "waiting",
    });

    return { status: "waiting" };
  });
});

export const leaveQueue = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated"
    );
  }

  const snapshot = await db
    .collection("matchmaking_queue")
    .where("userId", "==", uid)
    .where("status", "==", "waiting")
    .get();

  const batch = db.batch();
  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();

  return { status: "left" };
});

export const endChat = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const chatRoomId = data?.chatRoomId as string | undefined;

  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated"
    );
  }

  if (!chatRoomId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "chatRoomId is required"
    );
  }

  const chatRoomRef = db.collection("chat_rooms").doc(chatRoomId);

  await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(chatRoomRef);
    if (!roomSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Chat room not found"
      );
    }

    const roomData = roomSnap.data()!;
    const participants = (roomData.participants ?? []) as string[];
    if (!participants.includes(uid)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User is not a chat participant"
      );
    }

    transaction.update(chatRoomRef, {
      endedAt: admin.firestore.Timestamp.now(),
      endedBy: uid,
      active: false,
    });

    for (const participantUid of participants) {
      transaction.update(db.collection("users").doc(participantUid), {
        currentMatch: null,
      });
    }
  });

  // Remove any stale queue entries for this user after ending chat.
  const queueSnapshot = await db
    .collection("matchmaking_queue")
    .where("userId", "==", uid)
    .where("status", "==", "waiting")
    .get();

  if (!queueSnapshot.empty) {
    const batch = db.batch();
    for (const doc of queueSnapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }

  return { status: "ended" };
});
