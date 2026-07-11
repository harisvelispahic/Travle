import 'package:travle_desktop/providers/base_provider.dart';

import '../models/asset.dart';

class AssetProvider extends BaseProvider<Asset> {
  AssetProvider() : super("Assets");

  @override
  Asset fromJson(data) {
    return Asset.fromJson(data);
  }
}
