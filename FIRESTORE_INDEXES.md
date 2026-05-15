# Firestore Composite Indexes Required

This document lists the composite indexes that need to be created in Firestore Console.

## Index 1: categories (type, createdAt desc)

**Collection:** `categories`  
**Fields:**
- `type` (Ascending)
- `createdAt` (Descending)

**Usage:** CategoriesPage - Query quiz categories sorted by creation date

**Create in Console:**
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `categories`
4. Add fields: `type` (Ascending), `createdAt` (Descending)
5. Create index

---

## Index 2: categories (mode, createdAt desc)

**Collection:** `categories`  
**Fields:**
- `mode` (Ascending)
- `createdAt` (Descending)

**Usage:** DailyQuizPage - Query daily categories created within last 24 hours, sorted by creation date

**Create in Console:**
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `categories`
4. Add fields: `mode` (Ascending), `createdAt` (Descending)
5. Create index

---

## Alternative: Create via Console Error Links

When you run the app and these queries are executed, Firestore will provide console error messages with direct links to create the indexes. You can click those links to automatically create the indexes.

