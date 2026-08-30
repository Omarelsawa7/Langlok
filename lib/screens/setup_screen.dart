import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/library_controller.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final isLoading = library.status == LibraryStatus.loading;
    final hasError = library.status == LibraryStatus.error;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.video_library_outlined, size: 72, color: Colors.white70),
                const SizedBox(height: 24),
                const Text(
                  'LangTok',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pick a folder of local video files (MKV, MP4, AVI, WEBM, MOV) '
                  'to start learning with your own content.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                ),
                const SizedBox(height: 32),
                if (isLoading)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => library.pickStudyFolder(),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Study Folder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (hasError && library.errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    library.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
