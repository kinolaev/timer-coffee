part of 'database.dart';

@DriftAccessor(tables: [UserStats])
class UserStatsDao extends DatabaseAccessor<AppDatabase>
    with _$UserStatsDaoMixin {
  final AppDatabase db;

  UserStatsDao(this.db) : super(db);

  Future<void> insertUserStat({
    required String userId,
    required String recipeId,
    required double coffeeAmount,
    required double waterAmount,
    required int sweetnessSliderPosition,
    required int strengthSliderPosition,
    required String brewingMethodId,
    String? notes,
    String? beans,
    String? roaster,
    double? rating,
    int? coffeeBeansId,
    bool isMarked = false,
  }) async {
    await into(userStats).insertOnConflictUpdate(UserStatsCompanion(
      userId: Value(userId),
      recipeId: Value(recipeId),
      coffeeAmount: Value(coffeeAmount),
      waterAmount: Value(waterAmount),
      sweetnessSliderPosition: Value(sweetnessSliderPosition),
      strengthSliderPosition: Value(strengthSliderPosition),
      brewingMethodId: Value(brewingMethodId),
      createdAt: Value(DateTime.now().toUtc()),
      notes: Value(notes),
      beans: Value(beans),
      roaster: Value(roaster),
      rating: Value(rating),
      coffeeBeansId: Value(coffeeBeansId),
      isMarked: Value(isMarked),
    ));
  }

  Future<UserStatsModel?> fetchStatById(int id) async {
    final query = select(userStats)..where((tbl) => tbl.id.equals(id));
    final userStat = await query.getSingleOrNull();

    if (userStat == null) return null;

    return UserStatsModel(
      id: userStat.id,
      userId: userStat.userId,
      recipeId: userStat.recipeId,
      coffeeAmount: userStat.coffeeAmount,
      waterAmount: userStat.waterAmount,
      sweetnessSliderPosition: userStat.sweetnessSliderPosition,
      strengthSliderPosition: userStat.strengthSliderPosition,
      brewingMethodId: userStat.brewingMethodId,
      createdAt: userStat.createdAt,
      notes: userStat.notes,
      beans: userStat.beans,
      roaster: userStat.roaster,
      rating: userStat.rating,
      coffeeBeansId: userStat.coffeeBeansId,
      isMarked: userStat.isMarked,
    );
  }

  Future<List<UserStatsModel>> fetchAllStats() async {
    final query = select(userStats)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]);
    final List<UserStat> userStatsList = await query.get();

    return userStatsList
        .map((dbUserStat) => UserStatsModel(
              id: dbUserStat.id,
              userId: dbUserStat.userId,
              recipeId: dbUserStat.recipeId,
              coffeeAmount: dbUserStat.coffeeAmount,
              waterAmount: dbUserStat.waterAmount,
              sweetnessSliderPosition: dbUserStat.sweetnessSliderPosition,
              strengthSliderPosition: dbUserStat.strengthSliderPosition,
              brewingMethodId: dbUserStat.brewingMethodId,
              createdAt: dbUserStat.createdAt,
              notes: dbUserStat.notes,
              beans: dbUserStat.beans,
              roaster: dbUserStat.roaster,
              rating: dbUserStat.rating,
              coffeeBeansId: dbUserStat.coffeeBeansId,
              isMarked: dbUserStat.isMarked,
            ))
        .toList();
  }

  Future<void> updateUserStat({
    required int id,
    String? userId,
    String? recipeId,
    double? coffeeAmount,
    double? waterAmount,
    int? sweetnessSliderPosition,
    int? strengthSliderPosition,
    String? brewingMethodId,
    String? notes,
    String? beans,
    String? roaster,
    double? rating,
    int? coffeeBeansId,
    bool? isMarked,
  }) async {
    print(
        'UserStatsDao updateUserStat called with id: $id, coffeeBeansId: $coffeeBeansId'); // Print the parameters

    final updateCompanion = UserStatsCompanion(
      id: Value(id),
      userId: userId != null ? Value(userId) : Value.absent(),
      recipeId: recipeId != null ? Value(recipeId) : Value.absent(),
      coffeeAmount: coffeeAmount != null ? Value(coffeeAmount) : Value.absent(),
      waterAmount: waterAmount != null ? Value(waterAmount) : Value.absent(),
      sweetnessSliderPosition: sweetnessSliderPosition != null
          ? Value(sweetnessSliderPosition)
          : Value.absent(),
      strengthSliderPosition: strengthSliderPosition != null
          ? Value(strengthSliderPosition)
          : Value.absent(),
      brewingMethodId:
          brewingMethodId != null ? Value(brewingMethodId) : Value.absent(),
      notes: notes != null ? Value(notes) : Value.absent(),
      beans: beans != null ? Value(beans) : Value.absent(),
      roaster: roaster != null ? Value(roaster) : Value.absent(),
      rating: rating != null ? Value(rating) : Value.absent(),
      coffeeBeansId: coffeeBeansId == null ? Value(null) : Value(coffeeBeansId),
      isMarked: isMarked != null ? Value(isMarked) : Value.absent(),
    );

    await (update(userStats)..where((tbl) => tbl.id.equals(id)))
        .write(updateCompanion);

    print(
        'UserStatsDao updateUserStat completed for id: $id'); // Print after the update

    // Fetch and print the updated user stat
    final updatedStat = await fetchStatById(id);
    print('Updated stat coffeeBeansId: ${updatedStat?.coffeeBeansId}');
  }

  Future<List<String>> fetchAllDistinctRoasters() async {
    final query = selectOnly(userStats, distinct: true)
      ..addColumns([userStats.roaster])
      ..where(userStats.roaster.isNotNull())
      ..orderBy([
        OrderingTerm(expression: userStats.createdAt, mode: OrderingMode.desc)
      ]);
    final roasters =
        await query.map((row) => row.read(userStats.roaster)).get();
    return roasters.whereType<String>().toList();
  }

  Future<List<String>> fetchAllDistinctBeans() async {
    final query = selectOnly(userStats, distinct: true)
      ..addColumns([userStats.beans])
      ..where(userStats.beans.isNotNull())
      ..orderBy([
        OrderingTerm(expression: userStats.createdAt, mode: OrderingMode.desc)
      ]);
    final beans = await query.map((row) => row.read(userStats.beans)).get();
    return beans.whereType<String>().toList();
  }

  Future<void> deleteUserStat(int id) async {
    await (delete(userStats)..where((t) => t.id.equals(id))).go();
  }

  Future<double> fetchBrewedCoffeeAmount(DateTime start, DateTime end) async {
    final query = select(userStats)
      ..where((u) => u.createdAt.isBetweenValues(start, end));
    final List<double> totalWaterAmount =
        await query.map((row) => row.waterAmount).get();
    return totalWaterAmount.fold<double>(
        0.0, (double sum, double element) => sum + element);
  }

  Future<List<String>> fetchTopRecipes(DateTime start, DateTime end) async {
    final query = customSelect(
      'SELECT recipe_id, COUNT(recipe_id) AS usage_count '
      'FROM user_stats WHERE created_at BETWEEN ? AND ? '
      'GROUP BY recipe_id ORDER BY usage_count DESC LIMIT 3',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {userStats},
    );
    final resultRows = await query.get();
    return resultRows.map((row) => row.read<String>('recipe_id')).toList();
  }
}
