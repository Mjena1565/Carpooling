// screens/welcome_screen.dart
import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import 'signup_page.dart';
import 'login_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final List<String> features = [
    "Optimized Office Commutes",
    "Reduced Travel Time",
    "Eco-Friendly Routing",
    "Smart Matchmaking",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("JLR Carpool"),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Icon(Icons.directions_car_filled,
                    size: 100,
                    color: Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 20),
              const Text(
                "Smarter Commutes, Greener Future.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Powered by JLR Innovation",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const Text(
                "Key Benefits",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: features.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline, color: Theme.of(context).primaryColor),
                        title: Text(features[index]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: "Login",
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const LoginAuthScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: "Sign Up",
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const SignupScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}