import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/chat_api.dart';

class MessagesViewModel extends ChangeNotifier {
  final ChatApi _chatApi;

  MessagesViewModel({ChatApi? chatApi}) : _chatApi = chatApi ?? ChatApi();

  StreamSubscription<List<ProductChat>>? _subscription;
  bool isLoading = true;

  List<ProductChat> buyersChats = [];
  List<ProductChat> sellersChats = [];

  Future<void> loadChats() async {
    isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _chatApi.streamUserChats().listen(
      (chats) {
        final buyers = <ProductChat>[];
        final sellers = <ProductChat>[];

        for (final c in chats) {
          if (c.isBuyer) {
            sellers.add(c);
          } else {
            buyers.add(c);
          }
        }

        int cmp(ProductChat a, ProductChat b) {
          final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        }

        buyers.sort(cmp);
        sellers.sort(cmp);

        buyersChats = buyers;
        sellersChats = sellers;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    await loadChats();
  }

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) return '${dateTime.year}';
    if (difference.inDays > 30) return '${dateTime.day}/${dateTime.month}';
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Ahora';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

