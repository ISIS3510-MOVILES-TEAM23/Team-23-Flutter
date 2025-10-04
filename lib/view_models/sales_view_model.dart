import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/user_repository.dart';

class SalesViewModel extends ChangeNotifier {
  final PostRepository _postRepository;
  final UserRepository _userRepository;

  SalesViewModel({
    PostRepository? postRepository,
    UserRepository? userRepository,
  })  : _postRepository = postRepository ?? PostRepository(),
        _userRepository = userRepository ?? UserRepository();

  List<PostWithChat> allSales = [];
  List<PostWithChat> pendingSales = [];
  List<PostWithChat> completedSales = [];
  bool isLoading = true;

  Future<void> loadSalesData() async {
    try {
      isLoading = true;
      notifyListeners();

      final user = await _userRepository.getCurrentUser();
      final sales = await _postRepository.getUserPostsWithChats(user?.id ?? '');

      allSales = sales;
      pendingSales = sales
          .where((s) =>
              s.sale?.status == 'pending' ||
              s.sale?.status == 'acknowledged' ||
              (s.sale == null && s.chatId != null))
          .toList();
      completedSales =
          sales.where((s) => s.sale?.status == 'completed').toList();
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  String formatDollars(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  Color getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF4CAF50); // AppColors.success
      case 'canceled':
        return const Color(0xFFF44336); // AppColors.error
      case 'acknowledged':
        return Colors.blue;
      default:
        return const Color(0xFFFFA726); // AppColors.warning
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'canceled':
        return 'Canceled';
      case 'acknowledged':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }
}

