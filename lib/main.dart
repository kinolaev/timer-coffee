import 'dart:async'; // Import for StreamSubscription
import 'dart:convert';
import 'package:coffee_timer/database/database.dart';
import 'package:coffee_timer/env/env.dart';
import 'package:coffee_timer/models/supported_locale_model.dart';
import 'package:coffee_timer/providers/database_provider.dart';
import 'package:coffee_timer/purchase_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show SystemChrome, SystemUiMode, SystemUiOverlay, rootBundle;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // Import for In-App Purchase
import 'models/brewing_method_model.dart';
import './providers/recipe_provider.dart';
import './providers/theme_provider.dart';
import './providers/coffee_beans_provider.dart';
import './app_router.dart';
import './app_router.gr.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'models/recipe_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import './providers/snow_provider.dart';
import 'widgets/global_snow_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'notifiers/card_expansion_notifier.dart'; // Import the notifier
import './providers/user_stat_provider.dart'; // Import the new UserStatProvider

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);

  // OneSignal initialization
  // Remove this method to stop OneSignal Debugging
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  OneSignal.initialize(Env.oneSignalAppId);

  // Initialize PurchaseManager
  PurchaseManager();

  // Restore previous purchases
  InAppPurchase.instance.restorePurchases();

  // Initialize Supabase
  await Supabase.initialize(url: Env.supaUrl, anonKey: Env.supaKey);

  // Check if there is an existing session or logged-in user
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    // No session found, proceed with anonymous sign-in
    final authResult = await Supabase.instance.client.auth.signInAnonymously();
    if (authResult.user == null) {
      // Handle error
    } else {
      // Successfully signed in
    }
  }

  final user = Supabase.instance.client.auth.currentUser;
  OneSignal.login(user!.id);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isFirstLaunch = prefs.getBool('firstLaunched') ?? true;
  final AppDatabase database =
      AppDatabase(enableForeignKeyConstraints: !isFirstLaunch);
  final supportedLocalesDao = SupportedLocalesDao(database);
  final brewingMethodsDao = BrewingMethodsDao(database);

  // Initialize databaseProvider before passing it to CoffeeTimerApp
  final DatabaseProvider databaseProvider = DatabaseProvider(database);
  await databaseProvider.initializeDatabase();

  final supportedLocalesFuture = supportedLocalesDao.getAllSupportedLocales();
  final brewingMethodsFuture = brewingMethodsDao.getAllBrewingMethods();
  final List<SupportedLocaleModel> supportedLocales =
      await supportedLocalesFuture;
  final List<BrewingMethodModel> brewingMethods = await brewingMethodsFuture;
  List<Locale> localeList =
      supportedLocales.map((locale) => Locale(locale.locale)).toList();

  String themeModeString = prefs.getString('themeMode') ?? 'system';
  ThemeMode themeMode = ThemeMode.values.firstWhere(
      (e) => e.toString().split('.').last == themeModeString,
      orElse: () => ThemeMode.system);
  String? savedLocaleCode = prefs.getString('locale');
  Locale systemLocale =
      Locale(WidgetsBinding.instance.window.locale.languageCode);
  Locale initialLocale = Locale('en', ''); // Default to English as a fallback
  if (savedLocaleCode != null) {
    initialLocale = Locale(savedLocaleCode);
  } else if (localeList
      .any((locale) => locale.languageCode == systemLocale.languageCode)) {
    initialLocale = systemLocale;
  }

  final appRouter = AppRouter();
  usePathUrlStrategy();

  runApp(CoffeeTimerApp(
    database: database,
    databaseProvider: databaseProvider, // Pass the databaseProvider here
    supportedLocales: localeList,
    brewingMethods: brewingMethods,
    initialLocale: initialLocale,
    themeMode: themeMode,
    appRouter: appRouter,
  ));

  if (isFirstLaunch) {
    await prefs.setBool('firstLaunched', false);
  }

  FlutterNativeSplash.remove();
}

