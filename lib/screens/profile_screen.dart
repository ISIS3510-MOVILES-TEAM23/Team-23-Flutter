import 'dart:async';

import 'package:campus_marketplace/services/auth_service.dart';
import 'package:campus_marketplace/services/connectivity_service.dart';
import 'package:campus_marketplace/services/firestore_service.dart';
import 'package:campus_marketplace/services/hive_service.dart';
import 'package:campus_marketplace/services/profile_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../view_models/profile_view_model.dart';
import '../services/on_campus_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/majors.dart';
import '../widgets/product_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  List<Post> myProducts = [];
  bool isLoading = true;
  late ProfileViewModel _profileViewModel;

  // Campus status
  late OnCampusService _onCampusService;
  bool _isOnCampus = false;
  StreamSubscription<bool>? _campusSubscription;

  // Connectivity and sync services
  late ConnectivityService _connectivityService;
  late ProfileSyncService _profileSyncService;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('ProfileScreen initState called');
    _profileViewModel = ProfileViewModel();
    
    // Initialize services
    _onCampusService = OnCampusService(enableLogging: true);
    _connectivityService = ConnectivityService();
    _profileSyncService = ProfileSyncService(_connectivityService);
    
    debugPrint('OnCampusService created');
    _initializeCampusStatus();
    _initializeConnectivity();
    _loadUserData();
  }

  Future<void> _initializeCampusStatus() async {
    try {
      debugPrint('Initializing campus status...');
      final permissionStatus = await _onCampusService.ensurePermission();
      debugPrint('Permission status: $permissionStatus');
      if (permissionStatus == LocationPermissionStatus.granted) {
        debugPrint('Permission granted, getting initial status...');
        // Get initial status
        _isOnCampus = await _onCampusService.isOnCampus();
        debugPrint('Initial campus status: $_isOnCampus');
        setState(() {});

        // Listen for changes
        debugPrint('Setting up stream listener...');
        _campusSubscription = _onCampusService.watchOnCampus().listen((isOnCampus) {
          debugPrint('Campus status changed to: $isOnCampus');
          setState(() {
            _isOnCampus = isOnCampus;
          });
        });
        debugPrint('Stream listener set up');
      } else {
        debugPrint('Permission not granted: $permissionStatus');
        // Show a message to the user about enabling permissions
        if (permissionStatus == LocationPermissionStatus.deniedForever) {
          debugPrint('🚗Permission denied forever - user needs to go to settings');
          // You could show a dialog here asking user to go to settings
        } else if (permissionStatus == LocationPermissionStatus.denied) {
          debugPrint('Permission denied - will try to request again next time');
        } else if (permissionStatus == LocationPermissionStatus.serviceDisabled) {
          debugPrint('Location services are disabled - user needs to enable GPS');
        }
      }
    } catch (e, stackTrace) {
      // Handle error silently - campus status will remain false
      debugPrint('Failed to initialize campus status: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _initializeConnectivity() async {
    try {
      debugPrint('Initializing connectivity service...');
      
      // Check initial connectivity
      _isOnline = await _connectivityService.checkConnectivity();
      debugPrint('Initial connectivity status: $_isOnline');
      
      // Start monitoring connectivity changes
      _connectivityService.startMonitoring();
      _connectivitySubscription = _connectivityService.connectionStream.listen((isOnline) {
        debugPrint('Connectivity changed to: $isOnline');
        setState(() {
          _isOnline = isOnline;
        });
        
        // Show notification when connection restored
        if (isOnline && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection restored. Syncing profile changes...'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
      
      // Initialize profile sync service
      _profileSyncService.initialize();
      debugPrint('ProfileSyncService initialized');
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize connectivity: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadUserData() async {
    try {
      debugPrint('[ProfileScreen] 🔄 Loading user data...');
      final user = await FirestoreService.getCurrentUser();
      debugPrint('[ProfileScreen] 👤 User: ${user?.id} (${user?.name})');

      List<Post> products = [];
      if (user != null) {
        // Try to load from network first if online
        if (ConnectivityService().isConnected) {
          try {
            debugPrint('[ProfileScreen] 📦 Online - Fetching user posts from network...');
            products = await FirestoreService.getUserPosts(user.id);
            debugPrint('[ProfileScreen] ✅ Got ${products.length} products from network');

            // Cache the posts
            await CacheService().cacheUserPosts(
              user.id,
              products.map((p) => p.toJson()).toList(),
            );
            debugPrint('[ProfileScreen] 💾 Cached ${products.length} user posts');
          } catch (e) {
            debugPrint('[ProfileScreen] ❌ Network failed, trying cache: $e');
            // Fallback to cache
            final cached = await CacheService().getCachedUserPosts(user.id);
            if (cached != null) {
              products = cached.map((json) => Post.fromJson(json)).toList();
              debugPrint('[ProfileScreen] 📦 Loaded ${products.length} products from cache');
            }
          }
        } else {
          // Offline - load from cache
          debugPrint('[ProfileScreen] 📴 Offline - Loading from cache...');
          final cached = await CacheService().getCachedUserPosts(user.id);
          if (cached != null) {
            products = cached.map((json) => Post.fromJson(json)).toList();
            debugPrint('[ProfileScreen] ✅ Loaded ${products.length} products from cache');
          } else {
            debugPrint('[ProfileScreen] ⚠️ No cached user posts (open app online first)');
          }
        }
      } else {
        debugPrint('[ProfileScreen] ⚠️ No user found');
      }

      setState(() {
        currentUser = user;
        myProducts = products;
        isLoading = false;
      });
      debugPrint('[ProfileScreen] ✓ State updated: ${myProducts.length} products in myProducts');
    } catch (e) {
      debugPrint('[ProfileScreen] ❌ Error loading user data: $e');
      final currentUserId = AuthService().currentUser?.uid;
      
      // Try to load from cache first (optimistic UI)
      if (currentUserId != null) {
        final cachedUser = HiveService.getCachedUser(currentUserId);
        
        if (cachedUser != null) {
          setState(() {
            currentUser = cachedUser;
          });
          debugPrint('💾 Loaded user from cache: ${cachedUser.name}');
        }
      }

      // Then try to fetch from network if online
      if (_isOnline) {
        final user = await FirestoreService.getCurrentUser();
        List<Post> products = [];
        if (user != null) {
          products = await FirestoreService.getUserPosts(user.id);
          // Update cache
          await HiveService.cacheUser(user);
        }
        setState(() {
          currentUser = user;
          myProducts = products;
          isLoading = false;
        });
      } else {
        // Offline - use cached data
        setState(() {
          isLoading = false;
        });
        if (currentUser == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline - Unable to load profile'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Removed duplicate - using _signOut() instead

  Future<void> _updateProfile(
      String? name, String? email, String? password, String? major) async {
    if (currentUser == null) return;

    try {
      final updatedName = name ?? currentUser!.name;
      final updatedEmail = email ?? currentUser!.email;
      final updatedMajor = major ?? currentUser!.major;

      if (_isOnline) {
        // Online - update immediately
        await FirestoreService.updateUserProfile(
          userId: currentUser!.id,
          name: updatedName,
          email: updatedEmail,
          password: password,
          major: updatedMajor,
        );
        // Reload user data to get server state
        await _loadUserData();
      } else {
        // Offline - queue for sync and update cache (optimistic UI)
        await _profileSyncService.queueProfileUpdate(
          userId: currentUser!.id,
          name: updatedName,
          email: updatedEmail,
          major: updatedMajor ?? '',
        );
        
        // Update local state immediately (optimistic UI)
        setState(() {
          currentUser = User(
            id: currentUser!.id,
            name: updatedName,
            email: updatedEmail,
            major: updatedMajor,
            contactPreferences: currentUser!.contactPreferences,
            role: currentUser!.role,
            createdAt: currentUser!.createdAt,
            numberOfReviews: currentUser!.numberOfReviews,
            score: currentUser!.score,
          );
        });
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet
                  await _signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Sign out using AuthService
        await AuthService().signOut();

        // Navigate to login
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: currentUser?.name);
    final emailController = TextEditingController(text: currentUser?.email);
    final passwordController = TextEditingController();
    String? selectedMajor = currentUser?.major;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMajor,
                      decoration: InputDecoration(
                        labelText: 'Major / Carrera',
                        prefixIcon: const Icon(Icons.school),
                        hintText: 'Selecciona tu carrera',
                        helperText: selectedMajor == null ? 'Requerido' : null,
                        helperStyle: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      items: MAJORS.map((String major) {
                        return DropdownMenuItem<String>(
                          value: major,
                          child: Text(major),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedMajor = newValue;
                        });
                      },
                      isExpanded: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password (optional)',
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validar que se haya seleccionado una carrera
                    if (selectedMajor == null || selectedMajor!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Por favor selecciona tu carrera'),
                          backgroundColor: Colors.orange.shade700,
                        ),
                      );
                      return;
                    }
                    
                    // Validar que el nombre no esté vacío
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('El nombre no puede estar vacío'),
                          backgroundColor: Colors.orange.shade700,
                        ),
                      );
                      return;
                    }
                    
                    // Save changes
                    _updateProfile(
                      nameController.text,
                      emailController.text,
                      passwordController.text.isNotEmpty
                          ? passwordController.text
                          : null,
                      selectedMajor,
                    ).then((_) {
                      Navigator.pop(context);
                      
                      // Show appropriate message based on connectivity
                      final message = _isOnline
                          ? 'Profile updated successfully'
                          : 'Profile changes saved. Will sync when online.';
                      final backgroundColor = _isOnline
                          ? AppColors.success
                          : Colors.orange;
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: backgroundColor,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }).catchError((e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update profile: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _campusSubscription?.cancel();
    _onCampusService.dispose();
    _profileViewModel.dispose();
    _connectivitySubscription?.cancel();
    _connectivityService.dispose();
    _profileSyncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsMenu(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offline indicator banner
            if (!_isOnline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Offline - Changes will sync when online',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_profileSyncService.hasPendingUpdates())
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_profileSyncService.getPendingCount()} pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            
            const SizedBox(height: 30),

            // Profile Photo, Name and Email - Centered
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                    child: Text(
                      (currentUser?.name.isNotEmpty == true)
                          ? currentUser!.name.substring(0, 2).toUpperCase()
                          : 'UN',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentUser?.name ?? 'User Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Campus status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOnCampus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isOnCampus ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: _isOnCampus ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnCampus ? 'On Campus' : 'Off Campus',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _isOnCampus ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentUser?.email ?? 'email@university.edu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textSecondary.withOpacity(0.8),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (currentUser?.major != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.school,
                            size: 16,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentUser!.major!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _showEditProfileDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Agrega tu carrera en Editar Perfil',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.orange.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Edit Profile Button - Full Width
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Sales Button - Full Width
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/profile/sales');
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: const Text(
                    'Sales',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Drafts Button - Full Width (Scenario 8)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push('/profile/drafts');
                  },
                  icon: const Icon(Icons.drafts_outlined, size: 20),
                  label: const Text(
                    'Drafts',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // My Products Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'My Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Products Grid
            if (myProducts.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No products posted yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: myProducts.length,
                itemBuilder: (context, index) {
                  final product = myProducts[index];
                  return ProductCard(
                    product: product,
                    onTap: () {
                      context.go('/home/product/${product.id}');
                    },
                  );
                },
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}