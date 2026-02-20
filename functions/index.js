const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendPushNotification = functions.firestore
    .document("users/{userId}/notifications/{notificationId}")
    .onCreate(async (snapshot, context) => {
        const userId = context.params.userId;
        const notification = snapshot.data();

        if (!notification) {
            console.log("Brak danych notyfikacji.");
            return null;
        }

        console.log(`🔔 Wykryto nową notyfikację typu ${notification.type} dla użytkownika: ${userId}`);

        try {
            // 1. Pobieramy dane odbiorcy
            const userDoc = await admin.firestore().collection("users").doc(userId).get();
            if (!userDoc.exists) {
                console.log("❌ Użytkownik nie istnieje w bazie.");
                return null;
            }

            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;

            if (!fcmToken) {
                console.log(`⚠️ Użytkownik ${userId} nie ma zapisanego fcmToken w bazie.`);
                return null;
            }

            console.log(`Found token: ${fcmToken.substring(0, 10)}...`);

            // 2. Przygotowujemy treść
            let title = "JoinMe";
            let body = "Masz nowe powiadomienie!";
            const senderName = notification.extraData?.senderName || "Ktoś";
            const eventTitle = notification.extraData?.eventTitle || "";

            switch (notification.type) {
                case "new_message":
                    title = `Wiadomość od ${senderName}`;
                    body = notification.extraData?.text || "Kliknij, aby przeczytać.";
                    break;
                case "friend_request":
                    title = "Zaproszenie do znajomych";
                    body = `${senderName} chce Cię dodać do znajomych.`;
                    break;
                case "created_new_event":
                    title = "Nowe wydarzenie!";
                    body = `${senderName} utworzył(a): ${eventTitle}`;
                    break;
                case "event_joined":
                    title = "Nowy uczestnik";
                    body = `${senderName} dołączył(a) do: ${eventTitle}`;
                    break;
            }

            // 3. Wysyłamy PUSH
            const message = {
                notification: { title, body },
                token: fcmToken,
                android: {
                    priority: "high",
                    notification: {
                        channelId: "high_importance_channel",
                        icon: "launcher_icon",
                        clickAction: "FLUTTER_NOTIFICATION_CLICK"
                    }
                }
            };

            await admin.messaging().send(message);
            console.log(`✅ PUSH wysłany do ${userId}`);
            return null;

        } catch (error) {
            console.error("❌ Krytyczny błąd wysyłania PUSH:", error);
            return null;
        }
    });
