# Push Notification Kullanım Kılavuzu

## 📱 Kurulum Tamamlandı

Firebase Cloud Messaging (FCM) entegrasyonu tamamlandı. Artık kullanıcılara bildirim gönderebilirsiniz.

## 🔔 Bildirim Gönderme Yöntemleri

### 1. Firebase Console Üzerinden (Test için)

1. Firebase Console'a gidin: https://console.firebase.google.com
2. Projenizi seçin
3. Sol menüden **Cloud Messaging** seçin
4. **"Send your first message"** veya **"New notification"** butonuna tıklayın
5. Bildirim başlığı ve metnini girin
6. **"Send test message"** ile test edin veya **"Next"** ile devam edin
7. Hedef kitleyi seçin (tüm kullanıcılar veya belirli segmentler)
8. Gönderin

### 2. Firestore Üzerinden (Programatik)

Firestore'da `notifications` koleksiyonuna yeni bir doküman ekleyerek bildirim gönderebilirsiniz:

```javascript
// Firestore'da notifications koleksiyonuna ekle
{
  title: "Yeni Kategori Eklendi!",
  body: "Arabalar kategorisini keşfetmek için tıkla",
  data: {
    categoryKey: "arabalar",
    type: "category"
  },
  sendTo: "all", // veya "specific" (belirli kullanıcılar için)
  createdAt: Timestamp.now()
}
```

**Not:** Bu yöntem için bir Cloud Function oluşturmanız gerekir (aşağıda örnek var).

### 3. Cloud Functions ile (Önerilen)

Firebase Cloud Functions kullanarak otomatik bildirim gönderebilirsiniz:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    // Tüm kullanıcılara gönder
    if (notification.sendTo === 'all') {
      const tokensSnapshot = await admin.firestore()
        .collection('user_tokens')
        .get();
      
      const tokens = tokensSnapshot.docs.map(doc => doc.data().fcmToken);
      
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {},
        tokens: tokens.filter(token => token != null),
      };
      
      await admin.messaging().sendEachForMulticast(message);
    }
    
    return null;
  });
```

## 📊 Firestore Yapısı

### user_tokens Koleksiyonu
Her kullanıcının FCM token'ı burada saklanır:
```
user_tokens/
  {userId}/
    - fcmToken: "fcm_token_string"
    - userId: "user_id"
    - updatedAt: Timestamp
```

### notifications Koleksiyonu (Opsiyonel)
Bildirim göndermek için kullanılabilir:
```
notifications/
  {notificationId}/
    - title: "Bildirim Başlığı"
    - body: "Bildirim metni"
    - data: {
        categoryKey: "arabalar", // opsiyonel
        type: "category" // opsiyonel
      }
    - sendTo: "all" // veya "specific"
    - createdAt: Timestamp
```

## 🎯 Bildirim Türleri

### 1. Genel Bildirimler
```json
{
  "title": "Yeni Sorular Eklendi!",
  "body": "Sınırsız modda yeni soruları keşfet",
  "data": {
    "type": "unlimited"
  }
}
```

### 2. Kategori Bildirimleri
```json
{
  "title": "Yeni Kategori: Arabalar",
  "body": "Hangi arabayı tercih edersin?",
  "data": {
    "type": "category",
    "categoryKey": "arabalar"
  }
}
```

### 3. Özel Bildirimler
```json
{
  "title": "Günlük Ödülün Hazır!",
  "body": "Giriş yap ve ödülünü al",
  "data": {
    "type": "reward"
  }
}
```

## 🔧 Test Etme

1. Uygulamayı çalıştırın
2. Firebase Console'dan test bildirimi gönderin
3. Bildirim token'ını kontrol edin (console loglarına bakın)
4. Firestore'da `user_tokens` koleksiyonunda token'ın kaydedildiğini doğrulayın

## 📝 Önemli Notlar

- **iOS:** Bildirimler için APNs sertifikası gerekli (Firebase Console'da yapılandırın)
- **Android:** Google Services JSON dosyası zaten yapılandırılmış
- **Token Yönetimi:** Token'lar otomatik olarak Firestore'a kaydediliyor
- **Background:** Uygulama kapalıyken gelen bildirimler işleniyor
- **Foreground:** Uygulama açıkken gelen bildirimler için local notification eklenebilir

## 🚀 Sonraki Adımlar

1. Firebase Console'da Cloud Messaging'i etkinleştirin
2. iOS için APNs sertifikasını yapılandırın
3. Cloud Functions kurulumu yapın (isteğe bağlı)
4. Bildirim gönderme sistemini test edin

