const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  otp: { type: String },
  bio:{type:String},
  createdAt: { type: Date, default: Date.now },
  profilePic: { type: String },
  friends: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // List of friends
  sentRequests: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // Sent friend requests
  receivedRequests: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // Received friend requests
});

module.exports = mongoose.model('User', userSchema);