
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

    socket.on("sendMessage", async ({ receiverId, content, isVoice, voiceDuration, voiceData, voiceId, isImage, imageData, imageId }) => {
      try {
        const senderId = socket.userId;
        if (!receiverId || !content) {
          return socket.emit("error", { error: "Receiver ID and content are required" });
        }
        if (isVoice && !voiceId) {
          return socket.emit("error", { error: "Voice ID is required for voice messages" });
        }
        if (isImage && !imageId) {
          return socket.emit("error", { error: "Image ID is required for image messages" });
        }

        const sender = await User.findById(senderId).select('friends');
        if (!sender.friends.includes(receiverId)) {
          return socket.emit("error", { error: "You can only message friends" });
        }

        const message = new Message({
          sender: senderId,
          receiver: receiverId,
          content,
          isVoice: isVoice || false,
          voiceDuration: isVoice ? voiceDuration : null,
          voiceId: isVoice ? voiceId : null,
          isImage: isImage || false,
          imageId: isImage ? imageId : null,
          seen: false,
        });
        await message.save();

        io.to(receiverId).emit("receiveMessage", message);
        socket.emit("messageSent", message);

        if (isVoice && voiceData) {
          io.to(receiverId).emit("voiceNoteData", {
            messageId: message._id,
            voiceId: message.voiceId,
            voiceData,
            voiceDuration,
          });
        }

        if (isImage && imageData) {
          io.to(receiverId).emit("imageData", {
            messageId: message._id,
            imageId: message.imageId,
            imageData,
          });
        }

        message.deliveredAt = new Date();
        await message.save();
        io.to(senderId).emit("messageDelivered", { messageId: message._id, deliveredAt: message.deliveredAt });

        console.log(`Message sent from ${senderId} to ${receiverId}: ${isVoice ? `Voice (${voiceDuration}s)` : isImage ? `Image (ID: ${imageId})` : content}`);
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

    // New event for adding reactions
    socket.on("addReaction", async ({ messageId, emoji }) => {
      try {
        const userId = socket.userId;
        const message = await Message.findById(messageId);

        if (!message) {
          return socket.emit("error", { error: "Message not found" });
        }

        // Check if the user is either the sender or receiver of the message
        if (message.sender.toString() !== userId && message.receiver.toString() !== userId) {
          return socket.emit("error", { error: "You can only react to messages in your chats" });
        }

        // Add the reaction to the message
        message.reactions.push({
          emoji,
          userId,
          timestamp: new Date(),
        });
        await message.save();

        // Emit the updated message with reactions to both sender and receiver
        io.to(message.sender.toString()).emit("reactionAdded", {
          messageId: message._id,
          emoji,
          userId,
          timestamp: new Date(),
        });
        io.to(message.receiver.toString()).emit("reactionAdded", {
          messageId: message._id,
          emoji,
          userId,
          timestamp: new Date(),
        });

        console.log(`Reaction added by ${userId} to message ${messageId}: ${emoji}`);
      } catch (error) {
        console.error("Error adding reaction:", error);
        socket.emit("error", { error: "Failed to add reaction" });
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
    })
      .populate('reactions.userId', 'username') // Populate the userId in reactions to get the username
      .sort({ timestamp: 1 });

    res.json({ success: true, messages });
  } catch (error) {
    console.error("Error fetching messages:", error);
    res.status(500).json({ success: false, message: "Error fetching messages", error: error.message });
  }
};

module.exports = { setupMessaging, getChatHistory };