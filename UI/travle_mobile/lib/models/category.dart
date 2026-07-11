class Category {
  final int id;
  final String? name;
  final String? description;
  final int? parentCategoryId;
  final bool? isActive;

  Category({
    required this.id,
    this.name,
    this.description,
    this.parentCategoryId,
    this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String?,
      description: json['description'] as String?,
      parentCategoryId: json['parentCategoryId'] as int?,
      isActive: json['isActive'] as bool?,
    );
  }
}