class CoffeeTimerApp extends StatelessWidget {
  final AppDatabase database; // Add database to the constructor
  final DatabaseProvider
      databaseProvider; // Add databaseProvider to the constructor
  final List<Locale> supportedLocales;
  final List<BrewingMethodModel> brewingMethods;
  final Locale initialLocale;
  final ThemeMode themeMode;
  final AppRouter appRouter;

  const CoffeeTimerApp({
    Key? key,
    required this.database, // Add database to the constructor
    required this.databaseProvider, // Add databaseProvider to the constructor
    required this.supportedLocales,
    required this.brewingMethods,
    required this.initialLocale,
    required this.themeMode,
    required this.appRouter,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<RecipeProvider>(
          create: (_) =>
              RecipeProvider(initialLocale, supportedLocales, database),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(themeMode),
        ),
        ChangeNotifierProvider<SnowEffectProvider>(
          create: (_) => SnowEffectProvider(),
        ),
        Provider<List<BrewingMethodModel>>(
          create: (_) => brewingMethods,
        ),
        Provider<Locale>.value(value: initialLocale),
        Provider<DatabaseProvider>.value(
          value: databaseProvider,
        ),
        ChangeNotifierProvider<CoffeeBeansProvider>(
          create: (_) => CoffeeBeansProvider(database, databaseProvider),
        ),
        ChangeNotifierProvider<CardExpansionNotifier>(
          create: (_) => CardExpansionNotifier(),
        ),
        ChangeNotifierProvider<UserStatProvider>(
          // Add this line
          create: (_) => UserStatProvider(database),
        ),
      ],
      child: Consumer2<ThemeProvider, SnowEffectProvider>(
        builder: (context, themeProvider, snowProvider, child) {
          return MaterialApp.router(
            locale: Provider.of<RecipeProvider>(context, listen: true)
                .currentLocale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: supportedLocales,
            routerDelegate: appRouter.delegate(),
            routeInformationParser: appRouter.defaultRouteParser(),
            builder: (context, router) => Stack(
              children: [
                router!,
                GlobalSnowOverlay(isSnowing: snowProvider.isSnowing),
              ],
            ),
            debugShowCheckedModeBanner: false,
            title: 'Coffee Timer App',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
          );
        },
      ),
    );
  }
}

class QuickActionsManager extends StatefulWidget {
  final Widget child;
  final AppRouter appRouter;

  QuickActionsManager({Key? key, required this.child, required this.appRouter})
      : super(key: key);

  @override
  _QuickActionsManagerState createState() => _QuickActionsManagerState();
}

class _QuickActionsManagerState extends State<QuickActionsManager> {
  QuickActions quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();

    // Setup Quick Actions after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupQuickActions();
    });
  }

  void setupQuickActions() {
    quickActions.setShortcutItems([
      ShortcutItem(
        type: 'action_last_recipe',
        localizedTitle: AppLocalizations.of(context)!.quickactionmsg,
        icon: 'icon_coffee_cup',
      ),
    ]);

    quickActions.initialize((shortcutType) async {
      if (shortcutType == 'action_last_recipe') {
        RecipeProvider recipeProvider =
            Provider.of<RecipeProvider>(context, listen: false);
        RecipeModel? mostRecentRecipe =
            await recipeProvider.getLastUsedRecipe();
        if (mostRecentRecipe != null) {
          widget.appRouter.push(RecipeDetailRoute(
              brewingMethodId: mostRecentRecipe.brewingMethodId,
              recipeId: mostRecentRecipe.id));
        }
      }
    });
  }

  // Deliver Product
  void _deliverProduct(PurchaseDetails purchaseDetails) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.donationok),
          content: Text(AppLocalizations.of(context)!.donationtnx),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleError(IAPError error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.donationerr),
          content: Text(AppLocalizations.of(context)!.donationerrmsg),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
