const express = require('express');
const { Op, Sequelize } = require('sequelize');
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');
const fs = require('fs');

const db = require('../models');
const { runDeepfakeDetection } = require('../utils/deepfake_runner');


const {
  extractUrls,
} = require('../utils/virusTotal');

const {
  enrichUrlScan,
  enrichFileScan,
} = require('../services/virustotal_service');

const router = express.Router();

const Message = db.Message;
const Conversation = db.Conversation;
const BlockedUser = db.BlockedUser;
const User = db.User;

/* ============================================================
   MULTER CONFIG
============================================================ */
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) =>
    cb(null, `${Date.now()}-${file.originalname}`),
});

const upload = multer({ storage });

/* ============================================================
   SEND TEXT MESSAGE
============================================================ */
router.post('/send', async (req, res) => {
  try {
    const { sender_id, receiver_id, message } = req.body;

    if (!sender_id || !receiver_id || !message)
      return res.status(400).json({ message: 'Missing fields' });

    const blocked = await BlockedUser.findOne({
      where: {
        [Op.or]: [
          { blocker_id: sender_id, blocked_id: receiver_id },
          { blocker_id: receiver_id, blocked_id: sender_id },
        ],
      },
    });

    if (blocked) return res.status(403).json({ message: 'User blocked' });

    let convo = await Conversation.findOne({
      where: {
        [Op.or]: [
          { user1_id: sender_id, user2_id: receiver_id },
          { user1_id: receiver_id, user2_id: sender_id },
        ],
      },
    });

    if (!convo) {
      convo = await Conversation.create({
        user1_id: sender_id,
        user2_id: receiver_id,
      });
    }

    /* ---------------- URL SCAN (CACHED) ---------------- */
    const urls = extractUrls(message);

    let containsUrl = false;
    let urlScanResult = null;

    if (urls.length > 0) {
      containsUrl = true;
      urlScanResult = await enrichUrlScan(urls[0]); // ✅ CACHED
    }

    const msg = await Message.create({
      conversation_id: convo.id,
      sender_id,
      receiver_id,
      message,
      message_type: 'text',
      status: 'sent',
      deleted_for: [],
      contains_url: containsUrl,
      url_scan: urlScanResult,
    });

    const io = req.app.get('io');
    const onlineUsers = req.app.get('onlineUsers');

    /* ---------------- PUSH NOTIFICATION ---------------- */
    if (!onlineUsers[receiver_id]) {
      const receiver = await User.findByPk(receiver_id);
      if (receiver?.onesignal_player_id) {
        req.app.get('onesignalClient').createNotification({
          contents: {
            en: message.length > 100
              ? `${message.substring(0, 97)}...`
              : message,
          },
          headings: { en: `New message from ${sender_id}` },
          include_player_ids: [receiver.onesignal_player_id],
          data: { senderId: sender_id.toString(), type: 'text' },
        }).catch(console.error);
      }
    }

    if (onlineUsers[receiver_id]) {
      io.to(onlineUsers[receiver_id]).emit('new-message-arrived', {
        sender_id,
        receiver_id,
        messageId: msg.id,
        contains_url: msg.contains_url,
        url_scan: msg.url_scan,
      });
    }

    res.json(msg);
  } catch (err) {
    console.error('SEND MESSAGE ERROR:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

/* ============================================================
   UPLOAD IMAGE / FILE
============================================================ */
router.post('/upload', upload.single('file'), async (req, res) => {
  try {
    const { sender_id, receiver_id, message_type, allow_upload } = req.body;

    if (!req.file || !sender_id || !receiver_id || !message_type)
      return res.status(400).json({ message: 'Missing fields' });

    /* ---------------- HASH FILE ---------------- */
    const fileBuffer = fs.readFileSync(req.file.path);
    const fileHash = crypto
      .createHash('sha256')
      .update(fileBuffer)
      .digest('hex');

    /* ---------------- FILE SCAN (CACHED) ---------------- */
    const fileScanResult = await enrichFileScan(
      fileHash,
      req.file.path,
      allow_upload === 'true'
    );

    /* ---------------- DEEPFAKE DETECTION (IMAGES ONLY) ---------------- */
    let deepfakeScan = null;

    if (req.file.mimetype.startsWith('image/')) {
      try {
        deepfakeScan = await runDeepfakeDetection(req.file.path);
      } catch (err) {
        console.error('Deepfake detection failed:', err.message);
      }
    }


    const blocked = await BlockedUser.findOne({
      where: {
        [Op.or]: [
          { blocker_id: sender_id, blocked_id: receiver_id },
          { blocker_id: receiver_id, blocked_id: sender_id },
        ],
      },
    });

    if (blocked) return res.status(403).json({ message: 'User blocked' });

    let convo = await Conversation.findOne({
      where: {
        [Op.or]: [
          { user1_id: sender_id, user2_id: receiver_id },
          { user1_id: receiver_id, user2_id: sender_id },
        ],
      },
    });

    if (!convo) {
      convo = await Conversation.create({
        user1_id: sender_id,
        user2_id: receiver_id,
      });
    }

    const msg = await Message.create({
      conversation_id: convo.id,
      sender_id,
      receiver_id,
      message_type,
      file_url: `uploads/${req.file.filename}`,
      file_hash: fileHash,
      contains_file: true,
      file_scan: fileScanResult,
      deepfake_scan: deepfakeScan,
      status: 'sent',
      deleted_for: [],
    });

    const io = req.app.get('io');
    const onlineUsers = req.app.get('onlineUsers');

    if (!onlineUsers[receiver_id]) {
      const receiver = await User.findByPk(receiver_id);
      if (receiver?.onesignal_player_id) {
        req.app.get('onesignalClient').createNotification({
          contents: {
            en: message_type === 'image' ? 'sent a photo' : 'sent a file',
          },
          headings: { en: `New message from ${sender_id}` },
          include_player_ids: [receiver.onesignal_player_id],
          data: { senderId: sender_id.toString(), type: message_type },
        }).catch(console.error);
      }
    }

    if (onlineUsers[receiver_id]) {
      io.to(onlineUsers[receiver_id]).emit('new-message-arrived', {
        sender_id,
        receiver_id,
        messageId: msg.id,
        contains_file: true,
        file_scan: msg.file_scan,
      });
    }

    res.json(msg);
  } catch (err) {
    console.error('UPLOAD ERROR:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

/* ============================================================
   LOAD CHAT HISTORY (MYSQL SAFE)
============================================================ */
router.get('/:myId/:otherId', async (req, res) => {
  try {
    const myId = parseInt(req.params.myId);
    const otherId = parseInt(req.params.otherId);

    const convo = await Conversation.findOne({
      where: {
        [Op.or]: [
          { user1_id: myId, user2_id: otherId },
          { user1_id: otherId, user2_id: myId },
        ],
      },
    });

    if (!convo) return res.json([]);

    const messages = await Message.findAll({
      where: {
        conversation_id: convo.id,
        [Op.and]: [
          Sequelize.literal(
            `NOT JSON_CONTAINS(IFNULL(deleted_for, '[]'), CAST(${myId} AS JSON))`
          ),
        ],
      },
      order: [['createdAt', 'ASC']],
    });

    await Message.update(
      { status: 'delivered' },
      {
        where: {
          conversation_id: convo.id,
          sender_id: otherId,
          receiver_id: myId,
          status: 'sent',
        },
      }
    );

    res.json(messages);
  } catch (err) {
    console.error('LOAD CHAT ERROR:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

/* ============================================================
   DELETE / CLEAR / BLOCK (UNCHANGED)
============================================================ */

router.post('/delete-for-me', async (req, res) => {
  try {
    const { messageId, userId } = req.body;
    const message = await Message.findByPk(messageId);
    if (!message) return res.status(404).json({ message: 'Message not found' });

    const deletedFor = Array.isArray(message.deleted_for)
      ? [...message.deleted_for]
      : [];

    if (!deletedFor.includes(userId)) {
      deletedFor.push(userId);
      message.deleted_for = deletedFor;
      await message.save();
    }

    res.json({ success: true });
  } catch {
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/clear-chat', async (req, res) => {
  try {
    const { userId, otherUserId } = req.body;

    const convo = await Conversation.findOne({
      where: {
        [Op.or]: [
          { user1_id: userId, user2_id: otherUserId },
          { user1_id: otherUserId, user2_id: userId },
        ],
      },
    });

    if (!convo) return res.json({ success: true });

    const messages = await Message.findAll({
      where: { conversation_id: convo.id },
    });

    for (const msg of messages) {
      const deletedFor = Array.isArray(msg.deleted_for)
        ? [...msg.deleted_for]
        : [];
      if (!deletedFor.includes(userId)) {
        deletedFor.push(userId);
        await msg.update({ deleted_for: deletedFor });
      }
    }

    res.json({ success: true });
  } catch {
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/block', async (req, res) => {
  const { blocker_id, blocked_id } = req.body;
  await BlockedUser.findOrCreate({ where: { blocker_id, blocked_id } });
  res.json({ success: true });
});

router.post('/unblock', async (req, res) => {
  const { blocker_id, blocked_id } = req.body;
  await BlockedUser.destroy({ where: { blocker_id, blocked_id } });
  res.json({ success: true });
});

router.get('/is-blocked/:me/:other', async (req, res) => {
  const me = parseInt(req.params.me);
  const other = parseInt(req.params.other);

  const iBlocked = await BlockedUser.findOne({
    where: { blocker_id: me, blocked_id: other },
  });

  const theyBlocked = await BlockedUser.findOne({
    where: { blocker_id: other, blocked_id: me },
  });

  res.json({
    blocked: !!(iBlocked || theyBlocked),
    iBlocked: !!iBlocked,
  });
});

module.exports = router;
