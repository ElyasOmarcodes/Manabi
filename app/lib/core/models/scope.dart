/// Restricts a question to one book, one author and/or one category.
class SearchScope {
  const SearchScope({this.bookId, this.bookTitle, this.authorId, this.authorName, this.categoryId, this.categoryTitle});

  static const all = SearchScope();

  final String? bookId;
  final String? bookTitle;
  final String? authorId;
  final String? authorName;
  final String? categoryId;
  final String? categoryTitle;

  bool get isAll => bookId == null && authorId == null && categoryId == null;

  SearchScope withBook(String? id, String? title) => SearchScope(
      bookId: id, bookTitle: title, authorId: authorId, authorName: authorName, categoryId: categoryId, categoryTitle: categoryTitle);
  SearchScope withAuthor(String? id, String? name) => SearchScope(
      bookId: bookId, bookTitle: bookTitle, authorId: id, authorName: name, categoryId: categoryId, categoryTitle: categoryTitle);
  SearchScope withCategory(String? id, String? title) => SearchScope(
      bookId: bookId, bookTitle: bookTitle, authorId: authorId, authorName: authorName, categoryId: id, categoryTitle: title);

  /// The request body shape understood by the server and the local pipeline.
  Map<String, String> toRequest() => {
        'bookId': ?bookId,
        'authorId': ?authorId,
        'categoryId': ?categoryId,
      };

  factory SearchScope.fromJson(Map<String, dynamic>? j) => j == null
      ? all
      : SearchScope(
          bookId: j['bookId'] as String?,
          bookTitle: j['bookTitle'] as String?,
          authorId: j['authorId'] as String?,
          authorName: j['authorName'] as String?,
          categoryId: j['categoryId'] as String?,
          categoryTitle: j['categoryTitle'] as String?,
        );

  Map<String, dynamic> toJson() => {
        if (bookId != null) 'bookId': bookId,
        if (bookTitle != null) 'bookTitle': bookTitle,
        if (authorId != null) 'authorId': authorId,
        if (authorName != null) 'authorName': authorName,
        if (categoryId != null) 'categoryId': categoryId,
        if (categoryTitle != null) 'categoryTitle': categoryTitle,
      };

  @override
  bool operator ==(Object other) =>
      other is SearchScope && other.bookId == bookId && other.authorId == authorId && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(bookId, authorId, categoryId);
}
