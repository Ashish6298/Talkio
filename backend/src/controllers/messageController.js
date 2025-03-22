const jwt = require('jsonwebtoken');
const Message = require('../models/Message');

// Initialize Socket.IO messaging
const setupMessaging = (io) => {
  // Middleware to verify JWT for Socket.IO
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (!token) {
      return next(new Error("Authentication error: Token required"));
    }
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.id; // Attach userId to socket
      next();
    } catch (error) {
      next(new Error("Authentication error: Invalid token"));
    }
  });

  io.on("connection", (socket) => {
    console.log(`User connected: ${socket.userId} (Socket ID: ${socket.id})`);

    // Join user's own room
    socket.join(socket.userId);

    socket.on("sendMessage", async ({ receiverId, content }) => {
      try {
        const senderId = socket.userId;
        if (!receiverId || !content) {
          return socket.emit("error", { error: "Receiver ID and content are required" });
        }

        const message = new Message({
          sender: senderId,
          receiver: receiverId,
          content,
        });
        await message.save();

        // Emit to receiver
        io.to(receiverId).emit("receiveMessage", message);
        // Confirm to sender
        socket.emit("messageSent", message);

        console.log(`Message sent from ${senderId} to ${receiverId}: ${content}`);
      } catch (error) {
        console.error("Error sending message:", error);
        socket.emit("error", { error: "Failed to send message" });
      }
    });

    socket.on("disconnect", () => {
      console.log(`User disconnected: ${socket.userId} (Socket ID: ${socket.id})`);
    });
  });
};

// Fetch chat history
const getChatHistory = async (req, res) => {
  const { otherUserId } = req.params;
  const token = req.headers.authorization?.split(" ")[1]; // Expecting "Bearer <token>"

  try {
    if (!token) {
      return res.status(401).json({ success: false, message: "Token required" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.id;

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