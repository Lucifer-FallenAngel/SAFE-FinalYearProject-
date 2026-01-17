'use strict';

const Sequelize = require('sequelize'); // ✅ REQUIRED
const { sequelize } = require('../config/db');

/* ============================================================
   MODEL DEFINITIONS
============================================================ */

const User = require('./User')(sequelize, Sequelize.DataTypes);
const Conversation = require('./Conversation')(sequelize, Sequelize.DataTypes);
const Message = require('./Message')(sequelize, Sequelize.DataTypes);
const BlockedUser = require('./BlockedUser')(sequelize, Sequelize.DataTypes);
const ScanCache = require('./ScanCache')(sequelize, Sequelize.DataTypes);

/* ============================================================
   DB EXPORT
============================================================ */

const db = {};

db.Sequelize = Sequelize;     // ✅ REQUIRED for associations & DataTypes
db.sequelize = sequelize;

db.User = User;
db.Conversation = Conversation;
db.Message = Message;
db.BlockedUser = BlockedUser;
db.ScanCache = ScanCache;

module.exports = db;
