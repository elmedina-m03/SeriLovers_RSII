import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'providers/series_provider.dart';
import 'providers/watchlist_provider.dart';
import 'providers/episode_progress_provider.dart';
import 'providers/episode_review_provider.dart';
import 'providers/rating_provider.dart';
import 'providers/admin_user_provider.dart';
import 'providers/actor_provider.dart';
import 'providers/admin_stats_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'admin/providers/admin_series_provider.dart';
import 'admin/providers/admin_actor_provider.dart';
import 'admin/providers/admin_statistics_provider.dart';
import 'admin/providers/admin_challenge_provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/watchlist_service.dart';
import 'services/episode_progress_service.dart';
import 'services/episode_review_service.dart';
import 'services/rating_service.dart';
import 'services/recommendation_service.dart';
import 'providers/recommendation_provider.dart';
import 'screens/login_screen.dart';
import 'screens/series_list_screen.dart';
import 'screens/series_detail_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/my_lists_screen.dart';
import 'screens/create_watchlist_screen.dart';
import 'screens/watchlist_detail_screen.dart';
import 'screens/main_tab_screen.dart';
import 'admin/screens/admin_screen.dart';
import 'mobile/mobile_main_screen.dart';
import 'mobile/providers/mobile_navigation_provider.dart';
import 'mobile/screens/mobile_login_screen.dart';
import 'mobile/screens/mobile_home_screen.dart';
import 'mobile/screens/mobile_series_detail_screen.dart';
import 'mobile/screens/mobile_edit_profile_screen.dart';
import 'mobile/screens/mobile_register_screen.dart';
import 'mobile/providers/mobile_challenges_provider.dart';
import 'models/series.dart';
import 'core/theme/app_theme.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize notification service
  await NotificationService().initialize();
  
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
            final tempAuth = AuthProvider(authService: authService);
            return WatchlistProvider(
              service: WatchlistService(apiService: apiService),
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return WatchlistProvider(
              service: WatchlistService(apiService: apiService),
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, EpisodeProgressProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return EpisodeProgressProvider(
              service: EpisodeProgressService(apiService: apiService),
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return EpisodeProgressProvider(
              service: EpisodeProgressService(apiService: apiService),
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, EpisodeReviewProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return EpisodeReviewProvider(
              service: EpisodeReviewService(apiService: apiService),
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return EpisodeReviewProvider(
              service: EpisodeReviewService(apiService: apiService),
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, RatingProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return RatingProvider(
              service: RatingService(apiService: apiService),
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return RatingProvider(
              service: RatingService(apiService: apiService),
              authProvider: authProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, RecommendationProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return RecommendationProvider(
              service: RecommendationService(apiService: apiService),
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return RecommendationProvider(
              service: RecommendationService(apiService: apiService),
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
        ChangeNotifierProvider(
          create: (_) => MobileNavigationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MobileChallengesProvider>(
          create: (_) {
            final tempAuth = AuthProvider(authService: authService);
            return MobileChallengesProvider(
              apiService: apiService,
              authProvider: tempAuth,
            );
          },
          update: (context, authProvider, previous) {
            if (previous != null) {
              previous.updateAuthProvider(authProvider);
              return previous;
            }
            return MobileChallengesProvider(
              apiService: apiService,
              authProvider: authProvider,
            );
          },
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine initial route based on screen width
          // Always show login screen on desktop - no auto-login
          final screenWidth = constraints.maxWidth;
          final initialRoute = screenWidth > 900 ? '/login' : '/mobile_login';

          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                title: 'SeriLovers',
                theme: themeProvider.currentTheme,
                debugShowCheckedModeBanner: false,
            initialRoute: initialRoute,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/main': (context) => const MainTabScreen(),
              '/admin': (context) => const AdminScreen(),
              '/mobile': (context) => const MobileMainScreen(),
              '/mobile_login': (context) => const MobileLoginScreen(),
              '/mobile_register': (context) => const MobileRegisterScreen(),
              '/mobile_home': (context) => const MobileHomeScreen(),
              '/mobile_edit_profile': (context) => const MobileEditProfileScreen(),
              '/watchlist': (context) => const WatchlistScreen(),
              '/my_lists': (context) => const MyListsScreen(),
              '/create_list': (context) => const CreateWatchlistScreen(),
              '/list_view': (context) {
                final collectionId = ModalRoute.of(context)?.settings.arguments as int?;
                if (collectionId != null) {
                  return WatchlistDetailScreen(watchlistCollectionId: collectionId);
                }
                return const MyListsScreen();
              },
            },
            onGenerateRoute: (settings) {
              // Handle series detail route with Series argument
              if (settings.name == '/series_detail') {
                final series = settings.arguments as Series?;
                if (series != null) {
                  // Check screen width to determine which detail screen to use
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (screenWidth < 900) {
                    // Mobile: use mobile series detail screen
                    return MaterialPageRoute(
                      builder: (context) => MobileSeriesDetailScreen(series: series),
                    );
                  } else {
                    // Desktop: use regular series detail screen
                    return MaterialPageRoute(
                      builder: (context) => SeriesDetailScreen(series: series),
                    );
                  }
                }
              }

              // Default route (fallback) - check screen size
              final screenWidth = MediaQuery.of(context).size.width;
              if (screenWidth < 900) {
                return MaterialPageRoute(
                  builder: (context) => const MobileLoginScreen(),
                );
              }
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            },
          );
            },
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
