
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
});

module.exports = mongoose.model('Message', messageSchema);