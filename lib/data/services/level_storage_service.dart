import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/game_models.dart';

class LevelStorageService {
  static const String _boxName = 'levels_box';
  static late Box<String> _box;
  
  // Remote level pack storage URL (configurable via compile-time environment)
  static const String _baseUrl = String.fromEnvironment(
    'LEVELS_BASE_URL',
    defaultValue: 'https://levels.arrowknots.app',
  );

  /// Initialize Hive box and load starter pack if empty
  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    
    // If the box is completely empty, this is the first launch.
    // Load pack_1.json from local assets.
    if (_box.isEmpty) {
      await _loadLocalPack('assets/levels/pack_1.json');
    }
  }

  /// Parses a JSON pack and stores it in Hive
  static Future<void> _storePackData(String jsonString) async {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final Map<dynamic, String> entries = {};
    
    for (var item in jsonList) {
      if (item is Map<String, dynamic> && item.containsKey('id')) {
        // We store the id as the Hive key and the JSON string representation as the value
        final id = item['id'];
        entries[id] = jsonEncode(item);
      }
    }
    
    await _box.putAll(entries);
  }

  /// Load a pack from local assets
  static Future<void> _loadLocalPack(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      await _storePackData(jsonString);
    } catch (e) {
      print('Error loading local pack: $e');
    }
  }

  /// Load a pack from GitHub Pages over the internet
  static Future<bool> downloadPack(int packNumber) async {
    try {
      final url = Uri.parse('$_baseUrl/pack_$packNumber.json');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        await _storePackData(response.body);
        return true;
      } else {
        print('Failed to download pack $packNumber: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error downloading pack $packNumber: $e');
      return false;
    }
  }

  /// Get a specific level by ID
  static LevelConfig? getLevel(int id) {
    final jsonString = _box.get(id);
    if (jsonString != null) {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return LevelConfig.fromJson(jsonMap);
    }
    return null;
  }
  
  /// Check if we have a specific level
  static bool hasLevel(int id) {
    return _box.containsKey(id);
  }
}
