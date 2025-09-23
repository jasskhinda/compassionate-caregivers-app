import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/services/category_services.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import '../../../../../component/other/basic_button.dart';
import '../../../../../component/other/not_found_dialog.dart';
import '../../../../../utils/app_utils/AppUtils.dart';

class SubcategoryScreen extends StatefulWidget {
  const SubcategoryScreen({super.key});

  @override
  State<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends State<SubcategoryScreen> {

  // User info
  String? _role;

  // Instance
  final firestore = CategoryServices();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Text Editing controller
  late TextEditingController _controller = TextEditingController();

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
        });
      } else {
        debugPrint("No such document!");
      }
    } catch (e) {
      debugPrint("Error fetching document: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _getUserInfo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    final categoryName = args['category'] ?? 'Default Video Title';

    return Scaffold(
      bottomNavigationBar: (_role == 'Admin' || _role == 'Staff') ? Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BasicTextButton(
            width: AppUtils.getScreenSize(context).width >= 600 ? AppUtils.getScreenSize(context).width * 0.3 : AppUtils.getScreenSize(context).width * 0.7,
            text: 'Create Subcategory',
            buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
            textColor: Colors.white,
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Create Subcategory"),
                  content: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: "Subcategory Name"),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        firestore.createSubcategory(categoryName, _controller.text.trim());
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

          const SizedBox(height: 20)
        ],
      ) : const SizedBox.shrink(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SettingsAppBar(title: categoryName.toString()),

          SliverToBoxAdapter(
              child: Center(
                  child: SizedBox(
                      width: AppUtils.getScreenSize(context).width >= 600
                          ? AppUtils.getScreenSize(context).width * 0.45
                          : double.infinity,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 10),

                                // if (_isLoading)
                                //   const Center(child: CircularProgressIndicator()),

                                _subcategoryList(categoryName),

                                const SizedBox(height: 90)
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

  Widget _subcategoryList(String categoryName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryName)
          .collection('subcategories')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: NotFoundDialog(
              title: 'No Sub Categories Found',
              description: 'Try adding some categories to get started!',
            ),
          );
        }

        final subcategories = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subcategories.length,
          itemBuilder: (context, index) {
            final subcategoryDoc = subcategories[index];
            final subcategoryName = subcategoryDoc.id;

            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                tileColor: AppUtils.getColorScheme(context).secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(subcategoryName),
                trailing: _role != 'Caregiver' ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final videoCollectionRef = FirebaseFirestore.instance
                        .collection('categories')
                        .doc(categoryName)
                        .collection('subcategories')
                        .doc(subcategoryName)
                        .collection('videos');

                    final videoDocs = await videoCollectionRef.get();

                    if (videoDocs.docs.isNotEmpty) {
                      // Show warning dialog
                      if (!context.mounted) return;
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('Cannot Delete'),
                          content: const Text(
                            'Please delete all the videos associated with this category first.',
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
                        content: Text('Are you sure you want to delete "$subcategoryName"?'),
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
                            .collection('subcategories')
                            .doc(subcategoryName)
                            .delete();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$subcategoryName deleted successfully')),
                        );
                      } catch (e) {
                        print('Error deleting subcategory: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete $subcategoryName')),
                        );
                      }
                    }
                  },
                ) : null,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.subcategoryVideoScreen,
                    arguments: {
                      'categoryName': categoryName,
                      'subcategoryName': subcategoryName,
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