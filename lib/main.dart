import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const BlankMapApp());
}

class BlankMapApp extends StatelessWidget {
  const BlankMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlankMap Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep dark grey
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.tealAccent,
        ),
        fontFamily: 'Roboto', // Default clean font
      ),
      // Start at the Login Screen
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// 1. LOGIN SCREEN (Demo Onboarding)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();

  void _login() {
    if (_nameController.text.trim().isEmpty) return;

    // Navigate to the Main App and remove Login from history
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MainNavigationScreen(username: _nameController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.layers, size: 60, color: Colors.tealAccent),
              const SizedBox(height: 20),
              const Text(
                'BlankMap.',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Commercial maps are broken. Take back your city. Map what actually matters.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 50),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Choose a Civic Username',
                  labelStyle: const TextStyle(color: Colors.tealAccent),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.tealAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _login,
                  child: const Text(
                    'Join the Map',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. MAIN NAVIGATION (Holds the Bottom Tabs)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  final String username;
  const MainNavigationScreen({super.key, required this.username});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _activeLayer = 'r/Dustbins'; // Default layer

  // Function to switch to the map tab and set the specific layer
  void _goToMapWithLayer(String layer) {
    setState(() {
      _activeLayer = layer;
      _currentIndex = 1; // 1 is the Map Tab
    });
  }

  @override
  Widget build(BuildContext context) {
    // The three main screens of the app
    final List<Widget> screens = [
      TrendingScreen(onTagSelected: _goToMapWithLayer),
      MapScreen(
        activeLayer: _activeLayer,
        onLayerChanged: (newLayer) => setState(() => _activeLayer = newLayer),
      ),
      ProfileScreen(username: widget.username),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.whatshot),
            label: 'Trending',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'The Map'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ==========================================
// 3. TRENDING SCREEN (The "Front Page")
// ==========================================
class TrendingScreen extends StatelessWidget {
  final Function(String) onTagSelected;

  TrendingScreen({super.key, required this.onTagSelected});

  // Dummy data for the top 5 subcategories
  final List<Map<String, dynamic>> trendingTags = [
    {
      'tag': 'r/Dustbins',
      'desc': 'Track public dustbins to stop littering.',
      'pins': '1,204',
      'icon': Icons.delete_outline,
    },
    {
      'tag': 'r/Potholes',
      'desc': 'Warning tags for dangerous road damage.',
      'pins': '842',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'tag': 'r/CleanToilets',
      'desc': 'Verified usable public restrooms.',
      'pins': '610',
      'icon': Icons.wc,
    },
    {
      'tag': 'r/SafeWalking',
      'desc': 'Well-lit, safe routes for walking at night.',
      'pins': '430',
      'icon': Icons.directions_walk,
    },
    {
      'tag': 'r/FreeWater',
      'desc': 'Public drinking water points.',
      'pins': '290',
      'icon': Icons.water_drop,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trending SubMaps',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Top active civic layers in your city today.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: trendingTags.length,
                itemBuilder: (context, index) {
                  final item = trendingTags[index];
                  return Card(
                    color: Colors.grey.shade900,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.tealAccent.withOpacity(0.2),
                        child: Icon(item['icon'], color: Colors.tealAccent),
                      ),
                      title: Text(
                        item['tag'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          item['desc'],
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['pins'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.tealAccent,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => onTagSelected(
                        item['tag'],
                      ), // Triggers navigation to map
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. THE MAP SCREEN
// ==========================================
class MapPin {
  final String id;
  final LatLng location;
  final String layer;
  int upvotes;

  MapPin({
    required this.id,
    required this.location,
    required this.layer,
    this.upvotes = 1,
  });
}

class MapScreen extends StatefulWidget {
  final String activeLayer;
  final Function(String) onLayerChanged;

  const MapScreen({
    super.key,
    required this.activeLayer,
    required this.onLayerChanged,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng _initialCenter = const LatLng(28.6315, 77.2167); // New Delhi
  final List<String> _allLayers = [
    'r/Dustbins',
    'r/Potholes',
    'r/CleanToilets',
    'r/SafeWalking',
    'r/FreeWater',
  ];

  // Dummy global state for pins (in a real app, this is in your database)
  static final List<MapPin> _globalPins = [];

  void _dropPin() {
    setState(() {
      _globalPins.add(
        MapPin(
          id: DateTime.now().toString(),
          location: _mapController.camera.center, // Center of the crosshair
          layer: widget.activeLayer,
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pinned to ${widget.activeLayer}! +10 Karma'),
        backgroundColor: Colors.teal.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter pins by the currently active layer
    final activePins = _globalPins
        .where((pin) => pin.layer == widget.activeLayer)
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          // 1. The OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hackathon.blankmap',
              ),
              MarkerLayer(
                markers: activePins.map((pin) {
                  return Marker(
                    point: pin.location,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.tealAccent,
                      size: 40,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. Crosshair for dropping pins accurately
          const Center(child: Icon(Icons.add, color: Colors.black54, size: 30)),

          // 3. Floating Layer Selector (Modern UX)
          Positioned(
            top: 50, // Safe area from top
            left: 0,
            right: 0,
            child: SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allLayers.length,
                itemBuilder: (context, index) {
                  final layer = _allLayers[index];
                  final isSelected = layer == widget.activeLayer;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        layer,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.tealAccent,
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (selected) {
                        if (selected) widget.onLayerChanged(layer);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // Floating Action Button to drop a pin
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _dropPin,
        backgroundColor: Colors.tealAccent,
        icon: const Icon(Icons.add_location_alt, color: Colors.black),
        label: Text(
          'Pin to ${widget.activeLayer}',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ==========================================
// 5. PROFILE SCREEN (Dummy stats)
// ==========================================
class ProfileScreen extends StatelessWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.tealAccent,
              child: Icon(Icons.person, size: 50, color: Colors.black),
            ),
            const SizedBox(height: 20),
            Text(
              username,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Civic Contributor',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '42',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent,
                        ),
                      ),
                      Text(
                        'Pins Dropped',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '850',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent,
                        ),
                      ),
                      Text('Civic Karma', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
