import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (userId == null) {
      return const Center(
        child: Text('Please log in to view notifications.'),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Limit width to 800
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0), // Add more space at the top
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Center the title horizontally
              children: [
                // Title
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black, // Text color based on theme
                      ),
                  textAlign: TextAlign.center, // Center the text
                ),
                const SizedBox(height: 16.0), // Add spacing below the title
                // Notifications Container
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[200], // Background color for the container
                      borderRadius: BorderRadius.circular(16), // Rounded edges
                    ),
                    padding: const EdgeInsets.all(8.0), // Add padding inside the container
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('notifications')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('No notifications yet!'));
                        }

                        final notifications = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notificationDoc = notifications[index];
                            final notification = notificationDoc.data() as Map<String, dynamic>;

                            // Determine background color based on read status
                            final backgroundColor = notification['read'] == true
                                ? (isDarkMode ? Colors.grey[800] : Colors.white) // Read notification
                                : (isDarkMode ? Colors.black : Colors.grey[300]); // Unread notification

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: backgroundColor, // Background color based on read status
                                  borderRadius: BorderRadius.circular(12.0), // Rounded corners
                                ),
                                child: ListTile(
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Notification Type
                                      Text(
                                        notification['notificationType'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600], // Subtitle color
                                        ),
                                      ),
                                      const SizedBox(height: 4.0), // Spacing between type and message
                                      // Notification Message
                                      Text(
                                        notification['notification'] ?? 'No details available',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : Colors.black, // Text color based on theme
                                        ),
                                        maxLines: 1, // Limit to one line
                                        overflow: TextOverflow.ellipsis, // Add ellipsis if text overflows
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    // Mark the notification as read
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(userId)
                                        .collection('notifications')
                                        .doc(notificationDoc.id)
                                        .update({'read': true});

                                    // Show the notification details in a dialog
                                    // ignore: use_build_context_synchronously
                                    _showNotificationDialog(context, notification);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationDialog(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(notification['notificationType'] ?? 'Notification'),
          content: Text(notification['notification'] ?? 'No details available'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}