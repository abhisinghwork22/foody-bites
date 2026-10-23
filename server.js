const express = require('express');
const path = require('path');
const { Storage } = require('@google-cloud/storage');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 8080;
const BUCKET_NAME = process.env.GCS_BUCKET || 'abhishek-test-452001-tfstate';
const DATA_FILE = 'foody-bites/store-data.json';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123'; // Set via Cloud Run env var!

const storage = new Storage();

// Default Initial Data (Used on very first boot before Admin makes changes)
const DEFAULT_DATA = {
  storeConfig: {
    openHourIST: 10,  // 10:00 AM IST
    closeHourIST: 22, // 10:00 PM IST
    forceClosed: false,
    closedFrom: "",   // ISO datetime string in IST
    closedUntil: "",  // ISO datetime string in IST
    closedReason: ""  // e.g. "Closed for festival"
  },
  categories: ["All", "Indo Chinese", "North Indian", "South Indian", "Bread", "Non-Veg"],
  menu: [
    { id: "ic1", name: "Chowmein", category: "Indo Chinese", veg: true, desc: "Street-style wok-tossed noodles with crunchy julienned veggies.", portions: [{ label: "Half", price: 30 }, { label: "Full", price: 50 }] },
    { id: "ic2", name: "Veg Fried Rice", category: "Indo Chinese", veg: true, desc: "Fragrant rice stir-fried with fresh garden vegetables & Indo-Chinese sauces.", portions: [{ label: "Half", price: 40 }, { label: "Full", price: 70 }] },
    { id: "ic3", name: "Paneer Chilli", category: "Indo Chinese", veg: true, badge: "Popular", desc: "Golden fried paneer cubes tossed in spicy garlic-chilli sauce with capsicum.", portions: [{ label: "Half", price: 80 }, { label: "Full", price: 150 }] },
    { id: "ic4", name: "Soya Chilli", category: "Indo Chinese", veg: true, desc: "Juicy soya chunks coated in tangy, spicy Indo-Chinese chilli glaze.", portions: [{ label: "Half", price: 40 }, { label: "Full", price: 70 }] },
    { id: "ic5", name: "Manchurian", category: "Indo Chinese", veg: true, desc: "Crispy mixed-veg dumplings tossed in savoury coriander-garlic Manchurian sauce.", portions: [{ label: "Half", price: 55 }, { label: "Full", price: 100 }] },
    { id: "ni1", name: "Paneer Butter Masala", category: "North Indian", veg: true, badge: "Best with Naan!", desc: "Creamy, rich & irresistible cottage cheese simmered in buttery tomato-cashew gravy.", portions: [{ label: "Quarter", price: 110 }, { label: "Half", price: 205 }, { label: "Full", price: 390 }] },
    { id: "ni2", name: "Mix Dal Tadka", category: "North Indian", veg: true, desc: "Homestyle protein-rich yellow & mixed lentils tempered with aromatic spices.", portions: [{ label: "Quarter", price: 50 }, { label: "Half", price: 90 }, { label: "Full", price: 170 }] },
    { id: "si1", name: "Masala Dosa", category: "South Indian", veg: true, desc: "Crispy golden rice crepe stuffed with spiced potato mash, served with chutney & sambar.", portions: [{ label: "Full", price: 45 }] },
    { id: "si2", name: "Butter Masala Dosa", category: "South Indian", veg: true, badge: "Must Try", desc: "Crispy masala dosa roasted generously in rich butter.", portions: [{ label: "Full", price: 60 }] },
    { id: "br1", name: "Roti", category: "Bread", veg: true, desc: "Freshly made whole wheat tawa/tandoori roti.", portions: [{ label: "1 Pc", price: 7 }] },
    { id: "br2", name: "Butter Roti", category: "Bread", veg: true, desc: "Soft whole wheat roti brushed with butter.", portions: [{ label: "1 Pc", price: 11 }] },
    { id: "br3", name: "Naan", category: "Bread", veg: true, desc: "Soft and fluffy traditional tandoori naan.", portions: [{ label: "1 Pc", price: 20 }] },
    { id: "br4", name: "Butter Naan", category: "Bread", veg: true, badge: "Bestseller", desc: "Tandoori naan layered with melted butter — pairs best with Paneer Butter Masala!", portions: [{ label: "1 Pc", price: 25 }] },
    { id: "br5", name: "Drinking Water", category: "Bread", veg: true, desc: "Chilled packaged drinking water.", portions: [{ label: "1 Bottle", price: 15 }] },
    { id: "nv1", name: "Chicken Sukka", category: "Non-Veg", veg: false, badge: "Spicy & Rich", desc: "Tender chicken pieces slow-roasted in rich homemade masala.", portions: [{ label: "Quarter", price: 110 }, { label: "Half", price: 205 }, { label: "Full", price: 390 }] }
  ]
};

let cachedData = null;

async function getStoreData() {
  if (cachedData) return cachedData;
  try {
    const file = storage.bucket(BUCKET_NAME).file(DATA_FILE);
    const [exists] = await file.exists();
    if (!exists) {
      await file.save(JSON.stringify(DEFAULT_DATA, null, 2), { contentType: 'application/json' });
      cachedData = DEFAULT_DATA;
      return cachedData;
    }
    const [contents] = await file.download();
    cachedData = JSON.parse(contents.toString());
    return cachedData;
  } catch (err) {
    console.error("GCS read fallback to default:", err.message);
    return DEFAULT_DATA;
  }
}

async function saveStoreData(newData) {
  cachedData = newData;
  const file = storage.bucket(BUCKET_NAME).file(DATA_FILE);
  await file.save(JSON.stringify(newData, null, 2), { contentType: 'application/json' });
}

// Public API: Fetch Menu & Store Status
app.get('/api/store', async (req, res) => {
  const data = await getStoreData();
  res.json(data);
});

// Admin API: Update Menu or Store Status
app.post('/api/admin/update', async (req, res) => {
  const password = req.headers['x-admin-password'];
  if (password !== ADMIN_PASSWORD) {
    return res.status(401).json({ error: 'Invalid Admin Password!' });
  }
  const { storeConfig, menu } = req.body;
  const current = await getStoreData();
  const updated = {
    ...current,
    storeConfig: storeConfig || current.storeConfig,
    menu: menu || current.menu
  };
  await saveStoreData(updated);
  res.json({ success: true, data: updated });
});

// Serve Frontend
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Foody Bites Server listening on port ${PORT}`);
});