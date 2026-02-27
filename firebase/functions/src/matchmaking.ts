import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const MATCH_WINDOW_SECONDS = 5;

/**
 * Callable function: user joins the matchmaking queue.
 * If another user is already waiting (within the time window), they get matched.
 * Otherwise, the user is added to the queue and waits.
 */
export const joinQueue = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
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
  const now = admin.firestore.Timestamp.now();
  const windowStart = admin.firestore.Timestamp.fromMillis(
    now.toMillis() - MATCH_WINDOW_SECONDS * 1000
  );

  // Use a transaction to prevent race conditions (two users matching the same person)
  return db.runTransaction(async (transaction) => {
    const queueQuery = await transaction.get(
      db
        .collection("matchmaking_queue")
        .where("status", "==", "waiting")
        .where("timestamp", ">=", windowStart)
        .limit(10)
    );

    // Find a waiting user that isn't the caller
    const match = queueQuery.docs.find((doc) => doc.data().userId !== uid);

    if (match) {
      const matchData = match.data();
      const chatRoomRef = db.collection("chat_rooms").doc();

      // Create the chat room
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
      });

      // Update both users with the match
      const matchInfo = {
        chatRoomId: chatRoomRef.id,
        matchedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      transaction.update(db.collection("users").doc(uid), {
        currentMatch: matchInfo,
      });

      transaction.update(db.collection("users").doc(matchData.userId), {
        currentMatch: matchInfo,
      });

      // Mark the queue entry as matched
      transaction.update(match.ref, { status: "matched" });

      return { status: "matched", chatRoomId: chatRoomRef.id };
    }

    // No match found - remove any existing queue entry for this user first
    const existingEntry = await transaction.get(
      db
        .collection("matchmaking_queue")
        .where("userId", "==", uid)
        .where("status", "==", "waiting")
        .limit(1)
    );

    for (const doc of existingEntry.docs) {
      transaction.delete(doc.ref);
    }

    // Add to queue
    const queueRef = db.collection("matchmaking_queue").doc();
    transaction.set(queueRef, {
      userId: uid,
      displayName: userData.displayName,
      profilePicUrl: userData.profilePicUrl || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: "waiting",
    });

    return { status: "waiting" };
  });
});

/**
 * Callable function: user leaves the matchmaking queue.
 */
export const leaveQueue = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
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
