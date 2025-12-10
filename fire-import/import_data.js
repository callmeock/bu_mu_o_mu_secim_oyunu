// import_data.js

const admin = require("firebase-admin");
const xlsx = require("xlsx");
const fs = require("fs");

// 🔑 1) serviceAccount.json'u bu dosya ile aynı klasöre koy
const serviceAccount = JSON.parse(
  fs.readFileSync("./serviceAccount.json", "utf8")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 🌐 2) Tüm görsellerin taban URL'i
const BASE_IMAGE_URL = "https://callmeock.com/wp-content/uploads/2025/11/";

// 🧩 Türkçe karakterleri temizleyip dosya adı üretmek için
function slugify(text) {
  return text
    .toString()
    .trim()
    .toLowerCase()
    .replace(/ç/g, "c")
    .replace(/ğ/g, "g")
    .replace(/ı/g, "i")
    .replace(/ö/g, "o")
    .replace(/ş/g, "s")
    .replace(/ü/g, "u")
    .replace(/[^a-z0-9\s_]/g, "") // harf/rakam dışı karakterleri sil
    .replace(/\s+/g, "_"); // boşlukları _ yap
}

// Excel satırından açıklama alanını çek (kolon adı esnek)
function getDescriptionFromRow(row) {
  if (!row) return null;

  const candidates = ["text", "description", "aciklama", "açıklama"];

  for (const key of candidates) {
    if (row[key] && row[key].toString().trim().length > 0) {
      return row[key].toString().trim();
    }
  }

  return null;
}

// --------------------
//  KATEGORİ + DESCRIPTIONS
// --------------------

async function importCategoryExcel(excelPath) {
  console.log(`\n📥 Kategori Excel okunuyor: ${excelPath}`);

  const workbook = xlsx.readFile(excelPath);
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = xlsx.utils.sheet_to_json(sheet);

  if (!rows.length) {
    console.log("  ⚠️ Excel boş, atlanıyor.");
    return;
  }

  const categoryName = rows[0].category.toString().trim(); // Örn: "Makyaj", "Sehirler"
  const categorySlug = slugify(categoryName); // Örn: "makyaj", "sehirler"

  const items = [];
  for (const row of rows) {
    const itemName = row.item.toString().trim();
    const imageFile = row.image.toString().trim(); // Örn: "kirmizi_ruj.webp"
    const imageUrl = BASE_IMAGE_URL + imageFile;

    const descText =
      getDescriptionFromRow(row) || "Açıklama eklenecek."; // Excel'de varsa al, yoksa placeholder

    items.push(itemName);

    // descriptions koleksiyonuna item bazlı doküman
    const descRef = db.collection("descriptions").doc(itemName);
    console.log(`  ✏️ descriptions/${itemName}`);

    await descRef.set(
      {
        image: imageUrl,
        text: descText,
      },
      { merge: true } // varsa üzerine yazar, yoksa oluşturur
    );
  }

  // categories koleksiyonuna kategori dokümanı
  const categoryDocRef = db.collection("categories").doc(categoryName);
  const categoryImageUrl = BASE_IMAGE_URL + `${categorySlug}.webp`;

  console.log(`\n  📂 categories/${categoryName} kaydediliyor...`);
  await categoryDocRef.set(
    {
      image: categoryImageUrl, // Bu dosyayı sen WordPress'e yükleyeceksin: makyaj.webp, sehirler.webp
      items,
    },
    { merge: true }
  );

  console.log(`✅ Kategori import tamam: ${categoryName}`);
}

// --------------------
//  UNLIMITED QUESTIONS
// --------------------

async function importUnlimitedQuestions(excelPath) {
  console.log(`\n📥 Unlimited sorular Excel okunuyor: ${excelPath}`);

  const workbook = xlsx.readFile(excelPath);
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = xlsx.utils.sheet_to_json(sheet);

  let counter = 0;

  for (const row of rows) {
    const question = row.question.toString().trim();
    const optionA = row.optionA.toString().trim();
    const optionB = row.optionB.toString().trim();

    const imageAFile = slugify(optionA) + ".webp";
    const imageBFile = slugify(optionB) + ".webp";

    const doc = {
      active: true,
      question,
      optionA,
      optionB,
      imageA: BASE_IMAGE_URL + imageAFile,
      imageB: BASE_IMAGE_URL + imageBFile,
      weight: 1,
    };

    await db.collection("unlimited_questions").add(doc); // mevcutlara ekler, silmez
    counter++;

    console.log(
      `  ➕ Soru eklendi (${counter}): ${question} | ${optionA} vs ${optionB}`
    );
  }

  console.log(`✅ Unlimited import tamamlandı. Toplam soru: ${counter}`);
}

// --------------------
//  HEPSİNİ ÇALIŞTIR
// --------------------

async function run() {
  try {
    // 1) Kategoriler (makyaj & sehir)
    await importCategoryExcel("makyaj.xlsx");
    await importCategoryExcel("sehir.xlsx");

    // 2) Unlimited sorular (güncellenmediyse bile, tekrar çalıştırırsan
    //    aynı sorular bir kez daha eklenir, haberin olsun)
    await importUnlimitedQuestions("sorular.xlsx");

    console.log("\n🎉 Tüm import işlemleri başarıyla tamamlandı!");
    process.exit(0);
  } catch (err) {
    console.error("❌ Hata:", err);
    process.exit(1);
  }
}

run();
