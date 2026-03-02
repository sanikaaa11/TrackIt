import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;

  String? _userType;
  List<String> _selectedModules = [];

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: _currentStep == index ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentStep == index
                ? const Color(0xFF6FB1FC)
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildUserTypeStep() {
    final options = ["Student", "Professional", "Other"];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Let’s get to know you 👀",
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 30),
        ...options.map((type) {
          final selected = _userType == type;
          return GestureDetector(
            onTap: () {
              setState(() {
                _userType = type;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF6FB1FC),
                          Color(0xFFA18CD1),
                        ],
                      )
                    : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 16,
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildModulesStep() {
    final modules = ["Tasks", "Notes", "Expenses"];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "What do you want to track?",
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 30),
        ...modules.map((module) {
          final selected = _selectedModules.contains(module);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedModules.remove(module);
                } else {
                  _selectedModules.add(module);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF6FB1FC),
                          Color(0xFFA18CD1),
                        ],
                      )
                    : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Center(
                child: Text(
                  module,
                  style: TextStyle(
                    fontSize: 16,
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFinalStep() {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text(
        "Ready to stay organized?",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2C3E50),
        ),
      ),
      
      const SizedBox(height: 50),

      SizedBox(
        width: double.infinity,
        height: 65,
        child: ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboardingComplete', true);

            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const HomeScreen(),
              ),
            );
          },

          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            elevation: 5,
            backgroundColor: const Color(0xFF6FB1FC),
          ),
          child: const Text(
            "🚀 Start Tracking",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  );
}


  @override
Widget build(BuildContext context) {
  Widget content;

  if (_currentStep == 0) {
    content = _buildUserTypeStep();
  } else if (_currentStep == 1) {
    content = _buildModulesStep();
  } else {
    content = _buildFinalStep();
  }

  return Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [

            // Space from top
            const SizedBox(height: 25),

            // Back Arrow Row
            Align(
              alignment: Alignment.topLeft,
              child: _currentStep > 0
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      onPressed: _previousStep,
                    )
                  : const SizedBox(height: 38), // keeps height consistent
            ),

            const SizedBox(height: 15),

            // Progress Dots (Fixed position)
            _buildProgressDots(),

            const SizedBox(height: 40),

            // Animated Content Area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.2, 0),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slide,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  key: ValueKey(_currentStep),
                  width: double.infinity,
                  child: content,
                ),
              ),
            ),

            if (_currentStep < 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6FB1FC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Next",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),


            // Bottom spacing
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}


}
