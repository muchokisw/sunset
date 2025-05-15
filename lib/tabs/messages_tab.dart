import 'package:flutter/material.dart';

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'No messages yet!',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}