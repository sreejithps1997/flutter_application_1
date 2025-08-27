import 'package:flutter/material.dart';

class BookingDetailScreen extends StatelessWidget {
  static const routeName = '/booking-detail'; // ✅ For route-based navigation

  final Map<String, dynamic> booking;

  const BookingDetailScreen({Key? key, required this.booking})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(booking['status'] ?? 'Pending');

    return Scaffold(
      appBar: AppBar(
        title: Text("Booking Details"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow("Service", booking['service'] ?? 'Not specified'),
            _detailRow("Date", booking['date'] ?? 'N/A'),
            _detailRow("Time", booking['time'] ?? 'N/A'),
            _detailRow("Location", booking['location'] ?? 'Not provided'),
            _detailRow("Customer Name", booking['customerName'] ?? 'Anonymous'),
            _detailRow("Phone", booking['customerPhone'] ?? 'N/A'),
            _detailRow("Issue", booking['description'] ?? 'No description'),
            _detailRow("Payment Method", booking['payment'] ?? 'Cash'),
            SizedBox(height: 12),
            Row(
              children: [
                Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(
                    booking['status'] ?? 'Pending',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: statusColor,
                ),
              ],
            ),
            Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implement cancel logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Booking cancellation requested"),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                    child: Text("Cancel Booking"),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement reschedule flow
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Reschedule screen coming soon"),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: Text("Reschedule"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title: ",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}
