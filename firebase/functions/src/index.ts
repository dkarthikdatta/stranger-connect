import * as admin from "firebase-admin";

admin.initializeApp();

export { joinQueue, leaveQueue } from "./matchmaking";
export { cleanupQueue } from "./cleanup";
