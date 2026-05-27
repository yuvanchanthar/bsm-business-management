class CategoryModel {
  final String? id;
  final String name;
  final String description;
  final DateTime? createdAt;

  const CategoryModel({
    this.id,
    required this.name,
    this.description = '',
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };
}

class GroupedItemModel {
  final String category;
  final List<String> items;

  const GroupedItemModel({
    required this.category,
    required this.items,
  });

  factory GroupedItemModel.fromJson(Map<String, dynamic> json) {
    return GroupedItemModel(
      category: json['category']?.toString() ?? 'Uncategorized',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) {
                if (e is String) return e;
                if (e is Map && e.containsKey('itemName')) return e['itemName'].toString();
                if (e is Map && e.containsKey('name')) return e['name'].toString();
                return e.toString();
              })
              .toList() ??
          [],
    );
  }
}
