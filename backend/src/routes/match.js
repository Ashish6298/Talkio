const express = require("express");
const User = require("../models/User");
const router = express.Router();

// Match User
router.post("/match", async (req, res) => {
  try {
    const { userId, likedUserId } = req.body;
    
    const user = await User.findById(userId);
    const likedUser = await User.findById(likedUserId);
    
    if (!user || !likedUser) return res.status(404).json({ message: "User not found" });

    // Check if liked user has also liked the current user
    if (likedUser.matches.includes(userId)) {
      user.matches.push(likedUserId);
      likedUser.matches.push(userId);
      await user.save();
      await likedUser.save();
      return res.json({ message: "It's a Match!" });
    }

    res.json({ message: "User liked, waiting for mutual match." });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;
