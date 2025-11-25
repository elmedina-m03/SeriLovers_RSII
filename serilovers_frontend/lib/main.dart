import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'providers/series_provider.dart';
import 'providers/watchlist_provider.dart';
import 'providers/admin_user_provider.dart';
import 'providers/actor_provider.dart';
import 'providers/admin_stats_provider.dart';
import 'admin/providers/admin_series_provider.dart';
import 'admin/providers/admin_actor_provider.dart';
import 'admin/providers/admin_statistics_provider.dart';
import 'admin/providers/admin_challenge_provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/series_list_screen.dart';
import 'screens/series_detail_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/main_tab_screen.dart';
import 'admin/screens/admin_screen.dart';
import 'models/series.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
  
  // Debug log
  print("THEME ACTIVE");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Create service instances
    final apiService = ApiService();
    final authService = AuthService(apiService: apiService);
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = AuthProvider(authService: authService);
            // Initialize asynchronously (token loading)
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, SeriesProvider>(
          create: (_) {
            // Create a temporary instance - will be updated in update method
            final tempAuth = AuthProvider(authService: authService);
            return SeriesProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            // Update the existing SeriesProvider with the correct AuthProvider
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            // Create new instance if previous doesn't exist
            return SeriesProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, WatchlistProvider>(
          create: (_) {
            // Create a temporary instance - will be updated in update method
            final tempAuth = AuthProvider(authService: authService);
            return WatchlistProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            // Update the existing WatchlistProvider with the correct AuthProvider
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            // Create new instance if previous doesn't exist
            return WatchlistProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AdminUserProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return AdminUserProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return AdminUserProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ActorProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return ActorProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return ActorProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AdminStatsProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return AdminStatsProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return AdminStatsProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AdminSeriesProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return AdminSeriesProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return AdminSeriesProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AdminActorProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return AdminActorProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return AdminActorProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AdminStatisticsProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return AdminStatisticsProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return AdminStatisticsProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AdminChallengeProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return AdminChallengeProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return AdminChallengeProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
      ],
      child: MaterialApp(
        title: 'SeriLovers',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/main': (context) => const MainTabScreen(),
          '/admin': (context) => const AdminScreen(),
          '/watchlist': (context) => const WatchlistScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle series detail route with Series argument
          if (settings.name == '/series_detail') {
            final series = settings.arguments as Series?;
            if (series != null) {
              return MaterialPageRoute(
                builder: (context) => SeriesDetailScreen(series: series),
              );
            }
          }
          // Default route (fallback)
          return MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
