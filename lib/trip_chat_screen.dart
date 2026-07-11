import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart' show TayarColors, TayarThemeColors;

/// ====== شاشة المحادثة بين الراكب والطيار ======
/// بتتفعّل بعد قبول الطلب من الطرفين، وبتستخدم subcollection
/// داخل نفس الأوردر: orders/{orderId}/messages
/// عشان الشات يتقفل تلقائيًا مع انتهاء/إلغاء الرحلة (من غير أي تنظيف إضافي).
class TripChatScreen extends StatefulWidget {
  final String orderId;
  final String otherPartyName;

  const TripChatScreen({
    super.key,
    required this.orderId,
    required this.otherPartyName,
  });

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  CollectionReference<Map<String, dynamic>> get _messagesRef => FirebaseFirestore
      .instance
      .collection('orders')
      .doc(widget.orderId)
      .collection('messages');

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;
      await _messagesRef.add({
        'senderId': user?.uid,
        'senderName': user?.displayName ?? '',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // ====== نزول لآخر رسالة بعد الإرسال ======
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      // ====== نوضح سبب فشل الإرسال بدل ما يختفي بصمت (غالبًا صلاحيات Firestore) ======
      debugPrint('❌ خطأ في إرسال الرسالة: $e');
      _controller.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.chatErrorLoadingMessages}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: TayarColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherPartyName,
              style: TextStyle(color: context.textColor, fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('❌ خطأ في تحميل رسائل الشات: ${snapshot.error}');
                  return Center(
                    child: Text(
                      loc.chatErrorLoadingMessages,
                      style:  TextStyle(color: context.textGreyColor),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: TayarColors.primary,
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      loc.chatNoMessagesYet,
                      style:  TextStyle(color: context.textGreyColor),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMe = data['senderId'] == _myUid;
                    final text = (data['text'] as String?) ?? '';
                    final ts = data['createdAt'] as Timestamp?;
                    final timeLabel = ts != null
                        ? TimeOfDay.fromDateTime(ts.toDate()).format(context)
                        : '';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? context.cardColor
                              : TayarColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              text,
                              style:  TextStyle(
                                color: context.textColor,
                                fontSize: 14,
                              ),
                            ),
                            if (timeLabel.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                timeLabel,
                                style: TextStyle(
                                  color: (context.isDarkMode ? context.textColor : Colors.black).withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ====== حقل كتابة الرسالة ======
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.cardColor,
                border: Border(
                  top: BorderSide(
                    color: (context.isDarkMode ? context.textColor : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: context.textColor),
                      decoration: InputDecoration(
                        hintText: loc.chatTypeMessageHint,
                        hintStyle:  TextStyle(
                          color: context.textGreyColor,
                        ),
                        filled: true,
                        fillColor: context.bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: TayarColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          :  Icon(Icons.send, color: context.textColor, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
