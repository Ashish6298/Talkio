const User = require('../models/User');

const getUsers = async (req, res) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) {
      return res.status(401).json({ success: false, message: "Token required" });
    }

    const users = await User.find({}, 'username _id').lean();
    res.json({ success: true, users });
  } catch (error) {
    console.error("Error fetching users:", error);
    res.status(500).json({ success: false, message: "Error fetching users", error: error.message });
  }
};

module.exports = { getUsers };