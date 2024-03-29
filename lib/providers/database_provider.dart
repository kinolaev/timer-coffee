import 'package:coffee_timer/database/database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coffee_timer/database/extensions.dart';

class DatabaseProvider {
  final AppDatabase _db;

  DatabaseProvider(this._db);

  late final Future<SharedPreferences> _prefsFuture =
      SharedPreferences.getInstance();

  Future<bool> _isFirstLaunch() async {
    final prefs = await _prefsFuture;
    bool isFirstLaunch = prefs.getBool('firstLaunched') ?? true;
    return isFirstLaunch;
  }

  Future<void> initializeDatabase() async {
    if (await _isFirstLaunch()) {
      await loadDatabase();
    }
    await updateDatabase();
  }

  Future<void> loadDatabase() async {
    await Future.wait([
      _fetchAndStoreReferenceData(),
      _fetchAndStoreRecipes(),
      _fetchAndStoreExtraData(),
    ]);
  }

  Future<void> updateDatabase() async {
    if (!kIsWeb) {
      bool isConnected = await InternetConnectionChecker().hasConnection;
      if (!isConnected) {
        return;
      } else {
        await Future.wait([
          _fetchAndStoreReferenceData(),
          _fetchAndStoreRecipes(),
          _fetchAndStoreExtraData(),
        ]);
      }
    } else {
      await Future.wait([
        _fetchAndStoreReferenceData(),
        _fetchAndStoreRecipes(),
        _fetchAndStoreExtraData(),
      ]);
    }
  }

  Future<void> _fetchAndStoreReferenceData() async {
    final vendorsResponse =
        await Supabase.instance.client.from('vendors').select();
    final brewingMethodsResponse =
        await Supabase.instance.client.from('brewing_methods').select();
    final supportedLocalesResponse =
        await Supabase.instance.client.from('supported_locales').select();

    final vendors = vendorsResponse
        .map((json) => VendorsCompanionExtension.fromJson(json))
        .toList();
    final brewingMethods = brewingMethodsResponse
        .map((json) => BrewingMethodsCompanionExtension.fromJson(json))
        .toList();
    final supportedLocales = supportedLocalesResponse
        .map((json) => SupportedLocalesCompanionExtension.fromJson(json))
        .toList();

    await _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAll(_db.vendors, vendors, mode: InsertMode.insertOrReplace);
        batch.insertAll(_db.brewingMethods, brewingMethods,
            mode: InsertMode.insertOrReplace);
        batch.insertAll(_db.supportedLocales, supportedLocales,
            mode: InsertMode.insertOrReplace);
      });
    });
  }

  Future<void> _fetchAndStoreRecipes() async {
    final lastModified = await _db.recipesDao.fetchLastModified();
    var request = Supabase.instance.client
        .from('recipes')
        .select('*, recipe_localization(*), steps(*)');
    if (lastModified != null) {
      request = request.gt('last_modified', lastModified);
    }
    final response = await request;

    final recipes = response
        .map((json) => RecipesCompanionExtension.fromJson(json))
        .toList();

    // Extract and store localizations
    final localizationsJson =
        response.expand((json) => json['recipe_localization']).toList();
    final localizations = localizationsJson
        .map((json) => RecipeLocalizationsCompanionExtension.fromJson(json))
        .toList();

    // Extract and store steps
    final stepsJson = response.expand((json) => json['steps']).toList();
    final steps = stepsJson
        .map((json) => StepsCompanionExtension.fromJson(json))
        .toList();

    await _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAll(_db.recipes, recipes, mode: InsertMode.insertOrReplace);
        batch.insertAll(_db.recipeLocalizations, localizations,
            mode: InsertMode.insertOrReplace);
        batch.insertAll(_db.steps, steps, mode: InsertMode.insertOrReplace);
      });
    });
  }

  Future<void> _fetchAndStoreExtraData() async {
    final coffeeFactsResponse =
        await Supabase.instance.client.from('coffee_facts').select();
    final startPopupResponse =
        await Supabase.instance.client.from('start_popup').select();

    final coffeeFacts = coffeeFactsResponse
        .map((json) => CoffeeFactsCompanionExtension.fromJson(json))
        .toList();
    final startPopups = startPopupResponse
        .map((json) => StartPopupsCompanionExtension.fromJson(json))
        .toList();

    await _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAll(_db.coffeeFacts, coffeeFacts,
            mode: InsertMode.insertOrReplace);
        batch.insertAll(_db.startPopups, startPopups,
            mode: InsertMode.insertOrReplace);
      });
    });
  }
}
