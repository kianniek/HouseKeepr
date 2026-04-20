import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:math_expressions/math_expressions.dart';

import '../../cubits/personal_budget_cubit.dart';
import '../../cubits/personal_budget_state.dart';

class PersonalBudgetPage extends StatelessWidget {
  const PersonalBudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PersonalBudgetCubit(),
      child: const _PersonalBudgetView(),
    );
  }
}

class _PersonalBudgetView extends StatefulWidget {
  const _PersonalBudgetView();

  @override
  State<_PersonalBudgetView> createState() => _PersonalBudgetViewState();
}

class _PersonalBudgetViewState extends State<_PersonalBudgetView> {
  final _salaryController = TextEditingController();
  final _fixedCostsController = TextEditingController();
  final _formulaController = TextEditingController();
  final _householdExpensesController = TextEditingController();
  final _householdMembersController = TextEditingController();
  final _rentController = TextEditingController();
  final _servicesController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _internetController = TextEditingController();
  final _electricityController = TextEditingController();
  final _waterController = TextEditingController();

  String _formulaError = '';
  double _contribution = 0.0;
  double _leftover = 0.0;

  @override
  void dispose() {
    _salaryController.dispose();
    _fixedCostsController.dispose();
    _formulaController.dispose();
    _householdExpensesController.dispose();
    _householdMembersController.dispose();
    _rentController.dispose();
    _servicesController.dispose();
    _insuranceController.dispose();
    _internetController.dispose();
    _electricityController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  void _resetFieldToDefault(String key) {
    final defaults = PersonalBudgetState.initial();
    final cubit = context.read<PersonalBudgetCubit>();
    switch (key) {
      case 'salary':
        cubit.updateSalary(defaults.salary);
        _salaryController.text = defaults.salary > 0
            ? defaults.salary.toStringAsFixed(0)
            : '';
        break;
      case 'fixedCosts':
        cubit.updateFixedCosts(defaults.fixedCosts);
        _fixedCostsController.text = defaults.fixedCosts > 0
            ? defaults.fixedCosts.toStringAsFixed(0)
            : '';
        break;
      case 'rent':
        cubit.updateRent(defaults.rent);
        _rentController.text = defaults.rent > 0
            ? defaults.rent.toStringAsFixed(2)
            : '';
        break;
      case 'services':
        cubit.updateServices(defaults.services);
        _servicesController.text = defaults.services > 0
            ? defaults.services.toStringAsFixed(2)
            : '';
        break;
      case 'insurance':
        cubit.updateInsurance(defaults.insurance);
        _insuranceController.text = defaults.insurance > 0
            ? defaults.insurance.toStringAsFixed(2)
            : '';
        break;
      case 'internet':
        cubit.updateInternet(defaults.internet);
        _internetController.text = defaults.internet > 0
            ? defaults.internet.toStringAsFixed(2)
            : '';
        break;
      case 'electricity':
        cubit.updateElectricity(defaults.electricity);
        _electricityController.text = defaults.electricity > 0
            ? defaults.electricity.toStringAsFixed(2)
            : '';
        break;
      case 'water':
        cubit.updateWater(defaults.water);
        _waterController.text = defaults.water > 0
            ? defaults.water.toStringAsFixed(2)
            : '';
        break;
      case 'householdMembers':
        cubit.updateHouseholdMembers(defaults.householdMembers);
        _householdMembersController.text = defaults.householdMembers > 0
            ? defaults.householdMembers.toString()
            : '1';
        break;
      case 'formula':
        cubit.updateFormula(defaults.formula);
        _formulaController.text = defaults.formula;
        break;
      default:
        break;
    }
  }

  void _calculate(PersonalBudgetState state) {
    _formulaError = '';
    final discretionaryIncome = state.salary - state.fixedCosts;
    try {
      final p = GrammarParser();
      final exp = p.parse(state.formula);

      final cm = ContextModel();
      cm.bindVariable(Variable('salary'), Number(state.salary));
      cm.bindVariable(Variable('fixedCosts'), Number(state.fixedCosts));

      cm.bindVariable(
        Variable('householdExpenses'),
        Number(state.householdExpenses),
      );
      cm.bindVariable(
        Variable('householdMembers'),
        Number(state.householdMembers.toDouble()),
      );

      final household = state.householdMembers > 0
          ? state.householdExpenses / state.householdMembers
          : state.householdExpenses;
      cm.bindVariable(Variable('household'), Number(household));

      cm.bindVariable(
        Variable('DiscretionaryIncome'),
        Number(discretionaryIncome),
      );

      final surplus = discretionaryIncome - household;
      final positiveSurplus = surplus > 0 ? surplus : 0.0;
      cm.bindVariable(Variable('Surplus'), Number(positiveSurplus));

      // ignore: deprecated_member_use
      final evalResult = exp.evaluate(EvaluationType.REAL, cm);

      if (evalResult.isNaN || evalResult.isInfinite) {
        _formulaError = 'Invalid result';
        _contribution = 0.0;
      } else {
        _contribution = evalResult.toDouble();
        final minContribution = household;
        if (_contribution < minContribution) {
          _contribution = minContribution;
        }
      }
    } catch (e) {
      _formulaError = 'Syntax error in formula';
      _contribution = 0.0;
    }

    _leftover = discretionaryIncome - _contribution;
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Budget Contribution')),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BlocConsumer<PersonalBudgetCubit, PersonalBudgetState>(
        listener: (context, state) {},
        builder: (context, state) {
          _calculate(state);

          if (double.tryParse(_salaryController.text) != state.salary) {
            _salaryController.text = state.salary > 0
                ? state.salary.toStringAsFixed(0)
                : '';
          }
          if (double.tryParse(_fixedCostsController.text) != state.fixedCosts) {
            _fixedCostsController.text = state.fixedCosts > 0
                ? state.fixedCosts.toStringAsFixed(0)
                : '';
          }
          if (double.tryParse(_householdExpensesController.text) !=
              state.householdExpenses) {
            _householdExpensesController.text = state.householdExpenses > 0
                ? state.householdExpenses.toStringAsFixed(0)
                : '';
          }
          if (double.tryParse(_rentController.text) != state.rent) {
            _rentController.text = state.rent > 0
                ? state.rent.toStringAsFixed(2)
                : '';
          }
          if (double.tryParse(_servicesController.text) != state.services) {
            _servicesController.text = state.services > 0
                ? state.services.toStringAsFixed(2)
                : '';
          }
          if (double.tryParse(_insuranceController.text) != state.insurance) {
            _insuranceController.text = state.insurance > 0
                ? state.insurance.toStringAsFixed(2)
                : '';
          }
          if (double.tryParse(_internetController.text) != state.internet) {
            _internetController.text = state.internet > 0
                ? state.internet.toStringAsFixed(2)
                : '';
          }
          if (double.tryParse(_electricityController.text) !=
              state.electricity) {
            _electricityController.text = state.electricity > 0
                ? state.electricity.toStringAsFixed(2)
                : '';
          }
          if (double.tryParse(_waterController.text) != state.water) {
            _waterController.text = state.water > 0
                ? state.water.toStringAsFixed(2)
                : '';
          }
          if (int.tryParse(_householdMembersController.text) !=
              state.householdMembers) {
            _householdMembersController.text = state.householdMembers > 0
                ? state.householdMembers.toString()
                : '1';
          }
          if (_formulaController.text != state.formula) {
            _formulaController.text = state.formula;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 24.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInputCard(context, state),
                    const SizedBox(height: 24),
                    _buildFormulaCard(context, state),
                    const SizedBox(height: 24),
                    _buildResultsCard(context, state),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputCard(BuildContext context, PersonalBudgetState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Income & Fixed Costs',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('salary'),
              child: TextField(
                controller: _salaryController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monthly Salary',
                  prefixText: '€ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) {
                  final amount = double.tryParse(val) ?? 0.0;
                  context.read<PersonalBudgetCubit>().updateSalary(amount);
                },
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('fixedCosts'),
              child: TextField(
                controller: _fixedCostsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      'Fixed Monthly Costs (personal expenses, subscriptions, etc.)',
                  prefixText: '€ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) {
                  final amount = double.tryParse(val) ?? 0.0;
                  context.read<PersonalBudgetCubit>().updateFixedCosts(amount);
                },
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('rent'),
              child: TextField(
                controller: _rentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Rent',
                  prefixText: '€ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) => context
                    .read<PersonalBudgetCubit>()
                    .updateRent(double.tryParse(val) ?? 0.0),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('services'),
              child: TextField(
                controller: _servicesController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Services',
                  prefixText: '€ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) => context
                    .read<PersonalBudgetCubit>()
                    .updateServices(double.tryParse(val) ?? 0.0),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('insurance'),
              child: TextField(
                controller: _insuranceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Insurance ',
                  prefixText: '€ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) => context
                    .read<PersonalBudgetCubit>()
                    .updateInsurance(double.tryParse(val) ?? 0.0),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('internet'),
              child: TextField(
                controller: _internetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Internet ',
                  prefixText: '€ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) => context
                    .read<PersonalBudgetCubit>()
                    .updateInternet(double.tryParse(val) ?? 0.0),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('electricity'),
              child: TextField(
                controller: _electricityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Electricity ',
                  prefixText: '€ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) => context
                    .read<PersonalBudgetCubit>()
                    .updateElectricity(double.tryParse(val) ?? 0.0),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('water'),
              child: TextField(
                controller: _waterController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Water ',
                  prefixText: '€ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) => context
                    .read<PersonalBudgetCubit>()
                    .updateWater(double.tryParse(val) ?? 0.0),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('householdMembers'),
              child: TextField(
                controller: _householdMembersController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Household Members (divide by)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) {
                  final count = int.tryParse(val) ?? 1;
                  context.read<PersonalBudgetCubit>().updateHouseholdMembers(
                    count,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaCard(BuildContext context, PersonalBudgetState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contribution Formula',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _resetFieldToDefault('formula'),
              child: TextField(
                controller: _formulaController,
                decoration: InputDecoration(
                  labelText: 'Formula',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: _formulaError.isNotEmpty ? _formulaError : null,
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (val) {
                  context.read<PersonalBudgetCubit>().updateFormula(val);
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'AVAILABLE VARIABLES',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 12.0,
                          bottom: 8.0,
                        ),
                        child: Text(
                          'salary',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        'Gross salary — use DiscretionaryIncome (salary - fixedCosts) when you mean after fixed costs',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 12.0,
                          bottom: 8.0,
                        ),
                        child: Text(
                          'fixedCosts',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        'Your fixed monthly costs',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Text(
                          'DiscretionaryIncome',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        'salary - fixedCosts (use DiscretionaryIncome in formulas for after-fixed-cost salary)',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                        child: Text(
                          'householdExpenses',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        'Total household expenses to ',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                        child: Text(
                          'householdMembers',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        'Number of household members (divisor)',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                        child: Text(
                          'household',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        'householdExpenses / householdMembers',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                        child: Text(
                          'Surplus',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        'max(0, DiscretionaryIncome - household)',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context, PersonalBudgetState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _copyToClipboard(_contribution.toStringAsFixed(2)),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.primaryContainer, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    'Contribution Amount (1x)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '€${_contribution.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to copy',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _copyToClipboard(_leftover.toStringAsFixed(2)),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _leftover >= 0
                    ? scheme.tertiaryContainer
                    : scheme.errorContainer,
                width: 1.5,
              ),
            ),
            color: _leftover >= 0
                ? scheme.tertiaryContainer.withValues(alpha: 0.08)
                : scheme.errorContainer.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    'Leftover (After fixed costs & contribution)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _leftover >= 0 ? scheme.tertiary : scheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '€${_leftover.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _leftover >= 0 ? scheme.tertiary : scheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 14,
                        color: _leftover >= 0
                            ? scheme.onTertiaryContainer
                            : scheme.onError,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to copy',
                        style: TextStyle(
                          fontSize: 13,
                          color: _leftover >= 0
                              ? scheme.onTertiaryContainer
                              : scheme.onError,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
