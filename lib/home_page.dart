// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // Import this if not already present

// Import updated screen names
import 'profile_screen.dart';
import 'welcome_screen.dart';
import 'ride_companion_input_screen.dart';
import 'ride_driver_input_screen.dart';
import 'change_password_screen.dart';

// Get a named instance of Firestore
final FirebaseFirestore carpoolingFirestore = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: 'carpool',
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String _userDisplayName = 'Guest';
  String _userEmpId = 'Loading...';
  Map<String, dynamic> _userStats = {
    'rides_offered': 0,
    'rides_taken': 0,
    'co2_saved': 0.0,
    'rating': 0.0,
  };
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('DEBUG: HomeScreen initState called. Fetching user profile and stats...');
    _fetchUserProfileAndStats(); // Initial fetch upon screen creation
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    print('DEBUG: HomeScreen dispose called. Disposing TabController...');
    _tabController.dispose();
    super.dispose();
  }

  // A single method to fetch user profile and stats
  Future<void> _fetchUserProfileAndStats() async {
    print('DEBUG: Fetching user profile and stats...');
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = carpoolingFirestore.collection('users').doc(user.uid);
      try {
        final docSnapshot = await docRef.get();
        if (docSnapshot.exists && docSnapshot.data() != null) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          setState(() {
            _userDisplayName = data['name'] ?? user.email?.split('@')[0] ?? 'JLR User';
            _userEmpId = data['employeeId'] ?? 'N/A';
            _userStats = {
              'rides_offered': data['rides_offered'] ?? 0,
              'rides_taken': data['rides_taken'] ?? 0,
              'co2_saved': (data['co2_saved'] ?? 0.0).toDouble(),
              'rating': (data['rating'] ?? 0.0).toDouble(),
            };
            print('DEBUG: User profile and stats loaded successfully.');
          });
        } else {
          setState(() {
            _userDisplayName = user.email?.split('@')[0] ?? 'JLR User';
            _userEmpId = 'N/A';
            _userStats = {
              'rides_offered': 0,
              'rides_taken': 0,
              'co2_saved': 0.0,
              'rating': 0.0,
            };
          });
          print('DEBUG: Firestore document not found. Using default values.');
        }
      } catch (e) {
        print('ERROR: Failed to load user profile: $e');
        setState(() {
          _userDisplayName = 'Error!';
          _userEmpId = 'Error!';
        });
      }
    } else {
      setState(() {
        _userDisplayName = 'Guest';
        _userEmpId = 'N/A';
      });
      print('DEBUG: No authenticated user found. Setting display name to Guest.');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    print('DEBUG: Attempting to log out user.');
    await FirebaseAuth.instance.signOut();
    print('DEBUG: User signed out successfully.');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
      print('DEBUG: Navigated to WelcomeScreen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: HomeScreen build method called.');
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'JLR Carpool Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 6,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Home', icon: Icon(Icons.home)),
            Tab(text: 'About', icon: Icon(Icons.info_outline)),
            Tab(text: 'Features', icon: Icon(Icons.lightbulb_outline)),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(
                _userDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                'Emp ID: $_userEmpId',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),
            // Main Navigation Items
            ListTile(
              leading: Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.primary),
              title: const Text('Home Dashboard'),
              onTap: () {
                print('DEBUG: Tapped "Home Dashboard". Navigating to Home tab.');
                Navigator.pop(context);
                _tabController.animateTo(0);
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
              title: const Text('About This App'),
              onTap: () {
                print('DEBUG: Tapped "About This App". Navigating to About tab.');
                Navigator.pop(context);
                _tabController.animateTo(1);
              },
            ),
            ListTile(
              leading: Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary),
              title: const Text('Features & Benefits'),
              onTap: () {
                print('DEBUG: Tapped "Features & Benefits". Navigating to Features tab.');
                Navigator.pop(context);
                _tabController.animateTo(2);
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Account Settings',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.secondary),
              title: const Text('Manage Profile'),
              onTap: () async {
                print('DEBUG: Tapped "Manage Profile". Navigating to ProfilePage. Awaiting return...');
                Navigator.pop(context); // Close the drawer
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
                // No automatic refresh here. User will pull to refresh or re-open the app.
                print('DEBUG: Returned from ProfilePage. No automatic refresh triggered.');
              },
            ),
            ListTile(
              leading: Icon(Icons.lock_reset, color: Theme.of(context).colorScheme.secondary),
              title: const Text('Change Password'),
              onTap: () {
                print('DEBUG: Tapped "Change Password". Navigating to ChangePasswordScreen.');
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
              },
            ),
            const Divider(),
            // Logout Button
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
              onTap: () {
                print('DEBUG: Log Out button pressed.');
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _fetchUserProfileAndStats,
            child: _buildHomePage(context),
          ),
          _buildAboutPage(context),
          _buildFeaturesPage(context),
        ],
      ),
    );
  }

  Widget _buildHomePage(BuildContext context) {
    print('DEBUG: Building Home tab content.');
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // Allows pull-to-refresh
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Container(
              padding: const EdgeInsets.all(25.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [Theme.of(context).colorScheme.primary.withOpacity(0.9), Theme.of(context).colorScheme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.waving_hand, size: 60, color: Colors.white),
                  const SizedBox(height: 15),
                  Text(
                    "Welcome, $_userDisplayName!",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your daily commute, revolutionized by JLR. We're thrilled to have you onboard!",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            "What would you like to do today?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildActionCard(
            context,
            icon: Icons.directions_car,
            iconColor: Colors.green.shade600,
            title: 'Offer Ride',
            subtitle: 'As a Driver, share your commute and help colleagues.',
            onTap: () {
              print('DEBUG: Tapped "Offer Ride". Navigating to RideDriverInputScreen.');
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RideDriverInputScreen()));
            },
          ),
          const SizedBox(height: 20),
          _buildActionCard(
            context,
            icon: Icons.person_add,
            iconColor: Colors.orange.shade600,
            title: 'Request Ride',
            subtitle: 'As a Companion, find a ride and reach your destination comfortably.',
            onTap: () {
              print('DEBUG: Tapped "Request Ride". Navigating to RideCompanionInputScreen.');
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RideCompanionInputScreen()));
            },
          ),
          const SizedBox(height: 30),
          Text(
            "Your Carpool Highlights",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildStatGrid(
            ridesOffered: _userStats['rides_offered'].toString(),
            ridesTaken: _userStats['rides_taken'].toString(),
            co2Saved: _userStats['co2_saved'].toStringAsFixed(1),
            rating: _userStats['rating'].toStringAsFixed(1),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Helper Methods for building pages and cards
  Widget _buildStatGrid({
    required String ridesOffered,
    required String ridesTaken,
    required String co2Saved,
    required String rating,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 0,
      mainAxisSpacing: 0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(context, Icons.car_rental, 'Rides Offered', ridesOffered, Colors.blue.shade400),
        _buildStatCard(context, Icons.groups, 'Rides Taken', ridesTaken, Colors.purple.shade400),
        _buildStatCard(context, Icons.cloud_done, 'CO2 Saved (kg)', co2Saved, Colors.green.shade400),
        _buildStatCard(context, Icons.star, 'Rating', rating, Colors.amber.shade400),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      BuildContext context, {
        required IconData icon,
        required Color iconColor,
        required String title,
        required String subtitle,
        VoidCallback? onTap,
      }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutPage(BuildContext context) {
    print('DEBUG: Building About tab content.');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "About JLR Carpool",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "Our journey towards smarter, greener, and more connected commutes.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildAboutSectionCard(
            context,
            icon: Icons.flag_outlined,
            iconColor: Colors.purple.shade600,
            title: "Our Mission",
            description: "To revolutionize daily commutes by fostering a sustainable, efficient, and community-driven carpooling experience for everyone at JLR.",
          ),
          const SizedBox(height: 20),
          _buildAboutSectionCard(
            context,
            icon: Icons.visibility_outlined,
            iconColor: Colors.blue.shade600,
            title: "Our Vision",
            description: "To build a future where carpooling is the preferred choice, significantly reducing traffic congestion, minimizing carbon emissions, and enhancing connectivity among colleagues.",
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups_3_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "About Us",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "JLR Carpool is developed by a dedicated team committed to enhancing your daily commute. We believe in innovation that fosters sustainability and community.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Divider(color: Colors.grey.shade300, thickness: 1.0),
                  const SizedBox(height: 15),
                  Text(
                    "Our Team",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Development Lead: **[Your Lead's Name Here]**",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Core Team: **[Team Member 1], [Team Member 2], [Team Member 3]**",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 25),
                  Divider(color: Colors.grey.shade300, thickness: 1.0),
                  const SizedBox(height: 15),
                  Text(
                    "Contact Us",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "For support or inquiries, please reach out to us:",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Email: **support@jlrcarpool.com**",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Phone: **+91-XXXXXXXXXX** (Mon-Fri, 9 AM - 5 PM IST)",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            "Join us in driving change, one shared ride at a time. Together, we can make a difference!",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesPage(BuildContext context) {
    print('DEBUG: Building Features tab content.');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Discover Key Features",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "Seamlessly connect and optimize your rides with these powerful tools.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = (constraints.maxWidth - 15) / 2;
              final double itemHeight = itemWidth * 1.25;
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: itemWidth / itemHeight,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildFeatureGridItem(
                    context,
                    icon: Icons.map,
                    iconColor: Colors.teal,
                    title: "Optimized Routes",
                    description: "Efficient routes to minimize travel time.",
                    onTap: () {
                      print('DEBUG: Tapped on "Optimized Routes" feature.');
                    },
                  ),
                  _buildFeatureGridItem(
                    context,
                    icon: Icons.people_alt,
                    iconColor: Colors.indigo,
                    title: "Smart Matching",
                    description: "Connect with ideal drivers or companions.",
                    onTap: () {
                      print('DEBUG: Tapped on "Smart Matching" feature.');
                    },
                  ),
                  _buildFeatureGridItem(
                    context,
                    icon: Icons.eco,
                    iconColor: Colors.green,
                    title: "Eco Commutes",
                    description: "Reduce your carbon footprint by sharing rides.",
                    onTap: () {
                      print('DEBUG: Tapped on "Eco Commutes" feature.');
                    },
                  ),
                  _buildFeatureGridItem(
                    context,
                    icon: Icons.access_time,
                    iconColor: Colors.deepOrange,
                    title: "Time Efficiency",
                    description: "Streamlined processes for quick ride coordination.",
                    onTap: () {
                      print('DEBUG: Tapped on "Time Efficiency" feature.');
                    },
                  ),
                  _buildFeatureGridItem(
                    context,
                    icon: Icons.security,
                    iconColor: Colors.blueGrey,
                    title: "Secure & Safe",
                    description: "Ensuring a safe and reliable carpooling environment.",
                    onTap: () {
                      print('DEBUG: Tapped on "Secure & Safe" feature.');
                    },
                  ),
                  _buildFeatureGridItem(
                    context,
                    icon: Icons.chat,
                    iconColor: Theme.of(context).colorScheme.secondary,
                    title: "In-App Chat",
                    description: "Communicate seamlessly with your ride partners.",
                    onTap: () {
                      print('DEBUG: Tapped on "In-App Chat" feature.');
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          Text(
            "And many more features are being developed to make your JLR carpooling experience truly exceptional!",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context, {
        required String title,
        required String subTitle,
        required List<Widget> content,
        required IconData icon,
        required Color iconColor,
      }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 70,
              color: iconColor,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subTitle,
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            ...content,
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(BuildContext context, String text) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*');

    text.splitMapJoin(
      exp,
      onMatch: (m) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ));
        return '';
      },
      onNonMatch: (n) {
        spans.add(TextSpan(text: n));
        return '';
      },
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Icon(Icons.check_circle_outline, size: 22, color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16, height: 1.5, color: Colors.black87),
                children: spans,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              print('DEBUG: Tapped "Offer Ride (Driver)" button from home page.');
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RideDriverInputScreen()));
            },
            icon: const Icon(Icons.directions_car, size: 28),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15.0),
              child: Text(
                'Offer Ride (Driver)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 5,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              print('DEBUG: Tapped "Request Ride (Companion)" button from home page.');
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RideCompanionInputScreen()));
            },
            icon: const Icon(Icons.person_add, size: 28),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15.0),
              child: Text(
                'Request Ride (Companion)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 5,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGridItem(
      BuildContext context, {
        required IconData icon,
        required Color iconColor,
        required String title,
        required String description,
        VoidCallback? onTap,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: iconColor,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSectionCard(
      BuildContext context, {
        required IconData icon,
        required Color iconColor,
        required String title,
        required String description,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}