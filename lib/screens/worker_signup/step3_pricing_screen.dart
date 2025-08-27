import 'package:flutter/material.dart';
import 'step4_schedule_screen.dart';
import '../../models/worker_onboarding_data.dart';

class Step3PricingScreen extends StatefulWidget {
  static const routeName = '/step3-pricing';
  final WorkerOnboardingData onboardingData;

  const Step3PricingScreen({super.key, required this.onboardingData});

  @override
  State<Step3PricingScreen> createState() => _Step3PricingScreenState();
}

class _Step3PricingScreenState extends State<Step3PricingScreen> {
  String _selectedPaymentMethod = "Cash";
  final Map<String, String> _skillRates = {};
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();

  final Map<String, String> _averageMarketPrices = {
    "Regular House Cleaning": "₹300–500",
    "Deep Cleaning": "₹800–1500",
    "Post-Renovation Cleaning": "₹1000–2000",
    "Kitchen Deep Cleaning": "₹400–700",
    "Men's Haircut": "₹100–300",
    "Women's Haircut & Styling": "₹200–500",
    "Facial & Cleanup": "₹300–800",
    "Manicure & Pedicure": "₹200–500",
    "Eyebrow Threading": "₹50–150",
    "AC Servicing & Repair": "₹300–800",
    "Washing Machine Repair": "₹200–600",
    "Refrigerator Repair": "₹250–700",
    "TV & Electronics Repair": "₹200–1000",
    "Plumbing Services": "₹200–800",
    "Electrical Work": "₹200–600",
    "Painting Services": "₹15–25/sq ft",
    "Carpenter Services": "₹300–800",
  };

  void _proceedToNextStep() {
    if (_skillRates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter rates for your skills.")),
      );
      return;
    }

    if (_selectedPaymentMethod == "UPI" && _upiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your UPI ID.")),
      );
      return;
    }

    if (_selectedPaymentMethod == "Bank" &&
        (_accountController.text.trim().isEmpty ||
            _ifscController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your bank details.")),
      );
      return;
    }

    final updatedData = widget.onboardingData.copyWith(
      paymentMethod: _selectedPaymentMethod,
      wageMap: _skillRates, // Make sure you added this to your data model
      upiId: _upiController.text.trim(),
      bankAccountNumber: _accountController.text.trim(),
      ifscCode: _ifscController.text.trim(),
    );

    Navigator.pushNamed(
      context,
      Step4ScheduleScreen.routeName,
      arguments: updatedData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.onboardingData.skills;

    return Scaffold(
      appBar: AppBar(title: const Text("Pricing")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            LinearProgressIndicator(value: 0.6, color: Colors.deepPurple),
            const SizedBox(height: 24),

            const Text(
              "Set Your Rates",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ...skills.map((skill) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (_averageMarketPrices.containsKey(skill))
                      Text(
                        "Avg: ${_averageMarketPrices[skill]}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Your price (₹)",
                        hintText: "Enter your rate",
                      ),
                      onChanged: (val) {
                        _skillRates[skill] = val;
                      },
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),
            const Text(
              "Preferred Payment Method",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            RadioListTile<String>(
              title: const Text("Cash"),
              value: "Cash",
              groupValue: _selectedPaymentMethod,
              onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
            ),
            RadioListTile<String>(
              title: const Text("UPI Transfer"),
              value: "UPI",
              groupValue: _selectedPaymentMethod,
              onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
            ),
            if (_selectedPaymentMethod == "UPI")
              TextFormField(
                controller: _upiController,
                decoration: const InputDecoration(
                  labelText: "Enter your UPI ID",
                ),
              ),
            RadioListTile<String>(
              title: const Text("Bank Transfer"),
              value: "Bank",
              groupValue: _selectedPaymentMethod,
              onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
            ),
            if (_selectedPaymentMethod == "Bank")
              Column(
                children: [
                  TextFormField(
                    controller: _accountController,
                    decoration: const InputDecoration(
                      labelText: "Bank Account Number",
                    ),
                  ),
                  TextFormField(
                    controller: _ifscController,
                    decoration: const InputDecoration(labelText: "IFSC Code"),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedToNextStep,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
