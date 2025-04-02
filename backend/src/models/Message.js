
const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  receiver: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  seen: { type: Boolean, default: false },
  deliveredAt: { type: Date }, // New field for delivery timestamp
  seenAt: { type: Date }, // New field for seen timestamp
  isVoice: { type: Boolean, default: false },
  voiceDuration: { type: Number,default:null }, // Duration in seconds
  voiceId: {type: String,default: null},
  isImage: { type: Boolean, default: false }, // New field for images
  imageId: { type: String, default: null }, // New field for image ID
  reactions: [
    {
      emoji: { type: String, required: true }, // The emoji (e.g., "❤️")
      userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // Who reacted
      timestamp: { type: Date, default: Date.now }, // When the reaction was added
    },
  ],
  forwardedFrom: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Message', 
    default: null 
  }

});

module.exports = mongoose.model('Message', messageSchema);