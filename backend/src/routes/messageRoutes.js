const express = require('express');
const router = express.Router();
const { getChatHistory } = require('../controllers/messageController');

// Route to fetch chat history
router.get('/messages/:otherUserId', getChatHistory);

module.exports = router;