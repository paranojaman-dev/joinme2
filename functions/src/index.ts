
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();

export const sendNotificationOnNewMessage = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    if (!message) {
      return;
    }

    const chatId = context.params.chatId;
    const senderId = message.senderId;

    // Get chat participants
    const chatDoc = await db.collection("chats").doc(chatId).get();
    const chatData = chatDoc.data();
    if (!chatData) {
      return;
    }

    const userIds: string[] = chatData.users;

    // Get sender's name
    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.data()?.displayName ?? "Someone";

    // Prepare notification payload
    const payload = {
      notification: {
        title: `New message from ${senderName}`,
        body: message.text ?? (message.imageUrl ? "📸 Photo" : ""),
      },
      data: {
        chatId: chatId,
        senderId: senderId,
      },
    };

    // Send to all participants except the sender
    const tokens: string[] = [];
    for (const userId of userIds) {
      if (userId !== senderId) {
        const userDoc = await db.collection("users").doc(userId).get();
        const userToken = userDoc.data()?.fcmToken;
        if (userToken) {
          tokens.push(userToken);
        }
      }
    }

    if (tokens.length > 0) {
      await fcm.sendToDevice(tokens, payload);
    }
  });

