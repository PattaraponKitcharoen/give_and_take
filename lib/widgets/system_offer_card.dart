import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/transaction/transaction_cubit.dart';
import '../cubits/transaction/transaction_state.dart'; 
import '../repositories/offer_repository.dart';
import '../models/listing_model.dart';
import '../models/message_model.dart';
import '../models/offer_model.dart';
import '../screens/item_detail_screen.dart'; 

class SystemOfferCard extends StatelessWidget {
  final MessageModel msg;
  final String? activeOfferId;
  final String currentUserId;
  final VoidCallback onCancel;
  final VoidCallback onReject;
  final VoidCallback onAccept;
  final Function(Map<String, dynamic>) onCounter;
  final VoidCallback onVerifyOtp;
  final VoidCallback onCancelDeal;
  final Function(String, String) onOpenRating;
  final bool isSubmitting;

  const SystemOfferCard({
    super.key, required this.msg, required this.activeOfferId, required this.currentUserId,
    required this.onCancel, required this.onReject, required this.onAccept, required this.onCounter,
    required this.onVerifyOtp, required this.onCancelDeal, required this.onOpenRating,
    this.isSubmitting = false,
  });

  Widget _buildItemThumbnail(BuildContext context, ListingModel? item) {
    if (item == null) return const SizedBox(width: 80, height: 100);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(listing: item)));
      },
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: (item.thumbnailUrl != '') 
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item.thumbnailUrl, fit: BoxFit.cover))
                : const Icon(Icons.image, color: Colors.grey, size: 30),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(item.title, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offerData = msg.offerData;
    final targetItem = offerData?.targetItem;
    final offeredItem = offerData?.offeredItem;
    
    bool isSender = (msg.senderId == currentUserId);
    var myItemData = isSender ? offeredItem : targetItem;
    var theirItemData = isSender ? targetItem : offeredItem;

    if (activeOfferId == null || activeOfferId!.isEmpty) {
      return const SizedBox();
    }

    return StreamBuilder<OfferModel>(
      stream: context.read<OfferRepository>().getOfferStream(activeOfferId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
        }

        OfferModel? currentOffer = snapshot.data;
        String offerStatus = currentOffer?.status ?? 'pending';
        String lastOfferBy = currentOffer?.lastOfferBy ?? currentOffer?.senderId ?? '';
        bool isMyTurn = (lastOfferBy != currentUserId); 
        int currentOffset = currentOffer?.coinOffset ?? 0;
        
        String offsetText = 'แลกของต่อของ (ไม่มีการเพิ่มเหรียญ)'; 
        Color offsetColor = Colors.black54;

        if (currentOffset > 0) {
          bool iAmSender = (currentUserId == currentOffer?.senderId);
          offsetText = iAmSender ? 'คุณเสนอจ่ายเพิ่ม $currentOffset Coins' : 'อีกฝ่ายเสนอจ่ายเพิ่ม $currentOffset Coins';
          offsetColor = iAmSender ? Colors.red : Colors.green;
        } else if (currentOffset < 0) {
          bool iAmSender = (currentUserId == currentOffer?.senderId);
          offsetText = iAmSender ? 'คุณขอรับเงินเพิ่ม ${currentOffset.abs()} Coins' : 'อีกฝ่ายขอรับเงินเพิ่ม ${currentOffset.abs()} Coins';
          offsetColor = iAmSender ? Colors.green : Colors.red;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF008080), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              const Text('ข้อเสนอแลกเปลี่ยน', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildItemThumbnail(context, theirItemData),
                  const Icon(Icons.sync_alt, color: Color(0xFF008080), size: 32),
                  _buildItemThumbnail(context, myItemData),
                ],
              ),
              const Divider(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.monetization_on, color: offsetColor, size: 16), const SizedBox(width: 8), Text(offsetText, style: TextStyle(color: offsetColor, fontWeight: FontWeight.bold, fontSize: 13))],
                ),
              ),
              const Divider(height: 16),
              if (offerStatus == 'pending') ...[
                if (!isMyTurn)
                  Column(
                    children: [
                      const Text('รออีกฝ่ายพิจารณาข้อเสนอ...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onCancel, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('ยกเลิกข้อเสนอ'))),
                    ]
                  )
                else 
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: onReject, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('ปฏิเสธ'))),
                          const SizedBox(width: 10),
                          Expanded(child: ElevatedButton(onPressed: () {
                            if (currentOffer != null) {
                              onCounter(currentOffer.toJson());
                            }
                          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('ต่อรอง', style: TextStyle(color: Colors.white)))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity, 
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : onAccept, 
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)), 
                          child: isSubmitting 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('ยอมรับข้อเสนอ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        )
                      ),
                    ],
                  )
              ] else if (offerStatus == 'accepted' || offerStatus == 'in_progress') ...[
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('ตกลงแลกเปลี่ยนแล้ว', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                BlocBuilder<TransactionCubit, TransactionState>(
                  builder: (context, txState) {
                    if (txState is TransactionInitial || txState is TransactionLoading) {
                      if (activeOfferId != null && activeOfferId!.isNotEmpty) {
                        context.read<TransactionCubit>().listenToTransactionByOfferId(activeOfferId!);
                      }
                      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                    }
                    if (txState is TransactionLoaded) {
                      var codes = txState.currentTransaction.verificationCodes ?? {};
                      String myCode = codes[currentUserId] ?? '------';
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Column(children: [const Text('รหัสของคุณ (ให้อีกฝ่ายกรอก)', style: TextStyle(color: Colors.black54)), Text(myCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 5, color: Color(0xFF008080)))])),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onVerifyOtp, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)), child: const Text('กรอกรหัสของอีกฝ่าย', style: TextStyle(color: Colors.white)))),
                          const SizedBox(height: 8),
                          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onCancelDeal, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('ยกเลิกดีลนี้'))),
                        ],
                      );
                    }
                    return const SizedBox();
                  }
                )
              ] else ...[
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: offerStatus == 'completed' ? Colors.green.shade50 : (offerStatus == 'rejected' ? Colors.orange.shade50 : Colors.red.shade50), borderRadius: BorderRadius.circular(8)), child: Text(offerStatus == 'completed' ? 'แลกเปลี่ยนสำเร็จสมบูรณ์' : (offerStatus == 'rejected' ? 'ถูกปฏิเสธ' : 'ถูกยกเลิกแล้ว'), style: TextStyle(fontWeight: FontWeight.bold, color: offerStatus == 'completed' ? Colors.green : (offerStatus == 'rejected' ? Colors.orange : Colors.red)))),
                if (offerStatus == 'completed') ...[
                  BlocBuilder<TransactionCubit, TransactionState>(
                    builder: (context, txState) {
                      if (txState is TransactionLoaded) {
                        final tx = txState.currentTransaction;
                        String transactionId = tx.transactionId;
                        String partnerId = tx.members.firstWhere((id) => id != currentUserId, orElse: () => '');
                        
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            SizedBox(width: double.infinity, child: ElevatedButton.icon(
                              onPressed: () => onOpenRating(partnerId, transactionId), 
                              icon: const Icon(Icons.star, color: Colors.white, size: 20), 
                              label: const Text('จัดการคะแนน/รีวิว', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700)
                            )),
                          ],
                        );
                      }
                      return const SizedBox();
                    }
                  )
                ]
              ]
            ],
          ),
        );
      },
    );
  }
}