

const jwt = require('jsonwebtoken');
const Message = require('../models/Message');
const User = require('../models/User');

const setupMessaging = (io) => {
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (!token) {
      return next(new Error("Authentication error: Token required"));
    }
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.id;
      next();
    } catch (error) {
      next(new Error("Authentication error: Invalid token"));
    }
  });

  io.on("connection", (socket) => {
    console.log(`User connected: ${socket.userId} (Socket ID: ${socket.id})`);

    socket.join(socket.userId);

    socket.on("sendMessage", async ({ receiverId, content }) => {
      try {
        const senderId = socket.userId;
        if (!receiverId || !content) {
          return socket.emit("error", { error: "Receiver ID and content are required" });
        }

        const sender = await User.findById(senderId).select('friends');
        if (!sender.friends.includes(receiverId)) {
          return socket.emit("error", { error: "You can only message friends" });
        }

        const message = new Message({
          sender: senderId,
          receiver: receiverId,
          content,
          seen: false,
        });
        await message.save();

        // Emit to receiver
        io.to(receiverId).emit("receiveMessage", message);
        // Emit to sender
        socket.emit("messageSent", message);

        // Simulate delivery (in a real app, this would depend on the recipient's connection)
        message.deliveredAt = new Date();
        await message.save();
        io.to(senderId).emit("messageDelivered", { messageId: message._id, deliveredAt: message.deliveredAt });

        console.log(`Message sent from ${senderId} to ${receiverId}: ${content}`);
      } catch (error) {
        console.error("Error sending message:", error);
        socket.emit("error", { error: "Failed to send message" });
      }
    });

    socket.on("markMessagesAsSeen", async ({ senderId }) => {
      try {
        const receiverId = socket.userId;
        const messages = await Message.find({
          sender: senderId,
          receiver: receiverId,
          seen: false,
        });

        for (const message of messages) {
          message.seen = true;
          message.seenAt = new Date();
          await message.save();
          io.to(senderId).emit("messageSeen", {
            messageId: message._id,
            seenAt: message.seenAt,
          });
        }
      } catch (error) {
        console.error("Error marking messages as seen:", error);
        socket.emit("error", { error: "Failed to mark messages as seen" });
      }
    });

    socket.on("disconnect", () => {
      console.log(`User disconnected: ${socket.userId} (Socket ID: ${socket.id})`);
    });
  });
};

const getChatHistory = async (req, res) => {
  const { otherUserId } = req.params;
  const token = req.headers.authorization?.split(" ")[1];

  try {
    if (!token) {
      return res.status(401).json({ success: false, message: "Token required" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.id;

    const user = await User.findById(userId).select('friends');
    if (!user.friends.includes(otherUserId)) {
      return res.status(403).json({ success: false, message: "You can only view chat history with friends" });
    }

    const messages = await Message.find({
      $or: [
        { sender: userId, receiver: otherUserId },
        { sender: otherUserId, receiver: userId },
      ],
    }).sort({ timestamp: 1 });

    res.json({ success: true, messages });
  } catch (error) {
    console.error("Error fetching messages:", error);
    res.status(500).json({ success: false, message: "Error fetching messages", error: error.message });
  }
};

module.exports = { setupMessaging, getChatHistory };