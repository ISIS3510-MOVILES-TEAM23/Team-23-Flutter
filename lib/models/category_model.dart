class SubCategory {
  final String id; // maps from _id
  final String name;
  final String description;

  const SubCategory({
    required this.id,
    required this.name,
    required this.description,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
    };
  }
}

class Category {
  final String id; // maps from _id
  final String name;
  final String description;
  final SubCategory? subcategory;
  final String? icon;

  const Category({
    required this.id,
    required this.name,
    required this.description,
    this.subcategory,
    this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] ?? json['title'] ?? json['label'];
    final name = rawName is String ? rawName : rawName?.toString() ?? '';
    final rawDescription = json['description'] ?? json['subtitle'] ?? '';
    final description = rawDescription is String
        ? rawDescription
        : rawDescription?.toString() ?? '';
    final rawIcon = json['icon'] ?? json['icon_url'] ?? json['image'];
    final icon = rawIcon is String ? rawIcon : rawIcon?.toString();

    return Category(
      id: json['_id'] ?? json['id'] ?? '',
      name: name,
      description: description,
      subcategory: json['subcategory'] != null
          ? SubCategory.fromJson(json['subcategory'])
          : null,
      icon: icon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'subcategory': subcategory?.toJson(),
      if (icon != null) 'icon': icon,
    };
  }
}

