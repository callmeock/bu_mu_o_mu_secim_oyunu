# 📱 Store Upload Rehberi

## ✅ Build'ler Hazır!

### 📦 Android - Google Play Store

**Dosya:** `android/app/build/outputs/bundle/release/app-release.aab`  
**Boyut:** ~48 MB  
**Versiyon:** 1.1.2 (Build: 3)

#### Yükleme Adımları:

1. **Google Play Console'a giriş yapın:**
   - https://play.google.com/console

2. **Uygulamanızı seçin** (veya yeni uygulama oluşturun)

3. **Production → Create new release** seçin

4. **AAB dosyasını yükleyin:**
   - `android/app/build/outputs/bundle/release/app-release.aab` dosyasını sürükleyip bırakın

5. **Release notları ekleyin** (opsiyonel)

6. **Review → Start rollout to Production** ile yayınlayın

---

### 🍎 iOS - App Store

**Dosya:** `build/ios/ipa/*.ipa`  
**Boyut:** ~47.3 MB  
**Versiyon:** 1.1.2 (Build: 3)  
**Bundle ID:** com.ock.bumuomu

#### Yükleme Adımları:

**Yöntem 1: Apple Transporter (Önerilen)**

1. **Apple Transporter'ı indirin:**
   - Mac App Store'dan: https://apps.apple.com/us/app/transporter/id1450874784

2. **Transporter'ı açın ve giriş yapın**

3. **IPA dosyasını sürükleyip bırakın:**
   - `build/ios/ipa/*.ipa` dosyasını Transporter'a sürükleyin

4. **"Deliver" butonuna tıklayın**

**Yöntem 2: Xcode Organizer**

1. **Xcode'u açın**

2. **Window → Organizer** seçin

3. **Archives** sekmesine gidin

4. **"Distribute App"** butonuna tıklayın

5. **"App Store Connect"** seçin ve devam edin

**Yöntem 3: Komut Satırı (xcrun altool)**

```bash
xcrun altool --upload-app \
  --type ios \
  -f build/ios/ipa/*.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

---

## ⚠️ Önemli Notlar

### Android:
- ✅ AAB dosyası imzalanmış ve hazır
- ✅ Core Library Desugaring etkin
- ✅ Production AdMob ID'leri kullanılıyor

### iOS:
- ✅ IPA dosyası imzalanmış ve hazır
- ⚠️ **Launch image** hala placeholder - değiştirmeniz önerilir
- ✅ Production AdMob ID'leri kullanılıyor

---

## 📋 Store Listing İçin Gerekli Bilgiler

### Google Play Store:
- [ ] Uygulama adı
- [ ] Kısa açıklama (80 karakter)
- [ ] Uzun açıklama (4000 karakter)
- [ ] Screenshot'lar (en az 2, önerilen: 8)
- [ ] Feature graphic (1024x500)
- [ ] App icon (512x512)
- [ ] Privacy policy URL
- [ ] Kategori seçimi

### App Store:
- [ ] Uygulama adı
- [ ] Alt başlık (30 karakter)
- [ ] Açıklama (4000 karakter)
- [ ] Keywords (100 karakter)
- [ ] Screenshot'lar (iPhone ve iPad için)
- [ ] App icon (1024x1024)
- [ ] Privacy policy URL
- [ ] Kategori seçimi

---

## 🔍 Build Kontrol Listesi

### Android:
- [x] Release AAB oluşturuldu
- [x] İmzalama yapıldı
- [x] Version code: 3
- [x] Version name: 1.1.2
- [x] AdMob production ID'leri aktif

### iOS:
- [x] Release IPA oluşturuldu
- [x] İmzalama yapıldı (Team: DQ6CT7HK82)
- [x] Version: 1.1.2
- [x] Build: 3
- [x] Bundle ID: com.ock.bumuomu
- [x] AdMob production ID'leri aktif
- [ ] Launch image güncellenmeli (opsiyonel)

---

## 🚀 Sonraki Adımlar

1. **Store listing'leri hazırlayın** (açıklamalar, screenshot'lar, vb.)
2. **Privacy policy** sayfası oluşturun (gerekli)
3. **Test edin:** Her iki platformda da uygulamayı test edin
4. **Yükleyin:** Yukarıdaki adımları takip ederek store'lara yükleyin
5. **Review sürecini bekleyin:**
   - Google Play: Genellikle 1-3 gün
   - App Store: Genellikle 1-7 gün

---

## 📞 Yardım

Sorun yaşarsanız:
- **Google Play:** https://support.google.com/googleplay/android-developer
- **App Store:** https://developer.apple.com/support

