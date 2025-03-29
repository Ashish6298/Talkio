//userRoutes.js

const express = require('express');
const router = express.Router();
const { getUsers,getProfile } = require('../controllers/userController');// These routes are now handled directly in server.js to pass io
router.get('/users', getUsers);
router.get('/profile', getProfile);
module.exports = router;