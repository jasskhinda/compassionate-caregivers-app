import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/component/other/not_found_dialog.dart';
import 'package:caregiver/services/category_services.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import '../../../../component/appBar/main_app_bar.dart';
import '../../../../utils/app_utils/AppUtils.dart';
import 'package:provider/provider.dart';
import '../../../../theme/theme_provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final firestore = CategoryServices();
  late TextEditingController _controller = TextEditingController();

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;

  // User Info
  String? _role;

  // Get user video details
  Future<void> _getUserInfo() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_auth.currentUser!.uid.toString())
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          _role = data['role'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        debugPrint("No such document!");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint("Error fetching document: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          bottomNavigationBar: (_role == 'Admin' || _role == 'Staff') ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BasicTextButton(
                width: AppUtils.getScreenSize(context).width >= 600 ? AppUtils.getScreenSize(context).width * 0.3 : AppUtils.getScreenSize(context).width * 0.7,
                text: 'Create Category',
                buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                textColor: Colors.white,
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Create Category"),
                      content: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: "Category Name"),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            firestore.createCategory(_controller.text.trim());
                            Navigator.pop(context);
                            _controller.clear();
                          },
                          child: Text("Create", style: TextStyle(color: AppUtils.getColorScheme(context).tertiaryContainer)),
                        ),
                      ],
                    ),
                  );
                }
              ),
              SizedBox(height: AppUtils.getScreenSize(context).width >= 600 ? 20 : 100)
            ],
          ) : const SizedBox.shrink(),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
              const MainAppBar(title: 'Video Library'),

              SliverToBoxAdapter(
                child: Center(
                  child: SizedBox(
                    width: AppUtils.getScreenSize(context).width >= 600
                        ? AppUtils.getScreenSize(context).width * 0.45
                        : double.infinity,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),

                          if (_isLoading)
                            const Center(child: CircularProgressIndicator()),

                          _categoryList(),

                          const SizedBox(height: 120)
                        ]
                      )
                    )
                  )
                )
              )
            ]
          )
        );
      }
    );
  }

  Widget _categoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.getCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: NotFoundDialog(
              title: 'No Categories Found',
              description: 'Try adding some categories to get started!',
            ),
          );
        }

        final categories = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final categoryDoc = categories[index];
            final categoryName = categoryDoc.id;

            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                tileColor: AppUtils.getColorScheme(context).secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(categoryName),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final subcategoriesRef = FirebaseFirestore.instance
                        .collection('categories')
                        .doc(categoryName)
                        .collection('subcategories');

                    final subcategoryDocs = await subcategoriesRef.get();

                    if (subcategoryDocs.docs.isNotEmpty) {
                      if (!context.mounted) return;
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('Cannot Delete'),
                          content: const Text(
                            'Please delete all the subcategories under this category first.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    // Confirm delete
                    if (!context.mounted) return;

                    final confirmDelete = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Confirm Deletion'),
                        content: Text('Are you sure you want to delete "$categoryName"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirmDelete == true) {
                      try {
                        await FirebaseFirestore.instance
                            .collection('categories')
                            .doc(categoryName)
                            .delete();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$categoryName deleted successfully')),
                          );
                        }
                      } catch (e) {
                        print('Error deleting category: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete $categoryName')),
                          );
                        }
                      }
                    }
                  },
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.subcategoryScreen,
                    arguments: {
                      'category': categoryName,
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}