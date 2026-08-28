import 'package:flutter/material.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _userRepository;

  List<User> _users = [];
  User? _currentUser;

  UserProvider(this._userRepository);

  List<User> get users => List.unmodifiable(_users);
  User? get currentUser => _currentUser;

  Future<void> loadUsers() async {
    _users = await _userRepository.getAllUsers();
    notifyListeners();
  }

  Future<void> addUser(String name, {String? syncId}) async {
    final user = User(
      syncId: syncId ?? '',
      name: name,
      createdAt: DateTime.now(),
    );
    await _userRepository.insertUser(user);
    await loadUsers();
  }

  Future<void> loadCurrentUser(SettingsRepository settingsRepo) async {
    final idString = await settingsRepo.getSetting('current_user_id');
    if (idString != null) {
      final id = int.tryParse(idString);
      if (id != null) {
        _currentUser = getUserById(id);
        notifyListeners();
      }
    }
  }

  Future<void> setCurrentUser(User user, SettingsRepository settingsRepo) async {
    _currentUser = user;
    if (user.id != null) {
      await settingsRepo.setSetting('current_user_id', user.id!.toString());
    }
    notifyListeners();
  }

  Future<void> createAndSetUser(String name, SettingsRepository settingsRepo, {String? syncId}) async {
    final user = User(
      syncId: syncId ?? '',
      name: name,
      createdAt: DateTime.now(),
    );
    final id = await _userRepository.insertUser(user);
    await loadUsers();
    final newUser = getUserById(id);
    if (newUser != null) {
      await setCurrentUser(newUser, settingsRepo);
    }
  }

  Future<void> updateUser(User user) async {
    await _userRepository.updateUser(user);
    await loadUsers();
    if (_currentUser?.id == user.id) {
      _currentUser = user;
      notifyListeners();
    }
  }

  User? getUserById(int id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (e) {
      return null;
    }
  }
}
