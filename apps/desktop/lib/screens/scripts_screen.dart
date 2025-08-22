// lib/screens/scripts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Script class and related providers
class Script {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Script({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  int get wordCount => content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

// Provider for managing scripts (in-memory for now)
class ScriptsNotifier extends StateNotifier<List<Script>> {
  ScriptsNotifier() : super([
    // Add a sample script
    Script(
      id: '1',
      title: 'Welcome Script',
      content: '''Welcome to TelePrompt Pro!

This is your professional teleprompter solution designed for content creators, presenters, and video professionals.

With TelePrompt Pro, you can:
• Create and manage unlimited scripts
• Control scrolling speed with precision
• Use mirror mode for physical teleprompters
• Customize fonts, colors, and display settings
• Record videos while reading your script

Let's start by exploring the features:

The teleprompter display shows your script in a clean, readable format. You can control the scrolling speed using the slider or keyboard shortcuts. Press Space to play or pause, use the up and down arrows to adjust speed, and press Home to reset to the beginning.

The reading guide helps you maintain your position while reading. You can adjust its position and color in the settings.

For longer scripts, the progress indicator at the bottom shows how far through the script you've scrolled.

This sample script contains enough text to test the scrolling functionality. Try adjusting the speed to find your comfortable reading pace. Most professional presenters read at about 150-160 words per minute, but you can adjust this based on your style and content.

Ready to create your own script? Click the "New Script" button to get started!''',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ]);

  void addScript(String title, String content) {
    final script = Script(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    state = [...state, script];
  }

  void updateScript(String id, String title, String content) {
    state = state.map((script) {
      if (script.id == id) {
        return Script(
          id: id,
          title: title,
          content: content,
          createdAt: script.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return script;
    }).toList();
  }

  void deleteScript(String id) {
    state = state.where((script) => script.id != id).toList();
  }
}

final scriptsProvider = StateNotifierProvider<ScriptsNotifier, List<Script>>(
  (ref) => ScriptsNotifier(),
);

final selectedScriptProvider = StateProvider<Script?>((ref) => null);

class ScriptsScreen extends ConsumerWidget {
  final TabController? tabController;
  
  const ScriptsScreen({
    super.key,
    this.tabController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptsProvider);
    
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'My Scripts',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showAddScriptDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('New Script'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scripts list
          Expanded(
            child: scripts.isEmpty
                ? _buildEmptyState(context, ref)
                : _buildScriptsList(scripts, context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, 
            size: 80, 
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No scripts yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text('Create your first script to get started'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddScriptDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create Script'),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptsList(List<Script> scripts, BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scripts.length,
      itemBuilder: (context, index) {
        final script = scripts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              script.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${script.wordCount} words • Updated ${_formatDate(script.updatedAt)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(selectedScriptProvider.notifier).state = script;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Selected "${script.title}" - Go to Teleprompter tab'),
                        action: SnackBarAction(
                          label: 'Go',
                          onPressed: () {
                            // Navigate to teleprompter
                            tabController?.animateTo(0);
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Use'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditScriptDialog(context, ref, script),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, script),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showAddScriptDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Script'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                ref.read(scriptsProvider.notifier).addScript(
                  titleController.text,
                  contentController.text,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditScriptDialog(BuildContext context, WidgetRef ref, Script script) {
    final titleController = TextEditingController(text: script.title);
    final contentController = TextEditingController(text: script.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Script'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(scriptsProvider.notifier).updateScript(
                script.id,
                titleController.text,
                contentController.text,
              );
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Script script) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Script?'),
        content: Text('Are you sure you want to delete "${script.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(scriptsProvider.notifier).deleteScript(script.id);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}