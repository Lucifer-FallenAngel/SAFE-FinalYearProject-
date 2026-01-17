module.exports = (sequelize, DataTypes) => {
  return sequelize.define('ScanCache', {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },

    // url | file | image
    type: {
      type: DataTypes.STRING,
      allowNull: false,
    },

    // URL string OR file hash
    identifier: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },

    result: {
      type: DataTypes.JSON,
      allowNull: false,
    },

    lastScannedAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  });
};
