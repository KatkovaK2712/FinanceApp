import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_models.dart';
import '../services/transaction_service.dart';
import 'add_transaction_sheet.dart';
import 'edit_transaction_sheet.dart';

class RegularPaymentsScreen extends StatefulWidget {
  const RegularPaymentsScreen({super.key});

  @override
  State<RegularPaymentsScreen> createState() => _RegularPaymentsScreenState();
}

class _RegularPaymentsScreenState extends State<RegularPaymentsScreen> {
  List<Transaction> _regularPayments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegularPayments();
  }

  Future<void> _loadRegularPayments() async {
    setState(() => _isLoading = true);
    try {
      final allTransactions = await TransactionService.loadTransactions();
      setState(() {
        _regularPayments = allTransactions.where((t) => t.isRecurring).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Ошибка: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addRegularPayment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(
        onTransactionAdded: (transaction) async {
          final allTransactions = await TransactionService.loadTransactions();
          allTransactions.add(transaction);
          await TransactionService.saveTransactions(allTransactions);
          _loadRegularPayments();
        },
      ),
    );
  }

  void _editRegularPayment(Transaction payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditTransactionSheet(
        transaction: payment,
        onTransactionUpdated: (updated) async {
          final transactions = await TransactionService.loadTransactions();
          final index = transactions.indexWhere((t) => t.id == updated.id);
          if (index != -1) {
            transactions[index] = updated;
            await TransactionService.saveTransactions(transactions);
            _loadRegularPayments();
          }
        },
        onTransactionDeleted: (id) async {
          final transactions = await TransactionService.loadTransactions();
          transactions.removeWhere((t) => t.id == id);
          await TransactionService.saveTransactions(transactions);
          _loadRegularPayments();
        },
      ),
    );
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.00', 'ru_RU');
    return '${formatter.format(amount)} ₽';
  }

  String _getFrequencyText(String frequency, int interval) {
    switch (frequency) {
      case 'day': return interval == 1 ? 'каждый день' : 'каждые $interval дня';
      case 'week': return interval == 1 ? 'каждую неделю' : 'каждые $interval недели';
      case 'month': return interval == 1 ? 'каждый месяц' : 'каждые $interval месяца';
      case 'year': return interval == 1 ? 'каждый год' : 'каждые $interval года';
      default: return 'каждый месяц';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Регулярные платежи'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addRegularPayment,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _regularPayments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Нет регулярных платежей'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _addRegularPayment,
                        child: const Text('Добавить'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _regularPayments.length,
                  itemBuilder: (context, index) {
                    final payment = _regularPayments[index];
                    final isExpense = payment.type == TransactionType.expense;
                    final frequency = _getFrequencyText(
                      payment.recurringFrequency ?? 'month',
                      payment.recurringInterval ?? 1
                    );
                    
                    return Dismissible(
                      key: Key(payment.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        final confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить'),
                            content: const Text('Удалить этот регулярный платеж?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final transactions = await TransactionService.loadTransactions();
                          transactions.removeWhere((t) => t.id == payment.id);
                          await TransactionService.saveTransactions(transactions);
                          _loadRegularPayments();
                        }
                        return false;
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () => _editRegularPayment(payment),
                          leading: CircleAvatar(
                            backgroundColor: isExpense ? Colors.red.shade100 : Colors.green.shade100,
                            child: Icon(
                              isExpense ? Icons.trending_down : Icons.trending_up,
                              color: isExpense ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(
                            payment.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(payment.category),
                              if (payment.subCategory != null)
                                Text(payment.subCategory!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              Text(frequency, style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                            ],
                          ),
                          trailing: Text(
                            '${isExpense ? '-' : '+'}${_formatAmount(payment.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isExpense ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}