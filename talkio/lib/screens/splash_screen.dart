import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart'; // For text animation
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for fading the tagline
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Start the fade animation for the tagline after a delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      _animationController.forward();
    });

    // Navigate to LoginScreen after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E), // Dark blue-grey
              Color(0xFF16213E), // Slightly lighter blue-grey
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Talk-Io',
                    textStyle: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: Colors.cyanAccent,
                          blurRadius: 10,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    speed: const Duration(milliseconds: 100),
                  ),
                ],
                totalRepeatCount: 1,
                onFinished: () {
                  // Ensure the tagline animation starts after the typewriter effect
                  _animationController.forward();
                },
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  'Connecting the Future',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:animated_text_kit/animated_text_kit.dart'; // For text animation
// import 'login_screen.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   _SplashScreenState createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _rotationAnimation;
//   late Animation<double> _gradientAnimation;

//   @override
//   void initState() {
//     super.initState();
//     // Initialize animation controller for fading, scaling, rotating, and gradient
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 2500),
//     )..forward();

//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
//     );

//     _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack)),
//     );

//     _rotationAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     )..addListener(() {
//         if (_animationController.isCompleted) {
//           _animationController.repeat(reverse: true);
//         }
//       });

//     _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.linear),
//     );

//     // Navigate to LoginScreen after 5 seconds
//     Future.delayed(const Duration(seconds: 5), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const LoginScreen()),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: AnimatedBuilder(
//         animation: _gradientAnimation,
//         builder: (context, child) {
//           return Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [
//                   Color(0xFF1A1A2E).withOpacity(1 - _gradientAnimation.value),
//                   Color(0xFF16213E).withOpacity(_gradientAnimation.value),
//                 ],
//               ),
//             ),
//             child: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   AnimatedTextKit(
//                     animatedTexts: [
//                       ColorizeAnimatedText(
//                         'Talk-Io',
//                         textStyle: const TextStyle(
//                           fontSize: 48,
//                           fontWeight: FontWeight.bold,
//                           letterSpacing: 2.0,
//                         ),
//                         colors: [
//                           Colors.white,
//                           Colors.cyanAccent,
//                           Colors.blueAccent,
//                           Colors.white,
//                         ],
//                         speed: const Duration(milliseconds: 300),
//                       ),
//                     ],
//                     totalRepeatCount: 1,
//                     pause: const Duration(milliseconds: 500),
//                   ),
//                   const SizedBox(height: 20),
//                   AnimatedBuilder(
//                     animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _rotationAnimation]),
//                     builder: (context, child) {
//                       return Transform.rotate(
//                         angle: _rotationAnimation.value,
//                         child: Transform.scale(
//                           scale: _scaleAnimation.value,
//                           child: Opacity(
//                             opacity: _fadeAnimation.value,
//                             child: const Text(
//                               'Connecting the Future',
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 color: Colors.white70,
//                                 fontStyle: FontStyle.italic,
//                                 shadows: [
//                                   Shadow(
//                                     color: Colors.cyanAccent,
//                                     blurRadius: 5,
//                                     offset: Offset(0, 0),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }