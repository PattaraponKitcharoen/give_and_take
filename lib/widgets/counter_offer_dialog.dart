import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui/primary_button.dart';

class CounterOfferDialog extends StatefulWidget {
  final String offerId;
  final Map<String, dynamic> offerData;
  final String currentUserId;
  final Function(int, bool) onSubmit;

  const CounterOfferDialog(
      {super.key,
      required this.offerId,
      required this.offerData,
      required this.currentUserId,
      required this.onSubmit});

  @override
  State<CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<CounterOfferDialog> {
  final TextEditingController amountController = TextEditingController();
  String offerType = 'give';

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void addCoins(int amount) {
    int current = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
    amountController.text = (current + amount).toString();
  }

  Widget buildSegmentButton(
      String text, IconData icon, String value, Color activeColor) {
    bool isSelected = (value == offerType);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          offerType = value;
          if (value == 'none') amountController.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: isSelected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: isSelected ? AppShadows.raised : null),
          child: Column(children: [
            Icon(icon,
                size: 20,
                color: isSelected ? activeColor : AppColors.inkTertiary),
            const SizedBox(height: 6),
            Text(text,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? activeColor : AppColors.inkTertiary))
          ]),
        ),
      ),
    );
  }

  // 🟢 อัปเดตฟังก์ชันปุ่ม Quick Add ให้เปลี่ยนสีตามโหมด
  Widget _buildQuickAddButton(String text, int amount) {
    Color btnColor =
        offerType == 'give' ? AppColors.primary : AppColors.warning;

    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => addCoins(amount)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          backgroundColor: AppColors.surface,
          side: BorderSide(color: btnColor.withOpacity(0.3)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(text,
                style: AppText.label.copyWith(color: btnColor, fontSize: 14)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 กำหนดสีหลักของช่องกรอกตามโหมดที่เลือก
    Color activeThemeColor =
        offerType == 'give' ? AppColors.primary : AppColors.warning;
    Color activeBgColor = offerType == 'give'
        ? AppColors.primary.withOpacity(0.05)
        : AppColors.warningSoft.withOpacity(0.3);
    Color activeBorderColor = offerType == 'give'
        ? AppColors.primary.withOpacity(0.3)
        : AppColors.warningSoft;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Counter Offer', style: AppText.display),
                          SizedBox(height: 4),
                          Text('ปรับเปลี่ยนข้อเสนอของคุณ',
                              style: AppText.bodySecondary)
                        ]),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.inkSecondary)))
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                  padding: const EdgeInsets.all(5),
                  child: Row(children: [
                    buildSegmentButton('Give Coins', Icons.payments_outlined,
                        'give', AppColors.primary),
                    buildSegmentButton('Trade Only', Icons.handshake_outlined,
                        'none', AppColors.inkSecondary),
                    buildSegmentButton('Ask Coins', Icons.request_page_outlined,
                        'ask', AppColors.warning)
                  ]),
                ),
                const SizedBox(height: 28),
                if (offerType != 'none') ...[
                  // 🟢 อัปเดตช่องกรอกเหรียญให้ใช้สีที่ดักเงื่อนไขไว้
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: activeBgColor,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: activeBorderColor)),
                    child: Row(children: [
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              gradient: AppGradients.of(activeThemeColor),
                              boxShadow: AppShadows.glow(activeThemeColor),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.toll_rounded,
                              color: Colors.white)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink),
                              decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: const TextStyle(
                                      color: AppColors.hairline),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none))),
                      Text('COINS',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: activeThemeColor))
                    ]),
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
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.xl)),
                      child: const Column(children: [
                        Icon(Icons.swap_horiz_rounded,
                            size: 40, color: AppColors.primary),
                        SizedBox(height: 12),
                        Text('แลกของต่อของ',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark)),
                        Text('ไม่มีการใช้เหรียญในข้อเสนอนี้',
                            style: TextStyle(color: AppColors.inkSecondary))
                      ])),
                const SizedBox(height: 32),
                PrimaryButton(
                    height: 56,
                    onPressed: () {
                      int amount = offerType != 'none'
                          ? (int.tryParse(amountController.text) ?? 0)
                          : 0;
                      Navigator.pop(context);
                      widget.onSubmit(amount, offerType == 'give');
                    },
                    child: const Text('Send Counter Offer')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
