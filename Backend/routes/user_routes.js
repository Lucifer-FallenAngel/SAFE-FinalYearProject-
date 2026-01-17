const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const db = require('../models');

const User = db.User;
const Message = db.Message;

const router = express.Router();

// ---------------- ENSURE UPLOAD FOLDER EXISTS ----------------
const uploadDir = 'uploads/profile_pics';

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// ---------------- MULTER CONFIG (PROFILE PIC) ----------------
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueName = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, uniqueName + path.extname(file.originalname));
  },
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
});

// ---------------- GET ALL USERS + UNREAD COUNT ----------------
router.get('/', async (req, res) => {
  const myId = parseInt(req.query.myId);

  try {
    const users = await User.findAll({
      attributes: ['id', 'name', 'profile_pic'],
      order: [['createdAt', 'DESC']],
    });

    const result = [];

    for (const user of users) {
      // Skip the current logged-in user
      if (user.id === myId) continue;

      const unread = await Message.count({
        where: {
          sender_id: user.id,
          receiver_id: myId,
          status: 'sent',
        },
      });

      result.push({
        id: user.id,
        name: user.name,
        profile_pic: user.profile_pic,
        unread,
      });
    }

    res.json(result);
  } catch (err) {
    console.error('GET USERS ERROR:', err);
    res.status(500).json({ message: 'Failed to load users' });
  }
});

// ---------------- UPLOAD PROFILE PICTURE ----------------
router.post(
  '/upload-profile-pic',
  upload.single('profile_pic'),
  async (req, res) => {
    try {
      const { userId } = req.body;

      if (!userId) {
        return res.status(400).json({ message: 'User ID is required' });
      }

      if (!req.file) {
        return res.status(400).json({ message: 'No image uploaded' });
      }

      const user = await User.findByPk(userId);

      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }

      // Update the user record with the new filename
      user.profile_pic = req.file.filename;
      await user.save();

      res.json({
        message: 'Profile picture uploaded successfully',
        file: req.file.filename,
      });
    } catch (error) {
      console.error('UPLOAD ERROR:', error);
      res.status(500).json({ message: 'Upload failed' });
    }
  }
);

// ---------------- UPDATE ONESIGNAL PLAYER ID ----------------
router.post('/update-onesignal', async (req, res) => {
  const { userId, playerId } = req.body;

  if (!userId || !playerId) {
    return res.status(400).json({ message: 'Missing userId or playerId' });
  }

  try {
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.onesignal_player_id = playerId;
    await user.save();

    res.json({ success: true });
  } catch (err) {
    console.error('UPDATE ONESIGNAL ERROR:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;