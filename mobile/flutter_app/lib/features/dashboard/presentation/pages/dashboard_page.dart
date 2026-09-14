import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/pages/ai_chat_page.dart';
import '../../../../core/services/wallet_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Load wallet balance when page loads
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    final walletService = Provider.of<WalletService>(context, listen: false);
    await walletService.getBalance();
  }

  Future<void> _grantFreeBonus() async {
    final walletService = Provider.of<WalletService>(context, listen: false);
    await walletService.grantFreeTrialBonus();
    // Refresh balance after granting bonus
    await walletService.getBalance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEFACT FACILE Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletBalance,
            tooltip: 'Refresh Balance',
          ),
        ],
      ),
      body: Consumer<WalletService>(
        builder: (context, walletService, child) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: Alignment.center,
              children: [
                // Wallet Balance Section
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          'Token Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${walletService.balance} IA Tokens',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (walletService.isLoading)
                          const SizedBox(height: 10)
                        else
                          ElevatedButton(
                            onPressed: _grantFreeBonus,
                            child: const Text('Grant Free Bonus (500 tokens)'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // AI Chat Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/ai-chat');
                  },
                  icon: const Icon(Icons.robot_2),
                  label: const Text('Chat with AI'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 10),

                // Transaction History Button
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to transaction history page
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction history coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Transaction History'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      // TODO: Add bottom navigation bar
    );
  }
}