import 'package:flutter/material.dart';

class UsernameInput extends StatelessWidget {
  final TextEditingController controller;
  

  const UsernameInput({
    super.key,
    required this.controller,
    
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter LeetCode Username',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Username',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  fillColor: Colors.grey.shade900,
                  filled: true,
                ),
                style: const TextStyle(color: Colors.white),
                
              ),
            ),
            const SizedBox(width: 8),
           
          ],
        ),
      ],
    );
  }
}