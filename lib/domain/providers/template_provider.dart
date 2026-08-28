import 'package:flutter/material.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';

class TemplateProvider extends ChangeNotifier {
  final TemplateRepository _templateRepository;
  List<ExpenseTemplate> _templates = [];

  TemplateProvider(this._templateRepository);

  List<ExpenseTemplate> get templates => List.unmodifiable(_templates);

  Future<void> loadTemplates() async {
    _templates = await _templateRepository.getAllTemplates();
    notifyListeners();
  }

  Future<void> addTemplate(ExpenseTemplate template) async {
    await _templateRepository.insertTemplate(template);
    await loadTemplates();
  }

  Future<void> deleteTemplate(int id) async {
    await _templateRepository.deleteTemplate(id);
    await loadTemplates();
  }
}
