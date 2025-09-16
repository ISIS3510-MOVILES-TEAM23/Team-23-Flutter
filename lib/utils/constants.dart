class AppConstants {
  // App Info
  static const String appName = 'Campus Marketplace';
  static const String appTagline = 'Find what you need, sell what you don\'t';
  
  // API Configuration (para cuando se conecte con backend real)
  static const String apiBaseUrl = 'https://api.campusmarketplace.com';
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // Image Configuration
  static const int maxImageUpload = 5;
  static const double maxImageSizeMB = 10.0;
  static const List<String> allowedImageFormats = ['jpg', 'jpeg', 'png', 'gif'];
  
  // Product Configuration
  static const int minTitleLength = 3;
  static const int maxTitleLength = 100;
  static const int minDescriptionLength = 10;
  static const int maxDescriptionLength = 1000;
  static const double minPrice = 0.01;
  static const double maxPrice = 100000.00;
  
  // Chat Configuration
  static const int maxMessageLength = 500;
  static const Duration messagePollingInterval = Duration(seconds: 5);
  
  // Pagination
  static const int itemsPerPage = 20;
  static const int initialPage = 1;
}

class AppStrings {
  // Common
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String save = 'Save';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String sortBy = 'Sort By';
  static const String apply = 'Apply';
  static const String reset = 'Reset';
  static const String seeAll = 'See all';
  static const String noResults = 'No results found';
  
  // Home Screen
  static const String highlightedProducts = '🔥 Highlighted Products for you!';
  static const String newProducts = '🆕 New Products';
  static const String searchPlaceholder = 'Search for products...';
  
  // Categories
  static const String categories = 'Categories';
  static const String allCategories = 'All Categories';
  
  // Product Details
  static const String description = 'Description';
  static const String seller = 'Seller';
  static const String condition = 'Condition';
  static const String price = 'Price';
  static const String contactSeller = 'Contact Seller';
  static const String productSold = 'Product Sold';
  static const String views = 'views';
  static const String daysAgo = 'days ago';
  
  // Create Post
  static const String createPost = 'Create Post';
  static const String postProduct = 'Post Product';
  static const String photos = 'Photos';
  static const String addPhotos = 'Add up to 5 photos';
  static const String addPhoto = 'Add Photo';
  static const String title = 'Title';
  static const String enterTitle = 'Enter product title';
  static const String enterDescription = 'Describe your product...';
  static const String selectCategory = 'Select a category';
  static const String productPosted = 'Product posted successfully!';
  static const String failedToPost = 'Failed to post product';
  static const String addAtLeastOneImage = 'Please add at least one image';
  
  // Messages
  static const String messages = 'Messages';
  static const String noMessages = 'No messages yet';
  static const String startConversation = 'Start a conversation by contacting a seller';
  static const String typeMessage = 'Type a message...';
  static const String failedToSend = 'Failed to send message';
  static const String conversationNotFound = 'Conversation not found';
  static const String justNow = 'Just now';
  
  // Profile
  static const String profile = 'Profile';
  static const String myProducts = 'My Products';
  static const String purchases = 'Purchases';
  static const String favorites = 'Favorites';
  static const String pending = 'Pending';
  static const String editProfile = 'Edit Profile';
  static const String name = 'Name';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String newPassword = 'New Password (optional)';
  static const String profileUpdated = 'Profile updated successfully';
  static const String sales = 'sales';
  static const String products = 'Products';
  static const String noProductsYet = 'No products posted yet';
  static const String noPurchasesYet = 'No purchases yet';
  static const String noFavoritesYet = 'No favorites yet';
  static const String noPendingTransactions = 'No pending transactions';
  
  // Filters
  static const String filters = 'Filters';
  static const String priceRange = 'Price Range';
  static const String minPrice = 'Min Price';
  static const String maxPrice = 'Max Price';
  static const String conditionNew = 'New';
  static const String conditionLikeNew = 'Like New';
  static const String conditionGood = 'Good';
  static const String conditionFair = 'Fair';
  static const String newestFirst = 'Newest First';
  static const String priceLowToHigh = 'Price: Low to High';
  static const String priceHighToLow = 'Price: High to Low';
  static const String mostPopular = 'Most Popular';
  
  // Validation Messages
  static const String requiredField = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email';
  static const String invalidPrice = 'Please enter a valid price';
  static const String titleTooShort = 'Title must be at least 3 characters';
  static const String titleTooLong = 'Title must be less than 100 characters';
  static const String descriptionTooShort = 'Description must be at least 10 characters';
  static const String descriptionTooLong = 'Description must be less than 1000 characters';
  
  // Error Messages
  static const String somethingWentWrong = 'Something went wrong';
  static const String checkInternetConnection = 'Please check your internet connection';
  static const String tryAgainLater = 'Please try again later';
  static const String productNotFound = 'Product not found';
  static const String userNotFound = 'User not found';
  
  // Success Messages
  static const String changesSaved = 'Changes saved successfully';
  static const String productDeleted = 'Product deleted successfully';
  static const String addedToFavorites = 'Added to favorites';
  static const String removedFromFavorites = 'Removed from favorites';
  
  // Confirmation Messages
  static const String areYouSure = 'Are you sure?';
  static const String deleteProductConfirm = 'Are you sure you want to delete this product?';
  static const String logoutConfirm = 'Are you sure you want to log out?';
  static const String unsavedChanges = 'You have unsaved changes. Are you sure you want to leave?';
}