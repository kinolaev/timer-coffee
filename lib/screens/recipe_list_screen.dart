import 'package:coffee_timer/utils/icon_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe_model.dart';
import '../providers/recipe_provider.dart';
import '../widgets/favorite_button.dart';
import 'package:auto_route/auto_route.dart';
import '../app_router.gr.dart';

@RoutePage()
class RecipeListScreen extends StatefulWidget {
  final String? brewingMethodId;

  const RecipeListScreen({
    Key? key,
    @PathParam('brewingMethodId') this.brewingMethodId,
  }) : super(key: key);

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  late Future<String> brewingMethodName;
  late Future<List<RecipeModel>> recipesForBrewingMethod;

  @override
  void initState() {
    super.initState();
    brewingMethodName = Provider.of<RecipeProvider>(context, listen: false)
        .getBrewingMethodName(widget.brewingMethodId ?? "");
    recipesForBrewingMethod =
        Provider.of<RecipeProvider>(context, listen: false)
            .fetchRecipesForBrewingMethod(widget.brewingMethodId ?? "");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(children: [
          getIconByBrewingMethod(widget.brewingMethodId),
          const SizedBox(width: 8),
          FutureBuilder<String>(
            future: brewingMethodName,
            builder: (context, snapshot) => Text(snapshot.data ?? 'Loading...'),
          ),
        ]),
      ),
      body: FutureBuilder<List<RecipeModel>>(
        future: recipesForBrewingMethod,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No recipes found"));
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (BuildContext context, int index) {
              RecipeModel recipe = snapshot.data![index];
              return ListTile(
                title: Text(recipe.name),
                onTap: () => navigateToRecipeDetail(recipe),
                trailing: FavoriteButton(recipeId: recipe.id),
              );
            },
          );
        },
      ),
    );
  }

  void navigateToRecipeDetail(RecipeModel recipe) async {
    // Show loading dialog or indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: new Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              new CircularProgressIndicator(),
            ],
          ),
        );
      },
    );

    // Assuming RecipeProvider has a method to ensure data is ready
    await Provider.of<RecipeProvider>(context, listen: false).ensureDataReady();

    // Dismiss loading dialog or indicator
    Navigator.pop(context);

    // Navigate to detail screen
    context.router.push(RecipeDetailRoute(
        brewingMethodId: recipe.brewingMethodId, recipeId: recipe.id));
  }
}
