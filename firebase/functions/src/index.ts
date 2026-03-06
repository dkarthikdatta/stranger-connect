import * as admin from "firebase-admin";

admin.initializeApp();

export { joinQueue, leaveQueue, endChat } from "./matchmaking";
export { cleanupQueue } from "./cleanup";
