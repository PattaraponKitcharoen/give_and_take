import 'package:flutter/material.dart';

class CounterOfferDialog extends StatefulWidget {
  final String offerId; 
  final Map<String, dynamic> offerData; 
  final String currentUserId;
  final Function(int, bool) onSubmit;

  const CounterOfferDialog({
    super.key, 
    required this.offerId, 
    required this.offerData, 
    required this.currentUserId, 
    required this.onSubmit
  });

  @override
  State<CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<CounterOfferDialog> {
  final TextEditingController amountController = TextEditingController();
  String offerType = 'give';

  void addCoins(int amount) {
    int current = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
    amountController.text = (current + amount).toString();
  }

  Widget buildSegmentButton(String text, IconData icon, String value, Color activeColor) {
    bool isSelected = (value == offerType);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { offerType = value; if(value == 'none') amountController.clear(); }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : []),
          child: Column(children: [Icon(icon, size: 20, color: isSelected ? activeColor : Colors.grey.shade400), const SizedBox(height: 6), Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? activeColor : Colors.grey.shade500))]),
        ),
      ),
    );
  }

  // 🟢 อัปเดตฟังก์ชันปุ่ม Quick Add ให้เปลี่ยนสีตามโหมด
  Widget _buildQuickAddButton(String text, int amount) {
    Color btnColor = offerType == 'give' ? const Color(0xFF008080) : Colors.orange;
    
    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => addCoins(amount)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          side: BorderSide(color: btnColor.withOpacity(0.4), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: btnColor)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 กำหนดสีหลักของช่องกรอกตามโหมดที่เลือก
    Color activeThemeColor = offerType == 'give' ? const Color(0xFF008080) : Colors.orange;
    Color activeBgColor = offerType == 'give' ? const Color(0xFF008080).withOpacity(0.05) : Colors.orange.shade50.withOpacity(0.3);
    Color activeBorderColor = offerType == 'give' ? const Color(0xFF008080).withOpacity(0.3) : Colors.orange.shade200;

    return Dialog(
      backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), 
        behavior: HitTestBehavior.opaque, 
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Counter Offer', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('ปรับเปลี่ยนข้อเสนอของคุณ', style: TextStyle(fontSize: 14, color: Colors.blueGrey))]),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.black54)))
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.all(6),
                  child: Row(children: [buildSegmentButton('Give Coins', Icons.payments_outlined, 'give', const Color(0xFF008080)), buildSegmentButton('Trade Only', Icons.handshake_outlined, 'none', Colors.blueGrey), buildSegmentButton('Ask Coins', Icons.request_page_outlined, 'ask', Colors.orange)]),
                ),
                const SizedBox(height: 28),
                
                if (offerType != 'none') ...[
                  // 🟢 อัปเดตช่องกรอกเหรียญให้ใช้สีที่ดักเงื่อนไขไว้
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: activeBgColor, 
                      borderRadius: BorderRadius.circular(20), 
                      border: Border.all(color: activeBorderColor, width: 1.5)
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(color: activeThemeColor, shape: BoxShape.circle), 
                          child: const Icon(Icons.attach_money, color: Colors.white)
                        ), 
                        const SizedBox(width: 16), 
                        Expanded(
                          child: TextField(
                            controller: amountController, 
                            keyboardType: TextInputType.number, 
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900), 
                            decoration: InputDecoration(hintText: '0', hintStyle: TextStyle(color: Colors.grey.shade300), border: InputBorder.none)
                          )
                        ), 
                        Text('COINS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: activeThemeColor))
                      ]
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildQuickAddButton('+50', 50),
                      const SizedBox(width: 4),
                      _buildQuickAddButton('+100', 100),
                      const SizedBox(width: 4),
                      _buildQuickAddButton('+200', 200),
                      const SizedBox(width: 4),
                      _buildQuickAddButton('+500', 500),
                    ],
                  ),
                ] else
                  Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 32), decoration: BoxDecoration(color: const Color(0xFF008080).withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF008080).withOpacity(0.2))), child: const Column(children: [Icon(Icons.sync_alt, size: 40, color: Color(0xFF008080)), SizedBox(height: 12), Text('แลกของต่อของ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF008080))), Text('ไม่มีการใช้เหรียญในข้อเสนอนี้', style: TextStyle(color: Colors.blueGrey))])),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 56, 
                  child: ElevatedButton(
                    onPressed: () { 
                      int amount = offerType != 'none' ? (int.tryParse(amountController.text) ?? 0) : 0; 
                      Navigator.pop(context); 
                      widget.onSubmit(amount, offerType == 'give'); 
                    }, 
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), 
                    child: const Text('Send Counter Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}