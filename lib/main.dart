

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try to initialize Firebase, but continue without it if it fails
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization failed: $e');
    print('App will run in offline mode only');
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        title: 'Grocery Reminder',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthProvider extends ChangeNotifier {
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  User? _user;
  bool _firebaseAvailable = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get firebaseAvailable => _firebaseAvailable;

  AuthProvider() {
    _initializeFirebase();
  }

  void _initializeFirebase() {
    try {
      _auth = FirebaseAuth.instance;
      _googleSignIn = GoogleSignIn();
      _firebaseAvailable = true;
      
      _auth!.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      print('Firebase not available: $e');
      _firebaseAvailable = false;
    }
  }

  Future<bool> signInWithGoogle() async {
    if (!_firebaseAvailable) return false;
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth!.signInWithCredential(credential);
      return true;
    } catch (e) {
      print('Error signing in: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (!_firebaseAvailable) return;
    
    try {
      await _googleSignIn!.signOut();
      await _auth!.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // If Firebase is not available, go directly to home screen
        if (!authProvider.firebaseAvailable) {
          return HomeScreen();
        }
        
        if (authProvider.isLoggedIn) {
          return HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[300]!, Colors.green[600]!],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'Grocery Reminder',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Share shopping lists with your family',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 50),
              ElevatedButton.icon(
                onPressed: () async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  if (!authProvider.firebaseAvailable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Google Sign-in not available. Please set up Firebase.')),
                    );
                    return;
                  }
                  
                  final success = await authProvider.signInWithGoogle();
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to sign in')),
                    );
                  }
                },
                icon: Icon(Icons.login),
                label: Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green[600],
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  );
                },
                child: Text(
                  'Continue without login',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Grocery Groups'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          if (authProvider.isLoggedIn)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  authProvider.signOut();
                }
              },
            ),
        ],
      ),
      body: authProvider.isLoggedIn && authProvider.firebaseAvailable ? GroupsList() : LocalGroceryList(),
      floatingActionButton: authProvider.isLoggedIn && authProvider.firebaseAvailable
          ? FloatingActionButton(
              onPressed: () => _showCreateGroupDialog(context),
              child: Icon(Icons.add),
              backgroundColor: Colors.green[600],
            )
          : null,
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New Group'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Group name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _createGroup(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup(String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('groups').add({
          'name': name,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'members': [user.email],
          'items': [],
        });
      }
    } catch (e) {
      print('Error creating group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group')),
      );
    }
  }
}

class GroupsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: user?.email)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_add, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No groups yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Create your first group to start sharing lists',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final group = snapshot.data!.docs[index];
            final data = group.data() as Map<String, dynamic>;
            
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Icon(Icons.group, color: Colors.green[600]),
                ),
                title: Text(
                  data['name'] ?? 'Unnamed Group',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${data['members']?.length ?? 0} members'),
                trailing: Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDetailScreen(
                        groupId: group.id,
                        groupName: data['name'] ?? 'Unnamed Group',
                        isCreator: data['createdBy'] == user?.uid,
                      ),
                    ),
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

class LocalGroceryList extends StatefulWidget {
  @override
  _LocalGroceryListState createState() => _LocalGroceryListState();
}

class _LocalGroceryListState extends State<LocalGroceryList> {
  List<GroceryItem> items = [];
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final pendingItems = items.where((item) => !item.isCompleted).toList();
    final completedItems = items.where((item) => item.isCompleted).toList();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Add grocery item...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _addItem,
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _addItem(controller.text),
                    child: Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: Colors.green[600],
                    tabs: [
                      Tab(text: 'To Buy (${pendingItems.length})'),
                      Tab(text: 'Bought (${completedItems.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildItemsList(pendingItems, false),
                        _buildItemsList(completedItems, true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<GroceryItem> items, bool isCompleted) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isCompleted ? 'No items bought yet' : 'No items to buy',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: CheckboxListTile(
            title: Text(
              item.name,
              style: TextStyle(
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                color: item.isCompleted ? Colors.grey : null,
              ),
            ),
            value: item.isCompleted,
            onChanged: (value) {
              setState(() {
                item.isCompleted = value ?? false;
              });
            },
            secondary: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  this.items.remove(item);
                });
              },
            ),
          ),
        );
      },
    );
  }

  void _addItem(String name) {
    if (name.isNotEmpty) {
      setState(() {
        items.add(GroceryItem(name: name));
        controller.clear();
      });
    }
  }
}

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isCreator;

  GroupDetailScreen({
    required this.groupId,
    required this.groupName,
    required this.isCreator,
  });

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          if (widget.isCreator)
            IconButton(
              icon: Icon(Icons.person_add),
              onPressed: () => _showAddMemberDialog(context),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return Center(child: Text('Group not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final items = (data['items'] as List<dynamic>?)
              ?.map((item) => GroceryItem.fromMap(item))
              .toList() ?? [];

          final pendingItems = items.where((item) => !item.isCompleted).toList();
          final completedItems = items.where((item) => item.isCompleted).toList();

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: 'Add grocery item...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: _addItem,
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => _addItem(controller.text),
                          child: Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: Colors.green[600],
                          tabs: [
                            Tab(text: 'To Buy (${pendingItems.length})'),
                            Tab(text: 'Bought (${completedItems.length})'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildItemsList(pendingItems, false),
                              _buildItemsList(completedItems, true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemsList(List<GroceryItem> items, bool isCompleted) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isCompleted ? 'No items bought yet' : 'No items to buy',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: CheckboxListTile(
            title: Text(
              item.name,
              style: TextStyle(
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                color: item.isCompleted ? Colors.grey : null,
              ),
            ),
            subtitle: item.addedBy != null ? Text('Added by ${item.addedBy}') : null,
            value: item.isCompleted,
            onChanged: (value) => _toggleItem(item.id, value ?? false),
            secondary: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteItem(item.id),
            ),
          ),
        );
      },
    );
  }

  void _addItem(String name) async {
    if (name.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      final newItem = GroceryItem(
        name: name,
        addedBy: user?.email?.split('@')[0],
      );

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'items': FieldValue.arrayUnion([newItem.toMap()]),
      });

      controller.clear();
    }
  }

  void _toggleItem(String itemId, bool isCompleted) async {
    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();
    
    final data = doc.data() as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((item) => GroceryItem.fromMap(item))
        .toList();

    final itemIndex = items.indexWhere((item) => item.id == itemId);
    if (itemIndex != -1) {
      items[itemIndex].isCompleted = isCompleted;
      
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'items': items.map((item) => item.toMap()).toList(),
      });
    }
  }

  void _deleteItem(String itemId) async {
    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();
    
    final data = doc.data() as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((item) => GroceryItem.fromMap(item))
        .toList();

    items.removeWhere((item) => item.id == itemId);
    
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'items': items.map((item) => item.toMap()).toList(),
    });
  }

  void _showAddMemberDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Member'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter email address',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _addMember(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMember(String email) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'members': FieldValue.arrayUnion([email]),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Member added successfully')),
    );
  }
}

class GroceryItem {
  final String id;
  final String name;
  bool isCompleted;
  final String? addedBy;
  final DateTime createdAt;

  GroceryItem({
    required this.name,
    this.isCompleted = false,
    this.addedBy,
    String? id,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isCompleted': isCompleted,
      'addedBy': addedBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static GroceryItem fromMap(Map<String, dynamic> map) {
    return GroceryItem(
      id: map['id'],
      name: map['name'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      addedBy: map['addedBy'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}