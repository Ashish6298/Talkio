const express = require('express');
const router = express.Router();
const { getUsers } = require('../controllers/userController');

// These routes are now handled directly in server.js to pass io
router.get('/users', getUsers);

module.exports = router;