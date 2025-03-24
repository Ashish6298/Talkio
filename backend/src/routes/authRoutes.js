//authRoutes.js

const express = require('express');
const router = express.Router();
const { sendEmailOtp, verifyOtp, login } = require('../controllers/authController');

// Routes
router.post('/register', sendEmailOtp);
router.post('/verify-otp', verifyOtp);
router.post('/login', login);

module.exports = router;