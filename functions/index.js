const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.joinHouseholdByInviteCode = functions.https.onCall(async (data, context) => {
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
    await firestore.runTransaction(async (transaction) => {
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
