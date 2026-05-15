# 🔔 Bildirim Test Rehberi

## 📱 Adım 1: Token Kontrolü

### Yöntem A: Console Loglarından
1. Uygulamayı çalıştırın (`flutter run`)
2. Console'da şu logları arayın:
   - `✅ FCM Token alındı: [TOKEN]`
   - `✅ FCM Token Firestore'a kaydedildi`

### Yöntem B: Firestore'dan Kontrol
1. Firebase Console → Firestore Database
2. `user_tokens` koleksiyonunu açın
3. Dokümanlarda `fcmToken` alanını kontrol edin
4. Token'ı kopyalayın (test için gerekli)

## 🧪 Adım 2: Firebase Console'dan Test Bildirimi

### Hızlı Test (Test Message)
1. **Firebase Console** → https://console.firebase.google.com
2. Projenizi seçin: **bumuomu-96772**
3. Sol menüden **Cloud Messaging** seçin
4. **"Send your first message"** veya **"New notification"** butonuna tıklayın
5. **"Send test message"** sekmesine gidin
6. **FCM registration token** alanına token'ı yapıştırın (Firestore'dan kopyaladığınız)
7. **Notification title**: "Test Bildirimi"
8. **Notification text**: "Bu bir test bildirimidir"
9. **"Test"** butonuna tıklayın
10. Cihazınızda bildirimi kontrol edin

### Tüm Kullanıcılara Gönderme
1. **Firebase Console** → **Cloud Messaging**
2. **"New notification"** butonuna tıklayın
3. **Notification title**: "Yeni Kategori Eklendi!"
4. **Notification text**: "Arabalar kategorisini keşfetmek için tıkla"
5. **"Next"** butonuna tıklayın
6. **Target** seçin:
   - **"User segment"** → **"All users"** (tüm kullanıcılar)
   - veya **"Single device"** → Token girin
7. **"Next"** → **"Review"** → **"Publish"**

## 📊 Adım 3: Bildirim Durumlarını Test Etme

### 1. Foreground Test (Uygulama Açıkken)
- Uygulamayı açık tutun
- Firebase Console'dan bildirim gönderin
- Console loglarında şunu görmelisiniz: `📨 Foreground bildirim alındı: [title]`
- **Not:** Şu anda foreground'da local notification göstermiyoruz (eklenebilir)

### 2. Background Test (Uygulama Arka Planda)
- Uygulamayı arka plana alın (home tuşuna basın)
- Firebase Console'dan bildirim gönderin
- Bildirim cihazın bildirim merkezinde görünmeli
- Bildirime tıklayınca uygulama açılmalı

### 3. Terminated Test (Uygulama Kapalıyken)
- Uygulamayı tamamen kapatın
- Firebase Console'dan bildirim gönderin
- Bildirim cihazın bildirim merkezinde görünmeli
- Bildirime tıklayınca uygulama açılmalı

## 🔍 Adım 4: Sorun Giderme

### Token Alınamıyorsa
- ✅ APNs sertifikası yüklendi mi? (iOS için)
- ✅ İnternet bağlantısı var mı?
- ✅ Firebase yapılandırması doğru mu?
- ✅ Console loglarında hata var mı?

### Bildirim Gelmiyorsa
- ✅ Token doğru mu? (Firestore'dan kontrol edin)
- ✅ Bildirim izni verildi mi? (iOS Settings → Notifications)
- ✅ APNs sertifikası aktif mi? (Firebase Console → Cloud Messaging → iOS app)
- ✅ Test mesajı gönderirken token doğru mu?

### iOS Özel Kontroller
- ✅ APNs Authentication Key yüklendi mi?
- ✅ Bundle ID eşleşiyor mu? (com.ock.bumuomu)
- ✅ Firebase Console'da iOS app yapılandırması tamamlandı mı?

## 📝 Test Senaryoları

### Senaryo 1: Basit Bildirim
```json
{
  "title": "Merhaba!",
  "body": "Bu bir test bildirimidir"
}
```

### Senaryo 2: Kategori Yönlendirmeli
```json
{
  "title": "Yeni Kategori",
  "body": "Arabalar kategorisini keşfet!",
  "data": {
    "categoryKey": "arabalar",
    "type": "category"
  }
}
```

### Senaryo 3: Sınırsız Mod Bildirimi
```json
{
  "title": "Yeni Sorular",
  "body": "Sınırsız modda yeni soruları keşfet!",
  "data": {
    "type": "unlimited"
  }
}
```

## 🎯 Başarı Kriterleri

✅ Token Firestore'a kaydedildi
✅ Firebase Console'dan test mesajı gönderildi
✅ Bildirim cihazda göründü
✅ Bildirime tıklandığında uygulama açıldı
✅ Console loglarında bildirim alındı mesajı var

## 🚀 Sonraki Adımlar

Test başarılı olduktan sonra:
1. Foreground bildirimleri için local notification ekleyin (isteğe bağlı)
2. Bildirime tıklandığında navigasyon ekleyin
3. Cloud Functions ile otomatik bildirim sistemi kurun

