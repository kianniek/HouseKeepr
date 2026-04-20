import 'package:equatable/equatable.dart';

class PersonalBudgetState extends Equatable {
  final double salary;
  final double fixedCosts;
  final double householdExpenses;
  final int householdMembers;
  final double rent;
  final double services;
  final double insurance;
  final double internet;
  final double electricity;
  final double water;
  final String formula;

  const PersonalBudgetState({
    required this.salary,
    required this.fixedCosts,
    required this.householdExpenses,
    required this.householdMembers,
    required this.rent,
    required this.services,
    required this.insurance,
    required this.internet,
    required this.electricity,
    required this.water,
    required this.formula,
  });

  factory PersonalBudgetState.initial() {
    return const PersonalBudgetState(
      salary: 0.0,
      fixedCosts: 0.0,
      rent: 732.96,
      services: 50.00,
      insurance: 16.17,
      internet: 35.00,
      electricity: 50.00,
      water: 19.00,
      householdExpenses: 732.96 + 50.00 + 16.17 + 35.00 + 50.00 + 19.00,
      householdMembers: 2,
      formula: 'household + (Surplus / householdMembers)',
    );
  }

  PersonalBudgetState copyWith({
    double? salary,
    double? fixedCosts,
    double? householdExpenses,
    int? householdMembers,
    double? rent,
    double? services,
    double? insurance,
    double? internet,
    double? electricity,
    double? water,
    String? formula,
  }) {
    return PersonalBudgetState(
      salary: salary ?? this.salary,
      fixedCosts: fixedCosts ?? this.fixedCosts,
      householdExpenses: householdExpenses ?? this.householdExpenses,
      householdMembers: householdMembers ?? this.householdMembers,
      rent: rent ?? this.rent,
      services: services ?? this.services,
      insurance: insurance ?? this.insurance,
      internet: internet ?? this.internet,
      electricity: electricity ?? this.electricity,
      water: water ?? this.water,
      formula: formula ?? this.formula,
    );
  }

  @override
  List<Object?> get props => [
    salary,
    fixedCosts,
    rent,
    services,
    insurance,
    internet,
    electricity,
    water,
    householdExpenses,
    householdMembers,
    formula,
  ];
}
