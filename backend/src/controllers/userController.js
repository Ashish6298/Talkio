//userController.js

const jwt = require("jsonwebtoken");
const User = require("../models/User");

const getUsers = async (req, res) => {
  const token = req.headers.authorization?.split(" ")[1];
  try {
    if (!token) {
      return res
        .status(401)
        .json({ success: false, message: "Token required" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.id;

    const currentUser = await User.findById(userId).select(
      "friends sentRequests receivedRequests"
    );
    if (!currentUser) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    // Fetch all users, including the profilePic field
    const allUsers = await User.find({}, "username _id profilePic").lean();

    const friends = [];
    const strangers = [];
    for (const user of allUsers) {
      if (user._id.toString() === userId) continue;
      if (currentUser.friends.includes(user._id)) {
        friends.push({
          _id: user._id,
          username: user.username,
          profilePic: user.profilePic, // Include profilePic
        });
      } else {
        strangers.push({
          _id: user._id,
          username: user.username,
          profilePic: user.profilePic, // Include profilePic
          isSentRequest: currentUser.sentRequests.includes(user._id),
          isReceivedRequest: currentUser.receivedRequests.includes(user._id),
        });
      }
    }

    res.json({ success: true, friends, strangers });
  } catch (error) {
    console.error("Error fetching users:", error);
    res
      .status(500)
      .json({
        success: false,
        message: "Error fetching users",
        error: error.message,
      });
  }
};

const sendFriendRequest = (io) => async (req, res) => {
  const { receiverId } = req.body;
  const token = req.headers.authorization?.split(" ")[1];

  try {
    if (!token) {
      return res
        .status(401)
        .json({ success: false, message: "Token required" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const senderId = decoded.id;

    if (senderId === receiverId) {
      return res
        .status(400)
        .json({ success: false, message: "Cannot send request to yourself" });
    }

    const sender = await User.findById(senderId);
    const receiver = await User.findById(receiverId);

    if (!sender || !receiver) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    if (
      sender.friends.includes(receiverId) ||
      receiver.friends.includes(senderId)
    ) {
      return res
        .status(400)
        .json({ success: false, message: "Already friends" });
    }

    if (sender.sentRequests.includes(receiverId)) {
      return res
        .status(400)
        .json({ success: false, message: "Request already sent" });
    }

    sender.sentRequests.push(receiverId);
    receiver.receivedRequests.push(senderId);

    await sender.save();
    await receiver.save();

    // Emit event to receiver
    io.to(receiverId).emit("friendRequestReceived", {
      senderId,
      senderUsername: sender.username,
    });
    // Emit event to sender
    io.to(senderId).emit("friendRequestSent", {
      receiverId,
      receiverUsername: receiver.username,
    });

    res.json({ success: true, message: "Friend request sent" });
  } catch (error) {
    console.error("Error sending friend request:", error);
    res
      .status(500)
      .json({
        success: false,
        message: "Error sending friend request",
        error: error.message,
      });
  }
};

const acceptFriendRequest = (io) => async (req, res) => {
  const { senderId } = req.body;
  const token = req.headers.authorization?.split(" ")[1];

  try {
    if (!token) {
      return res
        .status(401)
        .json({ success: false, message: "Token required" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const receiverId = decoded.id;

    if (senderId === receiverId) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid request" });
    }

    const sender = await User.findById(senderId);
    const receiver = await User.findById(receiverId);

    if (!sender || !receiver) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    if (!receiver.receivedRequests.includes(senderId)) {
      return res
        .status(400)
        .json({ success: false, message: "No friend request found" });
    }

    sender.friends.push(receiverId);
    receiver.friends.push(senderId);

    sender.sentRequests = sender.sentRequests.filter(
      (id) => id.toString() !== receiverId
    );
    receiver.receivedRequests = receiver.receivedRequests.filter(
      (id) => id.toString() !== senderId
    );

    await sender.save();
    await receiver.save();

    // Emit event to both users
    io.to(senderId).emit("friendRequestAccepted", {
      userId: receiverId,
      username: receiver.username,
    });
    io.to(receiverId).emit("friendRequestAccepted", {
      userId: senderId,
      username: sender.username,
    });

    res.json({ success: true, message: "Friend request accepted" });
  } catch (error) {
    console.error("Error accepting friend request:", error);
    res
      .status(500)
      .json({
        success: false,
        message: "Error accepting friend request",
        error: error.message,
      });
  }
};

const getProfile = async (req, res) => {
  const token = req.headers.authorization?.split(" ")[1];
  try {
    if (!token) {
      return res
        .status(401)
        .json({ success: false, message: "Token required" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.id;

    const user = await User.findById(userId)
      .select("username email profilePic friends sentRequests receivedRequests")
      .populate("friends", "username profilePic")
      .lean();

    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    const profile = {
      username: user.username,
      email: user.email,
      profilePic: user.profilePic,
      numberOfFriends: user.friends.length,
      friends: user.friends,
      sentRequestsCount: user.sentRequests.length,
      receivedRequestsCount: user.receivedRequests.length,
    };

    res.json({ success: true, profile });
  } catch (error) {
    console.error("Error fetching profile:", error);
    res
      .status(500)
      .json({
        success: false,
        message: "Error fetching profile",
        error: error.message,
      });
  }
};

module.exports = {
  getUsers,
  sendFriendRequest,
  acceptFriendRequest,
  getProfile,
};
