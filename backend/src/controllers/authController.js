const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('cloudinary').v2;
const User = require('../models/User');

// Cloudinary configuration
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

// Multer configuration for Cloudinary
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'profile_pics',
    allowed_formats: ['jpg', 'png', 'jpeg'],
    transformation: [{ width: 500, height: 500, crop: 'limit' }]
  }
});

const upload = multer({ storage: storage });

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
console.log('CLOUDINARY_CLOUD_NAME:', process.env.CLOUDINARY_CLOUD_NAME);
console.log('CLOUDINARY_API_KEY:', process.env.CLOUDINARY_API_KEY ? '[HIDDEN]' : 'undefined');

// Verify transporter at startup
transporter.verify((error, success) => {
  if (error) {
    console.error('Transporter verification failed:', error);
  } else {
    console.log('Email transporter ready');
  }
});

// Send OTP Email function with profile picture
const sendEmailOtp = [
  upload.single('profilePic'), // Middleware to handle single file upload
  async (req, res) => {
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
        // Delete uploaded file from Cloudinary if user already exists
        if (req.file) {
          await cloudinary.uploader.destroy(req.file.filename);
        }
        return res.status(400).json({
          success: false,
          message: 'Username or email already registered',
        });
      }

      const otp = crypto.randomInt(100000, 999999).toString();
      const hashedPassword = await bcrypt.hash(password, 10);
      
      // Get profile picture URL from Cloudinary if uploaded
      const profilePicUrl = req.file ? req.file.path : null;
      console.log('Profile picture uploaded for', username, ':', profilePicUrl); // Debug log

      // Store OTP and email globally
      c_otp = otp;
      otpEmail = email;

      // Save user with OTP and profile picture (unverified)
      const user = new User({
        username,
        email,
        password: hashedPassword,
        profilePic: profilePicUrl,
        otp,
        createdAt: Date.now(),
      });
      await user.save();

      // Set OTP expiration (5 minutes)
      setTimeout(async () => {
        c_otp = null;
        otpEmail = null;
        await User.updateOne({ email }, { $unset: { otp: "" } });
      }, 300000);

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
        profilePicUrl: profilePicUrl
      });
    } catch (error) {
      // Delete uploaded file from Cloudinary if error occurs
      if (req.file) {
        await cloudinary.uploader.destroy(req.file.filename);
      }
      console.error('Error in sendEmailOtp:', error);
      res.status(500).json({
        success: false,
        message: 'Error sending OTP',
        error: error.message,
      });
    }
  }
];

// Verify OTP function (unchanged)
const verifyOtp = async (req, res) => {
  const { email, otp } = req.body;

  try {
    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Email and OTP are required',
      });
    }

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

    user.otp = undefined;
    await user.save();

    c_otp = null;
    otpEmail = null;

    res.status(201).json({
      success: true,
      message: 'Registration completed successfully',
      profilePic: user.profilePic
    });
  } catch (error) {
    console.error('Error in verifyOtp:', error);
    res.status(500).json({
      success: false,
      message: 'Error verifying OTP',
      error: error.message,
    });
  }
};

// Login function (unchanged except returning profilePic)
const login = async (req, res) => {
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
      profilePic: user.profilePic
    });
  } catch (error) {
    console.error('Error in login:', error);
    res.status(500).json({
      success: false,
      message: 'Error during login',
      error: error.message,
    });
  }
};

module.exports = { sendEmailOtp, verifyOtp, login };