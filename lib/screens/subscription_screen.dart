import 'package:flutter/material.dart';

class SubscriptionScreen extends StatelessWidget {
  static const routeName = '/subscription';

  const SubscriptionScreen({super.key});

  final List<Map<String, dynamic>> plans = const [
    {
      "title": "Basic Plan",
      "price": "Free",
      "features": [
        "Limited job access",
        "Basic support",
        "No promotions",
      ],
    },
    {
      "title": "Pro Plan",
      "price": "₹199/month",
      "features": [
        "Unlimited job access",
        "Priority support",
        "Highlighted in search",
        "Withdrawal access",
      ],
    },
    {
      "title": "Elite Plan",
      "price": "₹399/month",
      "features": [
        "Everything in Pro",
        "Top search ranking",
        "Featured profile badge",
        "Personal account manager",
      ],
    },
  ];

  void _subscribeToPlan(BuildContext context, String plan) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Subscribe to $plan"),
        content: Text("Your subscription to $plan has been activated."),
        actions: [
          TextButton(
            child: Text("OK", style: TextStyle(color: Colors.deepPurple)),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context, Map<String, dynamic> plan) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan['title'],
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(plan['price'], style: TextStyle(color: Colors.deepPurple)),
            SizedBox(height: 12),
            ...List.generate(plan['features'].length, (i) {
              return Row(
                children: [
                  Icon(Icons.check, color: Colors.green, size: 18),
                  SizedBox(width: 6),
                  Expanded(child: Text(plan['features'][i])),
                ],
              );
            }),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _subscribeToPlan(context, plan['title']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text("Subscribe"),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Subscription Plans"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          Text(
            "Choose a plan that suits your needs",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 20),
          ...plans.map((plan) => _planCard(context, plan)).toList(),
        ],
      ),
    );
  }
}
