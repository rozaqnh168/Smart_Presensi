require('dotenv').config();

const { createClient } = require('@supabase/supabase-js');
const express = require('express');
const multer = require('multer');
const crypto = require('node:crypto');
const path = require('node:path');

const app = express();
const PORT = Number(process.env.PORT || 3000);
const STORAGE_BUCKET = process.env.SUPABASE_STORAGE_BUCKET || 'attendance-photos';

const requiredEnv = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'];
const missingEnv = requiredEnv.filter((name) => !process.env[name]);
if (missingEnv.length > 0) {
  throw new Error(`Missing required environment variables: ${missingEnv.join(', ')}`);
}

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  },
);

const TOWER2_CENTER_LATITUDE = -7.28525;
const TOWER2_CENTER_LONGITUDE = 112.79534;
const GEOFENCE_HALF_SIDE_METERS = 15;
const EARTH_RADIUS_METERS = 6371000;
const latitudeOffset =
  ((GEOFENCE_HALF_SIDE_METERS / EARTH_RADIUS_METERS) * 180) / Math.PI;
const longitudeOffset =
  (GEOFENCE_HALF_SIDE_METERS /
    (EARTH_RADIUS_METERS *
      Math.cos((TOWER2_CENTER_LATITUDE * Math.PI) / 180)) *
    180) /
  Math.PI;

function isInsideTower2Geofence(latitude, longitude) {
  const lat = Number(latitude);
  const lon = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return false;

  return (
    lat >= TOWER2_CENTER_LATITUDE - latitudeOffset &&
    lat <= TOWER2_CENTER_LATITUDE + latitudeOffset &&
    lon >= TOWER2_CENTER_LONGITUDE - longitudeOffset &&
    lon <= TOWER2_CENTER_LONGITUDE + longitudeOffset
  );
}

async function removeUploadedPhoto(filePath) {
  const { error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .remove([filePath]);
  if (error) {
    console.error('[POST /api/absen] gagal menghapus foto cloud:', error.message);
  }
}

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype && file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('File yang diunggah harus berupa gambar.'));
    }
  },
});

app.post('/api/absen', upload.single('foto'), async (req, res) => {
  let uploadedPhotoPath;
  try {
    const {
      nrp,
      mata_kuliah: mataKuliah,
      catatan = '',
      latitude,
      longitude,
    } = req.body || {};

    if (!nrp || !mataKuliah || !latitude || !longitude) {
      return res.status(400).json({
        success: false,
        message: 'Field nrp, mata_kuliah, latitude, dan longitude wajib diisi.',
      });
    }
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'File foto wajib diunggah (field "foto").',
      });
    }
    if (typeof catatan !== 'string' || catatan.length > 500) {
      return res.status(400).json({
        success: false,
        message: 'Catatan maksimal 500 karakter.',
      });
    }
    if (!isInsideTower2Geofence(latitude, longitude)) {
      return res.status(403).json({
        success: false,
        message:
          'Absensi hanya diizinkan di dalam kotak 30 × 30 meter Tower 2 ITS.',
      });
    }

    const safeNrp = nrp.replace(/[^a-zA-Z0-9_-]/g, '') || 'unknown';
    const extension = path.extname(req.file.originalname).toLowerCase();
    const photoObjectPath =
      `${safeNrp}/${Date.now()}_${crypto.randomUUID()}${extension || '.jpg'}`;

    const { error: storageError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .upload(photoObjectPath, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: false,
      });
    if (storageError) throw storageError;
    uploadedPhotoPath = photoObjectPath;

    const { data: signedPhotoData, error: signedPhotoError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .createSignedUrl(photoObjectPath, 60 * 60 * 24);
    if (signedPhotoError) throw signedPhotoError;

    const { data, error } = await supabase
      .from('tbl_kehadiran')
      .insert({
        nrp,
        mata_kuliah: mataKuliah,
        catatan: catatan.trim() || null,
        latitude,
        longitude,
        foto_path: photoObjectPath,
      })
      .select('id, nrp, mata_kuliah, catatan, latitude, longitude, foto_path, waktu_absen')
      .single();

    if (error) throw error;

    return res.status(200).json({
      success: true,
      message: 'Absensi Berhasil',
      data: {
        id: data.id,
        nrp: data.nrp,
        mataKuliah: data.mata_kuliah,
        catatan: data.catatan,
        latitude: data.latitude,
        longitude: data.longitude,
        fotoPath: signedPhotoData.signedUrl,
        waktu_absen: data.waktu_absen,
      },
    });
  } catch (err) {
    if (uploadedPhotoPath) await removeUploadedPhoto(uploadedPhotoPath);
    if (err.code === '23505') {
      return res.status(409).json({
        success: false,
        message:
          'Anda sudah absen untuk mata kuliah ini hari ini. Satu mata kuliah hanya dapat diabsen sekali sehari.',
      });
    }
    console.error('[POST /api/absen] error:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal menyimpan absensi ke database cloud.',
    });
  }
});

app.get('/api/absen', async (req, res) => {
  res.set('Cache-Control', 'no-store');
  const nrp = typeof req.query.nrp === 'string' ? req.query.nrp.trim() : '';
  if (!nrp) {
    return res.status(400).json({
      success: false,
      message: 'Parameter nrp wajib diisi.',
    });
  }

  try {
    const { data, error } = await supabase
      .from('tbl_kehadiran')
      .select(
        'id, nrp, mata_kuliah, catatan, latitude, longitude, foto_path, waktu_absen',
      )
      .eq('nrp', nrp)
      .order('waktu_absen', { ascending: false })
      .order('id', { ascending: false });
    if (error) throw error;

    const recordsWithPhotoUrls = await Promise.all(
      data.map(async (record) => {
        const { data: photoData, error: photoError } = await supabase.storage
          .from(STORAGE_BUCKET)
          .createSignedUrl(record.foto_path, 60 * 60 * 24);
        if (photoError) throw photoError;
        return { ...record, foto_path: photoData.signedUrl };
      }),
    );
    return res.status(200).json({ success: true, data: recordsWithPhotoUrls });
  } catch (err) {
    console.error('[GET /api/absen] error:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal mengambil riwayat absensi dari database cloud.',
    });
  }
});

app.get('/', (_req, res) => {
  res.json({ status: 'ok', service: 'smart-presensi-backend' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Smart Presensi API berjalan di port ${PORT}`);
  console.log(`Storage foto Supabase: ${STORAGE_BUCKET}`);
});
