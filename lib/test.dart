import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/services/user_services.dart';

class Test extends StatefulWidget {
  const Test({super.key});

  @override
  State<Test> createState() => _TestState();
}

class _TestState extends State<Test> {
  TextEditingController _titleController = TextEditingController();
  TextEditingController _linkController = TextEditingController();
  final UserServices _userServices = UserServices();
  List<String> assignedCaregivers = [];

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _userServices.getCaregiverStream(), // Fetch caregivers dynamically
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error loading caregivers"));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text("No caregivers available"));
            }

            List<Map<String, dynamic>> caregivers = snapshot.data!;

            return StatefulBuilder(
              builder: (context, setState) {
                return Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Assign Caregivers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: caregivers.length,
                          itemBuilder: (context, index) {
                            String caregiverId = caregivers[index]["id"];
                            String caregiverName = caregivers[index]["name"];
                            bool isAdded = assignedCaregivers.contains(caregiverId);

                            return ListTile(
                              title: Text(caregiverName),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    if (isAdded) {
                                      assignedCaregivers.remove(caregiverId);
                                    } else {
                                      assignedCaregivers.add(caregiverId);
                                    }
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAdded ? Colors.green : Colors.blue,
                                ),
                                child: Text(isAdded ? "Added" : "Add"),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _assignVideoToFirestore() async {
    String videoId = DateTime.now().millisecondsSinceEpoch.toString();
    String videoTitle = _titleController.text;
    String videoUrl = _linkController.text;

    if (videoTitle.isEmpty || videoUrl.isEmpty || assignedCaregivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fill all details and select caregivers")));
      return;
    }

    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Store in `assigned_videos` collection
    await firestore.collection("assigned_videos").doc(videoId).set({
      "title": videoTitle,
      "videoUrl": videoUrl,
      "assignedCaregivers": assignedCaregivers,
    });

    // Store per caregiver in `caregiver_videos` collection
    for (String caregiverId in assignedCaregivers) {
      await firestore.collection("caregiver_videos").doc(caregiverId).collection("videos").doc(videoId).set({
        "title": videoTitle,
        "videoUrl": videoUrl,
        "progress": 0, // Initially 0% watched
        "completed": false
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Video assigned successfully!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Assign Video")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: "Video Title"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(labelText: "Video Link"),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showBottomSheet,
              icon: Icon(Icons.add),
              label: Text("Assign to Caregivers"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _assignVideoToFirestore,
              child: Text("Assign Video"),
            ),
          ],
        ),
      ),
    );
  }
}