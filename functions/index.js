const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

exports.joinHouseholdByInviteCode = functions.https.onCall(async (data, context) =>
{
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const { inviteCode } = data;
  if (!inviteCode || typeof inviteCode !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a string argument \"inviteCode\"."
    );
  }

  const firestore = admin.firestore();
  const households = firestore.collection("households");

  const query = await households.where("inviteCode", "==", inviteCode).limit(1).get();

  if (query.empty) {
    throw new functions.https.HttpsError("not-found", "No household found for that invite code.");
  }

  const householdDoc = query.docs[0];
  const householdId = householdDoc.id;
  const uid = context.auth.uid;

  try {
    await firestore.runTransaction(async (transaction) =>
    {
      const householdRef = households.doc(householdId);
      const userRef = firestore.collection("users").doc(uid);

      const householdSnapshot = await transaction.get(householdRef);
      if (!householdSnapshot.exists) {
        throw new functions.https.HttpsError("not-found", "Household does not exist.");
      }

      const householdData = householdSnapshot.data();
      const members = householdData.members || [];

      if (!members.includes(uid)) {
        transaction.update(householdRef, { members: admin.firestore.FieldValue.arrayUnion(uid) });
        transaction.set(userRef, { householdId }, { merge: true });
      }
    });

    return { householdId };
  } catch (error) {
    console.error("Transaction failed: ", error);
    throw new functions.https.HttpsError("internal", "Failed to join household.", error);
  }
});

const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");

exports.onGroceryListUpdate = onDocumentWritten(
  "households/{householdId}/groceries/{groceryId}",
  async (event) =>
  {
    const { householdId } = event.params;

    const payload = {
      data: {
        action: "update_shopping_list",
        type: "shopping_update",
      },
      topic: `household_${householdId}`
    };

    try {
      await admin.messaging().send(payload);
      console.log(`Sent silent push to topic: household_${householdId}`);
    } catch (error) {
      console.error("Failed to send silent push for shopping update: ", error);
    }
  }
);

exports.onPingCreated = onDocumentCreated(
  "households/{householdId}/pings/{pingId}",
  async (event) =>
  {
    const pingData = event.data.data();
    if (!pingData) return;

    const { recipientId, senderId, reason } = pingData;
    if (!recipientId) return;

    // Typically you would fetch the user's FCM tokens here.
    // For now, we will send it to a user-specific topic to ensure delivery.
    const payload = {
      data: {
        action: "ping_request",
        type: "ping",
        pingId: event.params.pingId,
        householdId: event.params.householdId,
        senderId: senderId,
        reason: reason || "Where are you?",
      },
      topic: `user_${recipientId}`,
      android: {
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            priority: 10,
          },
        },
      }
    };

    try {
      await admin.messaging().send(payload);
      console.log(`Sent high priority ping push to topic: user_${recipientId}`);
    } catch (error) {
      console.error("Failed to send ping push: ", error);
    }
  }
);

