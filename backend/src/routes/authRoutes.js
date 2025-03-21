const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const User = require('../models/User');

// Nodemailer transporter configuration
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
  tls: { rejectUnauthorized: false },
});

// Global variables for OTP storage
let c_otp = null;
let otpEmail = null;

// Debug environment variables
console.log('EMAIL_USER:', process.env.EMAIL_USER);
console.log('EMAIL_PASS:', process.env.EMAIL_PASS ? '[HIDDEN]' : 'undefined');

// Verify transporter at startup
transporter.verify((error, success) => {
  if (error) {
    console.error('Transporter verification failed:', error);
  } else {
    console.log('Email transporter ready');
  }
});

// Send OTP Email function
const sendEmailOtp = async (req, res) => {
  try {
    const { email, username, password } = req.body;

    if (!email || !username || !password) {
      return res.status(400).json({
        success: false,
        message: "Username, email, and password are required",
      });
    }

    // Check for existing user
    const existingUser = await User.findOne({ $or: [{ username }, { email }] });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Username or email already registered',
      });
    }

    const otp = crypto.randomInt(100000, 999999).toString(); // Generate 6-digit OTP
    const hashedPassword = await bcrypt.hash(password, 10);

    // Store OTP and email globally
    c_otp = otp;
    otpEmail = email;

    // Save user with OTP (unverified)
    const user = new User({
      username,
      email,
      password: hashedPassword,
      otp,
      createdAt: Date.now(),
    });
    await user.save();

    // Set OTP expiration (5 minutes)
    setTimeout(async () => {
      c_otp = null;
      otpEmail = null;
      // Optionally clear OTP from DB after expiration
      await User.updateOne({ email }, { $unset: { otp: "" } });
    }, 300000); // 5 minutes

    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'ConvoFlow Registration OTP',
      text: `Your OTP for ConvoFlow registration is: ${otp}. It is valid for 5 minutes.`,
    };

    await transporter.sendMail(mailOptions);
    console.log('Email sent successfully');

    res.status(200).json({
      success: true,
      message: `OTP sent to ${email}`,
    });
  } catch (error) {
    console.error('Error in sendEmailOtp:', error);
    res.status(500).json({
      success: false,
      message: 'Error sending OTP',
      error: error.message,
    });
  }
};

// Routes
router.post('/register', sendEmailOtp);

router.post('/verify-otp', async (req, res) => {
  const { email, otp } = req.body;

  try {
    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Email and OTP are required',
      });
    }

    // Check if OTP matches and is valid
    if (otpEmail !== email || c_otp !== otp) {
      return res.status(400).json({
        success: false,
        message: 'Invalid OTP or email',
      });
    }

    const user = await User.findOne({ email });
    if (!user || !user.otp) {
      return res.status(404).json({
        success: false,
        message: 'No pending registration found or OTP expired',
      });
    }

    if (user.otp !== otp) {
      return res.status(400).json({
        success: false,
        message: 'Invalid OTP',
      });
    }

    // Clear OTP after successful verification
    user.otp = undefined;
    await user.save();

    // Clear global variables
    c_otp = null;
    otpEmail = null;

    res.status(201).json({
      success: true,
      message: 'Registration completed successfully',
    });
  } catch (error) {
    console.error('Error in /verify-otp:', error);
    res.status(500).json({
      success: false,
      message: 'Error verifying OTP',
      error: error.message,
    });
  }
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  try {
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: 'Username and password are required',
      });
    }

    const user = await User.findOne({ username });
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    // Ensure OTP is cleared before login (optional)
    if (user.otp) {
      return res.status(403).json({
        success: false,
        message: 'Please verify your email first',
      });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    res.json({
      success: true,
      message: 'Login successful',
      token,
    });
  } catch (error) {
    console.error('Error in /login:', error);
    res.status(500).json({
      success: false,
      message: 'Error during login',
      error: error.message,
    });
  }
});

module.exports = router;