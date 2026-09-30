import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'personal_budget_state.dart';

class PersonalBudgetCubit extends Cubit<PersonalBudgetState> {
  static const _salaryKey = 'pb_salary';
  static const _fixedCostsKey = 'pb_fixedCosts';
  static const _formulaKey = 'pb_formula';
  static const _householdExpensesKey = 'pb_householdExpenses';
  static const _householdMembersKey = 'pb_householdMembers';
  static const _rentKey = 'pb_rent';
  static const _servicesKey = 'pb_services';
  static const _insuranceKey = 'pb_insurance';
  static const _internetKey = 'pb_internet';
  static const _electricityKey = 'pb_electricity';
  static const _waterKey = 'pb_water';

  PersonalBudgetCubit() : super(PersonalBudgetState.initial()) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final salary = prefs.getDouble(_salaryKey);
      final fixedCosts = prefs.getDouble(_fixedCostsKey);
      final formula = prefs.getString(_formulaKey);
      final householdExpenses = prefs.getDouble(_householdExpensesKey);
      final householdMembers = prefs.getInt(_householdMembersKey);
      final rent = prefs.getDouble(_rentKey);
      final services = prefs.getDouble(_servicesKey);
      final insurance = prefs.getDouble(_insuranceKey);
      final internet = prefs.getDouble(_internetKey);
      final electricity = prefs.getDouble(_electricityKey);
      final water = prefs.getDouble(_waterKey);

      emit(
        state.copyWith(
          salary: salary,
          fixedCosts: fixedCosts,
          formula: formula,
          householdExpenses: householdExpenses,
          householdMembers: householdMembers,
          rent: rent,
          services: services,
          insurance: insurance,
          internet: internet,
          electricity: electricity,
          water: water,
        ),
      );
    } catch (e) {
      // Keep initial local state if something goes wrong
    }
  }

  Future<void> updateSalary(double value) async {
    emit(state.copyWith(salary: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_salaryKey, value);
    } catch (_) {}
  }

  Future<void> updateFixedCosts(double value) async {
    emit(state.copyWith(fixedCosts: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fixedCostsKey, value);
    } catch (_) {}
  }

  Future<void> updateHouseholdExpenses(double value) async {
    emit(state.copyWith(householdExpenses: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_householdExpensesKey, value);
    } catch (_) {}
  }

  Future<void> updateHouseholdMembers(int value) async {
    emit(state.copyWith(householdMembers: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_householdMembersKey, value);
    } catch (_) {}
  }

  Future<void> _saveComponentsAndTotal() async {
    final total =
        state.rent +
        state.services +
        state.insurance +
        state.internet +
        state.electricity +
        state.water;
    emit(state.copyWith(householdExpenses: total));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_householdExpensesKey, total);
    } catch (_) {}
  }

  Future<void> updateRent(double value) async {
    emit(state.copyWith(rent: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_rentKey, value);
    } catch (_) {}
    await _saveComponentsAndTotal();
  }

  Future<void> updateServices(double value) async {
    emit(state.copyWith(services: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_servicesKey, value);
    } catch (_) {}
    await _saveComponentsAndTotal();
  }

  Future<void> updateInsurance(double value) async {
    emit(state.copyWith(insurance: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_insuranceKey, value);
    } catch (_) {}
    await _saveComponentsAndTotal();
  }

  Future<void> updateInternet(double value) async {
    emit(state.copyWith(internet: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_internetKey, value);
    } catch (_) {}
    await _saveComponentsAndTotal();
  }

  Future<void> updateElectricity(double value) async {
    emit(state.copyWith(electricity: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_electricityKey, value);
    } catch (_) {}
    await _saveComponentsAndTotal();
  }

  Future<void> updateWater(double value) async {
    emit(state.copyWith(water: value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_waterKey, value);
    } catch (_) {}
    await _saveComponentsAndTotal();
  }

  Future<void> updateFormula(String formula) async {
    emit(state.copyWith(formula: formula));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_formulaKey, formula);
    } catch (_) {}
  }
}
