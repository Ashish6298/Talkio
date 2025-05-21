
## Talkio - Your Ultimate Android Chat App 💬🚀

## 📌 Overview
Talkio is a vibrant Android chat app built with Flutter, powered by a robust Node.js backend with MongoDB and Socket.IO. It brings real-time messaging, friend requests, and user profiles to your fingertips, making every conversation a vibe. Whether you’re catching up with friends or making new connections, Talkio delivers a seamless, secure, and fun chatting experience on your Android device. Get ready to connect, chat, and vibe! 🎉  

## ✨ Features
✅ Real-Time Messaging: Chat instantly with friends using Socket.IO-powered messages.✅ Friend Requests: Send and accept friend requests to build your network.✅ User Profiles: Update your bio and personalize your vibe.✅ Secure Authentication: Sign up and log in with confidence, backed by secure sessions.✅ Media Sharing: Share images and files effortlessly in chats.✅ Sleek Flutter UI: Enjoy a smooth, modern interface for a top-tier chat experience.✅ Completely Free: Connect with friends without spending a dime!  


## 🚀 How to Use
1️⃣ Sign Up or Log In: Create an account or sign in to start your Talkio journey.2️⃣ Add Friends: Send friend requests to connect with others.3️⃣ Start Chatting: Open a chat and send real-time messages or share media.4️⃣ Update Your Profile: Customize your bio to show off your personality.5️⃣ Stay Connected: Accept friend requests and keep the conversation flowing.  

## 🔧 Installation Guide

Clone the Talkio repository to your local machine. Navigate to the project folder and install Flutter dependencies. Run the app to launch it on your Android emulator or device.  
```
git clone https://github.com/Ashish6298/Talkio
```
    cd Talkio
```
flutter pub get
```
    flutter run

## Backend Setup
Clone the backend repository and install Node.js dependencies. Create a .env file with your MongoDB URI and session secret. Start the Node.js server, and use your machine’s IP address to connect from your Flutter app on an Android emulator or device.  
```
git clone https://github.com/Ashish6298/Talkio
```
    cd backend
```
npm install
```
    node server.js

### 🎤 API Features for Flutter Devs
Talkio’s Node.js backend powers your Flutter app with a suite of RESTful APIs and real-time Socket.IO events:💬 Real-Time Messaging: Send and receive messages instantly with Socket.IO for a seamless chat experience.🤝 Friend Requests: Allow users to send and accept friend requests to grow their network.📝 User Profiles: Let users update their bio and manage their account details.🔒 Authentication: Provide secure sign-up and login with session-based authentication.📸 Media Uploads: Enable users to share images and files in chats, stored securely on the server.🛡️ Health Check: Monitor server status with a simple health endpoint.The backend handles errors gracefully, returning clear messages for invalid inputs or server issues, ensuring your Flutter app stays smooth and user-friendly.  

### 💡 Pro Tips & Notes
Messages are delivered in real-time using Socket.IO, making chats feel instant and lively. User sessions are securely managed with MongoDB and last for five minutes, perfect for quick chats. Store media files in the server’s uploads folder for easy sharing. Ensure your MongoDB URI and session secret are set in the .env file for a stable connection. For your Flutter app, consider using packages like socket_io_client for real-time messaging and dio for API calls. When testing on Android, connect to the backend using your machine’s IP address. 😎  

### 🧰 Tech Stack
The frontend shines with Flutter’s Dart-based framework for a stunning Android UI. The backend rocks with Express.js for speed, MongoDB for secure data storage, and Socket.IO for real-time messaging. The dotenv package keeps secrets safe, and CORS support ensures your Flutter app connects effortlessly.  

### Turn up the conversation and let Talkio rock your chat world! 💬
