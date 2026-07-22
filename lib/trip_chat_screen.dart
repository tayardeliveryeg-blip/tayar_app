import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart' show TayarColors, TayarThemeColors;
import 'theme_extensions.dart' show AppSpacing, AppRadius;

/// ====== شاشة المحادثة بين الراكب والطيار ======
/// بتتفعّل بعد قبول الطلب من الطرفين، وبتستخدم subcollection
/// داخل نفس الأوردر: orders/{orderId}/messages
/// عشان الشات يتقفل تلقائيًا مع انتهاء/إلغاء الرحلة (من غير أي تنظيف إضافي).
///
/// ====== حالة الرسالة (read receipts) ======
/// كل رسالة بيتسجّلها حقل 'read' (bool). الطرف اللي بيفتح الشاشة بيعلّم
/// أي رسالة مش منه كـ "مقروءة" تلقائيًا. علامة صح واحدة = اتبعتت،
/// علامتين صح ملوّنين = اتقرت.
///
/// ====== مؤشر الكتابة (typing indicator) ======
/// كل مستخدم بيكتب حالته في orders/{orderId}/typing/{uid} مع debounce
/// 3 ثواني، والطرف التاني بيسمع الـ doc ده بس.
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

  String? _otherPartyId;
  bool _isTypingLocally = false;
  Timer? _typingDebounce;
  final Set<String> _markedReadIds = {};

  static const List<String> _quickReplyKeys = [
    'chatQuickReplyOnMyWay',
    'chatQuickReplyArrived',
    'chatQuickReplyWaitPlease',
    'chatQuickReplyOk',
  ];

  DocumentReference<Map<String, dynamic>> get _orderRef =>
      FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _orderRef.collection('messages');

  CollectionReference<Map<String, dynamic>> get _typingRef =>
      _orderRef.collection('typing');

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadOtherPartyId();
  }

  // ====== نجيب معرّف الطرف التاني مرة واحدة من مستند الأوردر نفسه ======
  // (عشان نعرف نسمع مؤشر الكتابة بتاعه في orders/{orderId}/typing/{otherUid})
  Future<void> _loadOtherPartyId() async {
    try {
      final snap = await _orderRef.get();
      final data = snap.data();
      if (data == null || !mounted) return;
      final customerId = data['customerId'] as String?;
      final driverId = data['driverId'] as String?;
      setState(() {
        _otherPartyId = (_myUid == customerId) ? driverId : customerId;
      });
    } catch (e) {
      debugPrint('❌ خطأ في تحميل بيانات الأوردر للشات: $e');
    }
  }

  // ====== تحديث حالة "بيكتب الآن" مع تأخير (debounce) 3 ثواني ======
  void _onTextChanged(String value) {
    if (!_isTypingLocally) {
      _isTypingLocally = true;
      _setTypingStatus(true);
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      _isTypingLocally = false;
      _setTypingStatus(false);
    });
  }

  Future<void> _setTypingStatus(bool isTyping) async {
    if (_myUid.isEmpty) return;
    try {
      await _typingRef.doc(_myUid).set({
        'isTyping': isTyping,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ====== فشل تحديث حالة الكتابة مش خطأ حرج، متجاهلينه بهدوء ======
    }
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    if (quickText == null) _controller.clear();
    _typingDebounce?.cancel();
    _isTypingLocally = false;
    _setTypingStatus(false);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await _messagesRef.add({
        'senderId': user?.uid,
        'senderName': user?.displayName ?? '',
        'text': text,
        'read': false,
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
      if (quickText == null) _controller.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.chatErrorLoadingMessages}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ====== نعلّم أي رسائل جاية من الطرف التاني كـ "مقروءة" بمجرد ما تظهر هنا ======
  void _markIncomingMessagesAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final unread = docs.where((d) {
      final data = d.data();
      return data['senderId'] != _myUid &&
          data['read'] != true &&
          !_markedReadIds.contains(d.id);
    }).toList();
    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in unread) {
      _markedReadIds.add(d.id);
      batch.update(d.reference, {'read': true});
    }
    batch.commit().catchError((e) {
      debugPrint('❌ خطأ في تعليم الرسائل كمقروءة: $e');
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    if (_isTypingLocally) _setTypingStatus(false);
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
        toolbarHeight: 64,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: TayarColors.primary,
              child: Icon(Icons.person, color: context.onPrimaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherPartyName,
                    style: TextStyle(color: context.textColor, fontSize: 16),
                  ),
                  // ====== مؤشر "بيكتب الآن" أسفل اسم الطرف التاني ======
                  Builder(
                    builder: (context) {
                      final otherId = _otherPartyId;
                      if (otherId == null) return const SizedBox.shrink();
                      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _typingRef.doc(otherId).snapshots(),
                        builder: (context, snap) {
                          final data = snap.data?.data();
                          final isTyping = data?['isTyping'] == true;
                          if (!isTyping) return const SizedBox.shrink();
                          return Text(
                            loc.chatTypingIndicator,
                            style: const TextStyle(
                              color: TayarColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
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
                      style: TextStyle(color: context.textGreyColor),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: TayarColors.primary),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      loc.chatNoMessagesYet,
                      style: TextStyle(color: context.textGreyColor),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _markIncomingMessagesAsRead(docs);
                });

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
                    final isRead = data['read'] == true;
                    final ts = data['createdAt'] as Timestamp?;
                    final timeLabel = ts != null
                        ? TimeOfDay.fromDateTime(ts.toDate()).format(context)
                        : '';

                    return _ChatBubble(
                      isMe: isMe,
                      text: text,
                      timeLabel: timeLabel,
                      isRead: isRead,
                    );
                  },
                );
              },
            ),
          ),

          // ====== ردود سريعة جاهزة ======
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _quickReplyKeys.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final label = _quickReplyLabel(loc, _quickReplyKeys[index]);
                return ActionChip(
                  label: Text(label, style: const TextStyle(fontSize: 13)),
                  backgroundColor: context.cardColor,
                  side: BorderSide(color: context.dividerColor2),
                  labelStyle: TextStyle(color: context.textColor),
                  onPressed: _sending ? null : () => _sendMessage(label),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ====== حقل كتابة الرسالة ======
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.cardColor,
                border: Border(
                  top: BorderSide(color: context.textColor.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: context.textColor),
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: loc.chatTypeMessageHint,
                        hintStyle: TextStyle(color: context.textGreyColor),
                        filled: true,
                        fillColor: context.bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : () => _sendMessage(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: TayarColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: context.onPrimaryColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.send, color: context.textColor, size: 20),
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

  String _quickReplyLabel(AppLocalizations loc, String key) {
    switch (key) {
      case 'chatQuickReplyOnMyWay':
        return loc.chatQuickReplyOnMyWay;
      case 'chatQuickReplyArrived':
        return loc.chatQuickReplyArrived;
      case 'chatQuickReplyWaitPlease':
        return loc.chatQuickReplyWaitPlease;
      case 'chatQuickReplyOk':
        return loc.chatQuickReplyOk;
      default:
        return '';
    }
  }
}

// ====================================================
// ====== فقاعة رسالة واحدة (bubble) مع علامات القراءة ======
// ====================================================
class _ChatBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  final String timeLabel;
  final bool isRead;

  const _ChatBubble({
    required this.isMe,
    required this.text,
    required this.timeLabel,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? context.cardColor : TayarColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.xl),
            topRight: const Radius.circular(AppRadius.xl),
            bottomLeft: Radius.circular(isMe ? AppRadius.sm : AppRadius.xl),
            bottomRight: Radius.circular(isMe ? AppRadius.xl : AppRadius.sm),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(color: context.textColor, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: context.textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                // ====== علامات القراءة (بس على رسايلي أنا) ======
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 15,
                    color: isRead
                        ? const Color(0xFF34B7F1)
                        : context.textColor.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
